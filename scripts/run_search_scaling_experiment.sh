#!/usr/bin/env bash
set -euo pipefail

# Experiment: Search API P95 vs Horizontal Scaling (2,5,10 tasks)
# This pins autoscaling by setting min=max=desired for each step to avoid interference.
#
# Prereqs: terraform, aws cli, jq, locust
# Usage: bash scripts/run_search_scaling_experiment.sh

ENV_DIR="infrastructure/environments/dev"
RESULTS_DIR="loadtest/results"
LOCUST_FILE="loadtest/experiments/search_scaling_p95_experiment.py"
REGION=$(terraform -chdir="$ENV_DIR" output -raw aws_region 2>/dev/null || echo "us-west-2")

mkdir -p "$RESULTS_DIR"

ALB_URL=$(terraform -chdir="$ENV_DIR" output -raw alb_url)
ECS_CLUSTER=$(terraform -chdir="$ENV_DIR" output -raw ecs_cluster_name)
SEARCH_SVC=$(terraform -chdir="$ENV_DIR" output -raw search_api_service_name)

wait_service_stable() {
  local cluster="$1"
  local service="$2"
  echo "Waiting for ECS service $service to be stable..."
  while true; do
    OUT=$(aws ecs describe-services --cluster "$cluster" --services "$service" --region "$REGION" \
      --query "services[0].{Desired:desiredCount,Running:runningCount,Status:status}" --output json)
    DESIRED=$(echo "$OUT" | jq -r '.Desired')
    RUNNING=$(echo "$OUT" | jq -r '.Running')
    STATUS=$(echo "$OUT" | jq -r '.Status')
    echo "Status=$STATUS Desired=$DESIRED Running=$RUNNING"
    if [[ "$STATUS" == "ACTIVE" && "$DESIRED" == "$RUNNING" && "$DESIRED" != "null" ]]; then
      break
    fi
    sleep 10
  done
}

run_locust() {
  local label="$1"
  echo "Running Locust for desired_count=$label ..."
  # Step-load: 50 -> 500 users over 5 minutes (50 users every 30s)
  locust -f "$LOCUST_FILE" --host="$ALB_URL" --headless \
    --users 500 --step-load --step-users 50 --step-time 30s \
    --run-time 15m \
    --html "${RESULTS_DIR}/search_p95_scaling_${label}.html" \
    --csv "${RESULTS_DIR}/search_p95_scaling_${label}"
}

for desired in 2 5 10; do
  echo "Pinning Search API to desired=${desired} (min=max=desired) ..."
  terraform -chdir="$ENV_DIR" apply -auto-approve \
    -var="search_api_desired_count=${desired}" \
    -var="search_api_min_count=${desired}" \
    -var="search_api_max_count=${desired}"

  wait_service_stable "$ECS_CLUSTER" "$SEARCH_SVC"
  run_locust "$desired"
done

echo "Experiment complete. Results in ${RESULTS_DIR}"



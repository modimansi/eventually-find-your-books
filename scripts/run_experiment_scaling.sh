#!/usr/bin/env bash
set -euo pipefail

# Experiment 1: ALB P95 Latency vs Horizontal Scaling
# Runs Locust against the Search API for desired counts: 2, 5, 10
# Requires: terraform, aws cli, locust (pip install locust)

ENV_DIR="infrastructure/environments/dev"
RESULTS_DIR="loadtest/results"
LOCUST_FILE="loadtest/experiments/search_only_scaling.py"
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
  local desired="$1"
  echo "Running Locust for desired_count=$desired ..."
  # Step-load to approximate 0->500 over 5 minutes (50 users every 30s)
  locust -f "$LOCUST_FILE" --host="$ALB_URL" --headless \
    --users 500 --step-load --step-users 50 --step-time 30s \
    --run-time 15m \
    --html "${RESULTS_DIR}/alb_p95_scaling_${desired}.html" \
    --csv "${RESULTS_DIR}/alb_p95_scaling_${desired}"
}

for desired in 2 5 10; do
  echo "Applying search_api_desired_count=${desired} ..."
  terraform -chdir="$ENV_DIR" apply -auto-approve -var="search_api_desired_count=${desired}"
  wait_service_stable "$ECS_CLUSTER" "$SEARCH_SVC"
  run_locust "$desired"
done

echo "Experiment complete. Results in ${RESULTS_DIR}"



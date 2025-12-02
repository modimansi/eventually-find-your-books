# Recommendation API – Cache TTL Experiment

Objective: Measure how p95 latency and throughput change with different cache configurations for the Recommendation API (no cache, 5m TTL, 60m TTL). Also compare cold (0–5m) vs warm (15–20m) periods.

## Prerequisites
- Terraform, AWS CLI, Docker, Locust installed
- Environment already applied (`infrastructure/environments/dev`)
- ALB DNS: `http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com`

## One-time setup (already in repo)
- Experiment file: `loadtest/experiments/reco_cache_ttl_experiment.py`
- Service is routed from ALB: `/recommendations/*`
- Health endpoint exists: `/health`
- Metrics endpoint exists: `/metrics` (Prometheus format)

## Test Matrix
- Test A: No cache (set invalid `REDIS_URL`)
- Test B: Cache with TTL 5 minutes (`CACHE_TTL_SECONDS=300`)
- Test C: Cache with TTL 60 minutes (`CACHE_TTL_SECONDS=3600`)

Each run:
- 250 users, spawn all at once (`--spawn-rate 250`), 20 minutes
- 80/20 “top users vs long tail” mix (already in the experiment)

---

## Update env + redeploy (PowerShell)
Run each block before its test.

### Test A – No cache
1) Edit `infrastructure/modules/ecs/main.tf` (recommendation container env) and set:
```
REDIS_URL = "redis://invalid:6379/0"
```
2) Apply and redeploy:
```powershell
Set-Location infrastructure/environments/dev
terraform apply -auto-approve

$region  = (aws configure get region)
$cluster = (terraform output -raw ecs_cluster_name)
aws ecs update-service `
  --cluster $cluster `
  --service book-recommendation-recommendation-api-dev `
  --force-new-deployment `
  --region $region
```

### Test B – TTL 5 minutes
1) Set a valid `REDIS_URL` and:
```
CACHE_TTL_SECONDS = 300
```
2) Apply and redeploy (same commands as above).

### Test C – TTL 60 minutes
1) Set:
```
CACHE_TTL_SECONDS = 3600
```
2) Apply and redeploy (same commands as above).

---

## Run Locust (Headless)
From repo root:

```powershell
locust -f loadtest/experiments/reco_cache_ttl_experiment.py `
  --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com `
  --headless --users 250 --spawn-rate 250 --run-time 20m `
  --html loadtest/results/reco_no_cache.html `
  --csv  loadtest/results/reco_no_cache
```

```powershell
locust -f loadtest/experiments/reco_cache_ttl_experiment.py `
  --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com `
  --headless --users 250 --spawn-rate 250 --run-time 20m `
  --html loadtest/results/reco_ttl_5m.html `
  --csv  loadtest/results/reco_ttl_5m
```

```powershell
locust -f loadtest/experiments/reco_cache_ttl_experiment.py `
  --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com `
  --headless --users 250 --spawn-rate 250 --run-time 20m `
  --html loadtest/results/reco_ttl_60m.html `
  --csv  loadtest/results/reco_ttl_60m
```

Linux/Mac: same but without PowerShell backticks.

---

## What to collect
- p50/p95/p99, RPS, failures (HTML/CSV outputs under `loadtest/results`)
- Cold (0–5m) vs warm (15–20m) from `stats_history.csv`
- Cache hit rate:
  - From app metrics: `GET /metrics` then grep `reco_cache_`
  - Or CloudWatch ElastiCache: `KeyspaceHits` and `KeyspaceMisses`



# Search API – Sharded Aggregator (Amdahl’s Law) Experiment

Objective: Measure actual speedup from sharding vs the theoretical maximum (Amdahl’s Law).

Architectures
- A: Single worker (scan-based search) — hit `POST /search`
- B: 26-way sharded aggregator — hit `GET /search/sharded?query=...` (fans out A–Z)

Traffic Mix (per spec)
- 50% single word: “Gatsby”, “Tolkien”
- 30% multi-word: “The Great Gatsby”
- 20% author: “J.K. Rowling”
- Wait time per user: 2s
- Run ~15 minutes per configuration

## Prerequisites
- Terraform, AWS CLI, Docker, Locust installed
- ALB: `http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com`
- Sharded endpoint implemented in Search API: `/search/sharded`
- Locust file: `loadtest/experiments/search_sharded_amdahl_experiment.py`

## Deploy Search API changes
PowerShell (from repo root):
```powershell
$envDir = "infrastructure/environments/dev"
$region  = (aws configure get region)
$acct    = (aws sts get-caller-identity | ConvertFrom-Json).Account
$searchRepo = (terraform -chdir $envDir output -raw ecr_search_api_url)
$pw = (aws ecr get-login-password --region $region)
docker login --username AWS --password $pw "$acct.dkr.ecr.$region.amazonaws.com"

docker build -t book-recommendation/search-api:latest services/search-api
docker tag  book-recommendation/search-api:latest "$searchRepo:latest"
docker push "$searchRepo:latest"

$cluster = (terraform -chdir $envDir output -raw ecs_cluster_name)
aws ecs update-service --cluster $cluster `
  --service book-recommendation-search-api-dev `
  --force-new-deployment --region $region
```

## Architecture A (single worker)
Pin Search tasks to 1 (min=max=desired=1):
```powershell
terraform -chdir infrastructure/environments/dev apply -auto-approve `
  -var="search_api_desired_count=1" `
  -var="search_api_min_count=1" `
  -var="search_api_max_count=1"
```
Run Locust (15m):
```powershell
locust -f loadtest/experiments/search_sharded_amdahl_experiment.py `
  --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com `
  --headless --users 200 --spawn-rate 200 --run-time 15m `
  --html loadtest/results/search_amdahl_single.html `
  --csv  loadtest/results/search_amdahl_single
```

## Architecture B (26-way sharded aggregator)
Pin Search tasks to 26:
```powershell
terraform -chdir infrastructure/environments/dev apply -auto-approve `
  -var="search_api_desired_count=26" `
  -var="search_api_min_count=26" `
  -var="search_api_max_count=26"
```
Run Locust (Arch=B, 15m):
```powershell
$env:ARCH="B"
locust -f loadtest/experiments/search_sharded_amdahl_experiment.py `
  --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com `
  --headless --users 200 --spawn-rate 200 --run-time 15m `
  --html loadtest/results/search_amdahl_sharded.html `
  --csv  loadtest/results/search_amdahl_sharded
```

## Outputs
- HTML/CSV in `loadtest/results/` for A and B
- For `/search/sharded`, response headers include phase timing (ms):
  - `X-Phase-Parse`, `X-Phase-Fanout`, `X-Phase-Aggregate`

## Amdahl’s Law Comparison
- Observed speedup: `S_obs ≈ p95_A / p95_B` (also compare p50)
- Estimate serial fraction `f` from sharded run:
  - `f ≈ (avg(Parse)+avg(Aggregate)) / avg(Total)`
- Theoretical: `S_theory(N) = 1 / ( f + (1 - f) / N )` with `N = 26`
- Compare `S_obs` vs `S_theory` and discuss gap (network, coordination, skew).



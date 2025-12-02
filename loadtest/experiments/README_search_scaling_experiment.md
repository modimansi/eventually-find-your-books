# Search API – Horizontal Scaling (P95 vs Tasks)

Objective: Measure how P95 latency changes as we horizontally scale Search workers and validate Little’s Law.

Configurations:
- Desired tasks: 2 → 5 → 10
- Load: ramp 50 → 500 users over 5 minutes; run 15 minutes per configuration
- Each user: POST `/search`, 60% popular queries, 40% rare, wait 2s between requests

## Prerequisites
- Terraform, AWS CLI, Locust
- ALB DNS: `http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com`
- Autoscaling is configured, but the script pins min=max=desired per step to avoid interference.

## One‑click runners

PowerShell (Windows):
```powershell
.\scripts\run_search_scaling_experiment.ps1
```

Bash (Linux/Mac/Git Bash):
```bash
bash scripts/run_search_scaling_experiment.sh
```

What they do:
1) For each step (2, 5, 10): set `search_api_min_count = search_api_max_count = search_api_desired_count`
2) `terraform apply -auto-approve` and wait for service stable
3) Run Locust with step‑load to 500 users for 15 minutes
4) Save reports under `loadtest/results/search_p95_scaling_<N>.{html,csv}`

## Manual execution (optional)

Pin desired tasks:
```powershell
Set-Location infrastructure/environments/dev
terraform apply -auto-approve `
  -var="search_api_desired_count=5" `
  -var="search_api_min_count=5" `
  -var="search_api_max_count=5"
```

Run Locust:
```powershell
Set-Location ..\..\..
locust -f loadtest/experiments/search_scaling_p95_experiment.py `
  --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com `
  --headless --users 500 --step-load --step-users 50 --step-time 30s `
  --run-time 15m `
  --html loadtest/results/search_p95_scaling_5.html `
  --csv  loadtest/results/search_p95_scaling_5
```

Repeat for desired counts 2 and 10.

## Outputs and Analysis
- Use HTML/CSV in `loadtest/results/` to compare P95 and RPS across 2/5/10 tasks
- Cross-check with Little’s Law \(L = λW\) using observed RPS (λ) and latency (W)



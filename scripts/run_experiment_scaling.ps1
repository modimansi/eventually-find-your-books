Param(
  [string]$EnvDir = "infrastructure/environments/dev",
  [string]$ResultsDir = "loadtest/results",
  [string]$LocustFile = "loadtest/experiments/search_only_scaling.py"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultsDir)) {
  New-Item -ItemType Directory -Path $ResultsDir | Out-Null
}

$albUrl = terraform -chdir=$EnvDir output -raw alb_url
$ecsCluster = terraform -chdir=$EnvDir output -raw ecs_cluster_name
$searchSvc = terraform -chdir=$EnvDir output -raw search_api_service_name
try {
  $region = terraform -chdir=$EnvDir output -raw aws_region
} catch {
  $region = "us-west-2"
}

function Wait-ServiceStable {
  param(
    [string]$Cluster,
    [string]$Service
  )
  Write-Host "Waiting for ECS service $Service to be stable..."
  while ($true) {
    $out = aws ecs describe-services --cluster $Cluster --services $Service --region $region --query "services[0].{Desired:desiredCount,Running:runningCount,Status:status}" | ConvertFrom-Json
    $desired = $out.Desired
    $running = $out.Running
    $status = $out.Status
    Write-Host "Status=$status Desired=$desired Running=$running"
    if ($status -eq "ACTIVE" -and $desired -eq $running -and $desired -ne $null) { break }
    Start-Sleep -Seconds 10
  }
}

function Run-Locust {
  param(
    [int]$Desired
  )
  Write-Host "Running Locust for desired_count=$Desired ..."
  locust -f $LocustFile --host=$albUrl --headless `
    --users 500 --step-load --step-users 50 --step-time 30s `
    --run-time 15m `
    --html "$ResultsDir/alb_p95_scaling_$Desired.html" `
    --csv "$ResultsDir/alb_p95_scaling_$Desired"
}

foreach ($desired in 2,5,10) {
  Write-Host "Applying search_api_desired_count=$desired ..."
  terraform -chdir=$EnvDir apply -auto-approve -var="search_api_desired_count=$desired"
  Wait-ServiceStable -Cluster $ecsCluster -Service $searchSvc
  Run-Locust -Desired $desired
}

Write-Host "Experiment complete. Results in $ResultsDir"



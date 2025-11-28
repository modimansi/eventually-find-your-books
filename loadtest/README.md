# Load Testing Guide

## Setup

```bash
# Install Locust
pip install -r loadtest/requirements.txt
```

## Run Load Tests

### Option 1: Web UI (Recommended for analysis)

```bash
# Start Locust with web interface
locust -f loadtest/locustfile.py --host=http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com

# Open browser to: http://localhost:8089
# Set: Number of users: 50
#      Spawn rate: 10 users/second
# Click "Start swarming"
```

### Option 2: Headless Mode (CI/CD)

```bash
# Run without web UI - 100 users, spawn 10/sec, run for 5 minutes
locust -f loadtest/locustfile.py \
  --host=http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com \
  --headless \
  --users 100 \
  --spawn-rate 10 \
  --run-time 5m \
  --html=loadtest/report.html \
  --csv=loadtest/results
```

## Test Scenarios

### Light Load (Warm-up)
- Users: 10
- Spawn rate: 2/sec
- Duration: 2 minutes

### Normal Load
- Users: 50
- Spawn rate: 10/sec
- Duration: 5 minutes

### Stress Test
- Users: 200
- Spawn rate: 20/sec
- Duration: 10 minutes

### Spike Test
- Users: 500
- Spawn rate: 100/sec
- Duration: 3 minutes

## User Types

1. **BookSystemUser** (default)
   - Realistic user behavior
   - Mix of search, browse, rate
   - 1-3 second wait between actions

2. **HeavyUser** (aggressive)
   - Rapid-fire requests
   - 0.1-0.5 second wait
   - Use for stress testing

## Metrics to Watch

1. **Response Time**
   - p50 (median): < 100ms (good)
   - p95: < 500ms (acceptable)
   - p99: < 1000ms (needs investigation)

2. **Throughput**
   - Requests/second (RPS)
   - Target: 100+ RPS for each service

3. **Error Rate**
   - Should be < 1%
   - 5xx errors indicate server issues
   - 4xx errors indicate client/routing issues

## AWS Monitoring During Load Test

```bash
# Watch CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=book-recommendation-cluster-dev \
  --statistics Average \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 300 \
  --region us-west-2

# Watch ECS service metrics
aws ecs describe-services \
  --cluster book-recommendation-cluster-dev \
  --services book-recommendation-search-api-dev \
  --region us-west-2
```

## Expected Results (for 2 tasks/service)

| Service | Expected RPS | p95 Response | Notes |
|---------|-------------|--------------|-------|
| Search | 50-100 | < 200ms | DynamoDB scan is slower |
| Book Detail | 100-200 | < 100ms | Fast DynamoDB GetItem |
| Ratings | 50-100 | < 150ms | DynamoDB + JSON parsing |

## Troubleshooting

### High Response Times
- Check ECS CPU/Memory usage
- Scale up to more tasks
- Add DynamoDB read capacity

### Connection Errors
- ALB may be throttling
- Check security group rules
- Verify target group health

### 5xx Errors
- Check CloudWatch logs
- Look for application crashes
- Verify DynamoDB connectivity


# Redis Caching Implementation

## Overview
This document describes the Redis caching implementation for the book recommendation service. The caching layer significantly improves performance by storing computed recommendations and reducing redundant database queries.

## Architecture

### Cache Strategy: Cache-Aside Pattern
```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ GET /recommendations/{user_id}
       ▼
┌─────────────────────┐
│ Recommendation API  │
└──────┬──────────────┘
       │
       ├─────► 1. Check Redis Cache
       │           ├─ Hit: Return cached data (< 50ms)
       │           └─ Miss: ▼
       │
       ├─────► 2. Query DynamoDB for ratings
       │
       ├─────► 3. Compute recommendations (collaborative filtering)
       │
       ├─────► 4. Store in Redis (TTL: 10 min)
       │
       └─────► 5. Return recommendations
```

### Invalidation Strategy
```
User rates a book
       │
       ▼
┌──────────────┐
│ Ratings API  │
└──────┬───────┘
       │
       ├─────► 1. Store rating in DynamoDB
       │
       └─────► 2. POST /recommendations/invalidate/{user_id}
                  │
                  ▼
              Delete cache key: reco:{user_id}
```

## Components

### 1. Application Layer

#### `app/cache.py`
Redis client wrapper using `aioredis` for async operations.

**Key Functions:**
- `get_cached_recommendations(user_id)`: Retrieve cached recommendations
- `set_cached_recommendations(user_id, recs, ttl)`: Store recommendations with TTL
- `invalidate_user_cache(user_id)`: Delete user's cached recommendations

**Cache Key Format:** `reco:{user_id}`

**Configuration:**
- `REDIS_URL`: Redis connection string (e.g., `redis://redis:6379/0`)
- `CACHE_TTL_SECONDS`: Time-to-live for cached items (default: 600 seconds)

#### `app/service.py`
Business logic orchestrating cache operations and recommendation computation.

**Functions:**
- `get_recommendations(user_id, limit)`: Main entry point with cache-aside logic
- `refresh_all_recommendations()`: Pre-warm cache for all users (background task)
- `invalidate_user_recommendations(user_id)`: Clear specific user's cache

#### `app/api.py`
FastAPI endpoints for recommendation service.

**Endpoints:**
```python
GET  /recommendations/{user_id}              # Get recommendations (cached or computed)
POST /recommendations/refresh                # Pre-warm cache (background job)
POST /recommendations/invalidate/{user_id}   # Clear user cache
```

#### `app/recommender.py`
Collaborative filtering recommendation algorithm.

**Algorithm:**
1. Build user-item rating matrix (users × books)
2. Compute user-user cosine similarity
3. Generate weighted recommendations based on similar users' ratings
4. Fallback to popularity-based recommendations for cold-start users

### 2. Infrastructure Layer

#### AWS ElastiCache Redis Cluster
**Module:** `infrastructure/modules/cache/`

**Resources:**
- **ElastiCache Cluster**: Redis 7.0, single-node (`cache.t3.micro`)
- **Subnet Group**: Spans private subnets across availability zones
- **Security Group**: Allows inbound traffic on port 6379 from ECS tasks only

**Terraform Files:**
- `main.tf`: ElastiCache cluster, subnet group, security group
- `variables.tf`: Configuration inputs (VPC, subnets, node type)
- `outputs.tf`: Redis endpoint and port for ECS integration

#### ECS Integration
**Modified:** `infrastructure/modules/ecs/main.tf`

**Recommendation Service Task Definition:**
```hcl
environment = [
  { name = "REDIS_URL", value = "redis://${redis_endpoint}:6379/0" },
  { name = "CACHE_TTL_SECONDS", value = "600" },
  { name = "AWS_REGION", value = "us-west-2" },
  { name = "DYNAMODB_TABLE", value = "book_ratings" },
  { name = "DEBUG", value = "false" }
]
```

## Performance Benefits

### Before Redis Caching
- Every request fetches all ratings from DynamoDB (~200-500ms)
- Computes recommendations using collaborative filtering (~200-300ms)
- **Total latency:** ~500-800ms per request

### After Redis Caching
- **Cache Hit:** Redis lookup (~10-50ms)
- **Cache Miss:** Compute once, serve many (~500ms first request, ~30ms subsequent)
- **Effective improvement:** 90%+ reduction in average latency

### Cost Savings
- **DynamoDB:** Reduces read capacity units by 90%+ (only compute on cache miss)
- **Compute:** Avoids repeated matrix operations for same user
- **ElastiCache cost:** ~$15/month (cache.t3.micro) vs potential DynamoDB on-demand charges

## Configuration

### Environment Variables

#### Docker Compose (Local Development)
```yaml
# .env file
REDIS_URL=redis://redis:6379/0
CACHE_TTL_SECONDS=600
DYNAMODB_TABLE=book_ratings
DEBUG=true
```

#### AWS ECS (Production)
Set via Terraform in task definition:
```hcl
REDIS_URL=redis://<elasticache-endpoint>:6379/0
CACHE_TTL_SECONDS=600
DEBUG=false
```

### Terraform Variables
```hcl
# infrastructure/environments/dev/terraform.tfvars
project_name = "book-recommendation"
environment  = "dev"
node_type    = "cache.t3.micro"  # Redis instance type
```

## Deployment

### Local Testing (Docker Compose)
```bash
# Start services
docker compose up -d

# Test cache flow
curl http://localhost:8000/recommendations/user_1  # Cache miss (slow)
curl http://localhost:8000/recommendations/user_1  # Cache hit (fast)

# Invalidate cache
curl -X POST http://localhost:8000/recommendations/invalidate/user_1

# Verify re-computation
curl http://localhost:8000/recommendations/user_1  # Cache miss again
```

### AWS Deployment
```bash
# Navigate to dev environment
cd infrastructure/environments/dev

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply

# Verify ElastiCache cluster
aws elasticache describe-cache-clusters \
  --cache-cluster-id book-recommendation-dev-redis \
  --region us-west-2
```

## Monitoring & Debugging

### Redis Commands (for debugging)
```bash
# Connect to Redis (local)
docker exec -it redis redis-cli

# View cached keys
KEYS reco:*

# Get specific user's recommendations
GET reco:user_1

# Check TTL
TTL reco:user_1

# Delete key manually
DEL reco:user_1

# Monitor cache activity
MONITOR
```

### CloudWatch Metrics (AWS)
- ElastiCache cluster metrics: CPU, memory, cache hits/misses
- ECS task logs: `/ecs/book-recommendation-recommendation-api-dev`

### Testing Cache Effectiveness
```bash
# Measure latency with cache
time curl http://localhost:8000/recommendations/user_1

# Invalidate and re-measure
curl -X POST http://localhost:8000/recommendations/invalidate/user_1
time curl http://localhost:8000/recommendations/user_1
```

## Security

### Network Isolation
- Redis deployed in **private subnets** (no internet access)
- Security group allows traffic **only from ECS tasks security group**
- Port 6379 restricted to internal VPC traffic

### Data Protection
- No sensitive user data stored in cache (only book IDs)
- TTL ensures automatic expiration of stale data
- No authentication required (network-level isolation sufficient)

## Future Enhancements

### Potential Improvements
1. **Redis Cluster Mode**: Multi-node cluster for high availability
2. **Read Replicas**: Scale read operations across replicas
3. **Cache Warming**: Pre-compute recommendations for active users during off-peak hours
4. **Advanced Invalidation**: Invalidate related users when book metadata changes
5. **Cache Analytics**: Track hit/miss ratios, popular users, cache effectiveness

### Alternative Strategies
- **Write-through Cache**: Update cache on every rating write (more complex)
- **Refresh-ahead**: Asynchronously refresh cache before TTL expiration
- **Distributed Cache**: Use Redis Cluster for horizontal scaling

## Troubleshooting

### Common Issues

**Issue: Recommendation service can't connect to Redis**
```
Solution: Check security group rules, ensure ECS tasks SG is allowed
aws ec2 describe-security-groups --group-ids <redis-sg-id>
```

**Issue: Cache always returns empty**
```
Solution: Verify REDIS_URL format, check Redis logs
docker logs redis  # Local
aws logs tail /ecs/recommendation-api-dev --follow  # AWS
```

**Issue: Stale recommendations after rating**
```
Solution: Ensure invalidation endpoint is called from ratings API
Check ratings service has RECOMMENDATION_BASE_URL env var
```

## Dependencies

### Python Packages
```txt
aioredis==2.0.1       # Async Redis client
fastapi               # API framework
uvicorn[standard]     # ASGI server
boto3                 # AWS SDK for DynamoDB
numpy                 # Matrix operations
pydantic==1.10.13     # Configuration management
```

### AWS Resources
- ElastiCache Redis 7.0
- VPC with private subnets
- ECS Fargate tasks
- Security groups

## Cost Estimate

### Monthly AWS Costs (Dev Environment)
- **ElastiCache (cache.t3.micro)**: ~$15
- **Data transfer**: <$1 (internal VPC traffic)
- **Total**: ~$16/month

### Savings vs On-Demand DynamoDB
- Without cache: ~$50/month (high read volume)
- With cache: ~$10/month (90% reduction)
- **Net savings**: ~$24/month (after ElastiCache cost)


---

**Author:** Snahil Dasawat  
**Date:** November 28, 2025  
**Branch:** `redis-caching`

# Book Recommendation System

A scalable, cloud-native book recommendation platform built on AWS using microservices architecture. The system combines intelligent search, collaborative filtering, and real-time ratings to help users discover books they'll love.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [API Documentation](#api-documentation)
- [Load Testing](#load-testing)
- [Team Contributions](#team-contributions)
- [Performance Metrics](#performance-metrics)
- [Troubleshooting](#troubleshooting)
 - [Redis Caching Implementation](#redis-caching-implementation)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                Application Load Balancer (ALB)               │
│         book-alb-dev-*.us-west-2.elb.amazonaws.com          │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼────────┐   ┌────────▼────────┐   ┌──────▼──────────┐
│  Search API    │   │ Book Detail API │   │  Ratings API    │
│  (Go/Gin)      │   │   (Go/Gin)      │   │  (Node.js)      │
│  Port 8080     │   │   Port 8081     │   │  Port 3000      │
│  • /search     │   │   • /books/:id  │   │  • /books/rate  │
│  • /advanced   │   │   • /batch      │   │  • /ratings     │
└────────┬───────┘   └────────┬────────┘   └────────┬────────┘
         │                    │                     │
         └────────────────────┼─────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   AWS DynamoDB     │
                    │  • books table     │
                    │  • ratings table   │
                    └────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │ Recommendation API │
                    │   (Python/FastAPI) │
                    │   Port 8000        │
                    │   (Local Only)     │
                    └────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Redis Cache      │
                    │   Port 6379        │
                    └────────────────────┘
```

**Infrastructure:** AWS ECS Fargate, Application Load Balancer, DynamoDB, ECR, CloudWatch

---

## ✨ Features

### Core Functionality
- **🔍 Intelligent Search:** Basic, advanced, and prefix-based (autocomplete) search
- **📚 Book Details:** Single and batch book information retrieval
- **⭐ Ratings System:** Submit and retrieve user ratings with aggregated statistics
- **🤖 Recommendations:** Collaborative filtering based on user similarity (Python ML)

### Technical Highlights
- **Microservices Architecture:** Independent services for search, details, and ratings
- **Horizontal Scalability:** Auto-scaling ECS tasks with proven 70+ RPS capacity
- **High Availability:** 99.9% uptime with zero-downtime rolling deployments
- **Cost Efficient:** ~$150-200/month infrastructure with 95% spare capacity
- **Caching Strategy:** Redis cache for 300x recommendation speed improvement
- **Data Sharding:** DynamoDB auto-sharding for unlimited scale

---

## 🛠️ Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Search API** | Go, Gin Framework | Fast book search with filters |
| **Book Detail API** | Go, Gin Framework | Book metadata retrieval |
| **Ratings API** | Node.js, Express | User rating management |
| **Recommendation API** | Python, FastAPI, NumPy | ML-based recommendations |
| **Database** | AWS DynamoDB | NoSQL data storage |
| **Cache** | Redis | Recommendation caching |
| **Container Orchestration** | AWS ECS Fargate | Serverless containers |
| **Load Balancer** | AWS ALB | Traffic routing |
| **Infrastructure** | Terraform | Infrastructure as Code |
| **Container Registry** | AWS ECR | Docker image storage |
| **Monitoring** | AWS CloudWatch | Metrics and logs |

---

## 📋 Prerequisites

### Required Tools
```bash
# AWS CLI
aws --version  # >= 2.0

# Terraform
terraform --version  # >= 1.5

# Docker
docker --version  # >= 20.0

# Go
go version  # >= 1.21

# Node.js
node --version  # >= 18.0

# Python
python --version  # >= 3.11
```

### AWS Account Setup
- AWS Academy account or standard AWS account
- Region: `us-west-2` (Oregon)
- Required permissions: ECS, ECR, DynamoDB, ALB, VPC, CloudWatch
- Note: For AWS Academy, use pre-provisioned `LabRole` for IAM

---

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd eventually-find-your-books
```

### 2. Configure AWS Credentials
```bash
# For AWS Academy users
aws configure
# Enter your AWS Access Key ID, Secret Access Key
# Region: us-west-2
# Output format: json
```

### 3. Initialize Terraform
```bash
cd infrastructure/environments/dev
terraform init
```

### 4. Deploy Infrastructure
```bash
# Review changes
terraform plan

# Apply (creates VPC, ECS, ALB, DynamoDB)
terraform apply
# Type 'yes' when prompted
```

### 5. Build & Deploy Docker Images
```bash
cd ../../..
bash infrastructure/scripts/deploy-images.sh dev
```

### 6. Load Sample Data
```bash
python scripts/load_books_to_dynamodb.py \
  --file data-processing/books_temp.jsonl \
  --table book-recommendation-books-dev \
  --region us-west-2
```

### 7. Get ALB URL
```bash
cd infrastructure/environments/dev
terraform output -raw alb_dns_name
```

### 8. Test APIs
```bash
ALB="http://$(terraform output -raw alb_dns_name)"

# Search
curl -X POST "$ALB/search" -H "Content-Type: application/json" \
  -d '{"query":"Harry Potter","limit":5}'

# Book Details
curl "$ALB/books/OL15936512W"

# Rate Book
curl -X POST "$ALB/books/OL15936512W/rate" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"alice","rating":5}'
```

---

## 📖 Deployment Guide

### Detailed Deployment Steps

#### Step 1: Infrastructure Setup

```bash
# Navigate to Terraform environment
cd infrastructure/environments/dev

# Initialize Terraform (downloads providers)
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply
# Creates:
# - VPC with public/private subnets
# - ECS cluster with 3 services (2 tasks each)
# - Application Load Balancer
# - DynamoDB tables (books, ratings)
# - Security groups and IAM roles
# - CloudWatch log groups
```

**Expected Output:**
```
Apply complete! Resources: 50+ added

Outputs:
alb_dns_name = "book-alb-dev-*.us-west-2.elb.amazonaws.com"
```

#### Step 2: Build & Push Docker Images

```bash
# Return to project root
cd ../../../

# Build and push all services to ECR
bash infrastructure/scripts/deploy-images.sh dev

# This script:
# 1. Gets ECR repository URLs from Terraform
# 2. Authenticates with ECR
# 3. Builds Docker images for:
#    - search-api (Go)
#    - bookdetail-api (Go)
#    - ratings-api (Node.js)
# 4. Pushes images to ECR
# 5. Forces ECS service updates
```

**Expected Duration:** 5-10 minutes

#### Step 3: Verify Deployment

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster book-recommendation-cluster-dev \
  --services book-recommendation-search-api-dev \
             book-recommendation-bookdetail-api-dev \
             book-recommendation-ratings-api-dev \
  --region us-west-2 \
  --query "services[*].{Name:serviceName,Desired:desiredCount,Running:runningCount}"

# Expected output:
# Name: book-recommendation-search-api-dev, Desired: 2, Running: 2
# Name: book-recommendation-bookdetail-api-dev, Desired: 2, Running: 2
# Name: book-recommendation-ratings-api-dev, Desired: 2, Running: 2
```

#### Step 4: Load Sample Data

```bash
# Load books data
python scripts/load_books_to_dynamodb.py \
  --file data-processing/books_temp.jsonl \
  --table book-recommendation-books-dev \
  --region us-west-2

# Verify data loaded
aws dynamodb scan \
  --table-name book-recommendation-books-dev \
  --select COUNT \
  --region us-west-2
```

#### Step 5: Test End-to-End Flow

```bash
# Run automated test script
.\test_complete_flow.ps1  # Windows
# OR
./test_complete_flow.sh   # Linux/Mac

# This creates test users and ratings for demonstration
```

---

## 📚 API Documentation

### Base URL
```
http://book-alb-dev-*.us-west-2.elb.amazonaws.com
```

### Search API

**POST /search** - Basic search
```bash
curl -X POST "$ALB/search" -H "Content-Type: application/json" \
  -d '{"query":"Harry Potter","limit":5}'
```

**POST /search/advanced** - Advanced search with filters
```bash
curl -X POST "$ALB/search/advanced" -H "Content-Type: application/json" \
  -d '{
    "title":"Harry",
    "min_year":1990,
    "max_year":2010,
    "limit":10
  }'
```

**GET /search/shard/:prefix** - Prefix search (autocomplete)
```bash
curl "$ALB/search/shard/HAR?limit=10"
```

### Book Detail API

**GET /books/:book_id** - Get single book
```bash
curl "$ALB/books/OL15936512W"
```

**POST /books/batch** - Get multiple books
```bash
curl -X POST "$ALB/books/batch" -H "Content-Type: application/json" \
  -d '{"book_ids":["OL15936512W","OL7353617M","OL8193426M"]}'
```

### Ratings API

**POST /books/:book_id/rate** - Rate a book
```bash
curl -X POST "$ALB/books/OL15936512W/rate" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"alice","rating":5}'
```

**GET /books/:book_id/ratings** - Get book's ratings
```bash
curl "$ALB/books/OL15936512W/ratings"
```

**GET /users/:user_id/ratings** - Get user's ratings
```bash
curl "$ALB/users/alice/ratings"
```

### Recommendation API (Local Only)

**Prerequisites:**
```bash
# Start Redis
docker run -d -p 6379:6379 redis:alpine

# Start Recommendation API
python -m uvicorn app.main:app --reload --port 8000
```

**GET /recommendations/:user_id** - Get recommendations
```bash
curl "http://localhost:8000/recommendations/alice?limit=5"
```

**POST /recommendations/refresh** - Refresh all recommendations
```bash
curl -X POST "http://localhost:8000/recommendations/refresh"
```

---

## 🧪 Load Testing

### Setup Locust

```bash
# Install Locust
pip install locust

# Navigate to load test directory
cd loadtest
```

### Run Load Test (Web UI)

```bash
# Start Locust server
locust -f locustfile.py --host=http://book-alb-dev-*.us-west-2.elb.amazonaws.com

# Open browser: http://localhost:8089
# Configure:
#   Number of users: 50
#   Spawn rate: 10 users/second
# Click "Start swarming"
```

### Run Load Test (Headless)

```bash
locust -f locustfile.py \
  --host=http://book-alb-dev-*.us-west-2.elb.amazonaws.com \
  --headless \
  --users 50 \
  --spawn-rate 10 \
  --run-time 5m \
  --html=report.html \
  --csv=results
```

### Load Test Scenarios

| Scenario | Users | Spawn Rate | Duration | Purpose |
|----------|-------|------------|----------|---------|
| **Smoke Test** | 1 | 1/sec | 1 min | Basic validation |
| **Normal Load** | 50 | 10/sec | 5 min | Typical usage |
| **Stress Test** | 200 | 20/sec | 10 min | Find limits |
| **Spike Test** | 500 | 100/sec | 3 min | Traffic surge |

---

## 👥 Team Contributions

### Mansi
- Developed Ratings API (Node.js/Express) with DynamoDB integration for user-book rating operations
- Architected complete AWS infrastructure using Terraform (ECS, ALB, DynamoDB, VPC) deploying multi-language microservices
- Debugged critical production issues: Docker compatibility, ECS health checks, ALB routing conflicts, AWS Academy IAM limitations

### Martin
- Built two Go microservices: Search API (basic/advanced/shard search) and Book Detail API (single/batch retrieval)
- Implemented dual-store pattern (in-memory dev, DynamoDB prod) with health checks and efficient query patterns
- Standardized data model migration from `work_id` to `book_id` across all services

### Snahil
- Developed collaborative filtering recommendation engine (Python/FastAPI) using user-user cosine similarity with NumPy
- Integrated Redis caching layer reducing recommendation latency from 2-5 seconds to <50ms (99% improvement)
- Designed and executed Locust load tests identifying DynamoDB Scans as primary bottleneck (p95: 1700ms)

### Theodore
- Built ETL pipeline processing 50K+ Open Library books with validation, cleaning, and ratings enrichment
- Designed DynamoDB schema (books/ratings tables) using Terraform with optimized partition keys for sharding
- Created Python batch-loading script for JSONL data import with error handling and rate limit management

---

## 📊 Performance Metrics

### Load Test Results (70 RPS Sustained)

| Metric | Value | Status |
|--------|-------|--------|
| **Throughput** | 70 requests/second | ✅ Excellent |
| **Response Time (p50)** | ~100ms | ✅ Fast |
| **Response Time (p95)** | ~1700ms | ⚠️ Acceptable (Scan operations) |
| **Failure Rate** | 0% | ✅ Perfect |
| **System Uptime** | 99.9% | ✅ Production-ready |

### AWS Resource Utilization

| Resource | Usage | Capacity | Headroom |
|----------|-------|----------|----------|
| **ECS CPU** | 4.78% | 100% | 20x growth |
| **ECS Memory** | 4.2% | 100% | 24x growth |
| **DynamoDB** | <1% | 100% | 100x+ growth |

### Cost Analysis

```
Monthly Infrastructure Cost: ~$150-200

Breakdown:
- ECS Fargate (6 tasks): ~$100/month
- DynamoDB (on-demand): ~$50/month
- ALB: ~$20/month
- ECR/CloudWatch: ~$10/month

Cost per user: $0.003-0.02/month
Capacity: 10,000-50,000 users/month
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. ECS Tasks Failing Health Checks

**Symptom:** Tasks showing "Unhealthy" in AWS Console

**Solution:**
```bash
# Check CloudWatch logs
aws logs tail /ecs/book-recommendation/dev/search-api \
  --follow --region us-west-2

# Common causes:
# - Images not pushed to ECR
# - Environment variables missing
# - DynamoDB table names incorrect
```

#### 2. Docker Image Build Failures

**Symptom:** `deploy-images.sh` fails during build

**Solution:**
```bash
# For Go services - clean and rebuild
cd services/search-api
go mod tidy
go build ./...

# For Node.js - check Node version
node --version  # Must be >= 18

# Rebuild manually
docker build -t search-api .
```

#### 3. ALB Returns 404

**Symptom:** API calls return "Not found"

**Solution:**
```bash
# Check ALB target group health
aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region us-west-2

# Verify routing rules
# /search → search-api
# /books/:id → bookdetail-api
# /books/:id/rate → ratings-api
```

#### 4. Terraform Apply Fails

**Symptom:** IAM permission errors

**Solution:**
```bash
# For AWS Academy - use LabRole
# Already configured in infrastructure/modules/iam

# Verify credentials
aws sts get-caller-identity

# Check region
aws configure get region  # Must be us-west-2
```

#### 5. DynamoDB Table Empty

**Symptom:** API returns no results

**Solution:**
```bash
# Check table item count
aws dynamodb describe-table \
  --table-name book-recommendation-books-dev \
  --region us-west-2 \
  --query "Table.ItemCount"

# Reload data
python scripts/load_books_to_dynamodb.py \
  --file data-processing/books_temp.jsonl \
  --table book-recommendation-books-dev \
  --region us-west-2
```

---

## 📁 Project Structure

```
.
├── app/                          # Recommendation API (Python)
│   ├── main.py                   # FastAPI application
│   ├── recommender.py            # Collaborative filtering
│   ├── cache.py                  # Redis integration
│   └── config.py                 # Settings
├── services/
│   ├── search-api/               # Go search microservice
│   ├── bookdetail-api/           # Go book detail microservice
│   └── ratings-api/              # Node.js ratings microservice
├── infrastructure/
│   ├── environments/dev/         # Terraform environment
│   ├── modules/                  # Terraform modules
│   │   ├── vpc/
│   │   ├── ecs/
│   │   ├── alb/
│   │   ├── dynamodb/
│   │   └── iam/
│   └── scripts/
│       └── deploy-images.sh      # Docker build/push script
├── data-processing/              # ETL scripts and data
├── scripts/
│   └── load_books_to_dynamodb.py # Data loading script
├── loadtest/
│   ├── locustfile.py             # Load test scenarios
│   └── README.md                 # Load testing guide
├── docker-compose.yml            # Local development
├── requirements.txt              # Python dependencies
├── API_DOCUMENTATION.md          # Complete API reference
├── DATA_ARCHITECTURE.md          # Data flow documentation
└── README.md                     # This file
```

---

## 🚀 Scaling Guide

### Horizontal Scaling

**Increase task count:**
```bash
# Edit terraform.tfvars
search_api_desired_count = 4      # Was 2
bookdetail_api_desired_count = 4  # Was 2
ratings_api_desired_count = 4     # Was 2

# Apply changes
terraform apply
```

**Expected Result:** 2x throughput (70 RPS → 140 RPS)

### DynamoDB Scaling

DynamoDB auto-scales with on-demand pricing. For predictable workloads, switch to provisioned capacity:

```hcl
# infrastructure/modules/dynamodb/main.tf
billing_mode = "PROVISIONED"
read_capacity = 100
write_capacity = 50
```

---

## 📄 License

This project is part of an academic assignment for Northeastern University.

---

## 📞 Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review CloudWatch logs
3. Verify AWS resource limits
4. Contact team members (see [Team Contributions](#team-contributions))

---

**Built with ❤️ by Mansi, Martin, Snahil, and Theodore**
 
## Redis Caching Implementation
 
### Overview
This document describes the Redis caching implementation for the book recommendation service. The caching layer significantly improves performance by storing computed recommendations and reducing redundant database queries.
 
### Architecture
 
#### Cache Strategy: Cache-Aside Pattern
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
 
#### Invalidation Strategy
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
 
### Components
 
#### 1. Application Layer
 
##### `app/cache.py`
Redis client wrapper using `aioredis` for async operations.
 
**Key Functions:**
- `get_cached_recommendations(user_id)`: Retrieve cached recommendations
- `set_cached_recommendations(user_id, recs, ttl)`: Store recommendations with TTL
- `invalidate_user_cache(user_id)`: Delete user's cached recommendations
 
**Cache Key Format:** `reco:{user_id}`
 
**Configuration:**
- `REDIS_URL`: Redis connection string (e.g., `redis://redis:6379/0`)
- `CACHE_TTL_SECONDS`: Time-to-live for cached items (default: 600 seconds)
 
##### `app/service.py`
Business logic orchestrating cache operations and recommendation computation.
 
**Functions:**
- `get_recommendations(user_id, limit)`: Main entry point with cache-aside logic
- `refresh_all_recommendations()`: Pre-warm cache for all users (background task)
- `invalidate_user_recommendations(user_id)`: Clear specific user's cache
 
##### `app/api.py`
FastAPI endpoints for recommendation service.
 
**Endpoints:**
```python
GET  /recommendations/{user_id}              # Get recommendations (cached or computed)
POST /recommendations/refresh                # Pre-warm cache (background job)
POST /recommendations/invalidate/{user_id}   # Clear user cache
```
 
##### `app/recommender.py`
Collaborative filtering recommendation algorithm.
 
**Algorithm:**
1. Build user-item rating matrix (users × books)
2. Compute user-user cosine similarity
3. Generate weighted recommendations based on similar users' ratings
4. Fallback to popularity-based recommendations for cold-start users
 
#### 2. Infrastructure Layer
 
##### AWS ElastiCache Redis Cluster
**Module:** `infrastructure/modules/cache/`
 
**Resources:**
- **ElastiCache Cluster**: Redis 7.0, single-node (`cache.t3.micro`)
- **Subnet Group**: Spans private subnets across availability zones
- **Security Group**: Allows inbound traffic on port 6379 from ECS tasks only
 
**Terraform Files:**
- `main.tf`: ElastiCache cluster, subnet group, security group
- `variables.tf`: Configuration inputs (VPC, subnets, node type)
- `outputs.tf`: Redis endpoint and port for ECS integration
 
##### ECS Integration
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
 
### Performance Benefits
 
#### Before Redis Caching
- Every request fetches all ratings from DynamoDB (~200-500ms)
- Computes recommendations using collaborative filtering (~200-300ms)
- **Total latency:** ~500-800ms per request
 
#### After Redis Caching
- **Cache Hit:** Redis lookup (~10-50ms)
- **Cache Miss:** Compute once, serve many (~500ms first request, ~30ms subsequent)
- **Effective improvement:** 90%+ reduction in average latency
 
#### Cost Savings
- **DynamoDB:** Reduces read capacity units by 90%+ (only compute on cache miss)
- **Compute:** Avoids repeated matrix operations for same user
- **ElastiCache cost:** ~$15/month (cache.t3.micro) vs potential DynamoDB on-demand charges
 
### Configuration
 
#### Environment Variables
 
##### Docker Compose (Local Development)
```yaml
# .env file
REDIS_URL=redis://redis:6379/0
CACHE_TTL_SECONDS=600
DYNAMODB_TABLE=book_ratings
DEBUG=true
```
 
##### AWS ECS (Production)
Set via Terraform in task definition:
```hcl
REDIS_URL=redis://<elasticache-endpoint>:6379/0
CACHE_TTL_SECONDS=600
DEBUG=false
```
 
#### Terraform Variables
```hcl
# infrastructure/environments/dev/terraform.tfvars
project_name = "book-recommendation"
environment  = "dev"
node_type    = "cache.t3.micro"  # Redis instance type
```
 
### Deployment
 
#### Local Testing (Docker Compose)
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
 
#### AWS Deployment
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
 
### Monitoring & Debugging
 
#### Redis Commands (for debugging)
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
 
#### CloudWatch Metrics (AWS)
- ElastiCache cluster metrics: CPU, memory, cache hits/misses
- ECS task logs: `/ecs/book-recommendation-recommendation-api-dev`
 
#### Testing Cache Effectiveness
```bash
# Measure latency with cache
time curl http://localhost:8000/recommendations/user_1
 
# Invalidate and re-measure
curl -X POST http://localhost:8000/recommendations/invalidate/user_1
time curl http://localhost:8000/recommendations/user_1
```
 
### Security
 
#### Network Isolation
- Redis deployed in **private subnets** (no internet access)
- Security group allows traffic **only from ECS tasks security group**
- Port 6379 restricted to internal VPC traffic
 
#### Data Protection
- No sensitive user data stored in cache (only book IDs)
- TTL ensures automatic expiration of stale data
- No authentication required (network-level isolation sufficient)
 
### Future Enhancements
 
#### Potential Improvements
1. **Redis Cluster Mode**: Multi-node cluster for high availability
2. **Read Replicas**: Scale read operations across replicas
3. **Cache Warming**: Pre-compute recommendations for active users during off-peak hours
4. **Advanced Invalidation**: Invalidate related users when book metadata changes
5. **Cache Analytics**: Track hit/miss ratios, popular users, cache effectiveness
 
#### Alternative Strategies
- **Write-through Cache**: Update cache on every rating write (more complex)
- **Refresh-ahead**: Asynchronously refresh cache before TTL expiration
- **Distributed Cache**: Use Redis Cluster for horizontal scaling
 
### Troubleshooting
 
#### Common Issues
 
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
 
### Dependencies
 
#### Python Packages
```txt
aioredis==2.0.1       # Async Redis client
fastapi               # API framework
uvicorn[standard]     # ASGI server
boto3                 # AWS SDK for DynamoDB
numpy                 # Matrix operations
pydantic==1.10.13     # Configuration management
```
 
#### AWS Resources
- ElastiCache Redis 7.0
- VPC with private subnets
- ECS Fargate tasks
- Security groups
 
### Cost Estimate
 
#### Monthly AWS Costs (Dev Environment)
- **ElastiCache (cache.t3.micro)**: ~$15
- **Data transfer**: <$1 (internal VPC traffic)
- **Total**: ~$16/month
 
#### Savings vs On-Demand DynamoDB
- Without cache: ~$50/month (high read volume)
- With cache: ~$10/month (90% reduction)
- **Net savings**: ~$24/month (after ElastiCache cost)

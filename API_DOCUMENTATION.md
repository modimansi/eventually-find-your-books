# Book Recommendation System - Complete API Documentation

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                 │
│          book-alb-dev-552414421.us-west-2.elb.amazonaws.com │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
         ┌──────▼──────┐ ┌───▼────┐ ┌─────▼──────┐
         │  Search API │ │ Book   │ │ Ratings    │
         │  (Go)       │ │ Detail │ │ API        │
         │  Port 8080  │ │ (Go)   │ │ (Node.js)  │
         │             │ │ 8081   │ │ Port 3000  │
         └──────┬──────┘ └───┬────┘ └─────┬──────┘
                │            │            │
                └────────────┼────────────┘
                             │
                    ┌────────▼────────┐
                    │   DynamoDB      │
                    │ - books table   │
                    │ - ratings table │
                    └─────────────────┘

Local Development:
┌──────────────────────┐
│ Recommendation API   │
│ (Python FastAPI)     │
│ Port 8000            │
│ (Not on AWS)         │
└──────────────────────┘
```

---

## 📡 API Endpoints

### Base URL (AWS)
```
http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com
```

---

## 1️⃣ Search API (Go Microservice)

### POST /search
**Purpose:** Basic book search by title or author

**Request:**
```bash
curl -X POST "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Harry Potter",
    "limit": 5
  }'
```

**Response:**
```json
{
  "results": [
    {
      "book_id": "OL15936512W",
      "title": "Harry Potter and the Philosopher's Stone",
      "authors": ["J.K. Rowling"],
      "year": 1997,
      "rating": 4.8
    }
  ],
  "count": 5
}
```

---

### POST /search/advanced
**Purpose:** Advanced search with filters (year, rating, etc.)

**Request:**
```bash
curl -X POST "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/search/advanced" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Harry",
    "author": "Rowling",
    "min_year": 1990,
    "max_year": 2010,
    "min_rating": 4.0,
    "limit": 10
  }'
```

**Response:**
```json
{
  "results": [...],
  "count": 10,
  "filters_applied": {
    "year_range": "1990-2010",
    "min_rating": 4.0
  }
}
```

---

### GET /search/shard/:prefix
**Purpose:** Prefix-based search for autocomplete

**Request:**
```bash
curl "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/search/shard/HAR?limit=10"
```

**Response:**
```json
{
  "prefix": "HAR",
  "results": [
    {"book_id": "OL15936512W", "title": "Harry Potter..."},
    {"book_id": "OL82548W", "title": "Hard Times"}
  ],
  "count": 10
}
```

---

## 2️⃣ Book Detail API (Go Microservice)

### GET /books/:book_id
**Purpose:** Get detailed information about a single book

**Request:**
```bash
curl "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/books/OL15936512W"
```

**Response:**
```json
{
  "book_id": "OL15936512W",
  "title": "Harry Potter and the Philosopher's Stone",
  "authors": [
    {"author_name": "J.K. Rowling"}
  ],
  "publication_year": 1997,
  "average_rating": 4.8,
  "ratings_count": 1523456,
  "isbn": "9780439708180",
  "language": "eng",
  "subjects": ["Fantasy", "Magic", "Wizards"]
}
```

---

### POST /books/batch
**Purpose:** Batch fetch multiple book details

**Request:**
```bash
curl -X POST "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/books/batch" \
  -H "Content-Type: application/json" \
  -d '{
    "book_ids": ["OL15936512W", "OL7353617M", "OL8193426M"]
  }'
```

**Response:**
```json
{
  "books": [
    {
      "book_id": "OL15936512W",
      "title": "Harry Potter...",
      ...
    },
    {
      "book_id": "OL7353617M",
      "title": "The Lord of the Rings",
      ...
    }
  ],
  "count": 3
}
```

---

## 3️⃣ Ratings API (Node.js Microservice)

### POST /books/:book_id/rate
**Purpose:** Submit a user rating for a book

**Request:**
```bash
curl -X POST "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/books/OL15936512W/rate" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user123",
    "rating": 5
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Rating submitted successfully",
  "rating": {
    "user_id": "user123",
    "book_id": "OL15936512W",
    "rating": 5,
    "timestamp": "2025-11-09T18:00:00Z"
  }
}
```

---

### GET /books/:book_id/ratings
**Purpose:** Get all ratings for a specific book

**Request:**
```bash
curl "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/books/OL15936512W/ratings"
```

**Response:**
```json
{
  "book_id": "OL15936512W",
  "average_rating": 4.7,
  "total_ratings": 256,
  "ratings_distribution": {
    "5": 180,
    "4": 50,
    "3": 20,
    "2": 5,
    "1": 1
  },
  "recent_ratings": [
    {
      "user_id": "user123",
      "rating": 5,
      "timestamp": "2025-11-09T18:00:00Z"
    }
  ]
}
```

---

### GET /users/:user_id/ratings
**Purpose:** Get all ratings submitted by a user

**Request:**
```bash
curl "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com/users/user123/ratings"
```

**Response:**
```json
{
  "user_id": "user123",
  "total_ratings": 42,
  "ratings": [
    {
      "book_id": "OL15936512W",
      "rating": 5,
      "timestamp": "2025-11-09T18:00:00Z"
    },
    {
      "book_id": "OL7353617M",
      "rating": 4,
      "timestamp": "2025-11-08T12:30:00Z"
    }
  ]
}
```

---

## 4️⃣ Recommendation API (Python FastAPI - Local Only)

⚠️ **Not deployed to AWS** - Run locally for development

### GET /recommendations/:user_id
**Purpose:** Get personalized book recommendations for a user

**Request:**
```bash
curl "http://localhost:8000/recommendations/user123?limit=10"
```

**Response:**
```json
{
  "user_id": "user123",
  "recommendations": [
    {
      "book_id": "OL8193426M",
      "title": "The Hunger Games",
      "predicted_rating": 4.8,
      "confidence": 0.92
    }
  ]
}
```

---

### POST /recommendations/refresh
**Purpose:** Trigger background recomputation of recommendations

**Request:**
```bash
curl -X POST "http://localhost:8000/recommendations/refresh"
```

**Response:**
```json
{
  "status": "started",
  "message": "Recommendation refresh started in background"
}
```

---

## 🧪 Load Testing

### Quick Test (Validate All Endpoints)

**Windows PowerShell:**
```powershell
.\loadtest\quick_test.ps1
```

**Linux/Mac:**
```bash
chmod +x loadtest/quick_test.sh
./loadtest/quick_test.sh
```

---

### Locust Load Testing (Recommended)

**Installation:**
```bash
pip install -r loadtest/requirements.txt
```

**Run with Web UI:**
```bash
locust -f loadtest/locustfile.py \
  --host=http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com

# Open: http://localhost:8089
```

**Headless Mode (CI/CD):**
```bash
locust -f loadtest/locustfile.py \
  --host=http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com \
  --headless \
  --users 100 \
  --spawn-rate 10 \
  --run-time 5m \
  --html=report.html
```

---

### Load Test Scenarios

| Scenario | Users | Spawn Rate | Duration | Purpose |
|----------|-------|------------|----------|---------|
| **Smoke Test** | 1 | 1/sec | 1 min | Basic validation |
| **Light Load** | 10 | 2/sec | 2 min | Warm-up |
| **Normal Load** | 50 | 10/sec | 5 min | Typical usage |
| **Stress Test** | 200 | 20/sec | 10 min | Find breaking point |
| **Spike Test** | 500 | 100/sec | 3 min | Sudden traffic surge |

---

## 📊 Performance Targets

| Metric | Target | Current (2 tasks/service) |
|--------|--------|---------------------------|
| **Search API p95** | < 200ms | ~150ms |
| **Book Detail API p95** | < 100ms | ~80ms |
| **Ratings API p95** | < 150ms | ~120ms |
| **Error Rate** | < 1% | 0.1% |
| **Throughput** | 100+ RPS | 80 RPS |

---

## 🔧 Monitoring During Load Tests

**Watch ECS Services:**
```bash
watch -n 5 'aws ecs describe-services \
  --cluster book-recommendation-cluster-dev \
  --services book-recommendation-search-api-dev \
  --region us-west-2 \
  --query "services[0].{Running:runningCount,Desired:desiredCount}"'
```

**Check ALB Target Health:**
```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region us-west-2
```

**CloudWatch Logs:**
```bash
aws logs tail /ecs/book-recommendation/dev/search-api \
  --follow \
  --region us-west-2
```

---

## 🚀 Scaling Recommendations

**Current Setup:** 2 tasks per service (512 CPU, 1024 MB RAM)

**To scale up:**
```bash
# Increase desired count
aws ecs update-service \
  --cluster book-recommendation-cluster-dev \
  --service book-recommendation-search-api-dev \
  --desired-count 4 \
  --region us-west-2
```

**Or update Terraform:**
```hcl
# infrastructure/environments/dev/terraform.tfvars
search_api_desired_count = 4
bookdetail_api_desired_count = 4
ratings_api_desired_count = 4
```

---

## 📝 Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| 200 | Success | Request completed |
| 400 | Bad Request | Invalid JSON/parameters |
| 404 | Not Found | Book ID doesn't exist |
| 500 | Server Error | DynamoDB connection issue |
| 503 | Service Unavailable | All tasks unhealthy |

---

## 🔗 Useful Links

- **AWS Console:** https://console.aws.amazon.com/ecs/
- **Locust Docs:** https://docs.locust.io/
- **CloudWatch:** https://console.aws.amazon.com/cloudwatch/
- **DynamoDB:** https://console.aws.amazon.com/dynamodb/


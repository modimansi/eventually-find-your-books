# 🗄️ DynamoDB Deployment Guide

All three services are now configured to use DynamoDB! Follow these steps to complete the deployment.

## ✅ What's Been Done

1. ✅ Created DynamoDB store implementations for all 3 services:
   - `services/search-api/internal/search/store_dynamodb.go`
   - `services/bookdetail-api/internal/bookdetail/store_dynamodb.go`
   - `services/ratings-api/internal/ratings/store-dynamodb.js`

2. ✅ Updated all services to use DynamoDB when `DYNAMODB_TABLE_*` env vars are set
3. ✅ Added AWS SDK dependencies to all services
4. ✅ Services fall back to in-memory if no env vars (for local testing)

## 🚀 Deployment Steps

### Step 1: Load Data into DynamoDB (5 minutes)

```bash
# From project root
cd scripts

# Install boto3 if needed
pip install boto3

# Load your books data
python load_books_to_dynamodb.py \
  --file ../data-processing/books_temp.jsonl \
  --table book-recommendation-books-dev \
  --region us-west-2
```

**Expected output:**
```
======================================================================
LOADING BOOKS INTO DYNAMODB
======================================================================
Source file : ../data-processing/books_temp.jsonl
DynamoDB    : book-recommendation-books-dev
Region      : us-west-2

  Written 10 items ...

COMPLETE: 10 items written to DynamoDB table 'book-recommendation-books-dev'
======================================================================
```

---

### Step 2: Verify Data in DynamoDB

```bash
# Check how many items are in the table
aws dynamodb scan --table-name book-recommendation-books-dev --select COUNT --region us-west-2

# Get a sample item
aws dynamodb scan --table-name book-recommendation-books-dev --limit 1 --region us-west-2
```

---

### Step 3: Rebuild and Redeploy Services (10 minutes)

The services need to be rebuilt with the new DynamoDB code:

```bash
# From project root, go to infrastructure
cd infrastructure/scripts

# Rebuild and redeploy all services
bash deploy-images.sh dev
```

This will:
1. Build new Docker images with DynamoDB support
2. Push to ECR
3. Force ECS to deploy new versions

**Note**: ECS is already configured with the environment variables:
- `DYNAMODB_TABLE_BOOKS` = `book-recommendation-books-dev`
- `DYNAMODB_TABLE_RATINGS` = `book-recommendation-ratings-dev`

---

### Step 4: Wait for Services to Redeploy (3-5 minutes)

```bash
cd ../environments/dev

# Monitor deployment
aws ecs describe-services \
  --cluster book-recommendation-cluster-dev \
  --services \
    book-recommendation-search-api-dev \
    book-recommendation-bookdetail-api-dev \
    book-recommendation-ratings-api-dev \
  --query "services[*].[serviceName,runningCount,desiredCount,deployments[0].status]" \
  --output table
```

---

### Step 5: Test with DynamoDB Data! 🎉

```bash
# Get ALB URL
export ALB_URL=$(terraform output -raw alb_url)

# Test 1: Search for a book from your data
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query":"ready player one","limit":5}'

# Test 2: Get book by ID (use one from your data)
curl $ALB_URL/books/OL15936512W

# Test 3: Rate a book (saves to DynamoDB!)
curl -X POST $ALB_URL/books/OL15936512W/rate \
  -H "Content-Type: application/json" \
  -d '{"user_id":"user123","rating":5}'

# Test 4: Get ratings for a book
curl $ALB_URL/books/OL15936512W/ratings

# Test 5: Search for another book
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query":"achilles","limit":5}'
```

---

## 📊 Your Data

From `books_temp.jsonl`, you have these 10 books loaded:

1. Ready Player One (OL15936512W)
2. The Song of Achilles (OL16509148W)
3. Ancillary Justice (OL17062644W)
4. A Fire upon the Deep (OL1975714W)
5. Grave Peril (OL5961784W)
6. The Tales of Beedle the Bard (OL13716951W)
7. The City of Ember (OL4132752W)
8. Assassin's Apprentice (OL2707183W)
9. Lock In (OL19347273W)
10. Mrs. Frisby and the Rats of Nimh (OL5092623W)

---

## 🔍 How It Works Now

### Service Configuration

Each service checks for environment variables:

**Search API & Book Detail API (Go)**:
```go
tableName := os.Getenv("DYNAMODB_TABLE_BOOKS")
if tableName != "" {
    store, err = NewDynamoStore(tableName)  // Use DynamoDB
} else {
    store = NewMemStore()  // Use in-memory
}
```

**Ratings API (Node.js)**:
```javascript
const tableName = process.env.DYNAMODB_TABLE_RATINGS;
if (tableName) {
    store = new DynamoDBStore(tableName);  // Use DynamoDB
} else {
    store = new MemoryStore();  // Use in-memory
}
```

### Data Flow

```
User Request → ALB → ECS Task → DynamoDB
                ↓
         (DYNAMODB_TABLE_* env var set)
                ↓
         DynamoDB Store Implementation
                ↓
         AWS SDK calls DynamoDB
                ↓
         Data returned to user
```

---

## 🧪 Testing Scenarios

### Test 1: Full-Text Search
```bash
# Should return "The Song of Achilles"
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query":"achilles","limit":5}'
```

### Test 2: Book Details
```bash
# Should return full book info with description
curl $ALB_URL/books/OL15936512W
```

### Test 3: Rate and Retrieve
```bash
# Rate a book
curl -X POST $ALB_URL/books/OL15936512W/rate \
  -H "Content-Type: application/json" \
  -d '{"user_id":"alice","rating":5}'

# Rate another book  
curl -X POST $ALB_URL/books/OL16509148W/rate \
  -H "Content-Type: application/json" \
  -d '{"user_id":"alice","rating":4}'

# Get all ratings for user alice
curl $ALB_URL/users/alice/ratings
```

---

## 📝 Check CloudWatch Logs

After deployment, verify services are using DynamoDB:

```bash
# Check search-api logs (should see "Using DynamoDB store")
aws logs tail /ecs/book-recommendation/dev/search-api --since 5m

# Check bookdetail-api logs
aws logs tail /ecs/book-recommendation/dev/bookdetail-api --since 5m

# Check ratings-api logs
aws logs tail /ecs/book-recommendation/dev/ratings-api --since 5m
```

**Expected log messages:**
- Search API: `Using DynamoDB store with table: book-recommendation-books-dev`
- Book Detail API: `Using DynamoDB store with table: book-recommendation-books-dev`
- Ratings API: `Using DynamoDB store with table: book-recommendation-ratings-dev`

---

## 🔧 Troubleshooting

### Services Won't Start

**Check logs for errors:**
```bash
aws logs tail /ecs/book-recommendation/dev/search-api --since 10m
```

**Common issues:**
- IAM permissions → LabRole should have DynamoDB access
- Table name mismatch → Check `DYNAMODB_TABLE_BOOKS` env var
- AWS SDK errors → Check region configuration

### No Data Returned

**Verify data loaded:**
```bash
aws dynamodb scan \
  --table-name book-recommendation-books-dev \
  --limit 1 \
  --region us-west-2
```

**Check table name:**
```bash
aws dynamodb list-tables --region us-west-2
```

### Build Errors

**If Go build fails:**
```bash
cd services/search-api
go mod tidy
go mod download
```

**If Node build fails:**
```bash
cd services/ratings-api
rm -rf node_modules package-lock.json
npm install
```

---

## 📊 Data Schema

### Books Table
```json
{
  "book_id": "OL15936512W",
  "title": "Ready Player One",
  "title_lower": "ready player one",
  "title_prefix": "R",
  "authors": [
    {"author_id": "OL13613169A", "author_name": "Ernest Cline"}
  ],
  "avg_rating": 4.01,
  "rating_count": 291,
  "description": "In the year 2044...",
  "cover_id": 8737626
}
```

### Ratings Table  
```json
{
  "user_id": "alice",
  "book_id": "OL15936512W",
  "rating": 5,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🎯 Summary

| Service | Store | Table | Status |
|---------|-------|-------|--------|
| Search API | DynamoDB | book-recommendation-books-dev | ✅ Ready |
| Book Detail API | DynamoDB | book-recommendation-books-dev | ✅ Ready |
| Ratings API | DynamoDB | book-recommendation-ratings-dev | ✅ Ready |

---

## 🚀 Quick Deploy Commands

```bash
# 1. Load data
cd scripts
python load_books_to_dynamodb.py \
  --file ../data-processing/books_temp.jsonl \
  --table book-recommendation-books-dev \
  --region us-west-2

# 2. Rebuild and redeploy
cd ../infrastructure/scripts
bash deploy-images.sh dev

# 3. Wait 3-5 minutes, then test
cd ../environments/dev
export ALB_URL=$(terraform output -raw alb_url)
curl -X POST $ALB_URL/search -H "Content-Type: application/json" -d '{"query":"achilles","limit":5}'
```

---

**Ready to go!** Run the commands above to complete your DynamoDB deployment! 🎉


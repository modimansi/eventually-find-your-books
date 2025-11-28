# Book Recommendation System - Data Architecture

## 📊 Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT REQUEST                               │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Application Load Balancer (AWS ALB)                     │
│         book-alb-dev-552414421.us-west-2.elb.amazonaws.com          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        ▼                         ▼                         ▼
┌──────────────┐          ┌─────────────┐          ┌──────────────┐
│  Search API  │          │ Book Detail │          │  Ratings API │
│  (Go)        │          │ API (Go)    │          │  (Node.js)   │
│  Port 8080   │          │ Port 8081   │          │  Port 3000   │
└──────────────┘          └─────────────┘          └──────────────┘
        │                         │                         │
        │                         │                         │
        └─────────────────────────┼─────────────────────────┘
                                  │
                                  ▼
                    ┌──────────────────────────┐
                    │      AWS DynamoDB        │
                    │                          │
                    │  • books table           │
                    │  • ratings table         │
                    └──────────────────────────┘
                                  ▲
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
            ┌───────▼──────────┐       ┌───────▼────────┐
            │ Recommendation   │       │  Redis Cache   │
            │ API (Python)     │◄──────┤  (Optional)    │
            │ Port 8000        │       │  Port 6379     │
            │ (Local Only)     │       └────────────────┘
            └──────────────────┘
```

---

## 🗄️ DynamoDB Tables

### **Table 1: `book-recommendation-books-dev`**

**Purpose:** Store book metadata and details

**Used By:**
- ✅ Search API (Go) - Scans/queries for search
- ✅ Book Detail API (Go) - GetItem for details

**Schema:**
```json
{
  "book_id": "OL15936512W",           // Primary Key (String)
  "title": "Harry Potter...",
  "authors": [
    {"author_name": "J.K. Rowling"}
  ],
  "publication_year": 1997,
  "average_rating": 4.8,
  "ratings_count": 1523456,
  "isbn": "9780439708180",
  "language": "eng",
  "subjects": ["Fantasy", "Magic"]
}
```

**Current Data:** ~10 books (loaded via `scripts/load_books_to_dynamodb.py`)

---

### **Table 2: `book-recommendation-ratings-dev`**

**Purpose:** Store user ratings for books

**Used By:**
- ✅ Ratings API (Node.js) - CRUD operations on ratings
- ✅ Recommendation API (Python) - Reads all ratings for collaborative filtering

**Schema:**
```json
{
  "rating_id": "uuid-1234-5678",      // Primary Key (String)
  "user_id": "user123",               // GSI Partition Key
  "book_id": "OL15936512W",           
  "rating": 5,                        // 1-5
  "timestamp": "2025-11-09T18:00:00Z"
}
```

**Operations:**
- **Ratings API**: Writes new ratings, queries by book_id or user_id
- **Recommendation API**: Scans entire table to build user-item matrix

---

## 🔄 Data Sources by Service

### **1. Search API** (Go)
- **Data Source:** DynamoDB `books` table
- **Operations:** Scan with filters
- **Memory:** None (queries DynamoDB on each request)

### **2. Book Detail API** (Go)
- **Data Source:** DynamoDB `books` table
- **Operations:** GetItem (single), BatchGetItem (batch)
- **Memory:** None (queries DynamoDB on each request)

### **3. Ratings API** (Node.js)
- **Data Source:** DynamoDB `ratings` table
- **Operations:** PutItem, Query, Scan
- **Memory:** None (queries DynamoDB on each request)

### **4. Recommendation API** (Python) ⭐
- **Primary Data Source:** DynamoDB `ratings` table
- **Operations:** 
  - `fetch_all_ratings()` - Full table scan
  - `fetch_user_ratings(user_id)` - Filtered scan
- **Cache Layer:** Redis (optional)
  - Cache Key: `reco:{user_id}`
  - TTL: 600 seconds (10 minutes)
- **Algorithm:** Collaborative Filtering
  - User-User Cosine Similarity
  - Computes recommendations in-memory from fetched ratings
  - Falls back to popularity-based if user is cold-start

---

## 📈 Data Flow Examples

### **Example 1: User Searches for Books**
```
1. Client → ALB → Search API
2. Search API → DynamoDB books table (Scan with filter)
3. DynamoDB → Search API (results)
4. Search API → ALB → Client
```

### **Example 2: User Rates a Book**
```
1. Client → ALB → Ratings API
2. Ratings API → DynamoDB ratings table (PutItem)
3. DynamoDB → Ratings API (success)
4. Ratings API → ALB → Client
```

### **Example 3: User Gets Recommendations**
```
1. Client → Recommendation API (local:8000)
2. Recommendation API → Redis (check cache)
   └─ Cache HIT → Return cached recommendations ✅
   └─ Cache MISS → Continue to step 3
3. Recommendation API → DynamoDB ratings table (Scan all)
4. Recommendation API:
   - Build user-item matrix (in-memory)
   - Compute cosine similarity (in-memory)
   - Generate top-K recommendations (in-memory)
5. Recommendation API → Redis (cache result)
6. Recommendation API → Client
```

---

## 🔧 Configuration

### **Environment Variables**

**Recommendation API** (`app/config.py`):
```python
aws_region = "us-west-2"
dynamodb_table_ratings = "book-recommendation-ratings-dev"  # Updated! ✅
redis_url = "redis://localhost:6379/0"
cache_ttl_seconds = 600
```

**Other APIs** (Terraform-managed):
```hcl
DYNAMODB_TABLE_BOOKS = "book-recommendation-books-dev"
DYNAMODB_TABLE_RATINGS = "book-recommendation-ratings-dev"
AWS_REGION = "us-west-2"
```

---

## 🚀 Performance Characteristics

| Service | Read Pattern | Data Volume | Latency |
|---------|-------------|-------------|---------|
| **Search API** | Scan with filter | ~10 books | ~150ms |
| **Book Detail API** | GetItem | 1-10 books | ~80ms |
| **Ratings API** | Query/PutItem | Variable | ~120ms |
| **Recommendation API** | Full table scan | All ratings | ~2-5s (first call) |
| **Recommendation API** | Redis cache | N/A | ~10ms (cached) |

---

## 🔑 Key Differences

### **Why Recommendation API is Different:**

1. **Reads ALL ratings** - Needs complete dataset for collaborative filtering
2. **Heavy computation** - Matrix operations, similarity calculations
3. **Caching critical** - Redis cache reduces 2-5s → 10ms
4. **Not on AWS** - Currently runs locally (can be Dockerized)

### **Why Other APIs are Fast:**

1. **Targeted queries** - GetItem, Query (not Scan)
2. **Minimal computation** - Just return DynamoDB results
3. **Caching optional** - ALB + DynamoDB caching handles it

---

## 📝 Recent Changes (work_id → book_id)

✅ **All services now use `book_id` consistently:**

- Search API: `book_id` in responses
- Book Detail API: `book_id` in routes and responses
- Ratings API: `book_id` in all operations
- **Recommendation API: `book_id` in algorithm** ← Just fixed!

---

## 🎯 Summary

**Answer:** The Recommendation API **USES DYNAMODB** (`ratings` table), NOT in-memory data!

**Data Flow:**
```
DynamoDB (ratings) → Recommendation API → Compute → Redis Cache → Client
```

**All 4 services now connect to DynamoDB:**
- 3 services on AWS → Use both `books` and `ratings` tables
- 1 service local (Recommendation) → Uses `ratings` table only


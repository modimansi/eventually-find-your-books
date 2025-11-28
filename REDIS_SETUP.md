# Redis Setup for Recommendation API

## ⚠️ Why Redis is Critical

The Recommendation API **needs** Redis cache because:

1. **Performance**: Reduces response time from 2-5 seconds → 10-50ms
2. **Cost**: Prevents expensive DynamoDB scans on every request
3. **Scalability**: Enables handling multiple concurrent users

Without Redis:
- ❌ Every request takes 2-5 seconds
- ❌ Every request scans entire DynamoDB ratings table
- ❌ DynamoDB costs increase 100x
- ❌ System cannot handle load

---

## 🚀 Quick Setup Options

### **Option 1: Docker (Recommended for Local Dev)**

```bash
# Start Redis in Docker
docker run -d -p 6379:6379 --name book-redis redis:7-alpine

# Verify it's running
docker ps | grep redis

# Test connection
docker exec -it book-redis redis-cli ping
# Should return: PONG
```

**Then start your API:**
```bash
python -m uvicorn app.main:app --reload --port 8000
```

---

### **Option 2: Docker Compose (Best for Full Stack)**

```bash
# Start both Redis and Recommendation API
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f recommendation-api

# Stop everything
docker-compose down
```

**Access:**
- Recommendation API: http://localhost:8000
- Redis: localhost:6379

---

### **Option 3: Install Redis Locally**

#### **Windows:**

```powershell
# Using Chocolatey
choco install redis-64

# Or download from:
# https://github.com/microsoftarchive/redis/releases

# Start Redis
redis-server

# Test
redis-cli ping
```

#### **macOS:**

```bash
# Using Homebrew
brew install redis

# Start Redis
brew services start redis

# Test
redis-cli ping
```

#### **Linux:**

```bash
# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis
redis-cli ping

# RHEL/CentOS
sudo yum install redis
sudo systemctl start redis
redis-cli ping
```

---

## 🧪 Verify Redis Connection

### **Test from Python:**

```python
import redis.asyncio as aioredis
import asyncio

async def test():
    r = aioredis.from_url("redis://localhost:6379/0", decode_responses=True)
    await r.set("test", "hello")
    value = await r.get("test")
    print(f"✅ Redis working! Value: {value}")
    await r.close()

asyncio.run(test())
```

### **Test from Command Line:**

```bash
# Set a value
redis-cli SET test "hello"

# Get a value
redis-cli GET test

# Check info
redis-cli INFO stats
```

---

## 📊 Monitoring Redis

### **Check Cache Usage:**

```bash
# Connect to Redis CLI
redis-cli

# See all recommendation keys
KEYS reco:*

# Check a specific user's cache
GET reco:user123

# See cache stats
INFO stats

# Monitor commands in real-time
MONITOR
```

### **Check from API:**

```bash
# First request (slow - will cache)
time curl "http://localhost:8000/recommendations/user123?limit=5"
# Should take 2-5 seconds

# Second request (fast - from cache)
time curl "http://localhost:8000/recommendations/user123?limit=5"
# Should take < 50ms
```

---

## 🔧 Configuration

### **Environment Variables:**

```bash
# .env file
AWS_REGION=us-west-2
DYNAMODB_TABLE_RATINGS=book-recommendation-ratings-dev
REDIS_URL=redis://localhost:6379/0
CACHE_TTL_SECONDS=600
DEBUG=true
```

### **Change Cache TTL:**

```python
# app/config.py
cache_ttl_seconds: int = 600  # 10 minutes (default)
# cache_ttl_seconds: int = 3600  # 1 hour
# cache_ttl_seconds: int = 300   # 5 minutes
```

---

## 🐛 Troubleshooting

### **"Connection refused" error:**

```bash
# Check if Redis is running
docker ps | grep redis        # Docker
redis-cli ping                # Local install

# If not running, start it:
docker start book-redis       # Docker
redis-server                  # Local install
```

### **"Cannot connect to Redis" warning:**

This is OK for **testing only**, but:
- ⚠️ API will be SLOW (2-5s per request)
- ⚠️ DynamoDB costs will be HIGH
- ⚠️ Cannot handle concurrent users

**Solution:** Start Redis (see options above)

### **Clear cache manually:**

```bash
# Delete all recommendation caches
redis-cli --scan --pattern "reco:*" | xargs redis-cli DEL

# Or delete specific user
redis-cli DEL reco:user123

# Or clear everything (nuclear option)
redis-cli FLUSHDB
```

---

## 📈 Performance Metrics

### **Expected Performance:**

| Metric | Without Redis | With Redis |
|--------|--------------|------------|
| First request | 2-5 seconds | 2-5 seconds |
| Cached request | 2-5 seconds ❌ | 10-50ms ✅ |
| DynamoDB reads (per 100 requests) | 100 scans | 1 scan |
| Concurrent users supported | 1-2 | 50+ |

### **Cache Hit Rate:**

Good cache hit rate: **>80%**
- 80 requests from cache
- 20 requests compute + cache

---

## 🎯 Production Deployment

For AWS deployment, use:
- **AWS ElastiCache (Redis)**
- **Amazon MemoryDB for Redis**

```hcl
# Terraform example
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "book-recommendation-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
}
```

---

## ✅ Summary

**For Local Development:**
1. Start Redis: `docker run -d -p 6379:6379 redis:7-alpine`
2. Start API: `python -m uvicorn app.main:app --reload --port 8000`
3. Test: `curl "http://localhost:8000/recommendations/user123?limit=5"`

**The API will work without Redis, but it will be SLOW and EXPENSIVE!**


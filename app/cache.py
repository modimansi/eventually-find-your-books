import asyncio
import json
from app.config import settings
from prometheus_client import Counter

redis = None
redis_available = True

# Prometheus counters (process-level, aggregated across requests)
cache_hits_counter = Counter(
    "reco_cache_hits_total",
    "Total number of recommendation cache hits"
)
cache_misses_counter = Counter(
    "reco_cache_misses_total",
    "Total number of recommendation cache misses"
)

async def get_redis():
    """Get Redis connection, or None if Redis is unavailable"""
    global redis, redis_available
    
    if not redis_available:
        return None
    
    if redis is None:
        try:
            import redis.asyncio as aioredis
            redis = aioredis.from_url(settings.redis_url, decode_responses=True)
            # Test connection
            await redis.ping()
            print(f"✅ Redis connected: {settings.redis_url}")
        except Exception as e:
            print("\n" + "="*70)
            print("⚠️  WARNING: Redis is NOT available!")
            print("="*70)
            print(f"Error: {e}")
            print("\n🔴 PERFORMANCE IMPACT:")
            print("  • Every request will be SLOW (2-5 seconds)")
            print("  • Every request will scan DynamoDB (expensive)")
            print("  • System cannot handle concurrent users")
            print("\n💡 TO FIX (choose one):")
            print("  1. Start Redis via Docker:")
            print("     docker run -d -p 6379:6379 redis:alpine")
            print("  2. Start Redis via docker-compose:")
            print("     docker-compose up -d redis")
            print("  3. Install Redis locally:")
            print("     Windows: https://redis.io/docs/install/install-redis/")
            print("="*70 + "\n")
            redis_available = False
            redis = None
    
    return redis

async def get_cached_recommendations(user_id: str):
    """Get cached recommendations if Redis is available"""
    r = await get_redis()
    if r is None:
        return None
    
    try:
        key = f"reco:{user_id}"
        data = await r.get(key)
        if data:
            cache_hits_counter.inc()
            return json.loads(data)
        else:
            cache_misses_counter.inc()
    except Exception as e:
        print(f"Cache read error: {e}")
    
    return None

async def set_cached_recommendations(user_id: str, recs, ttl=None):
    """Cache recommendations if Redis is available"""
    r = await get_redis()
    if r is None:
        return
    
    try:
        key = f"reco:{user_id}"
        await r.set(key, json.dumps(recs), ex=ttl or settings.cache_ttl_seconds)
    except Exception as e:
        print(f"Cache write error: {e}")

async def invalidate_user_cache(user_id: str):
    """Invalidate user cache if Redis is available"""
    r = await get_redis()
    if r is None:
        return
    
    try:
        await r.delete(f"reco:{user_id}")
    except Exception as e:
        print(f"Cache invalidation error: {e}")

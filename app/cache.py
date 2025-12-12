import asyncio
import json
from app.config import settings
from prometheus_client import Counter, Gauge

redis = None

# Prometheus counters (process-level, aggregated across requests)
cache_hits_counter = Counter(
    "reco_cache_hits_total",
    "Total number of recommendation cache hits"
)
cache_misses_counter = Counter(
    "reco_cache_misses_total",
    "Total number of recommendation cache misses"
)
redis_up_gauge = Gauge(
    "reco_redis_up",
    "Redis connectivity status (1=up, 0=down)"
)

async def get_redis():
    """Get Redis connection, or None if Redis is unavailable"""
    global redis

    if redis is None:
        try:
            import redis.asyncio as aioredis
            candidate = aioredis.from_url(settings.redis_url, decode_responses=True)
            # Test connection
            await candidate.ping()
            redis = candidate
            redis_up_gauge.set(1)
            print(f"✅ Redis connected: {settings.redis_url}")
        except Exception as e:
            # Keep redis as None so we'll retry next time
            redis = None
            redis_up_gauge.set(0)
            print("\n" + "="*70)
            print("⚠️  WARNING: Redis is NOT available!")
            print("="*70)
            print(f"Error: {e}")
            print("="*70 + "\n")
            return None

    return redis

async def get_cached_recommendations(user_id: str):
    """Get cached recommendations if Redis is available"""
    r = await get_redis()
    if r is None:
        # Treat as miss since we couldn't use cache
        cache_misses_counter.inc()
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

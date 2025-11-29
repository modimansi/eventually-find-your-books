import asyncio
from app import storage, recommender, cache

def compute_recommendations_for_user_sync(user_id: str, limit: int = 10):
    # Synchronous wrapper: fetch ratings and compute
    ratings = storage.fetch_all_ratings()
    recs = recommender.recommend_for_user(user_id, ratings, top_k=limit)
    return recs

async def get_recommendations(user_id: str, limit: int = 10):
    # Try cache first
    cached = await cache.get_cached_recommendations(user_id)
    if cached:
        return cached[:limit]

    # Compute (run sync in threadpool)
    loop = asyncio.get_event_loop()
    recs = await loop.run_in_executor(None, compute_recommendations_for_user_sync, user_id, limit)
    await cache.set_cached_recommendations(user_id, recs)
    return recs

async def refresh_all_recommendations():
    # Compute and pre-warm cache for all users
    ratings = storage.fetch_all_ratings()
    users = sorted({r['user_id'] for r in ratings if 'user_id' in r})
    if not users:
        return 0
    loop = asyncio.get_event_loop()
    tasks = [
        loop.run_in_executor(None, compute_recommendations_for_user_sync, u, 10)
        for u in users
    ]
    results = await asyncio.gather(*tasks)
    for u, recs in zip(users, results):
        await cache.set_cached_recommendations(u, recs)
    return len(users)

async def invalidate_user_recommendations(user_id: str):
    """
    Invalidate cache for a single user (called after rating changes).
    """
    await cache.invalidate_user_cache(user_id)
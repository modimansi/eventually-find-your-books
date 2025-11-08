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
    # Compute and pre-warm cache for all users (example: compute top for each distinct user in ratings)
    ratings = storage.fetch_all_ratings()
    users = set([r['user_id'] for r in ratings])
    loop = asyncio.get_event_loop()
    tasks = []
    for u in users:
        tasks.append(loop.run_in_executor(None, compute_recommendations_for_user_sync, u, 10))
    results = await asyncio.gather(*tasks)
    # set into cache
    i = 0
    for u in users:
        await cache.set_cached_recommendations(u, results[i])
        i += 1
    return len(users)

from fastapi import APIRouter, HTTPException, BackgroundTasks
from app.models import RecommendationResponse
from app import service

router = APIRouter()

@router.get("/recommendations/{user_id}", response_model=RecommendationResponse)
async def get_recommendations(user_id: str, limit: int = 10):
    recs = await service.get_recommendations(user_id, limit)
    return RecommendationResponse(user_id=user_id, recommendations=recs)

@router.post("/recommendations/refresh")
async def refresh_recommendations(background_tasks: BackgroundTasks):
    # Kick off background recompute
    background_tasks.add_task(service.refresh_all_recommendations)
    return {"status": "started"}

@router.post("/recommendations/invalidate/{user_id}")
async def invalidate_recommendations(user_id: str):
    """
    Invalidate cached recommendations for a user.
    Call this from Ratings API after a successful rating write.
    """
    await service.invalidate_user_recommendations(user_id)
    return {"status": "ok", "user_id": user_id}
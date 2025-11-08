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

import uvicorn
from fastapi import FastAPI, Response
from app.api import router
from app.config import settings
from app import cache
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

app = FastAPI(title="Recommendation Service")
app.include_router(router)

@app.get("/health")
def health() -> dict:
    return {"status": "ok"}

@app.on_event("startup")
async def startup_event():
    # establish Redis connection early
    await cache.get_redis()

@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/recommendations/metrics")
def metrics_alias() -> Response:
    # Alias to pass through ALB rule /recommendations*
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=settings.debug)

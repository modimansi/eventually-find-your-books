import uvicorn
from fastapi import FastAPI
from app.api import router
from app.config import settings
from app import cache

app = FastAPI(title="Recommendation Service")
app.include_router(router)

@app.on_event("startup")
async def startup_event():
    # establish Redis connection early
    await cache.get_redis()

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=settings.debug)

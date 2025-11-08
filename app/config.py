from pydantic import BaseSettings

class Settings(BaseSettings):
    aws_region: str = "us-west-2"
    dynamodb_table: str = "book_ratings"
    redis_url: str = "redis://redis:6379/0"   # docker-compose service name
    cache_ttl_seconds: int = 600  # default TTL 10 minutes
    debug: bool = True

    class Config:
        env_file = ".env"

settings = Settings()

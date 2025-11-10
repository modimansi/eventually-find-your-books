from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    aws_region: str = "us-west-2"
    dynamodb_table_ratings: str = "book-recommendation-ratings-dev"
    redis_url: str = "redis://localhost:6379/0"  # Use localhost for local development
    cache_ttl_seconds: int = 600  # default TTL 10 minutes
    debug: bool = True

    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'

settings = Settings()

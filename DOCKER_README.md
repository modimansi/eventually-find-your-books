# Docker Setup Guide

This document explains how to build, run, and test all services in Docker, including search-api, bookdetail-api, and Redis. Place this file (DOCKER_README.md) in the project root next to docker-compose.yml.

---

## Project Structure

final/
├── docker-compose.yml
├── DOCKER_README.md
└── services/
    ├── search-api/
    │   ├── Dockerfile
    │   ├── .dockerignore
    │   └── cmd/api/main.go
    └── bookdetail-api/
        ├── Dockerfile
        ├── .dockerignore
        └── cmd/api/main.go

---

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- Internet access to pull base images (golang:1.23-alpine, gcr.io/distroless/static:nonroot, redis:7-alpine)
- Free local ports: 8080 (search-api), 8081 (bookdetail-api), 6379 (Redis)

---

## Build and Run

1) Build all images

    docker compose build

2) Start all containers in the background

    docker compose up -d

3) Check running containers

    docker compose ps

Expected example:

    NAME              STATE   PORTS
    search-api        Up      0.0.0.0:8080->8080/tcp
    bookdetail-api    Up      0.0.0.0:8081->8081/tcp
    redis             Up      0.0.0.0:6379->6379/tcp

---

## Health Checks

Search API

    curl -s http://localhost:8080/healthz
    # ok

Book Detail API

    curl -s http://localhost:8081/healthz
    # ok

Redis

    docker exec -it redis redis-cli ping
    # PONG

---

## Basic API Tests

Search API

    # Full search
    curl -s -X POST http://localhost:8080/search \
      -H "Content-Type: application/json" \
      -d '{"query":"Harry","limit":10}'

    # Advanced search
    curl -s -X POST http://localhost:8080/search/advanced \
      -H "Content-Type: application/json" \
      -d '{"title":"Gatsby","author":"Fitzgerald"}'

    # Shard search
    curl -s "http://localhost:8080/search/shard/H?query=ham&limit=5"

Book Detail API

    # Single book
    curl -s http://localhost:8081/books/OL1000046W

    # Batch query
    curl -s -X POST http://localhost:8081/books/batch \
      -H "Content-Type: application/json" \
      -d '{"work_ids":["OL1000046W","OL3000002W"]}'

---

## Logs and Management

View logs for all containers

    docker compose logs -f

View logs for one container

    docker logs -f search-api
    docker logs -f bookdetail-api

Stop all containers (keep volumes and images)

    docker compose down

Stop and remove everything, including Redis data volume

    docker compose down -v

Clean unused images and containers

    docker system prune -f

---

## Environment Variables

Both APIs support these environment variables (configured in docker-compose.yml):

| Variable  | Description                                       | Default     |
|----------|---------------------------------------------------|-------------|
| GIN_MODE | Gin mode (release recommended for production)     | release     |
| REDIS_URL| Redis endpoint for future caching integration     | redis:6379  |

You can override them in docker-compose.yml or via an .env file.

---

## Internal Networking

Docker Compose creates a shared internal network. Services can reach each other using service names:

- search-api → http://bookdetail-api:8081
- bookdetail-api → http://search-api:8080
- both → Redis at redis:6379

This allows internal service-to-service calls without exposing extra ports.

---

## Troubleshooting

1) Port already in use  
Change host port mapping in docker-compose.yml, for example:

    ports:
      - "8082:8080"

2) Health check failing  
Inspect logs:

    docker compose logs -f

Confirm the /healthz endpoint responds with "ok".

3) Redis connection error  
Check status:

    docker exec -it redis redis-cli ping
    # PONG

Inside containers use redis:6379, not localhost.

4) Slow builds  
Ensure each service has a .dockerignore to exclude .git, node_modules, and large artifacts.

5) Apple Silicon to x86 target (AWS ECS/EC2)  
Build amd64 images with buildx:

    docker buildx build --platform linux/amd64 -t local/search-api:dev ./services/search-api --load
    docker buildx build --platform linux/amd64 -t local/bookdetail-api:dev ./services/bookdetail-api --load
    docker compose up -d

---

## Multi-Stage Build Overview

Each service Dockerfile has two stages:

1) Build stage (golang:1.23-alpine)
   - Compiles the app into a static binary (CGO_ENABLED=0).
   - Caches dependencies through go.mod/go.sum to speed up rebuilds.

2) Runtime stage (gcr.io/distroless/static:nonroot)
   - Minimal, no shell, runs as non-root user.
   - Exposes the service port (8080 for search-api, 8081 for bookdetail-api).

This yields small, secure images (~20–25 MB).

---

## Verification Checklist

- Build: docker compose build → succeeds
- Start: docker compose up -d → three containers running
- Health: curl localhost:8080/healthz and 8081/healthz → "ok"
- Redis: docker exec -it redis redis-cli ping → "PONG"
- API tests: curl examples above return valid JSON
- Stop: docker compose down -v → containers removed cleanly

---

## Summary

- Place docker-compose.yml and this README in the project root.
- Use docker compose build and docker compose up -d to build and start all services.
- Verify health endpoints and run the curl tests.
- Manage lifecycle with docker compose ps, logs -f, and down.
- Redis is included for future Cache-Aside integration.
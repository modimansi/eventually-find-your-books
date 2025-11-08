# Search API

A Go (Gin) microservice that provides simple book search functionality.  
Implements three endpoints for basic, advanced, and shard-based search.

---

## Directory Structure

search-api/
├── cmd/api/main.go
├── internal/search/
│   ├── handler.go
│   └── store_mem.go
├── Dockerfile
├── .dockerignore
└── README.md

---

## Overview

The Search API allows clients to search books from an in-memory dataset.  
Future versions can connect to databases, Redis caches, or Elasticsearch.

Key features:
- Full-text and field-based search (title, author)
- A–Z sharded search simulation
- Configurable result limits
- Health endpoint for monitoring

---

## Endpoints

| Method | Endpoint | Purpose | Example |
|--------|-----------|----------|----------|
| POST | `/search` | Full-text search across all books | `{"query": "Harry Potter", "limit": 20}` |
| POST | `/search/advanced` | Multi-field search by title and author | `{"title": "Gatsby", "author": "Fitzgerald"}` |
| GET | `/search/shard/{prefix}` | Search only within a shard (A–Z) | `/search/shard/H?query=hamlet` |
| GET | `/healthz` | Health check | — |

---

## Example Requests

Full search:

    curl -s -X POST http://localhost:8080/search \
      -H "Content-Type: application/json" \
      -d '{"query":"Harry","limit":10}'

Advanced search:

    curl -s -X POST http://localhost:8080/search/advanced \
      -H "Content-Type: application/json" \
      -d '{"title":"Gatsby","author":"Fitzgerald"}'

Shard-based search:

    curl -s "http://localhost:8080/search/shard/H?query=ham&limit=5"

Health check:

    curl -s http://localhost:8080/healthz

---

## Implementation Notes

- Uses **in-memory data** (`store_mem.go`) for testing and demonstration.
- The `Store` interface abstracts data access — can later point to:
  - DynamoDB / PostgreSQL
  - Elasticsearch / OpenSearch
  - Redis cache
- Sharded search simply filters titles by the first letter.
- JSON input is parsed with Gin’s binding system; all errors return standard JSON.

---

## Running Locally (without Docker)

Build and run:

    go mod tidy
    go run ./cmd/api

Test the endpoint:

    curl http://localhost:8080/healthz

---

## Running in Docker

From project root (where `docker-compose.yml` is located):

    docker compose up -d search-api

Standalone build:

    cd services/search-api
    docker build -t local/search-api:dev .
    docker run -p 8080:8080 local/search-api:dev

Check health:

    curl http://localhost:8080/healthz

---

## Environment Variables

| Variable | Description | Default |
|-----------|--------------|----------|
| `GIN_MODE` | Gin mode (`release` or `debug`) | `release` |
| `REDIS_URL` | Optional Redis endpoint for caching | `redis:6379` |

---

## Extending the Service

Possible improvements:
- Replace in-memory store with a real backend (PostgreSQL, DynamoDB, Elasticsearch)
- Add Redis-based caching (Cache-Aside pattern)
- Add pagination, sorting, and fuzzy matching
- Add Prometheus metrics and structured logs
- Add authentication and rate limiting

---

## License

This service is part of the Distributed Book Recommendation System (CS6650 Final Project).  
Developed in Go 1.23.
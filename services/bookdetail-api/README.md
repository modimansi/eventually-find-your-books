# Book Detail API

A Go (Gin) microservice that provides book detail retrieval by ID or batch query.  
This service is part of the Distributed Book Recommendation System.

---

## Directory Structure

bookdetail-api/
├── cmd/api/main.go
├── internal/bookdetail/
│   ├── handler.go
│   └── store_mem.go
├── Dockerfile
├── .dockerignore
└── README.md

---

## Overview

The Book Detail API allows clients to fetch book information either for a single book or for multiple books in a batch request.  
Currently, it uses an in-memory dataset but is designed to easily connect to real databases or caching layers in the future.

Key features:
- Retrieve book details by unique work ID
- Batch query multiple book IDs in a single request
- In-memory mock data for local testing
- Health endpoint for monitoring container status

---

## Endpoints

| Method | Endpoint | Purpose | Example |
|--------|-----------|----------|----------|
| GET | `/books/{book_id}` | Get details for a single book | `/books/OL1000046W` |
| POST | `/books/batch` | Get multiple books by ID list | `{"book_ids": ["OL1000046W", "OL3000002W"]}` |
| GET | `/healthz` | Health check | — |

---

## Example Requests

Single book request:

    curl -s http://localhost:8081/books/OL1000046W

Batch request:

    curl -s -X POST http://localhost:8081/books/batch \
      -H "Content-Type: application/json" \
      -d '{"book_ids": ["OL1000046W", "OL3000002W"]}'

Health check:

    curl -s http://localhost:8081/healthz

---

## Implementation Notes

- Uses **in-memory data** defined in `store_mem.go` for demonstration and testing.
- The `Store` interface abstracts data access, so it can be replaced later with:
  - DynamoDB or PostgreSQL for persistent storage
  - Redis for caching (Cache-Aside pattern)
- Returns structured JSON objects following the `BookDTO` format:
  ```json
  {
    "book_id": "OL1000046W",
    "title": "The Great Gatsby",
    "authors": ["F. Scott Fitzgerald"]
  }
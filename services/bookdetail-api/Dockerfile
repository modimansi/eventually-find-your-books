# ------------------------------
# Multi-stage Dockerfile for bookdetail-api
# Build a static Go binary, then run it in a minimal distroless image.
# ------------------------------

# ===== Build stage =====
FROM golang:1.23-alpine AS build
WORKDIR /src

RUN apk add --no-cache ca-certificates tzdata

# Cache go deps
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary for Linux amd64
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN go build -trimpath -ldflags="-s -w" -o /out/bookdetail-api ./cmd/api

# ===== Runtime stage =====
FROM gcr.io/distroless/static:nonroot
WORKDIR /app

ENV GIN_MODE=release

COPY --from=build /out/bookdetail-api /app/bookdetail-api

EXPOSE 8081

USER nonroot:nonroot

ENTRYPOINT ["/app/bookdetail-api"]
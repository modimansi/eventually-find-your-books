# ------------------------------
# Multi-stage Dockerfile for search-api
# Build a static Go binary, then run it in a minimal distroless image.
# ------------------------------

# ===== Build stage =====
FROM golang:1.23-alpine AS build
WORKDIR /src

# Install minimal build-time dependencies (certs, time zone data)
RUN apk add --no-cache ca-certificates tzdata

# Leverage build cache: copy go.mod/go.sum first
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source
COPY . .

# Build static binary for Linux amd64
# Set CGO_ENABLED=0 to avoid libc dependencies
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN go build -trimpath -ldflags="-s -w" -o /out/search-api ./cmd/api

# ===== Runtime stage =====
# Distroless: tiny, secure, no shell
FROM gcr.io/distroless/static:nonroot
WORKDIR /app

# Optional: set Gin to release mode in container
ENV GIN_MODE=release

# Copy built binary from builder
COPY --from=build /out/search-api /app/search-api

# Expose the HTTP port used by the app
EXPOSE 8080

# Run as non-root user provided by distroless
USER nonroot:nonroot

# Entrypoint: run server
ENTRYPOINT ["/app/search-api"]
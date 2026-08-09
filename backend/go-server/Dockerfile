# Multi-stage build for Go backend
FROM golang:1.26-alpine AS builder

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# ─── Production image ─────────────────────────────────────
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app

COPY --from=builder /app/server .
COPY migrations ./migrations

# Create upload directory
RUN mkdir -p /app/uploads/avatars

EXPOSE 8080

CMD ["./server"]

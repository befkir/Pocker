FROM golang:1.20 AS builder

WORKDIR /app

COPY . .

# Build the backend service
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -o poker-service .

# Final stage
FROM alpine:latest

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=builder /app/poker-service .

EXPOSE 8080

CMD ["./poker-service"]

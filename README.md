# Poker Service (Texas Hold'em)

This repository contains a simple example project built with Go (backend) and
Flutter/Dart (frontend) that evaluates poker hands, compares two hands, and
estimates win probability via Monte Carlo simulation. The architecture mirrors
the `TempConv` project with gRPC + HTTP gateway, Docker containers, and
Kubernetes manifests for deployment.

## Overview

- `backend/` – Go service implementing poker logic and exposing a gRPC API.
- `backend/proto` – Protocol buffer definitions for the service.
- `poker_frontend/` – Flutter web application communicating with the backend.
- `k8s/` – Kubernetes manifests for deploying both components.

## Getting started

1. **Prerequisites**
   - Go 1.20+
   - Flutter SDK (see [install instructions](https://flutter.dev/docs/get-started/install)).
   - Docker (amd64 images required).
   - `kubectl`, `gcloud`, `gke-gcloud-auth-plugin` for GKE deployments.
   - `k6` for load testing (optional).

2. **Backend setup**
   ```bash
   cd backend
   go mod tidy

   # generate protobuf bindings
   protoc --go_out=. --go-grpc_out=. proto/poker.proto
   ```

3. **Frontend setup**
   ```bash
   cd poker_frontend
   flutter pub get
   ```

4. **Run locally**
   - build & run backend:
     ```bash
     go run ./...
     ```
   - build & serve frontend (debug):
     ```bash
     flutter run -d web-server
     ```

5. **Docker / Kubernetes**
   Build images with `docker build` and push to a registry (e.g. GCR). Apply
   manifests in `k8s/` after adjusting image names.

6. **GKE Deployment**
   Authenticate and configure cluster using `gcloud` and `kubectl`.

7. **Testing**
   `go test ./...` runs service unit tests; `k6` scripts can hit HTTP endpoints
   for performance evaluation.

## Hand evaluation rules

- Cards are two-character strings: `<Suit><Rank>`.
- Evaluate best 5-card hand from hole + community cards (0–5).
- Ranks follow standard poker hierarchy; ties are detected properly.

See `backend/eval.go` and `backend/eval_test.go` for implementation details.

---

The remainder of this README walks through each component in more detail.

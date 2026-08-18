# Microservice Performance Comparison

Small Java 17 / Spring Boot benchmark system for comparing communication styles across five services:

| Service | HTTP port | Role |
| --- | ---: | --- |
| order-service REST baseline | 8080 | External `POST /api/orders` orchestration over REST |
| order-service gRPC-inventory variant | 8090 | Same external API, inventory call over gRPC |
| product-service | 8081 | Product lookup |
| inventory-service | 8082 / 9090 | REST inventory API and current gRPC inventory reservation |
| payment-service | 8083 | Payment processing |
| notification-service | 8084 | Notification sending |

The REST baseline keeps all service-to-service calls on REST. The current gRPC variant is intentionally partial: only `order-service -> inventory-service` uses gRPC, while product, payment, and notification remain REST.

Start the stack:

```powershell
docker compose up -d --build
```

Run smoke checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke-rest.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-grpc.ps1
```

Dashboard smoke scripts:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-rest-01-smoke-dashboard.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-grpc-01-smoke-dashboard.ps1
```

Jaeger UI: http://localhost:16686

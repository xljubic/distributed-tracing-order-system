# Microservice Performance Comparison

Small Java 17 / Spring Boot benchmark system for comparing communication styles across five services:

| Service | HTTP port | Role |
| --- | ---: | --- |
| order-service REST baseline | 8080 | External `POST /api/orders` orchestration over REST |
| order-service gRPC-inventory variant | 8090 | Same external API, inventory call over gRPC |
| order-service full-gRPC variant | 8100 | Same external API, all internal calls over gRPC |
| product-service | 8081 | Product lookup |
| inventory-service | 8082 / 9090 | REST inventory API and current gRPC inventory reservation |
| payment-service | 8083 | Payment processing |
| notification-service | 8084 | Notification sending |

Internal gRPC ports are product `9091`, inventory `9090`, payment `9092`, and notification `9093`.

The REST baseline keeps all service-to-service calls on REST. The partial gRPC variant uses gRPC only for `order-service -> inventory-service`. The full gRPC variant keeps the external HTTP `POST /api/orders` API but uses gRPC for product, inventory, payment, and notification calls.

Start the stack:

```powershell
docker compose up -d --build
```

Run smoke checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke-rest.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-grpc.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-full-grpc.ps1
```

Dashboard smoke scripts:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-rest-01-smoke-dashboard.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-grpc-01-smoke-dashboard.ps1
```

Jaeger UI: http://localhost:16686

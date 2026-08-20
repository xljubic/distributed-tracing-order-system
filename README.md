# Microservice Performance Comparison

Small Java 17 / Spring Boot benchmark system for comparing distributed communication styles. Every model exposes the same external `POST /api/orders` API; only internal communication changes.

| Model | External port | Internal communication |
| --- | ---: | --- |
| REST | 8080 | Product, inventory, payment, and notification over REST |
| Partial gRPC | 8090 | Inventory over gRPC; other calls over REST |
| Full gRPC | 8100 | Product, inventory, payment, and notification over gRPC |
| Async/event-driven | 8110 | REST synchronous critical path + Kafka notification |
| Hybrid | 8120 | gRPC synchronous critical path + Kafka notification |

Service ports are product `8081`/`9091`, inventory `8082`/`9090`, payment `8083`/`9092`, and notification `8084`/`9093`. The Docker-internal Kafka broker is `kafka:9092`; optional host access is `localhost:9094`.

Start the stack:

```powershell
docker compose up -d --build
```

Run smoke checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke-rest.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-grpc.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-full-grpc.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-async.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-hybrid.ps1
```

Dashboard smoke scripts:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-rest-01-smoke-dashboard.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-grpc-01-smoke-dashboard.ps1
```

Ports: `8080` REST, `8090` partial gRPC, `8100` full gRPC, `8110` async, `8120` hybrid, `16686` Jaeger, `9094` Kafka host access.

Jaeger UI: http://localhost:16686

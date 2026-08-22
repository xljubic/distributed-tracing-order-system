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
docker compose --profile rest --profile partial-grpc --profile full-grpc --profile async --profile hybrid up -d --build
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

## Final experiment workflow

Final measurements must run one model at a time. Compose profiles isolate the selected order-service variant while reusing the databases, product, inventory, payment, and notification infrastructure. Each repetition resets the five PostgreSQL databases, clears Kafka state, and recreates Jaeger so trace storage starts empty and bounded before a fresh warm-up.

Reset the five PostgreSQL databases to the repository seed state, clear Kafka state, recreate Jaeger, then start one model and warm it with exactly 20 successful order requests:

```powershell
.\scripts\reset-experiment.ps1
.\scripts\start-model.ps1 -Model rest
.\scripts\warmup-model.ps1 -Model rest -Requests 20
```

Run the five measured scenarios with five repetitions for one model:

```powershell
.\scripts\run-final-experiments.ps1 -Model rest -Runs 5
```

Use `-Model all` to run every model sequentially. Use `-Scenario baseline`, `stress`, `spike`, `endurance`, or `edge` to run one scenario, or `-Scenario all` for the default complete set. Each repetition performs the same configured number of successful warm-up requests before measurement; use `-WarmupRequests` to change the default of 20. Each session is stored under `results/final/<timestamp>/` with `metadata.json`; smoke and dashboard scripts remain separate.

Aggregate a session using Python where available:

```powershell
python .\scripts\aggregate-results.py results\final\<timestamp>
```

On Windows without Python, use the equivalent PowerShell aggregator:

```powershell
.\scripts\aggregate-results.ps1 -ResultsFolder results\final\<timestamp>
```

Both aggregators produce `raw-results.csv`, `aggregated-results.csv`, and `comparison.csv`. Use `.\scripts\trace-check.ps1` after representative runs to query the expected Jaeger service names and trace endpoints.

## Supplementary literature benchmark

The isolated literature benchmark uses the existing Order Service and Product Service without changing `POST /api/orders`. The client calls one of these endpoints on the running Order Service:

```text
GET /api/supplementary/literature/{transport}/{shape}/{payloadSize}
```

Use `rest` or `grpc` for `transport`, `flat` or `nested` for `shape`, and `small`, `medium`, or `large` for `payloadSize`. Product ID 1 is read from the existing deterministic Product Service seed data. Flat responses contain product fields and `payload`; nested responses contain the same product under `product` and payload metadata/data under `payload`. The fixed payload data sizes are 128, 4,096, and 65,536 ASCII characters respectively.

The supplementary smoke check exercises both transports, both shapes, all payload sizes, and the unchanged order endpoint:

```powershell
.\scripts\smoke-literature-benchmark.ps1
```

Any load tool can call the endpoint repeatedly with different transport, shape, payload, and load settings. Latency, p95, throughput, and error rate come from the load tool; CPU and RAM can be sampled for the Order and Product Service containers with `docker stats` during each isolated run.

The complete literature workflow uses one reusable implementation with three separate result sets:

```powershell
.\scripts\run-literature-benchmarks.ps1 -Set all -Runs 3
```

Use `-Set niswar`, `-Set jarmoszewicz`, or `-Set hamo` to run one source. Add `-Smoke` for the reduced six-run validation matrix (two Niswar request-count cases, one Jarmoszewicz case per protocol/payload pairing, and one Hamo case per protocol/payload pairing):

```powershell
.\scripts\run-literature-benchmarks.ps1 -Set all -Runs 1 -Smoke
```

Niswar uses exactly 100, 200, 300, 400, and 500 requests at one VU with the fixed 128-byte payload. Jarmoszewicz uses flat responses, 1,024-byte and 896,000-byte payloads at 10, 50, and 100 VU. Hamo uses flat responses and the existing 128-, 4,096-, and 65,536-byte payloads at 10, 50, and 100 VU. Load-controlled runs last 10 seconds by default; use `-DurationSeconds` to change this. Every run performs 10 read-only warm-up requests before sampling and measurement.

Results never mix sources: each session stores raw files and per-set outputs under `results/literature/<timestamp>/<set>/raw/`. Resource samples are saved beside each k6 JSON result as `.resources.csv`, containing UTC timestamp, container, CPU percentage, and memory bytes for `order-service-rest` and `product-service`. The aggregator writes each set's `aggregated-results.csv` and `summary.csv`, plus the session-level `literature-comparison-summary.csv`.

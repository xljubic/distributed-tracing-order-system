Canonical scripts (brief usage):

- aggregate-literature-results.ps1: Aggregate literature benchmark JSON + resource CSV files.
  Usage: powershell -File scripts\aggregate-literature-results.ps1 -SessionFolder results\literature\2026-08-23_012749

- aggregate-performance-results.ps1: Aggregate final performance run JSON files.
  Usage: powershell -File scripts\aggregate-performance-results.ps1 -SessionFolder results\performance\2026-08-21_165935

- analyze-traces.py: Analyze tracing session and produce CSV summaries.
  Usage: python scripts\analyze-traces.py results\tracing\final\<timestamp>

- collect-literature-docker-stats.ps1: Collect container resource samples during runs.

- reset-experiment.ps1: Reset application, database and Kafka state.

- run-literature-benchmarks.ps1: Run literature benchmark suite.

- run-performance-experiment.ps1: Run canonical performance experiment (historical).

- run-tracing-experiment.ps1: Run controlled-probe tracing experiment (final run, heavy). Do NOT run without review.

- smoke-literature-benchmark.ps1: Smoke run for literature benchmark.

- smoke-model.ps1: Run a single-model smoke k6 test. Usage: powershell -File scripts\smoke-model.ps1 -Model rest

- start-model.ps1: Start services for a specific model profile.

- verify-jaeger-persistence.ps1: Verify Jaeger Badger persistence across restart.

- warmup-model.ps1: Warm up model endpoints before measurements.

Note: This README intentionally lists scripts considered canonical for thesis preparation. Deleted legacy dashboard and demo scripts are removed.
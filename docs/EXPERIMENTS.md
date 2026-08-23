Experiments overview

This document explains the relationship between the external k6 performance
experiments, the literature benchmark, and the tracing-based internal analysis.

1. External k6 performance experiments
   - Canonical performance experiment: results/performance/2026-08-21_165935
   - Measures: latency distribution, throughput, p95, error rates
   - Authority: The k6 runs and aggregated CSVs are the authoritative external measurements

2. Literature benchmark
   - Canonical literature dataset: results/literature/2026-08-23_012749
   - Purpose: contextualize performance against published workloads (Niswar, Jarmoszewicz, Hamo)

3. Distributed tracing internal analysis
   - Purpose: explain where latency occurs internally and why communication-model changes affect observed performance
   - Uses controlled-probe experiments with ParentBased sampler (root ratio 0) so only externally-sampled probe traces are preserved

Methodology notes
- k6 answers WHAT happened externally (latency, errors)
- Distributed tracing helps explain WHERE time is spent and WHICH dependencies contribute
- Tracing experiments are shorter background-load profiles with controlled probes for observation, not statistical benchmarking

Refer to scripts/README.md for script invocations.
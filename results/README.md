This folder contains canonical experiment results and tracing outputs.

Structure:

- performance/
  - 2026-08-21_165935/  # canonical 125-run performance experiment (tracked)

- literature/
  - 2026-08-23_012749/  # canonical 180-run literature benchmark (tracked)

- tracing/
  - smoke/               # disposable smoke runs (ignored)
  - final/               # final tracing runs (tracked metadata/archives)

Files:
- aggregated-results.csv: aggregated experiment CSVs for the performance experiment
- literature-comparison-summary.csv: aggregated literature comparison summary
- raw-checksums.sha256: SHA-256 manifests for raw evidence

Notes:
- Do NOT modify the canonical raw JSON evidence in the performance and literature folders.
- The tracing raw expansion directories under results/tracing/final/*/raw are ignored; final archives are tracked instead.
Aggregation note for literature canonical dataset

What changed:
- Fixed aggregator to correctly compute `mean_error_rate` by reading `http_req_failed.value` when present (k6 v0.44+ metric shape), and falling back to `passes/(passes+fails)` when not available.
- Added guards to detect inconsistent or missing metrics and fail-fast to prevent silent zero error rates.

Verification:
- Raw JSON and `.resources.csv` files were not modified.
- `raw-checksums.sha256` present and used to validate file integrity.

Purpose:
- Document the aggregation bugfix and confirm canonical raw data preservation.

If you need more details or the exact code change, check `scripts/aggregate-literature-results.ps1` in the `scripts/` folder.

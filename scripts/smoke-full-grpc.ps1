Remove-Item Env:K6_WEB_DASHBOARD -ErrorAction SilentlyContinue
Remove-Item Env:K6_WEB_DASHBOARD_OPEN -ErrorAction SilentlyContinue
Remove-Item Env:K6_WEB_DASHBOARD_PORT -ErrorAction SilentlyContinue
Remove-Item Env:K6_WEB_DASHBOARD_EXPORT -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force "results\full-grpc" | Out-Null

$env:BASE_URL="http://localhost:8100"

Write-Host "Running full gRPC smoke test..." -ForegroundColor Cyan
Write-Host "Target: $env:BASE_URL" -ForegroundColor Yellow

k6 run `
  --summary-export="results\full-grpc\01-smoke-summary.json" `
  k6-tests\rest\01-smoke-test.js

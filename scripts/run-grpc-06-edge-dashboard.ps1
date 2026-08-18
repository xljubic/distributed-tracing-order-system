param(
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

# Clean previously inherited k6 variables so scripts do not affect each other.
Get-ChildItem Env:K6* | Remove-Item -ErrorAction SilentlyContinue
Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force "results\grpc-inventory" | Out-Null
New-Item -ItemType Directory -Force "screenshots\grpc-inventory" | Out-Null

$env:BASE_URL = "http://localhost:8090"
$env:K6_WEB_DASHBOARD = "true"
$env:K6_WEB_DASHBOARD_PORT = "5666"

if (-not $NoBrowser) {
    $env:K6_WEB_DASHBOARD_OPEN = "true"
}

Write-Host "Running Edge-case test - gRPC-inventory..." -ForegroundColor Cyan
Write-Host "Target: $env:BASE_URL" -ForegroundColor Yellow
Write-Host "Dashboard: http://localhost:5666" -ForegroundColor Green
Write-Host "JSON summary: results\grpc-inventory\06-edge-summary.json" -ForegroundColor Green
Write-Host "Screenshots folder: screenshots\grpc-inventory" -ForegroundColor Green
Write-Host ""

k6 run `
  --summary-export="results\grpc-inventory\06-edge-summary.json" `
  "k6-tests\rest\06-edge-case-test.js"

$exitCode = $LASTEXITCODE

# Clean dashboard variables after the run.
Get-ChildItem Env:K6* | Remove-Item -ErrorAction SilentlyContinue
Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue

exit $exitCode

param(
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

# Clean previously inherited k6 variables so scripts do not affect each other.
Get-ChildItem Env:K6* | Remove-Item -ErrorAction SilentlyContinue
Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force "results\rest" | Out-Null
New-Item -ItemType Directory -Force "screenshots\rest" | Out-Null

$env:BASE_URL = "http://localhost:8080"
$env:K6_WEB_DASHBOARD = "true"
$env:K6_WEB_DASHBOARD_PORT = "5665"

if (-not $NoBrowser) {
    $env:K6_WEB_DASHBOARD_OPEN = "true"
}

Write-Host "Running Baseline load test - REST..." -ForegroundColor Cyan
Write-Host "Target: $env:BASE_URL" -ForegroundColor Yellow
Write-Host "Dashboard: http://localhost:5665" -ForegroundColor Green
Write-Host "JSON summary: results\rest\02-baseline-summary.json" -ForegroundColor Green
Write-Host "Screenshots folder: screenshots\rest" -ForegroundColor Green
Write-Host ""

k6 run `
  --summary-export="results\rest\02-baseline-summary.json" `
  "k6-tests\rest\02-baseline-load-test.js"

$exitCode = $LASTEXITCODE

# Clean dashboard variables after the run.
Get-ChildItem Env:K6* | Remove-Item -ErrorAction SilentlyContinue
Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue

exit $exitCode

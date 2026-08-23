param(
    [ValidateSet('rest','partial-grpc','full-grpc','async','hybrid')]
    [string]$Model,
    [string]$OutputRoot = "results/tracing/smoke"
)

$endpoints = @{
    rest = 'http://localhost:8080'
    'partial-grpc' = 'http://localhost:8090'
    'full-grpc' = 'http://localhost:8100'
    async = 'http://localhost:8110'
    hybrid = 'http://localhost:8120'
}

if (-not $endpoints.ContainsKey($Model)) {
    throw "Unknown model: $Model"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$baseUrl = $endpoints[$Model]
$sessionDir = Join-Path $OutputRoot $Model
New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null

# Run the canonical smoke test (k6) against the chosen model. Outputs are stored
# under results/tracing/smoke and are considered disposable.
$env:BASE_URL = $baseUrl
Write-Host "Running smoke k6 against $Model ($baseUrl) - output: $sessionDir"
# Note: actual run is deliberate and controlled by the user; this script only
# invokes the standard smoke test.
& k6 run k6-tests/performance/01-smoke-test.js --summary-export=$sessionDir\summary.json
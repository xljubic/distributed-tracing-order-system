param(
    [string]$JaegerUrl = "http://localhost:16686"
)

$ErrorActionPreference = "Stop"
$services = @(
    "order-service-rest",
    "order-service-grpc",
    "order-service-full-grpc",
    "order-service-async",
    "order-service-hybrid"
)

try {
    Invoke-WebRequest -Uri "$JaegerUrl/api/services" -UseBasicParsing | Out-Null
} catch {
    throw "Jaeger is not reachable at $JaegerUrl."
}

Write-Host "Jaeger is reachable at $JaegerUrl" -ForegroundColor Green
foreach ($service in $services) {
    $queryUrl = "$JaegerUrl/api/traces?service=$service&limit=5"
    try {
        $traces = (Invoke-WebRequest -Uri $queryUrl -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json).data
        Write-Host "${service}: $($traces.Count) trace result(s)" -ForegroundColor Green
        Write-Host "  $queryUrl"
    } catch {
        Write-Host "${service}: no query result or service not observed yet" -ForegroundColor Yellow
        Write-Host "  $queryUrl"
    }
}
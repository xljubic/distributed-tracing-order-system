<#
.SYNOPSIS
    Automated Jaeger persistence smoke check (thesis Phase 6).

.DESCRIPTION
        Confirms that traces survive a Jaeger container restart when
        docker-compose.tracing.yml (Badger storage) is applied:
            1. Sends one order request and captures its trace id.
            2. Confirms the trace is retrievable from the Jaeger Query API.
            3. Captures the full set of span IDs from that trace.
            4. Restarts the jaeger container.
            5. Confirms the same trace id exists and that every pre-restart span ID is
                 still present after restart (additional late-arriving spans are allowed).

.PARAMETER Endpoint
    Order-service endpoint to call. Default http://localhost:8080 (REST model).
#>
param(
    [string]$Endpoint = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Get-JaegerTrace {
    param([string]$TraceId)
    try {
        return Invoke-RestMethod -Uri "http://localhost:16686/api/traces/$TraceId" -TimeoutSec 15
    } catch {
        return $null
    }
}

Write-Host "Sending a probe order request to $Endpoint ..." -ForegroundColor Cyan
$traceId = -join ((1..32) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
$spanId = -join ((1..16) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
$traceparent = "00-$traceId-$spanId-01"
$payload = '{"items":[{"productId":1,"quantity":1}]}'

$response = Invoke-WebRequest -Uri "$Endpoint/api/orders" -Method Post -Body $payload `
    -ContentType "application/json" -Headers @{ traceparent = $traceparent } -UseBasicParsing -TimeoutSec 30
if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
    throw "Probe order request failed with status $($response.StatusCode)."
}

# Allow the OpenTelemetry batch span processor to flush every span in the trace
# before taking the "before restart" snapshot, otherwise a late-arriving span can
# be mistaken for data loss (or gain) caused by the restart itself.
Start-Sleep -Seconds 10
$before = Get-JaegerTrace -TraceId $traceId
if (-not $before -or -not $before.data -or $before.data.Count -eq 0) {
    throw "Trace $traceId was not found in Jaeger before restart. Persistence check FAILED."
}
$spanIdsBefore = @(
    $before.data[0].spans |
        ForEach-Object { $_.spanID } |
        Sort-Object -Unique
)
if ($spanIdsBefore.Count -eq 0) {
    throw "Trace $traceId has no spans before restart. Persistence check FAILED."
}

$spanCountBefore = $spanIdsBefore.Count
Write-Host "Trace $traceId found before restart with $spanCountBefore unique span ID(s)." -ForegroundColor Green

Write-Host "Restarting jaeger container..." -ForegroundColor Cyan
docker restart jaeger | Out-Null
Start-Sleep -Seconds 8

$deadline = (Get-Date).AddSeconds(60)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $health = Invoke-WebRequest -Uri "http://localhost:16686/" -UseBasicParsing -TimeoutSec 5
        if ($health.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    throw "Jaeger did not become healthy again after restart."
}

$after = Get-JaegerTrace -TraceId $traceId
if (-not $after -or -not $after.data -or $after.data.Count -eq 0) {
    throw "Trace $traceId was NOT found in Jaeger after restart. Persistence check FAILED."
}
$spanIdsAfter = @(
    $after.data[0].spans |
        ForEach-Object { $_.spanID } |
        Sort-Object -Unique
)
$spanCountAfter = $spanIdsAfter.Count

$afterSet = @{}
foreach ($id in $spanIdsAfter) {
    $afterSet[$id] = $true
}

$missingSpanIds = @(
    $spanIdsBefore |
        Where-Object { -not $afterSet.ContainsKey($_) }
)

if ($missingSpanIds.Count -gt 0) {
    throw "Trace $traceId is missing $($missingSpanIds.Count) pre-restart span ID(s) after restart. Persistence check FAILED."
}

Write-Host "Trace $traceId found after restart with $spanCountAfter unique span ID(s)." -ForegroundColor Green
Write-Host "Jaeger persistence check PASSED." -ForegroundColor Green

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("rest", "partial-grpc", "full-grpc", "async", "hybrid")]
    [string]$Model,
    [ValidateRange(1, 10000)]
    [int]$Requests = 20
)

$ErrorActionPreference = "Stop"
$endpoints = @{
    "rest" = "http://localhost:8080"
    "partial-grpc" = "http://localhost:8090"
    "full-grpc" = "http://localhost:8100"
    "async" = "http://localhost:8110"
    "hybrid" = "http://localhost:8120"
}
$payload = '{"items":[{"productId":1,"quantity":1}]}'
$successfulRequests = 0
$attempts = 0
$maxAttempts = [Math]::Max($Requests * 3, $Requests + 5)

$endpoint = $endpoints[$Model]
Write-Host "Warming up $Model with exactly $Requests successful requests..." -ForegroundColor Cyan
while ($successfulRequests -lt $Requests -and $attempts -lt $maxAttempts) {
    $attempts++
    try {
        $response = Invoke-WebRequest -Uri "$endpoint/api/orders" -Method Post -Body $payload -ContentType "application/json" -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            $successfulRequests++
        }
    } catch {
        Write-Verbose "Warm-up request failed: $($_.Exception.Message)"
    }
}

if ($successfulRequests -ne $Requests) {
    throw "Warm-up failed for model '$Model': only $successfulRequests/$Requests successful requests after $attempts attempts."
}

Write-Host "Warm-up complete: $successfulRequests/$Requests successful requests." -ForegroundColor Green
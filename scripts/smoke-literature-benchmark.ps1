$ErrorActionPreference = "Stop"

$baseUrl = if ($env:LITERATURE_BENCHMARK_BASE_URL) { $env:LITERATURE_BENCHMARK_BASE_URL } else { "http://localhost:8080" }
$payloadLengths = @{ small = 128; medium = 4096; large = 65536 }

function Get-BenchmarkResponse([string]$transport, [string]$shape, [string]$payloadSize) {
    $uri = "$baseUrl/api/supplementary/literature/$transport/$shape/$payloadSize"
    $response = Invoke-RestMethod -Uri $uri -Method Get
    if ($shape -eq "flat") {
        if ($response.id -ne 1 -or $response.payload.Length -ne $payloadLengths[$payloadSize]) { throw "Invalid $transport flat $payloadSize response." }
    } else {
        if ($response.product.id -ne 1 -or $response.payload.data.Length -ne $payloadLengths[$payloadSize]) { throw "Invalid $transport nested $payloadSize response." }
    }
    return $response
}

foreach ($shape in @("flat", "nested")) {
    foreach ($payloadSize in @("small", "medium", "large")) {
        $rest = Get-BenchmarkResponse "rest" $shape $payloadSize
        $grpc = Get-BenchmarkResponse "grpc" $shape $payloadSize
        if ((ConvertTo-Json $rest -Depth 10 -Compress) -ne (ConvertTo-Json $grpc -Depth 10 -Compress)) {
            throw "REST and gRPC responses differ for $shape/$payloadSize."
        }
    }
}

$orderPayload = '{"items":[{"productId":1,"quantity":1}]}'
$order = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Method Post -Body $orderPayload -ContentType "application/json"
if ($null -eq $order.id) { throw "Existing POST /api/orders smoke check failed." }

Write-Host "Literature benchmark smoke checks passed: REST/gRPC flat and nested responses, all payload sizes, and POST /api/orders." -ForegroundColor Green
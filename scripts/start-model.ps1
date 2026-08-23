param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("rest", "partial-grpc", "full-grpc", "async", "hybrid")]
    [string]$Model,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$modelConfig = @{
    "rest" = @{ Service = "order-service-rest"; Endpoint = "http://localhost:8080" }
    "partial-grpc" = @{ Service = "order-service-partial-grpc"; Endpoint = "http://localhost:8090" }
    "full-grpc" = @{ Service = "order-service-full-grpc"; Endpoint = "http://localhost:8100" }
    "async" = @{ Service = "order-service-async"; Endpoint = "http://localhost:8110" }
    "hybrid" = @{ Service = "order-service-hybrid"; Endpoint = "http://localhost:8120" }
}
$allProfiles = @("--profile", "rest", "--profile", "partial-grpc", "--profile", "full-grpc", "--profile", "async", "--profile", "hybrid")

Write-Host "Stopping previously measured order-service variants..." -ForegroundColor Cyan
foreach ($serviceName in @("order-service-rest", "order-service-partial-grpc", "order-service-full-grpc", "order-service-async", "order-service-hybrid")) {
    $containerId = docker compose @allProfiles ps -q $serviceName 2>$null
    if ($containerId) {
        docker stop $containerId | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not stop previous order-service variant '$serviceName'."
        }
    }
}

$config = $modelConfig[$Model]
Write-Host "Starting model '$Model'..." -ForegroundColor Cyan
docker compose --profile $Model up -d $config.Service
if ($LASTEXITCODE -ne 0) {
    throw "Could not start model '$Model'."
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $response = Invoke-WebRequest -Uri "$($config.Endpoint)/api/orders" -Method Get -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        # The application may still be starting or waiting for its database.
    }
    Start-Sleep -Seconds 3
}

if (-not $ready) {
    docker compose --profile $Model logs --tail=80 $config.Service
    throw "Model '$Model' did not become ready within $TimeoutSeconds seconds."
}

$runningServices = docker compose @allProfiles ps --status running --services
if ($runningServices -notcontains $config.Service) {
    throw "Selected model '$Model' is not running after startup."
}

Write-Host "Selected model: $Model" -ForegroundColor Green
Write-Host "Endpoint: $($config.Endpoint)" -ForegroundColor Green
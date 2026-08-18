Write-Host "Checking Docker Desktop..." -ForegroundColor Cyan

docker version

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop is not running. Start Docker Desktop and run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Creating results folders..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force "results\demo" | Out-Null
New-Item -ItemType Directory -Force "results\rest" | Out-Null
New-Item -ItemType Directory -Force "results\grpc-inventory" | Out-Null

Write-Host "Stopping old Docker Compose services..." -ForegroundColor Cyan

docker compose down --remove-orphans

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Compose down failed." -ForegroundColor Red
    exit 1
}

Write-Host "Building Docker images..." -ForegroundColor Cyan

docker compose build

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Compose build failed." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Docker Compose services..." -ForegroundColor Cyan

docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Compose up failed." -ForegroundColor Red
    exit 1
}

Write-Host "Waiting for services to start..." -ForegroundColor Cyan

Start-Sleep -Seconds 70

Write-Host "Current Docker status:" -ForegroundColor Cyan

docker compose ps

Write-Host ""
Write-Host "REST order-service: http://localhost:8080/swagger-ui/index.html" -ForegroundColor Green
Write-Host "gRPC inventory variant: http://localhost:8090/swagger-ui/index.html" -ForegroundColor Green
Write-Host "Jaeger: http://localhost:16686" -ForegroundColor Green
Write-Host ""
Write-Host "Smoke REST: .\scripts\smoke-rest.ps1" -ForegroundColor Yellow
Write-Host "Smoke gRPC-inventory: .\scripts\smoke-grpc.ps1" -ForegroundColor Yellow
Write-Host "REST stress dashboard: .\scripts\run-rest-03-stress-dashboard.ps1" -ForegroundColor Yellow
Write-Host "gRPC-inventory stress dashboard: .\scripts\run-grpc-03-stress-dashboard.ps1" -ForegroundColor Yellow

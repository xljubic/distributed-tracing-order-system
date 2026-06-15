Write-Host "Checking Docker Desktop..." -ForegroundColor Cyan
docker version

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop is not running. Start Docker Desktop and run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Building Maven project..." -ForegroundColor Cyan
mvn package -DskipTests

if ($LASTEXITCODE -ne 0) {
    Write-Host "Maven build failed. Fix the build first, then run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Docker Compose services..." -ForegroundColor Cyan
docker compose down
docker compose up -d --build

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Compose failed." -ForegroundColor Red
    exit 1
}

Write-Host "Waiting for services to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 70

Write-Host "Current Docker status:" -ForegroundColor Cyan
docker compose ps

Write-Host ""
Write-Host "REST order-service:        http://localhost:8080/swagger-ui/index.html" -ForegroundColor Green
Write-Host "gRPC inventory variant:    http://localhost:8090/swagger-ui/index.html" -ForegroundColor Green
Write-Host "Jaeger:                    http://localhost:16686" -ForegroundColor Green
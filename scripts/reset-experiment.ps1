$ErrorActionPreference = "Stop"

$allProfiles = @("--profile", "rest", "--profile", "partial-grpc", "--profile", "full-grpc", "--profile", "async", "--profile", "hybrid")
$orderServices = @("order-service-rest", "order-service-grpc", "order-service-full-grpc", "order-service-async", "order-service-hybrid")
$databaseServices = @("product-db", "order-db", "inventory-db", "payment-db", "notification-db")
$applicationServices = @("product-service", "inventory-service", "payment-service", "notification-service")
$jaegerService = @("jaeger")
$kafkaService = @("kafka")
$resetServices = $orderServices + $databaseServices + $applicationServices + $jaegerService + $kafkaService

Write-Host "Stopping experiment services and removing database and Kafka state..." -ForegroundColor Cyan
docker compose @allProfiles stop ($resetServices)
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose reset failed."
}

docker compose @allProfiles rm -f ($resetServices)
if ($LASTEXITCODE -ne 0) {
    throw "Could not remove stopped experiment containers."
}

$databaseVolumeSuffixes = @("product_db_data", "order_db_data", "inventory_db_data", "payment_db_data", "notification_db_data")
$databaseVolumes = docker volume ls --format "{{.Name}}" | Where-Object {
    $volumeName = $_
    $databaseVolumeSuffixes | Where-Object { $volumeName -like "*_$($_)" }
}
if ($databaseVolumes) {
    docker volume rm $databaseVolumes
    if ($LASTEXITCODE -ne 0) {
        throw "Could not remove database volumes."
    }
}

$kafkaVolumeSuffixes = @("kafka_data")
$kafkaVolumes = docker volume ls --format "{{.Name}}" | Where-Object {
    $volumeName = $_
    $kafkaVolumeSuffixes | Where-Object { $volumeName -like "*_$($_)" }
}
if ($kafkaVolumes) {
    docker volume rm $kafkaVolumes
    if ($LASTEXITCODE -ne 0) {
        throw "Could not remove Kafka volume."
    }
}

Write-Host "Starting shared experiment infrastructure..." -ForegroundColor Cyan
docker compose up -d product-db order-db inventory-db payment-db notification-db kafka jaeger product-service inventory-service payment-service notification-service
if ($LASTEXITCODE -ne 0) {
    throw "Shared infrastructure startup failed."
}

Write-Host "Reset complete: all five PostgreSQL volumes were deleted and recreated from the repository seed migrations; Kafka state was cleared; Jaeger was recreated for a fresh in-memory trace store." -ForegroundColor Green
$env:BASE_URL="http://localhost:8090"
$env:K6_WEB_DASHBOARD="true"
$env:K6_WEB_DASHBOARD_OPEN="true"
$env:K6_WEB_DASHBOARD_PORT="5666"
$env:K6_WEB_DASHBOARD_EXPORT="results\demo\grpc-stress-report.html"

Write-Host "Running gRPC-inventory stress test..." -ForegroundColor Cyan
Write-Host "Dashboard: http://localhost:5666" -ForegroundColor Green

k6 run k6-tests\rest\03-stress-test.js
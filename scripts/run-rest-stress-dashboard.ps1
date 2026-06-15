$env:BASE_URL="http://localhost:8080"
$env:K6_WEB_DASHBOARD="true"
$env:K6_WEB_DASHBOARD_OPEN="true"
$env:K6_WEB_DASHBOARD_PORT="5665"
$env:K6_WEB_DASHBOARD_EXPORT="results\demo\rest-stress-report.html"

Write-Host "Running REST stress test..." -ForegroundColor Cyan
Write-Host "Dashboard: http://localhost:5665" -ForegroundColor Green

k6 run k6-tests\rest\03-stress-test.js
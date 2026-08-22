param(
    [ValidateSet("all", "niswar", "jarmoszewicz", "hamo")]
    [string]$Set = "all",
    [ValidateRange(1, 100)]
    [int]$Runs = 3,
    [switch]$Smoke,
    [ValidateRange(1, 300)]
    [int]$WarmupRequests = 10,
    [ValidateRange(1, 3600)]
    [int]$DurationSeconds = 10
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$baseUrl = if ($env:LITERATURE_BENCHMARK_BASE_URL) { $env:LITERATURE_BENCHMARK_BASE_URL } else { "http://localhost:8080" }
$k6RequestScript = Join-Path $repoRoot "k6-tests\literature\request-count-test.js"
$k6LoadScript = Join-Path $repoRoot "k6-tests\literature\load-test.js"
$statsScript = Join-Path $repoRoot "scripts\collect-literature-docker-stats.ps1"
$aggregatorScript = Join-Path $repoRoot "scripts\aggregate-literature-results.ps1"
$sessionName = Get-Date -Format "yyyy-MM-dd_HHmmss"
$sessionRoot = Join-Path $repoRoot "results\literature\$sessionName"
$duration = if ($Smoke) { 3 } else { $DurationSeconds }
$effectiveRuns = $Runs

if (Test-Path $sessionRoot) { throw "Experiment session already exists: $sessionRoot" }
New-Item -ItemType Directory -Force $sessionRoot | Out-Null

function Get-ToolVersion([string]$command, [string[]]$arguments) {
    try { return ((& $command @arguments 2>&1 | Out-String).Trim()) } catch { return "unavailable" }
}

function Assert-ContainerRunning([string]$name) {
    $running = docker inspect --format '{{.State.Running}}' $name 2>$null
    if ($LASTEXITCODE -ne 0 -or $running -ne "true") { throw "Required container '$name' is not running." }
}

function Invoke-Warmup([string]$protocol, [string]$shape, [string]$payloadSize) {
    $successful = 0
    $attempts = 0
    $maxAttempts = [Math]::Max($WarmupRequests * 3, $WarmupRequests + 5)
    while ($successful -lt $WarmupRequests -and $attempts -lt $maxAttempts) {
        $attempts++
        try {
            $response = Invoke-RestMethod -Uri "$baseUrl/api/supplementary/literature/$protocol/$shape/$payloadSize" -Method Get -TimeoutSec 30
            if ($null -ne $response) { $successful++ }
        } catch { }
    }
    if ($successful -ne $WarmupRequests) { throw "Warm-up failed for $protocol/$shape/${payloadSize}: $successful/$WarmupRequests successful requests." }
}

function Assert-Summary([string]$path, [int]$expectedRequests) {
    if (-not (Test-Path $path)) { throw "k6 did not create summary JSON: $path" }
    try { $summary = Get-Content $path -Raw | ConvertFrom-Json } catch { throw "Invalid k6 summary JSON: $path" }
    if ($null -eq $summary.metrics -or $null -eq $summary.metrics.http_req_duration) { throw "Required k6 metrics are missing: $path" }
    if ($expectedRequests -gt 0) {
        $requestMetric = $summary.metrics.PSObject.Properties["http_reqs"].Value
        $actual = [int]$requestMetric.PSObject.Properties["count"].Value
        if ($actual -ne $expectedRequests) { throw "Expected $expectedRequests requests but k6 recorded $actual in $path." }
    }
}

function Invoke-MeasuredRun([string]$paper, [string]$protocol, [string]$shape, [string]$payloadSize, [int]$requestCount, [int]$vus) {
    Assert-ContainerRunning "order-service-rest"
    Assert-ContainerRunning "product-service"
    Invoke-Warmup $protocol $shape $payloadSize

    $suffix = if ($requestCount -gt 0) { "$requestCount" } else { "vu$vus" }
    $fileName = if ($paper -eq "niswar") {
        "$paper-$protocol-$shape-$suffix-run-{0:D2}.json"
    } else {
        "$paper-$protocol-$payloadSize-$suffix-run-{0:D2}.json"
    }
    $rawFolder = Join-Path $sessionRoot "$paper\raw"
    New-Item -ItemType Directory -Force $rawFolder | Out-Null
    $resultPath = Join-Path $rawFolder ($fileName -f $script:currentRun)
    $resourcePath = $resultPath -replace '\.json$', '.resources.csv'
    $stopFile = Join-Path $rawFolder ("$($fileName -f $script:currentRun).stop")
    if (Test-Path $resultPath) { throw "Refusing to overwrite result: $resultPath" }

    $collectorJob = Start-Job -FilePath $statsScript -ArgumentList $resourcePath, $stopFile, 1
    try {
        $env:BASE_URL = $baseUrl
        $env:PROTOCOL = $protocol
        $env:SHAPE = $shape
        $env:PAYLOAD_SIZE = $payloadSize
        if ($requestCount -gt 0) {
            $env:TOTAL_REQUESTS = [string]$requestCount
            Remove-Item Env:VUS -ErrorAction SilentlyContinue
            & k6 run "--summary-export=$resultPath" $k6RequestScript
        } else {
            $env:VUS = [string]$vus
            $env:DURATION = "${duration}s"
            Remove-Item Env:TOTAL_REQUESTS -ErrorAction SilentlyContinue
            & k6 run "--summary-export=$resultPath" $k6LoadScript
        }
        $k6ExitCode = $LASTEXITCODE
    } finally {
        New-Item -ItemType File -Force $stopFile | Out-Null
        Wait-Job $collectorJob -Timeout 15 | Out-Null
        Receive-Job $collectorJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job $collectorJob -Force -ErrorAction SilentlyContinue
        Remove-Item $stopFile -Force -ErrorAction SilentlyContinue
        Remove-Item Env:BASE_URL, Env:PROTOCOL, Env:SHAPE, Env:PAYLOAD_SIZE, Env:TOTAL_REQUESTS, Env:VUS, Env:DURATION -ErrorAction SilentlyContinue
    }

    Assert-Summary $resultPath $requestCount
    if ($k6ExitCode -ne 0) {
        Write-Warning "Thresholds failed for $paper $protocol $shape $payloadSize; valid result preserved, continuing."
    }
    $script:successfulRuns++
}

function Write-SetMetadata([string]$paper, [object]$configuration, [int]$expectedRuns) {
    $setFolder = Join-Path $sessionRoot $paper
    New-Item -ItemType Directory -Force $setFolder | Out-Null
    [ordered]@{
        experiment_set = $paper
        literature_comparison_target = $configuration.target
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        protocols = @("rest", "grpc")
        endpoint = "/api/supplementary/literature/{transport}/{shape}/{payloadSize}"
        benchmark_architecture = "Client -> Order Service -> Product Service"
        shape_variants = $configuration.shapes
        payload_definitions_bytes = $configuration.payloads
        load_definition = $configuration.load
        total_request_count = $configuration.request_definition
        repetitions = $effectiveRuns
        expected_measured_runs = $expectedRuns
        run_duration = $configuration.duration
        warm_up_procedure = "$WarmupRequests successful read-only requests per run; excluded from k6 measurement"
        measured_metrics = @("average latency", "median latency", "p95 latency", "throughput", "error rate", "CPU", "RAM")
        cpu_ram_collection = "docker stats --no-stream every 1 second during measured k6 execution; order-service-rest and product-service"
        docker_containers = @("order-service-rest", "product-service")
    } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $setFolder "metadata.json")
}

$niswarCounts = if ($Smoke) { @(100) } else { @(100, 200, 300, 400, 500) }
$niswarCases = if ($Smoke) { @(@("rest", "flat"), @("grpc", "nested")) } else { @(@("rest", "flat"), @("rest", "nested"), @("grpc", "flat"), @("grpc", "nested")) }
$jarmoszewiczVus = if ($Smoke) { @(10) } else { @(10, 50, 100) }
$jarmoszewiczCases = if ($Smoke) { @(@("rest", "small-1kb"), @("grpc", "large-875kb")) } else { @(@("rest", "small-1kb"), @("rest", "large-875kb"), @("grpc", "small-1kb"), @("grpc", "large-875kb")) }
$hamoVus = if ($Smoke) { @(10) } else { @(10, 50, 100) }
$hamoCases = if ($Smoke) { @(@("rest", "small"), @("grpc", "large")) } else { @(@("rest", "small"), @("rest", "medium"), @("rest", "large"), @("grpc", "small"), @("grpc", "medium"), @("grpc", "large")) }
$selectedSets = if ($Set -eq "all") { @("niswar", "jarmoszewicz", "hamo") } else { @($Set) }
$script:successfulRuns = 0
$expectedTotal = 0

$niswarExpected = $niswarCases.Count * $niswarCounts.Count * $effectiveRuns
$jarmoszewiczExpected = $jarmoszewiczCases.Count * $jarmoszewiczVus.Count * $effectiveRuns
$hamoExpected = $hamoCases.Count * $hamoVus.Count * $effectiveRuns
if ($selectedSets -contains "niswar") { $expectedTotal += $niswarExpected }
if ($selectedSets -contains "jarmoszewicz") { $expectedTotal += $jarmoszewiczExpected }
if ($selectedSets -contains "hamo") { $expectedTotal += $hamoExpected }

if ($selectedSets -contains "niswar") {
    Write-SetMetadata "niswar" ([pscustomobject]@{
        target = "Niswar et al. (2024)"
        shapes = @("flat", "nested")
        payloads = @{ small = 128 }
        load = "exact total requests: 100, 200, 300, 400, 500; one VU"
        request_definition = "total requests per measured run"
        duration = "request-count controlled"
    }) $niswarExpected
    foreach ($case in $niswarCases) {
        foreach ($requestCount in $niswarCounts) {
            for ($script:currentRun = 1; $script:currentRun -le $effectiveRuns; $script:currentRun++) {
                Write-Host "[Niswar $($case[0]) $($case[1]) requests=$requestCount run $script:currentRun/$effectiveRuns]" -ForegroundColor Cyan
                Invoke-MeasuredRun "niswar" $case[0] $case[1] "small" $requestCount 1
            }
        }
    }
}

if ($selectedSets -contains "jarmoszewicz") {
    Write-SetMetadata "jarmoszewicz" ([pscustomobject]@{
        target = "Jarmoszewicz, Iwanowski and Plechawska-Wójcik (2024)"
        shapes = @("flat")
        payloads = @{ "small-1kb" = 1024; "large-875kb" = 896000 }
        load = "10, 50, and 100 VU; $duration second duration per run"
        request_definition = "load duration controlled"
        duration = "${duration}s"
    }) $jarmoszewiczExpected
    foreach ($case in $jarmoszewiczCases) {
        $protocol = $case[0]
        $payloadSize = $case[1]
        foreach ($vus in $jarmoszewiczVus) {
                for ($script:currentRun = 1; $script:currentRun -le $effectiveRuns; $script:currentRun++) {
                    Write-Host "[Jarmoszewicz $protocol $payloadSize vu=$vus run $script:currentRun/$effectiveRuns]" -ForegroundColor Cyan
                    Invoke-MeasuredRun "jarmoszewicz" $protocol "flat" $payloadSize 0 $vus
                }
        }
    }
}

if ($selectedSets -contains "hamo") {
    Write-SetMetadata "hamo" ([pscustomobject]@{
        target = "Hamo and Saberian (2023)"
        shapes = @("flat")
        payloads = @{ small = 128; medium = 4096; large = 65536 }
        load = "10, 50, and 100 VU; $duration second duration per run"
        request_definition = "load duration controlled"
        duration = "${duration}s"
    }) $hamoExpected
    foreach ($case in $hamoCases) {
        $protocol = $case[0]
        $payloadSize = $case[1]
        foreach ($vus in $hamoVus) {
                for ($script:currentRun = 1; $script:currentRun -le $effectiveRuns; $script:currentRun++) {
                    Write-Host "[Hamo $protocol $payloadSize vu=$vus run $script:currentRun/$effectiveRuns]" -ForegroundColor Cyan
                    Invoke-MeasuredRun "hamo" $protocol "flat" $payloadSize 0 $vus
                }
        }
    }
}

[ordered]@{
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    experiment_sets = $selectedSets
    expected_total_runs = $expectedTotal
    successful_runs = $script:successfulRuns
    protocols = @("rest", "grpc")
    benchmark_architecture = "Client -> Order Service -> Product Service"
    environment = "local Docker Desktop"
    docker_version = Get-ToolVersion "docker" @("version", "--format", "{{.Server.Version}}")
    k6_version = Get-ToolVersion "k6" @("version")
    java_version = Get-ToolVersion "java" @("-version")
    git_commit = (& git rev-parse HEAD).Trim()
    benchmark_branch = (& git branch --show-current).Trim()
    smoke = [bool]$Smoke
    repetitions = $effectiveRuns
    warmup_requests = $WarmupRequests
} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $sessionRoot "session-metadata.json")

& $aggregatorScript -SessionFolder $sessionRoot
if ($LASTEXITCODE -ne 0) { throw "Literature result aggregation failed." }
Write-Host "Literature benchmark session complete: $sessionRoot" -ForegroundColor Green
Write-Host "Successful runs: $script:successfulRuns/$expectedTotal" -ForegroundColor Green

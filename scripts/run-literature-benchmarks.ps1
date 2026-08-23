param(
    [ValidateSet("all", "niswar", "jarmoszewicz", "hamo")]
    [string]$Set = "all",

    [ValidateRange(1, 20)]
    [int]$Runs = 3,

    [switch]$Smoke,

    [ValidateRange(1, 100)]
    [int]$WarmupRequests = 10
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$baseUrl = if ($env:LITERATURE_BENCHMARK_BASE_URL) {
    $env:LITERATURE_BENCHMARK_BASE_URL
} else {
    "http://localhost:8080"
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$session = Join-Path $root "results\literature\$timestamp"

$k6Script = Join-Path $root "k6-tests\literature\load-test.js"
$collector = Join-Path $root "scripts\collect-literature-docker-stats.ps1"
$aggregate = Join-Path $root "scripts\aggregate-literature-results.ps1"

$sets = if ($Set -eq "all") {
    @("niswar", "jarmoszewicz", "hamo")
} else {
    @($Set)
}

$script:successful = 0

New-Item -ItemType Directory -Force $session | Out-Null


function Assert-Container {
    param([string]$Name)

    $running = docker inspect --format '{{.State.Running}}' $Name 2>$null

    if ($LASTEXITCODE -ne 0 -or $running -ne "true") {
        throw "Container is not running: $Name"
    }
}


function Invoke-Warmup {
    param(
        [string]$Protocol,
        [string]$Shape,
        [string]$Payload
    )

    $successful = 0
    $maxAttempts = $WarmupRequests * 3

    for (
        $attempt = 1;
        $attempt -le $maxAttempts -and $successful -lt $WarmupRequests;
        $attempt++
    ) {
        try {
            $uri = "$baseUrl/api/supplementary/literature/$Protocol/$Shape/$Payload"

            $response = Invoke-RestMethod `
                -Uri $uri `
                -Method Get `
                -TimeoutSec 60

            if ($null -ne $response) {
                $successful++
            }
        }
        catch {
            Start-Sleep -Milliseconds 200
        }
    }

    if ($successful -ne $WarmupRequests) {
        throw "Warm-up failed for $Protocol/$Shape/$Payload. Successful: $successful/$WarmupRequests"
    }
}


function Validate-Result {
    param(
        [string]$Path,
        [int]$ExpectedRequests
    )

    if (-not (Test-Path $Path)) {
        throw "Missing k6 result: $Path"
    }

    $summary = Get-Content $Path -Raw | ConvertFrom-Json

    if ($null -eq $summary.metrics.PSObject.Properties["http_req_duration"]) {
        throw "Missing http_req_duration metric: $Path"
    }

    if ($ExpectedRequests -gt 0) {

        $httpReqsMetric =
            $summary.metrics.PSObject.Properties["http_reqs"].Value

        $actual =
            [int]$httpReqsMetric.PSObject.Properties["count"].Value

        if ($actual -ne $ExpectedRequests) {
            throw "Expected $ExpectedRequests requests but recorded $actual in $Path"
        }
    }
}


function Save-Metadata {
    param(
        [string]$Paper,
        [hashtable]$Data,
        [int]$ExpectedRuns
    )

    $folder = Join-Path $session $Paper
    New-Item -ItemType Directory -Force $folder | Out-Null

    $Data.experiment_set = $Paper
    $Data.timestamp = (Get-Date).ToUniversalTime().ToString("o")
    $Data.protocols = @("rest", "grpc")
    $Data.endpoint = "/api/supplementary/literature/{transport}/{shape}/{payloadSize}"
    $Data.benchmark_architecture = "Client -> Order Service -> Product Service"
    $Data.repetitions = $Runs
    $Data.expected_measured_runs = $ExpectedRuns

    $Data.warm_up_procedure =
        "$WarmupRequests successful read-only requests excluded from measurement"

    $Data.measured_metrics = @(
        "average latency",
        "median latency",
        "p95 latency",
        "throughput",
        "error rate",
        "CPU",
        "RAM"
    )

    $Data.cpu_ram_collection =
        "docker stats sampled every 1 second during measured execution"

    $Data.docker_containers = @(
        "order-service-rest",
        "product-service"
    )

    $Data |
        ConvertTo-Json -Depth 12 |
        Set-Content (Join-Path $folder "metadata.json")
}


function Run-Case {
    param(
        [hashtable]$Case,
        [int]$RunNumber
    )

    Assert-Container "order-service-rest"
    Assert-Container "product-service"

    Invoke-Warmup `
        -Protocol $Case.protocol `
        -Shape $Case.shape `
        -Payload $Case.payload

    $rawFolder =
        Join-Path $session "$($Case.paper)\raw"

    New-Item `
        -ItemType Directory `
        -Force `
        $rawFolder |
        Out-Null


    if ($Case.paper -eq "niswar") {

        $fileName =
            "niswar-$($Case.protocol)-$($Case.shape)-$($Case.total)-run-{0:D2}.json" `
            -f $RunNumber
    }
    elseif ($Case.paper -eq "jarmoszewicz") {

        $fileName =
            "jarmoszewicz-$($Case.protocol)-$($Case.payload)-$($Case.profile)-run-{0:D2}.json" `
            -f $RunNumber
    }
    elseif ($Case.paper -eq "hamo") {

        $fileName =
            "hamo-$($Case.protocol)-$($Case.payload)-$($Case.total)-vu$($Case.vus)-run-{0:D2}.json" `
            -f $RunNumber
    }
    else {
        throw "Unknown paper: $($Case.paper)"
    }


    $resultPath =
        Join-Path $rawFolder $fileName

    $resourcePath =
        $resultPath -replace '\.json$', '.resources.csv'

    $stopPath =
        $resultPath -replace '\.json$', '.stop'


    $collectorJob =
        Start-Job `
            -FilePath $collector `
            -ArgumentList $resourcePath, $stopPath, 1


    try {

        $env:BASE_URL = $baseUrl
        $env:PROTOCOL = $Case.protocol
        $env:SHAPE = $Case.shape
        $env:PAYLOAD_SIZE = $Case.payload
        $env:EXECUTOR = $Case.executor

        $env:DURATION = if ($Case.duration) {
            "$($Case.duration)s"
        } else {
            "60s"
        }

        $env:TOTAL_REQUESTS = if ($Case.total) {
            [string]$Case.total
        } else {
            ""
        }

        $env:VUS = if ($Case.vus) {
            [string]$Case.vus
        } else {
            "1"
        }

        $env:RATE = if ($Case.rate) {
            [string]$Case.rate
        } else {
            ""
        }

        $env:START_RATE = if ($Case.startRate) {
            [string]$Case.startRate
        } else {
            ""
        }

        $env:TARGET_RATE = if ($Case.targetRate) {
            [string]$Case.targetRate
        } else {
            ""
        }

        $env:PREALLOCATED_VUS = if ($Case.preAllocated) {
            [string]$Case.preAllocated
        } else {
            ""
        }

        $env:MAX_VUS = if ($Case.maxVus) {
            [string]$Case.maxVus
        } else {
            ""
        }

        $env:START_VUS = if ($Case.startVus) {
            [string]$Case.startVus
        } else {
            ""
        }

        $env:TARGET_VUS = if ($Case.targetVus) {
            [string]$Case.targetVus
        } else {
            ""
        }

        $env:MAX_DURATION = "24h"


        & k6 run `
            "--summary-export=$resultPath" `
            $k6Script

        $exitCode = $LASTEXITCODE
    }
    finally {

        New-Item `
            -ItemType File `
            -Force `
            $stopPath |
            Out-Null

        Wait-Job `
            $collectorJob `
            -Timeout 20 |
            Out-Null

        Receive-Job `
            $collectorJob `
            -ErrorAction SilentlyContinue |
            Out-Null

        Remove-Job `
            $collectorJob `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item `
            $stopPath `
            -Force `
            -ErrorAction SilentlyContinue


        Remove-Item `
            Env:BASE_URL,
            Env:PROTOCOL,
            Env:SHAPE,
            Env:PAYLOAD_SIZE,
            Env:EXECUTOR,
            Env:DURATION,
            Env:TOTAL_REQUESTS,
            Env:VUS,
            Env:RATE,
            Env:START_RATE,
            Env:TARGET_RATE,
            Env:PREALLOCATED_VUS,
            Env:MAX_VUS,
            Env:START_VUS,
            Env:TARGET_VUS,
            Env:MAX_DURATION `
            -ErrorAction SilentlyContinue
    }


    Validate-Result `
        -Path $resultPath `
        -ExpectedRequests $Case.total


    if ($exitCode -ne 0) {
        Write-Warning `
            "k6 threshold failed, but valid result was preserved: $resultPath"
    }

    $script:successful++
}


# ============================================================
# NISWAR
# ============================================================

if ($sets -contains "niswar") {

    $requestCounts =
        if ($Smoke) {
            @(100)
        }
        else {
            @(100, 200, 300, 400, 500)
        }


    $protocolShapePairs =
        if ($Smoke) {
            @(
                @("rest", "flat"),
                @("grpc", "nested")
            )
        }
        else {
            @(
                @("rest", "flat"),
                @("rest", "nested"),
                @("grpc", "flat"),
                @("grpc", "nested")
            )
        }


    $expected =
        $requestCounts.Count *
        $protocolShapePairs.Count *
        $Runs


    Save-Metadata `
        -Paper "niswar" `
        -ExpectedRuns $expected `
        -Data @{

            target =
                "Niswar et al. (2024)"

            shape_variants =
                @("flat", "nested")

            payload_definitions_bytes = @{
                small = 128
            }

            load_definition =
                "Exact completed request count using shared-iterations"

            request_counts =
                @(100, 200, 300, 400, 500)

            vus = 1

            aspects_matching_paper = @(
                "REST versus gRPC",
                "flat versus nested retrieval",
                "100-500 request counts",
                "response time",
                "CPU utilization"
            )

            aspects_differing = @(
                "GraphQL omitted",
                "isolated Order-to-Product read benchmark"
            )
        }


    foreach ($pair in $protocolShapePairs) {

        foreach ($count in $requestCounts) {

            for ($run = 1; $run -le $Runs; $run++) {

                Write-Host `
                    "[Niswar $($pair[0]) $($pair[1]) requests=$count run $run/$Runs]"


                Run-Case `
                    -RunNumber $run `
                    -Case @{

                        paper = "niswar"
                        protocol = $pair[0]
                        shape = $pair[1]
                        payload = "small"

                        total = $count
                        vus = 1

                        executor = "shared-iterations"
                    }
            }
        }
    }
}


# ============================================================
# JARMOSZEWICZ
# ============================================================

if ($sets -contains "jarmoszewicz") {

    $duration =
        if ($Smoke) {
            5
        }
        else {
            60
        }


    if ($Smoke) {

        $cases = @(

            @{
                protocol = "rest"
                payload = "small-1kb"
                profile = "j1-low"

                executor = "constant-arrival-rate"

                rate = 150
                preAllocated = 300
                maxVus = 1200
            },

            @{
                protocol = "grpc"
                payload = "large-875kb"
                profile = "j2-50"

                executor = "constant-vus"
                vus = 50
            }
        )
    }
    else {

        $cases = @()

        foreach ($protocol in @("rest", "grpc")) {

            $cases += @{

                protocol = $protocol
                payload = "small-1kb"
                profile = "j1-low"

                executor = "constant-arrival-rate"

                rate = 150
                preAllocated = 300
                maxVus = 1200
            }


            $cases += @{

                protocol = $protocol
                payload = "small-1kb"
                profile = "j1-medium"

                executor = "constant-arrival-rate"

                rate = 300
                preAllocated = 500
                maxVus = 1600
            }


            $cases += @{

                protocol = $protocol
                payload = "small-1kb"
                profile = "j1-ramp"

                executor = "ramping-arrival-rate"

                startRate = 100
                targetRate = 1200

                preAllocated = 500
                maxVus = 2000
            }


            $cases += @{

                protocol = $protocol
                payload = "large-875kb"
                profile = "j2-50"

                executor = "constant-vus"
                vus = 50
            }


            $cases += @{

                protocol = $protocol
                payload = "large-875kb"
                profile = "j2-100"

                executor = "constant-vus"
                vus = 100
            }


            $cases += @{

                protocol = $protocol
                payload = "large-875kb"
                profile = "j2-ramp"

                executor = "ramping-vus"

                startVus = 2
                targetVus = 100
            }
        }
    }


    $expected =
        $cases.Count * $Runs


    Save-Metadata `
        -Paper "jarmoszewicz" `
        -ExpectedRuns $expected `
        -Data @{

            target =
                "Jarmoszewicz, Iwanowski and Plechawska-Wojcik (2024)"

            shape_variants =
                @("flat")

            payload_definitions_bytes = @{
                "small-1kb" = 1024
                "large-875kb" = 896000
            }

            run_duration_seconds = 60

            load_profiles = @(
                "j1-low: 150 req/s",
                "j1-medium: 300 req/s",
                "j1-ramp: 100 -> 1200 req/s",
                "j2-50: 50 active VUs",
                "j2-100: 100 active VUs",
                "j2-ramp: 2 -> 100 active VUs"
            )

            aspects_matching_paper = @(
                "Spring Boot microservices",
                "REST versus gRPC",
                "approximately 1 KB payload",
                "approximately 875 KiB payload",
                "60-second load scenarios",
                "arrival-rate and active-user load styles",
                "CPU",
                "RAM",
                "response time",
                "throughput"
            )

            aspects_differing = @(
                "isolated read benchmark rather than exact CRUD/image workload",
                "k6 instead of Gatling"
            )
        }


    foreach ($case in $cases) {

        for ($run = 1; $run -le $Runs; $run++) {

            Write-Host `
                "[Jarmoszewicz $($case.protocol) $($case.payload) $($case.profile) run $run/$Runs]"


            $runCase = @{

                paper = "jarmoszewicz"
                protocol = $case.protocol
                shape = "flat"

                payload = $case.payload
                profile = $case.profile

                executor = $case.executor
                duration = $duration

                total = 0

                vus = $case.vus
                rate = $case.rate

                startRate = $case.startRate
                targetRate = $case.targetRate

                preAllocated = $case.preAllocated
                maxVus = $case.maxVus

                startVus = $case.startVus
                targetVus = $case.targetVus
            }


            Run-Case `
                -RunNumber $run `
                -Case $runCase
        }
    }
}


# ============================================================
# HAMO
# ============================================================

if ($sets -contains "hamo") {

    # Original paper:
    #
    # 14 B:
    # 500,000 requests
    #
    # 150 KiB:
    # 200,000 requests
    #
    # 3 MiB:
    # 20,000 requests
    #
    # VU levels:
    # 1, 10, 50, 100, 400
    #
    # In this thesis the request counts are uniformly
    # scaled to 10% because of the local experimental environment.
    #
    # Pilot testing also showed that:
    #
    # 3 MiB + 400 VU
    #
    # caused severe saturation:
    # approximately 50% failed requests and very high latency.
    #
    # Therefore the 400-VU point is omitted ONLY for
    # the 3 MiB payload.
    #
    # 14 B and 150 KiB still use:
    # 1, 10, 50, 100, 400 VU
    #
    # 3 MiB uses:
    # 1, 10, 50, 100 VU


    $requestCounts = @{

        "hamo-small" = 50000

        "hamo-medium" = 20000

        "hamo-large" = 2000
    }


    $originalRequestCounts = @{

        "hamo-small" = 500000

        "hamo-medium" = 200000

        "hamo-large" = 20000
    }


    if ($Smoke) {

        $cases = @(

            @{
                protocol = "rest"
                payload = "hamo-small"
                total = 100
                vus = 1
            },

            @{
                protocol = "grpc"
                payload = "hamo-large"
                total = 20
                vus = 10
            }
        )
    }
    else {

        $cases = @()


        foreach ($protocol in @("rest", "grpc")) {

            # -----------------------------------------
            # SMALL - 14 B
            # VUs: 1, 10, 50, 100, 400
            # -----------------------------------------

            foreach ($vus in @(1, 10, 50, 100, 400)) {

                $cases += @{

                    protocol = $protocol
                    payload = "hamo-small"

                    total = $requestCounts["hamo-small"]

                    vus = $vus
                }
            }


            # -----------------------------------------
            # MEDIUM - 150 KiB
            # VUs: 1, 10, 50, 100, 400
            # -----------------------------------------

            foreach ($vus in @(1, 10, 50, 100, 400)) {

                $cases += @{

                    protocol = $protocol
                    payload = "hamo-medium"

                    total = $requestCounts["hamo-medium"]

                    vus = $vus
                }
            }


            # -----------------------------------------
            # LARGE - 3 MiB
            # VUs: 1, 10, 50, 100
            #
            # 400 VU intentionally omitted.
            # -----------------------------------------

            foreach ($vus in @(1, 10, 50, 100)) {

                $cases += @{

                    protocol = $protocol
                    payload = "hamo-large"

                    total = $requestCounts["hamo-large"]

                    vus = $vus
                }
            }
        }
    }


    $expected =
        $cases.Count * $Runs


    Save-Metadata `
        -Paper "hamo" `
        -ExpectedRuns $expected `
        -Data @{

            target =
                "Hamo and Saberian (2023)"

            shape_variants =
                @("flat")

            payload_definitions_bytes = @{

                "hamo-small" = 14

                "hamo-medium" = 153600

                "hamo-large" = 3145728
            }


            source_request_counts =
                $originalRequestCounts

            local_request_counts =
                $requestCounts

            request_count_scale_factor =
                0.1


            vu_levels_small =
                @(1, 10, 50, 100, 400)

            vu_levels_medium =
                @(1, 10, 50, 100, 400)

            vu_levels_large =
                @(1, 10, 50, 100)


            omitted_case =
                "3 MiB payload at 400 VU"


            omitted_case_reason =
                "Pilot test caused severe saturation in the local environment, approximately 50 percent failed requests, very high latency and interrupted iterations."


            load_definition =
                "shared-iterations with fixed completed request count and configurable VUs"


            run_duration =
                "completion controlled"


            aspects_matching_paper = @(

                "HTTP/REST versus gRPC",

                "14-byte payload",

                "approximately 150 KiB payload",

                "approximately 3 MiB payload",

                "1, 10, 50 and 100 VU levels",

                "400 VU retained for small and medium payloads",

                "fixed total request-count design",

                "latency",

                "throughput",

                "scalability"
            )


            aspects_differing = @(

                "request counts uniformly scaled to 10 percent for local thesis hardware",

                "400 VU omitted for the 3 MiB payload after pilot saturation",

                "Java/Spring implementation instead of Go",

                "isolated Order-to-Product read benchmark"
            )
        }


    foreach ($case in $cases) {

        for ($run = 1; $run -le $Runs; $run++) {

            Write-Host `
                "[Hamo $($case.protocol) $($case.payload) requests=$($case.total) vu=$($case.vus) run $run/$Runs]"


            Run-Case `
                -RunNumber $run `
                -Case @{

                    paper = "hamo"

                    protocol = $case.protocol

                    shape = "flat"

                    payload = $case.payload

                    total = $case.total

                    vus = $case.vus

                    executor = "shared-iterations"
                }
        }
    }
}


# ============================================================
# SESSION METADATA
# ============================================================

$expectedSessionRuns = 0


if ($sets -contains "niswar") {

    $expectedSessionRuns +=
        if ($Smoke) {
            2 * $Runs
        }
        else {
            20 * $Runs
        }
}


if ($sets -contains "jarmoszewicz") {

    $expectedSessionRuns +=
        if ($Smoke) {
            2 * $Runs
        }
        else {
            12 * $Runs
        }
}


if ($sets -contains "hamo") {

    $expectedSessionRuns +=
        if ($Smoke) {
            2 * $Runs
        }
        else {
            28 * $Runs
        }
}


$sessionMetadata = [ordered]@{

    timestamp =
        (Get-Date).ToUniversalTime().ToString("o")

    experiment_sets =
        $sets

    expected_total_runs =
        $expectedSessionRuns

    successful_runs =
        $script:successful

    smoke =
        [bool]$Smoke

    repetitions =
        $Runs

    warmup_requests =
        $WarmupRequests

    git_commit =
        (git rev-parse HEAD)

    branch =
        (git branch --show-current)
}


$sessionMetadata |
    ConvertTo-Json -Depth 10 |
    Set-Content `
        (Join-Path $session "session-metadata.json")


# ============================================================
# AGGREGATION
# ============================================================

& $aggregate `
    -SessionFolder $session


if ($LASTEXITCODE -ne 0) {
    throw "Literature aggregation failed"
}


Write-Host ""
Write-Host `
    "Literature benchmark complete." `
    -ForegroundColor Green

Write-Host `
    "Session: $session"

Write-Host `
    "Successful runs: $script:successful / $expectedSessionRuns"
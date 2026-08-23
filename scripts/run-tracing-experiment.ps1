<#
.SYNOPSIS
    Runs the controlled-probe distributed-tracing experiment (thesis Phases 5-10, 16).

.DESCRIPTION
    For each communication model and each of the three representative load scenarios
    (baseline, spike, stress), this script:
      1. Resets application/database/Kafka state for a clean model start (Jaeger is left
         running throughout the whole tracing session so its persistent Badger volume
         accumulates every probe trace; it is never recreated per model/scenario).
      2. Starts the model with docker-compose.tracing.yml applied, so every Java service
         runs a ParentBased trace-id-ratio sampler with root ratio 0 (see that file).
      3. Warms the model up, then launches the shortened k6 background-load profile for
         the scenario (k6-tests/tracing/*.js) while firing controlled probe requests that
         each carry a freshly generated, sampled W3C traceparent header.
      4. Waits for the load (and, for async/hybrid, extra time for Kafka-consumer work) to
         finish, then retrieves each probe trace from the Jaeger Query HTTP API and stores
         it as JSON evidence, recording every probe (including failures) in a manifest.

    This is a short, targeted internal-observability experiment, NOT a re-run of the
    completed 125-run final experiment or the 180-run literature benchmark.

.PARAMETER Models
    One or more of rest, partial-grpc, full-grpc, async, hybrid. Default: all five.

.PARAMETER Scenarios
    One or more of baseline, spike, stress. Default: all three.

.PARAMETER Repetitions
    Tracing repetitions per model/scenario. Default 3 (per thesis design: 3 reps x 10
    probes = 30 probes per combination, ~450 total across 5 models x 3 scenarios).

.PARAMETER ProbesPerRepetition
    Controlled probe requests fired per repetition. Default 10.

.PARAMETER OutputRoot
    Root folder for the tracing session. Default results/tracing/final.
#>
param(
    [ValidateSet("rest", "partial-grpc", "full-grpc", "async", "hybrid")]
    [string[]]$Models = @("rest", "partial-grpc", "full-grpc", "async", "hybrid"),

    [ValidateSet("baseline", "spike", "stress")]
    [string[]]$Scenarios = @("baseline", "spike", "stress"),

    [ValidateRange(1, 20)]
    [int]$Repetitions = 3,

    [ValidateRange(1, 100)]
    [int]$ProbesPerRepetition = 10,

    [string]$OutputRoot = "results/tracing/final",

    [ValidateRange(0, 10)]
    [int]$MaxReplacementProbesPerRepetition = 3,

    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

# Git provenance guard: refuse normal final runs when working tree is dirty unless -AllowDirty is provided.
if (-not $AllowDirty) {
    $status = git status --porcelain
    if ($status) {
        throw "Working tree is dirty. Commit changes or run with -AllowDirty for a temporary validation run. Aborting."
    }
}

$culture = [Globalization.CultureInfo]::InvariantCulture
$composeFiles = @("-f", "docker-compose.yml", "-f", "docker-compose.tracing.yml")

$modelConfig = @{
    "rest"          = @{ Service = "order-service-rest";      Endpoint = "http://localhost:8080" }
    "partial-grpc"  = @{ Service = "order-service-partial-grpc";      Endpoint = "http://localhost:8090" }
    "full-grpc"     = @{ Service = "order-service-full-grpc"; Endpoint = "http://localhost:8100" }
    "async"         = @{ Service = "order-service-async";     Endpoint = "http://localhost:8110" }
    "hybrid"        = @{ Service = "order-service-hybrid";    Endpoint = "http://localhost:8120" }
}

# Shortened tracing load profiles, derived from the same k6 scenarios used by the final
# experiment (see README "Tracing experiment" section for the exact stage-by-stage mapping).
$scenarioConfig = @{
    "baseline" = @{ Script = "k6-tests/tracing/baseline-tracing-load.js"; DurationSeconds = 40; TargetVus = 10; ProbePhase = "steady" }
    "stress"   = @{ Script = "k6-tests/tracing/stress-tracing-load.js";   DurationSeconds = 50; TargetVus = 75; ProbePhase = "peak_hold" }
    "spike"    = @{ Script = "k6-tests/tracing/spike-tracing-load.js";    DurationSeconds = 60; TargetVus = 100; ProbePhase = "peak_hold" }
}

# Probe windows (start offset and duration) within the shortened k6 scenario where probes should be fired
$scenarioProbeWindow = @{
    "baseline" = @{ Start = 10; Duration = 10 }    # stable 10 VU window
    "stress"   = @{ Start = 30; Duration = 10 }    # 75-VU hold at 30-40s
    "spike"    = @{ Start = 20; Duration = 20 }    # 100-VU hold at 20-40s
}

$allOrderServices = @("order-service-rest", "order-service-partial-grpc", "order-service-full-grpc", "order-service-async", "order-service-hybrid")
$appServices = @("product-service", "inventory-service", "payment-service", "notification-service")
$databaseServices = @("product-db", "order-db", "inventory-db", "payment-db", "notification-db")
$databaseVolumeSuffixes = @("product_db_data", "order_db_data", "inventory_db_data", "payment_db_data", "notification_db_data")
$kafkaVolumeSuffixes = @("kafka_data")

function Invoke-Compose {
    param([string[]]$Arguments)
    docker compose @composeFiles @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

# Ensure Jaeger is started once for the whole tracing session (Badger-backed volume persists between attempts)
Write-Host "Ensuring Jaeger is running for the tracing session..." -ForegroundColor Cyan
Invoke-Compose -Arguments @("up", "-d", "jaeger")

# Wait for Jaeger Query API readiness
$jaegerDeadline = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $jaegerDeadline) {
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:16686/api/services" -TimeoutSec 5
        if ($resp -and $resp.Count -ge 0) { break }
    } catch { }
    Start-Sleep -Seconds 2
}

function New-HexId {
    param([int]$ByteLength)
    $bytes = New-Object byte[] $ByteLength
    $rng = [Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    # A W3C trace/span id must not be all-zero; regenerate in the extremely unlikely case it is.
    if (($bytes | Measure-Object -Sum).Sum -eq 0) {
        return New-HexId -ByteLength $ByteLength
    }
    return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Reset-ModelEnvironment {
    param([string]$Model)

    Write-Host "[$Model] Resetting application/database/Kafka state (Jaeger is preserved)..." -ForegroundColor Cyan

    $stopTargets = $allOrderServices + $appServices + $databaseServices + @("kafka")
    Invoke-Compose -Arguments (@("stop") + $stopTargets)
    Invoke-Compose -Arguments (@("rm", "-f") + $stopTargets)

    $volumeSuffixes = $databaseVolumeSuffixes + $kafkaVolumeSuffixes
    $volumesToRemove = docker volume ls --format "{{.Name}}" | Where-Object {
        $volumeName = $_
        $volumeSuffixes | Where-Object { $volumeName -like "*_$($_)" }
    }
    if ($volumesToRemove) {
        docker volume rm $volumesToRemove | Out-Null
    }

    Invoke-Compose -Arguments @("up", "-d", "product-db", "order-db", "inventory-db", "payment-db", "notification-db", "kafka", "product-service", "inventory-service", "payment-service", "notification-service")

    $config = $modelConfig[$Model]
    Write-Host "[$Model] Starting order-service variant with tracing sampler config..." -ForegroundColor Cyan
    Invoke-Compose -Arguments @("--profile", $Model, "up", "-d", $config.Service)

    $deadline = (Get-Date).AddSeconds(300)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri "$($config.Endpoint)/api/orders" -Method Get -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) { $ready = $true; break }
        } catch { }
        Start-Sleep -Seconds 3
    }
    if (-not $ready) {
        throw "[$Model] order-service did not become ready within 300 seconds."
    }

    powershell -ExecutionPolicy Bypass -File "scripts/warmup-model.ps1" -Model $Model -Requests 10
}

function Send-ProbeRequest {
    param([string]$Endpoint)

    $traceId = New-HexId -ByteLength 16
    $spanId = New-HexId -ByteLength 8
    $traceparent = "00-$traceId-$spanId-01"
    $payload = '{"items":[{"productId":1,"quantity":1}]}'

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $status = 0
    try {
        $response = Invoke-WebRequest -Uri "$Endpoint/api/orders" -Method Post -Body $payload `
            -ContentType "application/json" -Headers @{ traceparent = $traceparent } `
            -UseBasicParsing -TimeoutSec 30
        $status = $response.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }
    }
    $stopwatch.Stop()

    return [pscustomobject]@{
        trace_id     = $traceId
        span_id      = $spanId
        traceparent  = $traceparent
        timestamp    = (Get-Date).ToUniversalTime().ToString("o")
        http_status  = $status
        duration_ms  = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds, 3)
    }
}

function Get-JaegerTrace {
    param([string]$TraceId)
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:16686/api/traces/$TraceId" -TimeoutSec 15
        if ($result.data -and $result.data.Count -gt 0 -and $result.data[0].spans.Count -gt 0) {
            return $result.data[0]
        }
    } catch { }
    return $null
}

function Parse-K6Summary {
    param([string]$SummaryPath)
    if (-not (Test-Path $SummaryPath)) { return $null }
    try {
        $json = Get-Content $SummaryPath -Raw | ConvertFrom-Json
        $metrics = $json.metrics
        $http_reqs = $null
        $iterations = $null
        $error_rate = $null
        $checks_rate = $null
        $avg_ms = $null
        $p95_ms = $null
        $req_per_sec = $null

        if ($metrics.http_reqs) {
            if ($metrics.http_reqs.values -and $metrics.http_reqs.values.count -ne $null) { $http_reqs = $metrics.http_reqs.values.count }
            elseif ($metrics.http_reqs.value -ne $null) { $http_reqs = $metrics.http_reqs.value }
            if ($metrics.http_reqs.values -and $metrics.http_reqs.values.rate -ne $null) { $req_per_sec = $metrics.http_reqs.values.rate }
        }

        if ($metrics.iterations) {
            if ($metrics.iterations.values -and $metrics.iterations.values.count -ne $null) { $iterations = $metrics.iterations.values.count }
            elseif ($metrics.iterations.value -ne $null) { $iterations = $metrics.iterations.value }
        }

        if ($metrics.http_req_failed) {
            if ($metrics.http_req_failed.value -ne $null) {
                $error_rate = $metrics.http_req_failed.value
            } elseif ($metrics.http_req_failed.values -and $metrics.http_req_failed.values.fails -ne $null -and $metrics.http_req_failed.values.passes -ne $null) {
                $fails = [double]$metrics.http_req_failed.values.fails
                $passes = [double]$metrics.http_req_failed.values.passes
                if (($fails + $passes) -gt 0) { $error_rate = $fails / ($fails + $passes) }
            }
        }

        if ($metrics.checks) {
            if ($metrics.checks.value -ne $null) { $checks_rate = $metrics.checks.value }
            elseif ($metrics.checks.values -and $metrics.checks.values.rate -ne $null) { $checks_rate = $metrics.checks.values.rate }
        }

        if ($metrics.http_req_duration -and $metrics.http_req_duration.values) {
            if ($metrics.http_req_duration.values.avg -ne $null) { $avg_ms = $metrics.http_req_duration.values.avg }
            if ($metrics.http_req_duration.values.'p(95)' -ne $null) { $p95_ms = $metrics.http_req_duration.values.'p(95)' }
        }

        return [pscustomobject]@{
            summary_path = $SummaryPath
            request_count = $http_reqs
            iterations = $iterations
            error_rate = $error_rate
            checks_rate = $checks_rate
            avg_ms = $avg_ms
            p95_ms = $p95_ms
            req_per_sec = $req_per_sec
        }
    } catch { return $null }
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$sessionDir = Join-Path $OutputRoot $timestamp
New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sessionDir "analysis") | Out-Null

$gitCommit = (git rev-parse HEAD).Trim()
$gitBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$startedAt = (Get-Date).ToUniversalTime().ToString("o")

function Get-ToolVersionSafe {
    param([string]$Command)
    try {
        return (Invoke-Expression $Command | Select-Object -First 1)
    } catch {
        return $null
    }
}

$javaVersion = $null
try { $javaVersion = (& java -version 2>&1 | Select-Object -First 1) } catch { }
$mavenVersion = Get-ToolVersionSafe -Command "mvn -v"
$dockerVersion = Get-ToolVersionSafe -Command "docker version --format '{{.Server.Version}}'"
$k6Version = Get-ToolVersionSafe -Command "k6 version"

$osName = $null
$cpuName = $null
$ramGb = $null
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
    $osName = $osInfo.Caption
    $cpuName = $cpuInfo.Name
    $ramGb = [Math]::Round(([double]$osInfo.TotalVisibleMemorySize / 1MB), 2)
} catch { }

$manifestPath = Join-Path $sessionDir "probe-manifest.csv"
"model,scenario,repetition,attempt,probe_seq,trace_id,traceparent,timestamp_utc,http_status,duration_ms,export_verified" |
    Out-File -FilePath $manifestPath -Encoding utf8

$totalsByCombo = @{}
$acceptedAttempts = 0
$rejectedAttempts = 0
$failedRepetitions = 0
$retriedRepetitions = 0

foreach ($model in $Models) {
    $endpoint = $modelConfig[$model].Endpoint

    foreach ($scenario in $Scenarios) {
        $rawDir = Join-Path $sessionDir "raw/$model/$scenario"
        New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

        $backgroundDir = Join-Path $sessionDir "background-load/$model/$scenario"
        New-Item -ItemType Directory -Force -Path $backgroundDir | Out-Null
        $bgSummaryCsv = Join-Path $backgroundDir 'background-load-summary.csv'
        if (-not (Test-Path $bgSummaryCsv)) {
            "model,scenario,repetition,attempt,target_vus,request_count,iterations,error_rate,checks_rate,avg_ms,p95_ms,req_per_sec,k6_exit_code" | Out-File -FilePath $bgSummaryCsv -Encoding utf8
        }

        $scenarioCfg = $scenarioConfig[$scenario]
        $successCount = 0
        $probeCountThisCombo = 0

        for ($rep = 1; $rep -le $Repetitions; $rep++) {
            $repSucceeded = $false
            $attempt = 1
            $maxAttempts = 3
            $repRetried = $false
            while ($attempt -le $maxAttempts -and -not $repSucceeded) {
                Write-Host "[$model/$scenario] Repetition $rep attempt $attempt - resetting environment and starting background load..." -ForegroundColor Yellow

                # Start from a clean DB/Kafka/application state for each attempt
                Reset-ModelEnvironment -Model $model

                $env:BASE_URL = $endpoint
                $summaryFile = Join-Path $backgroundDir ("rep-{0:00}-attempt-{1:00}.json" -f $rep, $attempt)
                $k6Cmd = "k6 run $($scenarioCfg.Script) --summary-export=$summaryFile"
                $k6Job = Start-Job -ScriptBlock {
                    param($cmd, $baseUrl, $repoRoot)
                    Set-Location $repoRoot
                    $env:BASE_URL = $baseUrl
                    Invoke-Expression $cmd
                    return $LASTEXITCODE
                } -ArgumentList $k6Cmd, $endpoint, $repoRoot

                # Wait until the scenario's probe window starts so probes execute during the stable hold
                $window = $scenarioProbeWindow[$scenario]
                $probeWindowStart = if ($window) { [int]$window.Start } else { [int]([Math]::Floor($scenarioCfg.DurationSeconds / 3)) }
                $probeWindowDuration = if ($window) { [int]$window.Duration } else { [int]([Math]::Max(5, [Math]::Floor($scenarioCfg.DurationSeconds / 3))) }

                $startWait = $probeWindowStart
                Start-Sleep -Seconds $startWait

                $probeInterval = [Math]::Max(0.1, ($probeWindowDuration) / $ProbesPerRepetition)

                $repetitionProbes = New-Object System.Collections.ArrayList
                for ($seq = 1; $seq -le $ProbesPerRepetition; $seq++) {
                    $probe = Send-ProbeRequest -Endpoint $endpoint
                    $probe | Add-Member -NotePropertyName probe_seq -NotePropertyValue $seq
                    $probe | Add-Member -NotePropertyName attempt -NotePropertyValue $attempt
                    [void]$repetitionProbes.Add($probe)
                    Start-Sleep -Seconds $probeInterval
                }

                Wait-Job -Job $k6Job | Out-Null
                $k6ExitCode = 1
                $k6Result = Receive-Job -Job $k6Job
                if ($k6Result -is [array] -and $k6Result.Length -gt 0) {
                    $k6ExitCode = [int]$k6Result[-1]
                } elseif ($k6Result -ne $null) {
                    $k6ExitCode = [int]$k6Result
                }
                Remove-Job -Job $k6Job | Out-Null

                $parsedSummary = Parse-K6Summary -SummaryPath $summaryFile
                if ($parsedSummary) {
                    "$model,$scenario,$rep,$attempt,$($scenarioCfg.TargetVus),$($parsedSummary.request_count),$($parsedSummary.iterations),$($parsedSummary.error_rate),$($parsedSummary.checks_rate),$($parsedSummary.avg_ms),$($parsedSummary.p95_ms),$($parsedSummary.req_per_sec),$k6ExitCode" |
                        Out-File -FilePath $bgSummaryCsv -Encoding utf8 -Append
                } else {
                    "$model,$scenario,$rep,$attempt,$($scenarioCfg.TargetVus),,,,,,,,$k6ExitCode" |
                        Out-File -FilePath $bgSummaryCsv -Encoding utf8 -Append
                }

                if ($model -in @("async", "hybrid")) {
                    Write-Host "[$model/$scenario] Waiting for asynchronous Kafka work to finish before trace export..." -ForegroundColor DarkYellow
                    Start-Sleep -Seconds 10
                } else {
                    Start-Sleep -Seconds 3
                }

                $verifiedThisAttempt = 0
                if ($k6ExitCode -ne 0) {
                    Write-Host "[$model/$scenario] k6 exited with code $k6ExitCode; marking attempt failed." -ForegroundColor Red
                }
                foreach ($probe in $repetitionProbes) {
                    $trace = Get-JaegerTrace -TraceId $probe.trace_id
                    if (-not $trace) {
                        Start-Sleep -Seconds 5
                        $trace = Get-JaegerTrace -TraceId $probe.trace_id
                    }

                    $verified = $false
                    if ($trace) {
                        $tracePath = Join-Path $rawDir "$($probe.trace_id).json"
                        $trace | ConvertTo-Json -Depth 50 | Out-File -FilePath $tracePath -Encoding utf8
                        $verified = $true
                        $verifiedThisAttempt++
                    }

                    "$model,$scenario,$rep,$($probe.attempt),$($probe.probe_seq),$($probe.trace_id),$($probe.traceparent),$($probe.timestamp),$($probe.http_status),$($probe.duration_ms),$verified" |
                        Out-File -FilePath $manifestPath -Encoding utf8 -Append

                    $probeCountThisCombo++
                }

                if ($k6ExitCode -eq 0 -and $verifiedThisAttempt -ge $ProbesPerRepetition) {
                    $repSucceeded = $true
                    $successCount += $verifiedThisAttempt
                    $acceptedAttempts++
                    Write-Host "[$model/$scenario] Repetition $rep attempt $attempt succeeded: $verifiedThisAttempt/$ProbesPerRepetition verified." -ForegroundColor Green
                } else {
                    $rejectedAttempts++
                    Write-Host "[$model/$scenario] Repetition $rep attempt $attempt failed: $verifiedThisAttempt/$ProbesPerRepetition verified." -ForegroundColor Red
                    $attempt++
                    if ($attempt -le $maxAttempts) {
                        if (-not $repRetried) {
                            $retriedRepetitions++
                            $repRetried = $true
                        }
                        Write-Host "Retrying repetition $rep (attempt $attempt)..." -ForegroundColor Yellow
                    } else {
                        $failedRepetitions++
                        Write-Host "Repetition $rep exhausted attempts. Marking as failed." -ForegroundColor Red
                    }
                }
            }
        }

        $totalsByCombo["$model|$scenario"] = @{ probes = $probeCountThisCombo; verified = $successCount }
        Write-Host "[$model/$scenario] Completed: $successCount verified traces out of $probeCountThisCombo probes sent." -ForegroundColor Green
    }
}

$finishedAt = (Get-Date).ToUniversalTime().ToString("o")

$probeSpacingByScenario = @{}
foreach ($scenario in $Scenarios) {
    $window = $scenarioProbeWindow[$scenario]
    if ($window) {
        $probeSpacingByScenario[$scenario] = [Math]::Round(([double]$window.Duration) / [double]$ProbesPerRepetition, 3)
    }
}

$metadata = [ordered]@{
    experiment_type              = "distributed-tracing-controlled-probe"
    timestamp                    = $startedAt
    git_commit                   = $gitCommit
    branch                       = $gitBranch
    started_at_utc               = $startedAt
    finished_at_utc               = $finishedAt
    java_version                 = $javaVersion
    maven_version                = $mavenVersion
    docker_version               = $dockerVersion
    k6_version                   = $k6Version
    os                           = $osName
    cpu                          = $cpuName
    ram_gb                       = $ramGb
    models                       = $Models
    scenarios                    = $Scenarios
    repetitions_per_combination  = $Repetitions
    probes_per_repetition_target = $ProbesPerRepetition
    load_profiles                = $scenarioConfig
    sampler                      = [ordered]@{
        strategy                = "parentbased_traceidratio"
        root_sampling_ratio     = 0
        probe_sampling          = "W3C traceparent header generated before the request, sampled flag 01"
        env_vars                = @("OTEL_TRACES_SAMPLER", "OTEL_TRACES_SAMPLER_ARG", "OTEL_PROPAGATORS")
        propagators             = "tracecontext,baggage"
        compose_override        = "docker-compose.tracing.yml"
    }
    opentelemetry_agent_version  = "2.25.0"
    jaeger_version               = "1.60"
    probe_windows                = $scenarioProbeWindow
    probe_spacing_seconds        = $probeSpacingByScenario
    accepted_attempts            = $acceptedAttempts
    rejected_attempts            = $rejectedAttempts
    failed_repetitions           = $failedRepetitions
    retried_repetitions          = $retriedRepetitions
    background_load_profiles     = $scenarioConfig
    jaeger_storage               = [ordered]@{
        type   = "badger"
        image  = "jaegertracing/all-in-one:1.60"
        volume = "jaeger_badger_data"
        local_workaround_user = "0:0"
    }
    totals_by_model_scenario     = $totalsByCombo
    notes                        = @(
        "Load durations are shortened from the final k6 scenarios for internal request-path observation, not a statistical benchmark.",
        "This experiment does NOT rerun results/performance/2026-08-21_165935 or results/literature/2026-08-23_012749.",
        "Failed attempts are retried from clean DB/Kafka/application state; no post-load replacement probes are sent."
    )
}
$metadata.allow_dirty = $AllowDirty
$metadata.manifest_path = $manifestPath

$metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $sessionDir "metadata.json") -Encoding utf8

Write-Host "Tracing experiment complete. Session folder: $sessionDir" -ForegroundColor Green
Write-Host "Run 'python scripts/analyze-traces.py $sessionDir' to generate the analysis CSVs." -ForegroundColor Green

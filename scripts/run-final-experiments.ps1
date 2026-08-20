param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("rest", "partial-grpc", "full-grpc", "async", "hybrid", "all")]
    [string]$Model,
    [ValidateRange(1, 100)]
    [int]$Runs = 5,
    [ValidateSet("baseline", "stress", "spike", "endurance", "edge", "all")]
    [string]$Scenario = "all",
    [ValidateRange(1, 10000)]
    [int]$WarmupRequests = 20
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$modelNames = @("rest", "partial-grpc", "full-grpc", "async", "hybrid")
$scenarioFiles = @{
    "baseline" = "02-baseline-load-test.js"
    "stress" = "03-stress-test.js"
    "spike" = "04-spike-test.js"
    "endurance" = "05-endurance-test.js"
    "edge" = "06-edge-case-test.js"
}
$endpoints = @{
    "rest" = "http://localhost:8080"
    "partial-grpc" = "http://localhost:8090"
    "full-grpc" = "http://localhost:8100"
    "async" = "http://localhost:8110"
    "hybrid" = "http://localhost:8120"
}

function Get-ToolVersion([string]$command, [string[]]$arguments) {
    try {
        return ((& $command @arguments 2>&1 | Out-String).Trim())
    } catch {
        return "unavailable"
    }
}

$modelsToRun = if ($Model -eq "all") { $modelNames } else { @($Model) }
$scenariosToRun = if ($Scenario -eq "all") { @("baseline", "stress", "spike", "endurance", "edge") } else { @($Scenario) }
$sessionName = Get-Date -Format "yyyy-MM-dd_HHmmss"
$sessionRoot = Join-Path $repoRoot "results\final\$sessionName"
if (Test-Path $sessionRoot) {
    throw "Experiment session already exists: $sessionRoot"
}
New-Item -ItemType Directory -Force $sessionRoot | Out-Null

$metadata = [ordered]@{
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    git_commit = (& git rev-parse HEAD).Trim()
    repetitions = $Runs
    warmup_requests = $WarmupRequests
    models = $modelsToRun
    scenarios = $scenariosToRun
    java_version = Get-ToolVersion "java" @("-version")
    docker_version = Get-ToolVersion "docker" @("version", "--format", "{{.Server.Version}}")
    k6_version = Get-ToolVersion "k6" @("version")
    operating_system = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    execution_environment = "local Docker Desktop"
    opentelemetry_jaeger_enabled = $true
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $sessionRoot "metadata.json")

foreach ($currentModel in $modelsToRun) {
    foreach ($currentScenario in $scenariosToRun) {
        $modelScenarioRoot = Join-Path $sessionRoot "$currentModel\$currentScenario"
        New-Item -ItemType Directory -Force $modelScenarioRoot | Out-Null

        for ($run = 1; $run -le $Runs; $run++) {
            $resultPath = Join-Path $modelScenarioRoot ("run-{0:D2}.json" -f $run)
            if (Test-Path $resultPath) {
                throw "Refusing to overwrite existing result: $resultPath"
            }

            Write-Host "[$currentModel/$currentScenario run $run/$Runs] Resetting databases..." -ForegroundColor Cyan
            & (Join-Path $PSScriptRoot "reset-experiment.ps1")
            if ($LASTEXITCODE -ne 0) { throw "Reset failed." }

            & (Join-Path $PSScriptRoot "start-model.ps1") -Model $currentModel
            if ($LASTEXITCODE -ne 0) { throw "Model startup failed." }

            & (Join-Path $PSScriptRoot "warmup-model.ps1") -Model $currentModel -Requests $WarmupRequests
            if ($LASTEXITCODE -ne 0) { throw "Warm-up failed." }

            Remove-Item Env:K6_WEB_DASHBOARD -ErrorAction SilentlyContinue
            Remove-Item Env:K6_WEB_DASHBOARD_OPEN -ErrorAction SilentlyContinue
            Remove-Item Env:K6_WEB_DASHBOARD_PORT -ErrorAction SilentlyContinue
            Remove-Item Env:K6_WEB_DASHBOARD_EXPORT -ErrorAction SilentlyContinue
            $env:BASE_URL = $endpoints[$currentModel]
            $scenarioPath = Join-Path $repoRoot ("k6-tests\rest\{0}" -f $scenarioFiles[$currentScenario])

            Write-Host "[$currentModel/$currentScenario run $run/$Runs] Running measured scenario..." -ForegroundColor Yellow
            & k6 run "--summary-export=$resultPath" $scenarioPath

            $k6ExitCode = $LASTEXITCODE
            if (-not (Test-Path $resultPath)) {
                throw "Measured scenario failed for $currentModel/$currentScenario run ${run}: k6 did not create a summary JSON file."
            }

            try {
                $summary = Get-Content $resultPath -Raw | ConvertFrom-Json
                if ($null -eq $summary.metrics -or $null -eq $summary.metrics.http_req_duration) {
                    throw "Required k6 metrics are missing."
                }
            } catch {
                throw "Measured scenario failed for $currentModel/$currentScenario run ${run}: summary JSON is missing or invalid. $($_.Exception.Message)"
            }

            if ($k6ExitCode -ne 0) {
                Write-Warning "Thresholds failed for $currentModel/$currentScenario run $run/$Runs, result preserved, continuing."
            }
        }
    }
}

Write-Host "Experiment session complete: $sessionRoot" -ForegroundColor Green
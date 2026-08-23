param(
    [Parameter(Mandatory = $true)]
    [string]$ResultsFolder
)

$ErrorActionPreference = "Stop"
$invariantCulture = [Globalization.CultureInfo]::InvariantCulture
$rawFields = @("model", "scenario", "run", "avg_ms", "median_ms", "p90_ms", "p95_ms", "p99_ms", "max_ms", "req_per_sec", "error_rate", "checks_rate", "iterations")
$aggregateFields = @("model", "scenario", "runs", "mean_avg_ms", "std_avg_ms", "mean_p95_ms", "std_p95_ms", "mean_req_per_sec", "std_req_per_sec", "mean_error_rate", "mean_checks_rate")
$rows = @()

Get-ChildItem -Path $ResultsFolder -Recurse -Filter "run-*.json" | ForEach-Object {
    if ($_.Name -match '^run-(\d+)\.json$') {
        $parts = $_.FullName -split '[\\/]'
        $modelIndex = [Array]::IndexOf($parts, ($parts | Where-Object { $_ -in @("rest", "partial-grpc", "full-grpc", "async", "hybrid") } | Select-Object -First 1))
        if ($modelIndex -ge 0 -and $modelIndex + 1 -lt $parts.Length) {
            $model = $parts[$modelIndex]
            $scenario = $parts[$modelIndex + 1]
            $summary = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $metrics = $summary.metrics
            function Metric($name, $value) {
                $metric = $metrics.PSObject.Properties[$name].Value
                if ($null -eq $metric) { return $null }
                $property = $metric.PSObject.Properties[$value]
                if ($null -ne $property) {
                    if ($property.Value -is [ValueType]) { return ([double]$property.Value).ToString("0.######", $invariantCulture) }
                    return $property.Value
                }
                $nestedValues = $metric.PSObject.Properties["values"].Value
                if ($null -ne $nestedValues) {
                    $nestedProperty = $nestedValues.PSObject.Properties[$value]
                    if ($null -eq $nestedProperty) { return $null }
                    if ($nestedProperty.Value -is [ValueType]) { return ([double]$nestedProperty.Value).ToString("0.######", $invariantCulture) }
                    return $nestedProperty.Value
                }
                return $null
            }
            $rows += [pscustomobject]@{
                model = $model; scenario = $scenario; run = [int]$Matches[1]
                avg_ms = Metric "http_req_duration" "avg"; median_ms = Metric "http_req_duration" "med"
                p90_ms = Metric "http_req_duration" "p(90)"; p95_ms = Metric "http_req_duration" "p(95)"
                p99_ms = Metric "http_req_duration" "p(99)"; max_ms = Metric "http_req_duration" "max"
                req_per_sec = Metric "http_reqs" "rate"; error_rate = Metric "http_req_failed" "value"
                checks_rate = Metric "checks" "value"; iterations = Metric "iterations" "count"
            }
        }
    }
}

if ($rows.Count -eq 0) { throw "No run-XX.json result files found." }
$rows | Select-Object $rawFields | Export-Csv (Join-Path $ResultsFolder "raw-results.csv") -NoTypeInformation

function Values($group, $property) {
    @($group | ForEach-Object { $value = $_.$property; if ($null -ne $value -and $value -ne "") { [double]::Parse([string]$value, $invariantCulture) } })
}
function MeanOrBlank($values) { if ($values.Count -gt 0) { ([Math]::Round(($values | Measure-Object -Average).Average, 6)).ToString("0.######", $invariantCulture) } else { "" } }
function StdOrBlank($values) {
    if ($values.Count -gt 1) {
        $mean = ($values | Measure-Object -Average).Average
        $sumSquaredDifferences = 0.0
        foreach ($value in $values) {
            $difference = [double]$value - $mean
            $sumSquaredDifferences += $difference * $difference
        }
        $standardDeviation = [Math]::Sqrt($sumSquaredDifferences / ($values.Count - 1))
        ([Math]::Round($standardDeviation, 6)).ToString("0.######", $invariantCulture)
    } else { "" }
}

$aggregated = @()
$rows | Group-Object model, scenario | ForEach-Object {
    $group = $_.Group
    $avg = Values $group "avg_ms"; $p95 = Values $group "p95_ms"; $throughput = Values $group "req_per_sec"
    $aggregated += [pscustomobject]@{
        model = $group[0].model; scenario = $group[0].scenario; runs = $group.Count
        mean_avg_ms = MeanOrBlank $avg; std_avg_ms = StdOrBlank $avg
        mean_p95_ms = MeanOrBlank $p95; std_p95_ms = StdOrBlank $p95
        mean_req_per_sec = MeanOrBlank $throughput; std_req_per_sec = StdOrBlank $throughput
        mean_error_rate = MeanOrBlank (Values $group "error_rate")
        mean_checks_rate = MeanOrBlank (Values $group "checks_rate")
    }
}
$aggregated | Select-Object $aggregateFields | Export-Csv (Join-Path $ResultsFolder "aggregated-results.csv") -NoTypeInformation

$comparison = foreach ($scenario in @("baseline", "stress", "spike", "endurance", "edge")) {
    $row = [ordered]@{ scenario = $scenario }
    foreach ($model in @("async", "full-grpc", "hybrid", "partial-grpc", "rest")) {
        $value = ($aggregated | Where-Object { $_.scenario -eq $scenario -and $_.model -eq $model }).mean_p95_ms
        $row["${model}_mean_p95_ms"] = $value
    }
    [pscustomobject]$row
}
$comparison | Export-Csv (Join-Path $ResultsFolder "comparison.csv") -NoTypeInformation

Write-Host "Wrote raw-results.csv, aggregated-results.csv, and comparison.csv to $ResultsFolder" -ForegroundColor Green
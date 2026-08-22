param(
    [Parameter(Mandatory = $true)]
    [string]$SessionFolder
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture
$setNames = @("niswar", "jarmoszewicz", "hamo")
$aggregateFields = @(
    "paper", "protocol", "shape", "payload_label", "payload_bytes", "request_count", "vus", "runs",
    "mean_avg_latency_ms", "std_avg_latency_ms", "mean_median_latency_ms", "std_median_latency_ms",
    "mean_p95_ms", "std_p95_ms", "mean_throughput_rps", "std_throughput_rps", "mean_error_rate", "std_error_rate",
    "mean_cpu_order_pct", "peak_cpu_order_pct", "mean_cpu_product_pct", "peak_cpu_product_pct",
    "mean_ram_order_mb", "peak_ram_order_mb", "mean_ram_product_mb", "peak_ram_product_mb"
)

function Get-Number($object, [string]$property) {
    $direct = $object.PSObject.Properties[$property]
    if ($null -ne $direct) { return [double]$direct.Value }
    $values = $object.PSObject.Properties["values"]
    if ($null -ne $values -and $null -ne $values.Value.PSObject.Properties[$property]) {
        return [double]$values.Value.PSObject.Properties[$property].Value
    }
    return $null
}

function Format-Number($value) {
    if ($null -eq $value) { return "" }
    return ([double]$value).ToString("0.######", $culture)
}

function Mean($values) {
    $items = @($values | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) { return $null }
    return (($items | Measure-Object -Average).Average)
}

function Sample-Std($values) {
    $items = @($values | Where-Object { $null -ne $_ })
    if ($items.Count -lt 2) { return $null }
    $mean = Mean $items
    $sum = 0.0
    foreach ($item in $items) {
        $difference = [double]$item - $mean
        $sum += $difference * $difference
    }
    return [Math]::Sqrt($sum / ($items.Count - 1))
}

function Get-Descriptor([string]$name) {
    if ($name -match '^niswar-(rest|grpc)-(flat|nested)-(\d+)-run-\d+\.json$') {
        return [pscustomobject]@{ paper = "niswar"; protocol = $Matches[1]; shape = $Matches[2]; payload_label = "small"; payload_bytes = 128; request_count = [int]$Matches[3]; vus = $null }
    }
    if ($name -match '^jarmoszewicz-(rest|grpc)-(small-1kb|large-875kb)-vu(\d+)-run-\d+\.json$') {
        $bytes = if ($Matches[2] -eq "small-1kb") { 1024 } else { 896000 }
        return [pscustomobject]@{ paper = "jarmoszewicz"; protocol = $Matches[1]; shape = $null; payload_label = $Matches[2]; payload_bytes = $bytes; request_count = $null; vus = [int]$Matches[3] }
    }
    if ($name -match '^hamo-(rest|grpc)-(small|medium|large)-vu(\d+)-run-\d+\.json$') {
        $bytesByLabel = @{ small = 128; medium = 4096; large = 65536 }
        return [pscustomobject]@{ paper = "hamo"; protocol = $Matches[1]; shape = $null; payload_label = $Matches[2]; payload_bytes = $bytesByLabel[$Matches[2]]; request_count = $null; vus = [int]$Matches[3] }
    }
    throw "Unexpected literature result filename: $name"
}

function Get-ResourceSummary([string]$path, [string]$container) {
    if (-not (Test-Path $path)) { throw "Missing resource samples: $path" }
    $samples = @(Import-Csv $path | Where-Object { $_.container -eq $container })
    if ($samples.Count -eq 0) { throw "No resource samples for $container in $path" }
    $cpu = @($samples | ForEach-Object { [double]::Parse($_.cpu_percent, $culture) })
    $ram = @($samples | ForEach-Object { [double]::Parse($_.memory_bytes, $culture) / 1MB })
    return [pscustomobject]@{
        meanCpu = Mean $cpu
        peakCpu = ($cpu | Measure-Object -Maximum).Maximum
        meanRam = Mean $ram
        peakRam = ($ram | Measure-Object -Maximum).Maximum
    }
}

if (-not (Test-Path $SessionFolder)) { throw "Session folder not found: $SessionFolder" }
$allRows = @()
foreach ($paper in $setNames) {
    $setFolder = Join-Path $SessionFolder $paper
    $rawFolder = Join-Path $setFolder "raw"
    if (-not (Test-Path $rawFolder)) { continue }
    $runRows = @()
    Get-ChildItem $rawFolder -Filter "*.json" | ForEach-Object {
        $descriptor = Get-Descriptor $_.Name
        $summary = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $durationMetric = $summary.metrics.PSObject.Properties["http_req_duration"].Value
        $httpReqs = $summary.metrics.PSObject.Properties["http_reqs"].Value
        $failed = $summary.metrics.PSObject.Properties["http_req_failed"].Value
        $errorRate = if ($null -eq $failed) { 0.0 } else { Get-Number $failed "rate" }
        if ($null -eq $errorRate) { $errorRate = 0.0 }
        $median = Get-Number $durationMetric "med"
        $resourcesPath = $_.FullName -replace '\.json$', '.resources.csv'
        $orderResources = Get-ResourceSummary $resourcesPath "order-service-rest"
        $productResources = Get-ResourceSummary $resourcesPath "product-service"
        $runRows += [pscustomobject]@{
            descriptor = $descriptor
            avg = Get-Number $durationMetric "avg"
            median = $median
            p95 = Get-Number $durationMetric "p(95)"
            throughput = Get-Number $httpReqs "rate"
            error = $errorRate
            order = $orderResources
            product = $productResources
        }
    }

    $aggregated = @($runRows | Group-Object { "$($_.descriptor.protocol)|$($_.descriptor.shape)|$($_.descriptor.payload_label)|$($_.descriptor.request_count)|$($_.descriptor.vus)" } | ForEach-Object {
        $group = @($_.Group)
        $first = $group[0].descriptor
        [pscustomobject]@{
            paper = $first.paper; protocol = $first.protocol; shape = $first.shape; payload_label = $first.payload_label
            payload_bytes = $first.payload_bytes; request_count = $first.request_count; vus = $first.vus; runs = $group.Count
            mean_avg_latency_ms = Format-Number (Mean @($group | ForEach-Object { $_.avg })); std_avg_latency_ms = Format-Number (Sample-Std @($group | ForEach-Object { $_.avg }))
            mean_median_latency_ms = Format-Number (Mean @($group | ForEach-Object { $_.median })); std_median_latency_ms = Format-Number (Sample-Std @($group | ForEach-Object { $_.median }))
            mean_p95_ms = Format-Number (Mean @($group | ForEach-Object { $_.p95 })); std_p95_ms = Format-Number (Sample-Std @($group | ForEach-Object { $_.p95 }))
            mean_throughput_rps = Format-Number (Mean @($group | ForEach-Object { $_.throughput })); std_throughput_rps = Format-Number (Sample-Std @($group | ForEach-Object { $_.throughput }))
            mean_error_rate = Format-Number (Mean @($group | ForEach-Object { $_.error })); std_error_rate = Format-Number (Sample-Std @($group | ForEach-Object { $_.error }))
            mean_cpu_order_pct = Format-Number (Mean @($group | ForEach-Object { $_.order.meanCpu })); peak_cpu_order_pct = Format-Number (Mean @($group | ForEach-Object { $_.order.peakCpu }))
            mean_cpu_product_pct = Format-Number (Mean @($group | ForEach-Object { $_.product.meanCpu })); peak_cpu_product_pct = Format-Number (Mean @($group | ForEach-Object { $_.product.peakCpu }))
            mean_ram_order_mb = Format-Number (Mean @($group | ForEach-Object { $_.order.meanRam })); peak_ram_order_mb = Format-Number (Mean @($group | ForEach-Object { $_.order.peakRam }))
            mean_ram_product_mb = Format-Number (Mean @($group | ForEach-Object { $_.product.meanRam })); peak_ram_product_mb = Format-Number (Mean @($group | ForEach-Object { $_.product.peakRam }))
        }
    })
    $aggregated | Select-Object $aggregateFields | Export-Csv (Join-Path $setFolder "aggregated-results.csv") -NoTypeInformation
    $aggregated | Select-Object $aggregateFields | Export-Csv (Join-Path $setFolder "summary.csv") -NoTypeInformation
    $allRows += $aggregated
}

$allRows | Select-Object $aggregateFields | Export-Csv (Join-Path $SessionFolder "literature-comparison-summary.csv") -NoTypeInformation
Write-Host "Wrote literature aggregation outputs to $SessionFolder" -ForegroundColor Green

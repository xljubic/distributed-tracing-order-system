param(
    [Parameter(Mandatory = $true)]
    [string]$SessionFolder
)

$ErrorActionPreference = "Stop"

$culture = [Globalization.CultureInfo]::InvariantCulture

$setNames = @(
    "niswar",
    "jarmoszewicz",
    "hamo"
)

$aggregateFields = @(
    "paper",
    "protocol",
    "shape",
    "payload_label",
    "payload_bytes",
    "load_profile",
    "request_count",
    "total_requests",
    "vus",
    "run_duration_seconds",
    "runs",
    "mean_avg_latency_ms",
    "std_avg_latency_ms",
    "mean_median_latency_ms",
    "std_median_latency_ms",
    "mean_p95_ms",
    "std_p95_ms",
    "mean_throughput_rps",
    "std_throughput_rps",
    "mean_error_rate",
    "std_error_rate",
    "mean_cpu_order_pct",
    "peak_cpu_order_pct",
    "mean_cpu_product_pct",
    "peak_cpu_product_pct",
    "mean_ram_order_mb",
    "peak_ram_order_mb",
    "mean_ram_product_mb",
    "peak_ram_product_mb"
)


function Get-Number {
    param(
        $Object,
        [string]$Property
    )

    if ($null -eq $Object) {
        return $null
    }

    $direct = $Object.PSObject.Properties[$Property]

    if ($null -ne $direct) {
        return [double]$direct.Value
    }

    $valuesProperty = $Object.PSObject.Properties["values"]

    if (
        $null -ne $valuesProperty -and
        $null -ne $valuesProperty.Value.PSObject.Properties[$Property]
    ) {
        return [double]$valuesProperty.Value.PSObject.Properties[$Property].Value
    }

    return $null
}


function Format-Number {
    param($Value)

    if ($null -eq $Value) {
        return ""
    }

    return ([double]$Value).ToString("0.######", $culture)
}


function Mean {
    param($Values)

    $items = @(
        $Values |
            Where-Object { $null -ne $_ }
    )

    if ($items.Count -eq 0) {
        return $null
    }

    return ($items | Measure-Object -Average).Average
}


function Sample-Std {
    param($Values)

    $items = @(
        $Values |
            Where-Object { $null -ne $_ }
    )

    if ($items.Count -lt 2) {
        return $null
    }

    $mean = Mean $items
    $sum = 0.0

    foreach ($item in $items) {
        $difference = [double]$item - [double]$mean
        $sum += $difference * $difference
    }

    return [Math]::Sqrt(
        $sum / ($items.Count - 1)
    )
}


function Get-Descriptor {
    param([string]$Name)

    if ($Name -match '^niswar-(rest|grpc)-(flat|nested)-(\d+)-run-\d+\.json$') {
        return [pscustomobject]@{
            paper = "niswar"
            protocol = $Matches[1]
            shape = $Matches[2]
            payload_label = "small"
            payload_bytes = 128
            load_profile = "request-count"
            request_count = [int]$Matches[3]
            total_requests = [int]$Matches[3]
            vus = 1
        }
    }

    if ($Name -match '^jarmoszewicz-(rest|grpc)-(small-1kb|large-875kb)-(j1-low|j1-medium|j1-ramp|j2-50|j2-100|j2-ramp)-run-\d+\.json$') {

        $bytes = if ($Matches[2] -eq "small-1kb") {
            1024
        } else {
            896000
        }

        return [pscustomobject]@{
            paper = "jarmoszewicz"
            protocol = $Matches[1]
            shape = "flat"
            payload_label = $Matches[2]
            payload_bytes = $bytes
            load_profile = $Matches[3]
            request_count = $null
            total_requests = $null
            vus = $null
        }
    }

    if ($Name -match '^hamo-(rest|grpc)-(hamo-small|hamo-medium|hamo-large)-(\d+)-vu(\d+)-run-\d+\.json$') {

        $bytesByLabel = @{
            "hamo-small" = 14
            "hamo-medium" = 153600
            "hamo-large" = 3145728
        }

        return [pscustomobject]@{
            paper = "hamo"
            protocol = $Matches[1]
            shape = "flat"
            payload_label = $Matches[2]
            payload_bytes = $bytesByLabel[$Matches[2]]
            load_profile = "vu$($Matches[4])"
            request_count = $null
            total_requests = [int]$Matches[3]
            vus = [int]$Matches[4]
        }
    }

    throw "Unexpected literature result filename: $Name"
}


function Get-ResourceSummary {
    param(
        [string]$Path,
        [string]$Container
    )

    if (-not (Test-Path $Path)) {
        throw "Missing resource samples: $Path"
    }

    $samples = @(
        Import-Csv $Path |
            Where-Object {
                $_.container -eq $Container
            }
    )

    if ($samples.Count -eq 0) {
        throw "No resource samples for $Container in $Path"
    }

    $cpu = @(
        $samples |
            ForEach-Object {
                [double]::Parse(
                    $_.cpu_percent,
                    $culture
                )
            }
    )

    $ram = @(
        $samples |
            ForEach-Object {
                [double]::Parse(
                    $_.memory_bytes,
                    $culture
                ) / 1MB
            }
    )

    return [pscustomobject]@{
        meanCpu = Mean $cpu
        peakCpu = ($cpu | Measure-Object -Maximum).Maximum
        meanRam = Mean $ram
        peakRam = ($ram | Measure-Object -Maximum).Maximum
    }
}


if (-not (Test-Path $SessionFolder)) {
    throw "Session folder not found: $SessionFolder"
}

$allRows = @()


foreach ($paper in $setNames) {

    $setFolder = Join-Path $SessionFolder $paper
    $rawFolder = Join-Path $setFolder "raw"

    if (-not (Test-Path $rawFolder)) {
        continue
    }

    $runRows = @()

    Get-ChildItem $rawFolder -Filter "*.json" |
        Sort-Object Name |
        ForEach-Object {

            $descriptor = Get-Descriptor $_.Name

            $summary = Get-Content $_.FullName -Raw |
                ConvertFrom-Json

            $durationMetric =
                $summary.metrics.PSObject.Properties["http_req_duration"].Value

            $httpReqs =
                $summary.metrics.PSObject.Properties["http_reqs"].Value

            $failed =
                $summary.metrics.PSObject.Properties["http_req_failed"].Value

            # k6's exported http_req_failed is a Rate metric shaped as
            # { fails, passes, thresholds, value }, not { rate } or { values: { rate } }.
            # "passes" counts occurrences where the boolean metric was true (i.e. the
            # request failed), so value = passes / (passes + fails).
            $rawFailedPasses = $null
            $rawFailedFails = $null

            if ($null -ne $failed) {
                $passesProperty = $failed.PSObject.Properties["passes"]
                $failsProperty = $failed.PSObject.Properties["fails"]

                if ($null -ne $passesProperty) {
                    $rawFailedPasses = [double]$passesProperty.Value
                }

                if ($null -ne $failsProperty) {
                    $rawFailedFails = [double]$failsProperty.Value
                }
            }

            $errorRate = if ($null -eq $failed) {
                0.0
            } else {
                $directValue = Get-Number $failed "value"

                if ($null -ne $directValue) {
                    $directValue
                } elseif (
                    $null -ne $rawFailedPasses -and
                    $null -ne $rawFailedFails -and
                    ($rawFailedPasses + $rawFailedFails) -gt 0
                ) {
                    $rawFailedPasses / ($rawFailedPasses + $rawFailedFails)
                } else {
                    $null
                }
            }

            if ($null -eq $errorRate) {
                $errorRate = 0.0
            }

            # Guard against a future k6 metric-shape change silently collapsing a real
            # failure rate back to zero: raw failed-request counters must agree with it.
            if (
                $null -ne $rawFailedPasses -and
                $rawFailedPasses -gt 0 -and
                $errorRate -le 0.0
            ) {
                throw "Aggregation inconsistency in $($_.Name): raw http_req_failed shows $rawFailedPasses failed request(s) but the computed error rate is 0. Check the k6 summary JSON metric shape."
            }

            $resourcesPath =
                $_.FullName -replace '\.json$', '.resources.csv'

            $orderResources =
                Get-ResourceSummary `
                    -Path $resourcesPath `
                    -Container "order-service-rest"

            $productResources =
                Get-ResourceSummary `
                    -Path $resourcesPath `
                    -Container "product-service"

            $durationSeconds = $null

            $stateProperty =
                $summary.PSObject.Properties["state"]

            if ($null -ne $stateProperty) {

                $state = $stateProperty.Value

                if (
                    $null -ne $state -and
                    $null -ne $state.PSObject.Properties["testRunDurationMs"]
                ) {
                    $durationSeconds =
                        [double]$state.PSObject.Properties["testRunDurationMs"].Value / 1000
                }
            }

            $runRows += [pscustomobject]@{
                descriptor = $descriptor
                avg = Get-Number $durationMetric "avg"
                median = Get-Number $durationMetric "med"
                p95 = Get-Number $durationMetric "p(95)"
                throughput = Get-Number $httpReqs "rate"
                error = $errorRate
                duration = $durationSeconds
                order = $orderResources
                product = $productResources
            }
        }


    $groups = $runRows |
        Group-Object {
            "$($_.descriptor.protocol)|" +
            "$($_.descriptor.shape)|" +
            "$($_.descriptor.payload_label)|" +
            "$($_.descriptor.load_profile)|" +
            "$($_.descriptor.request_count)|" +
            "$($_.descriptor.total_requests)|" +
            "$($_.descriptor.vus)"
        }


    $aggregated = @(
        $groups |
            ForEach-Object {

                $group = @($_.Group)
                $first = $group[0].descriptor

                [pscustomobject]@{
                    paper = $first.paper
                    protocol = $first.protocol
                    shape = $first.shape
                    payload_label = $first.payload_label
                    payload_bytes = $first.payload_bytes
                    load_profile = $first.load_profile
                    request_count = $first.request_count
                    total_requests = $first.total_requests
                    vus = $first.vus

                    run_duration_seconds =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.duration
                                    }
                            )
                        )

                    runs = $group.Count

                    mean_avg_latency_ms =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.avg
                                    }
                            )
                        )

                    std_avg_latency_ms =
                        Format-Number (
                            Sample-Std @(
                                $group |
                                    ForEach-Object {
                                        $_.avg
                                    }
                            )
                        )

                    mean_median_latency_ms =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.median
                                    }
                            )
                        )

                    std_median_latency_ms =
                        Format-Number (
                            Sample-Std @(
                                $group |
                                    ForEach-Object {
                                        $_.median
                                    }
                            )
                        )

                    mean_p95_ms =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.p95
                                    }
                            )
                        )

                    std_p95_ms =
                        Format-Number (
                            Sample-Std @(
                                $group |
                                    ForEach-Object {
                                        $_.p95
                                    }
                            )
                        )

                    mean_throughput_rps =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.throughput
                                    }
                            )
                        )

                    std_throughput_rps =
                        Format-Number (
                            Sample-Std @(
                                $group |
                                    ForEach-Object {
                                        $_.throughput
                                    }
                            )
                        )

                    mean_error_rate =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.error
                                    }
                            )
                        )

                    std_error_rate =
                        Format-Number (
                            Sample-Std @(
                                $group |
                                    ForEach-Object {
                                        $_.error
                                    }
                            )
                        )

                    mean_cpu_order_pct =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.order.meanCpu
                                    }
                            )
                        )

                    peak_cpu_order_pct =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.order.peakCpu
                                    }
                            )
                        )

                    mean_cpu_product_pct =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.product.meanCpu
                                    }
                            )
                        )

                    peak_cpu_product_pct =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.product.peakCpu
                                    }
                            )
                        )

                    mean_ram_order_mb =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.order.meanRam
                                    }
                            )
                        )

                    peak_ram_order_mb =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.order.peakRam
                                    }
                            )
                        )

                    mean_ram_product_mb =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.product.meanRam
                                    }
                            )
                        )

                    peak_ram_product_mb =
                        Format-Number (
                            Mean @(
                                $group |
                                    ForEach-Object {
                                        $_.product.peakRam
                                    }
                            )
                        )
                }
            }
    )


    $aggregated |
        Select-Object $aggregateFields |
        Export-Csv `
            (Join-Path $setFolder "aggregated-results.csv") `
            -NoTypeInformation

    $aggregated |
        Select-Object $aggregateFields |
        Export-Csv `
            (Join-Path $setFolder "summary.csv") `
            -NoTypeInformation

    $allRows += $aggregated
}


$allRows |
    Select-Object $aggregateFields |
    Export-Csv `
        (Join-Path $SessionFolder "literature-comparison-summary.csv") `
        -NoTypeInformation


Write-Host "Wrote literature aggregation outputs to $SessionFolder" -ForegroundColor Green
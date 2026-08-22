param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [Parameter(Mandatory = $true)]
    [string]$StopFile,
    [ValidateRange(1, 60)]
    [int]$IntervalSeconds = 1
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture
$containers = @("order-service-rest", "product-service")
"timestamp_utc,container,cpu_percent,memory_bytes" | Set-Content -Path $OutputPath

function Convert-MemoryToBytes([string]$value) {
    $match = [regex]::Match($value.Trim(), '^([0-9.]+)(B|[KMGTP]i?B)$')
    if (-not $match.Success) { return 0 }
    $number = [double]::Parse($match.Groups[1].Value, $culture)
    $multipliers = @{ B = 1; KB = 1000; MB = 1000000; GB = 1000000000; TB = 1000000000000; KiB = 1024; MiB = 1048576; GiB = 1073741824; TiB = 1099511627776 }
    return [int64]($number * $multipliers[$match.Groups[2].Value])
}

while (-not (Test-Path $StopFile)) {
    $timestamp = (Get-Date).ToUniversalTime().ToString("o")
    $stats = docker stats --no-stream --format '{{.Name}};{{.CPUPerc}};{{.MemUsage}}' $containers 2>$null
    foreach ($line in $stats) {
        $parts = $line -split ';', 3
        if ($parts.Count -ne 3) { continue }
        $cpu = [double]::Parse(($parts[1] -replace '%', '').Trim(), $culture)
        $memory = Convert-MemoryToBytes (($parts[2] -split '/')[0])
        "$timestamp,$($parts[0]),$($cpu.ToString('0.######', $culture)),$memory" | Add-Content -Path $OutputPath
    }
    Start-Sleep -Seconds $IntervalSeconds
}

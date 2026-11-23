$ErrorActionPreference = 'Stop'

$gcc = (Get-Command gcc.exe -CommandType Application | Select-Object -First 1).Source
$projectDir = Split-Path -Parent $PSScriptRoot
$commonDir = Join-Path $projectDir 'common'
$indicatorsDir = Join-Path $projectDir 'indicators'
$sources = @(
    (Join-Path $commonDir 'fast_reader.c')
    (Join-Path $indicatorsDir 'vwap.c')
    (Join-Path $indicatorsDir 'ohlc.c')
    (Join-Path $indicatorsDir 'sma.c')
    (Join-Path $indicatorsDir 'signal.c')
)
$variants = [ordered]@{ NAIVE = 'Static naive'; RUNNING = 'Static running sum'; FIXEDPOINT = 'Fixed-point running sum'; MALLOC = 'Heap naive' }
$report = Join-Path $PSScriptRoot 'stageB_perf_results_windows.md'
$workDir = Join-Path $PSScriptRoot ('.stageB-perf-' + [Guid]::NewGuid().ToString('N'))
$benchmark = Join-Path $workDir 'benchmark.exe'
$tempReport = Join-Path $workDir 'report.md'

Push-Location -LiteralPath $projectDir
try {
    $null = [IO.Directory]::CreateDirectory($workDir)
    $config = $null
    $tradeCount = $null
    $reportLines = foreach ($variant in $variants.Keys) {
        Write-Host "[Stage B $variant] Compiling with -O2."
        & $gcc '-std=c17' '-O2' '-Wall' '-Wextra' '-Werror' (Join-Path $PSScriptRoot ('main_stageB_perf_' + $variant.ToLowerInvariant() + '.c')) '-I' $commonDir '-I' $indicatorsDir @sources '-o' $benchmark
        if ($LASTEXITCODE -ne 0) { throw "GCC failed to compile $variant (exit code $LASTEXITCODE)." }

        $output = @(& $benchmark --config)
        if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1 -or $output[0] -cnotmatch '^(TEST20|DEV|STRESS)\t([1-9][0-9]*)\t([1-9][0-9]*)\t([1-9][0-9]*)\t([1-9][0-9]*)$') {
            throw "Invalid benchmark configuration for $variant."
        }
        if ($null -eq $config) {
            $config = $output[0]
            $dataset = $Matches[1]
            $rounds = [int]$Matches[2]
            $passes = $Matches[3]
            $short = $Matches[4]
            $long = $Matches[5]
            '# Stage B performance on Windows'
            ''
            "Dataset $dataset, SMA windows $short/$long, GCC -O2. Elapsed time is averaged over $passes passes per round and covers only in-memory processing. Trade and signal counts are per pass."
            ''
            '| Variant | Round | Trades | BUY | SELL | Average elapsed (ns) |'
            '| :--- | ---: | ---: | ---: | ---: | ---: |'
        } elseif ($output[0] -cne $config) {
            throw "Inconsistent benchmark configuration for $variant."
        }

        Write-Host "[Stage B $variant] Running $dataset."
        foreach ($round in 1..$rounds) {
            $output = @(& $benchmark --round $round)
            if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1 -or $output[0] -cnotmatch '^stageB_perf\t([1-9][0-9]*)\t([1-9][0-9]*)\t([0-9]+)\t([0-9]+)\t([0-9]+\.[0-9]+)$' -or $Matches[1] -cne [string]$round) {
                throw "Invalid benchmark result for $variant, round $round. $($output -join ' ')"
            }
            if ($null -eq $tradeCount) { $tradeCount = $Matches[2] }
            if ($Matches[2] -cne $tradeCount) { throw "Inconsistent trade count for $variant, round $round." }
            '| {0} | {1} | {2} | {3} | {4} | {5} |' -f $variants[$variant], $round, $tradeCount, $Matches[3], $Matches[4], $Matches[5]
        }
    }

    [IO.File]::WriteAllLines($tempReport, [string[]]$reportLines)
    if ([IO.File]::Exists($report)) {
        [IO.File]::Replace($tempReport, $report, [NullString]::Value)
    } else {
        [IO.File]::Move($tempReport, $report)
    }
    Write-Output $reportLines
    Write-Output "Saved $report"
} finally {
    Pop-Location
    if ([IO.Directory]::Exists($workDir)) {
        [IO.File]::Delete($benchmark)
        [IO.File]::Delete($tempReport)
        [IO.Directory]::Delete($workDir)
    }
}

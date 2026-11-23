$ErrorActionPreference = 'Stop'

$gcc = (Get-Command gcc.exe -CommandType Application | Select-Object -First 1).Source
$projectDir = Split-Path -Parent $PSScriptRoot
$commonDir = Join-Path $projectDir 'common'
$indicatorsDir = Join-Path $projectDir 'indicators'
$sources = @(
    (Join-Path $PSScriptRoot 'main_stageA_perf.c')
    (Join-Path $commonDir 'trade_io.c')
    (Join-Path $indicatorsDir 'vwap.c')
    (Join-Path $indicatorsDir 'ohlc.c')
    (Join-Path $indicatorsDir 'sma.c')
    (Join-Path $indicatorsDir 'signal.c')
)
$report = Join-Path $PSScriptRoot 'stageA_perf_results_windows.md'
$workDir = Join-Path $PSScriptRoot ('.stageA-perf-' + [Guid]::NewGuid().ToString('N'))
$benchmark = Join-Path $workDir 'benchmark.exe'
$tempReport = Join-Path $workDir 'report.md'
$levels = 0, 2

Push-Location -LiteralPath $projectDir
try {
    $null = [IO.Directory]::CreateDirectory($workDir)
    $metadata = $null
    $timingsByLevel = @{}
    foreach ($level in $levels) {
        Write-Host "[Stage A -O$level] Compiling benchmark."
        & $gcc '-std=c17' "-O$level" '-Wall' '-Wextra' '-Werror' '-DBENCHMARK_PROGRESS' '-I' $commonDir '-I' $indicatorsDir @sources '-o' $benchmark
        if ($LASTEXITCODE -ne 0) {
            throw "GCC failed to compile main_stageA_perf.c at -O$level (exit code $LASTEXITCODE)."
        }

        Write-Host "[Stage A -O$level] Running the benchmark on the STRESS dataset."
        $output = @(& $benchmark)
        if ($LASTEXITCODE -ne 0) {
            throw "Benchmark failed at -O$level (exit code $LASTEXITCODE). $($output -join ' ')"
        }

        $summary = @($output | Where-Object { $_ -cmatch '^stageA_perf\t' })
        if ($summary.Count -eq 0 -or $summary[0] -cnotmatch '^stageA_perf\t[1-9][0-9]*\t[1-9][0-9]*\t[^\t]+(?:\t[^\t]+)*$') {
            throw "Missing or invalid benchmark metadata at -O$level."
        }
        if ($null -eq $metadata) {
            $metadata = $summary[0]
            $fields = $metadata -split '\t'
            $roundCount = [int]$fields[1]
            $runCount = [int]$fields[2]
            $metricNames = $fields[3..($fields.Count - 1)]
        }
        if ($summary[0] -cne $metadata -or ($summary.Count - 1) -ne $roundCount) {
            throw "Inconsistent benchmark metadata or timing row count at -O$level."
        }

        $timingsByLevel[$level] = @(foreach ($round in 1..$roundCount) {
            $fields = $summary[$round] -split '\t'
            if ($fields.Count -ne ($metricNames.Count + 2) -or $fields[1] -cne [string]$round -or $fields -contains '') {
                throw "Invalid benchmark output at -O$level, round $round."
            }
            $fields[2..($fields.Count - 1)] -join ' / '
        })
        Write-Host "[Stage A -O$level] Measurements complete."
    }

    Write-Host "[Stage A] Saving the Markdown report."
    $reportLines = @(
        "Each cell shows $($metricNames -join ', ') averaged over $runCount runs."
        ''
        '| Round | -O0 | -O2 |'
        '| ---: | ---: | ---: |'
        foreach ($index in 0..($roundCount - 1)) {
            '| {0} | {1} | {2} |' -f ($index + 1), $timingsByLevel[0][$index], $timingsByLevel[2][$index]
        }
    )

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

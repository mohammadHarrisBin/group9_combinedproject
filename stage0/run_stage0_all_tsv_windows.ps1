$ErrorActionPreference = 'Stop'

$gcc = (Get-Command gcc.exe -CommandType Application | Select-Object -First 1).Source
$projectDir = Split-Path -Parent $PSScriptRoot
$includeDir = Join-Path $projectDir 'common'
$source = Join-Path $PSScriptRoot 'stage0_all_tsv.c'
$report = Join-Path $PSScriptRoot 'stage0_all_tsv_results_windows.md'

$workDir = Join-Path $PSScriptRoot ('.stage0-all-tsv-' + [Guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($workDir)
$tempReport = Join-Path $workDir 'report.md'
$levels = 0..3

try {
    $metadata = $null
    $timingsByLevel = @{}
    foreach ($level in $levels) {
        $benchmark = Join-Path $workDir "benchmark-O$level.exe"
        & $gcc '-std=c17' "-O$level" '-Wall' '-Wextra' '-Werror' '-I' $includeDir $source '-o' $benchmark
        if ($LASTEXITCODE -ne 0) {
            throw "GCC failed at -O$level (exit code $LASTEXITCODE)."
        }

        $summary = @(& $benchmark)
        if ($LASTEXITCODE -ne 0) {
            throw "The benchmark failed at -O$level (exit code $LASTEXITCODE)."
        }
        if ($summary.Count -eq 0 -or $summary[0] -notmatch '^[1-9][0-9]*\t[1-9][0-9]*$') {
            throw "Invalid benchmark metadata at -O$level."
        }
        if ($null -eq $metadata) {
            $metadata = $summary[0]
            $roundCount, $runCount = $metadata -split '\t'
            $roundCount = [int]$roundCount
        }
        if ($summary[0] -ne $metadata -or ($summary.Count - 1) -ne $roundCount) {
            throw "Inconsistent counts or number of rows at -O$level."
        }

        $timingsByLevel[$level] = @(foreach ($round in 1..$roundCount) {
            $fields = $summary[$round] -split '\t'
            if ($fields.Count -ne 3 -or $fields[0] -ne "$round" -or !$fields[1] -or !$fields[2]) {
                throw "Invalid benchmark output at -O$level, round $round."
            }
            "$($fields[1]) / $($fields[2])"
        })
    }

    $reportLines = @(
        "Measurements per method in each round: $runCount."
        'Each cell shows the iterative / recursive averages.'
        ''
        '| Round | -O0 | -O1 | -O2 | -O3 |'
        '| ---: | ---: | ---: | ---: | ---: |'
        foreach ($round in 1..$roundCount) {
            $cells = foreach ($level in $levels) {
                $timingsByLevel[$level][$round - 1]
            }
            '| {0} | {1} |' -f $round, ($cells -join ' | ')
        }
    )

    [IO.File]::WriteAllLines($tempReport, [string[]]$reportLines)
    if ([IO.File]::Exists($report)) {
        [IO.File]::Replace($tempReport, $report, [NullString]::Value)
    } else {
        [IO.File]::Move($tempReport, $report)
    }
    Write-Output "Saved $report"
} finally {
    foreach ($level in $levels) {
        [IO.File]::Delete((Join-Path $workDir "benchmark-O$level.exe"))
    }
    [IO.File]::Delete($tempReport)
    [IO.Directory]::Delete($workDir)
}

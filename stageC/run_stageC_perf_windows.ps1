param(
    [ValidatePattern('^[0-9]+$')]
    [string]$Rounds = '1'
)

$ErrorActionPreference = 'Stop'
$roundCount = 0
if (-not [int]::TryParse($Rounds, [ref]$roundCount) -or $roundCount -lt 1) {
    throw 'Rounds must be a positive integer.'
}

$gcc = (Get-Command gcc.exe -CommandType Application | Select-Object -First 1).Source
$projectDir = Split-Path -Parent $PSScriptRoot
$commonDir = Join-Path $projectDir 'common'
$indicatorsDir = Join-Path $projectDir 'indicators'
$sources = @(
    (Join-Path $PSScriptRoot 'main_stageC_perf.c')
    (Join-Path $commonDir 'fast_reader.c')
    (Join-Path $indicatorsDir 'sma.c')
    (Join-Path $indicatorsDir 'signal.c')
)
$flags = @('-std=c17', '-O3', '-Wall', '-Wextra', '-Werror')
$thresholds = @('0.1', '0.5', '1.0', '2.0', '5.0', '10.0', '20.0', '50.0', '100.0')
$report = Join-Path $PSScriptRoot 'stageC_perf_results_windows.md'
$workDir = Join-Path $PSScriptRoot ('.stageC-perf-' + [Guid]::NewGuid().ToString('N'))
$benchmark = Join-Path $workDir 'benchmark.exe'
$tempReport = Join-Path $workDir 'report.md'
$replayRows = [Collections.Generic.List[string]]::new()
$rivalRows = [Collections.Generic.List[string]]::new()

Push-Location -LiteralPath $projectDir
try {
    $null = [IO.Directory]::CreateDirectory($workDir)
    Write-Host '[Stage C] Compiling with GCC -O3.'
    & $gcc @flags '-I' $commonDir '-I' $indicatorsDir @sources '-o' $benchmark
    if ($LASTEXITCODE -ne 0) { throw "GCC failed to compile Stage C (exit code $LASTEXITCODE)." }

    foreach ($speed in '1', '10', '100', '1000') {
        for ($round = 1; $round -le $roundCount; $round++) {
            Write-Host "[Stage C] Running ${speed}x, round $round."
            $rows = @(& $benchmark $speed | ForEach-Object {
                if ($_ -cmatch '^stageC_(perf|rival)\t') { $_ } else { Write-Host $_ }
            })
            if ($LASTEXITCODE -ne 0) {
                throw "Stage C failed at ${speed}x, round $round (exit code $LASTEXITCODE)."
            }

            $replay = $null
            $rivals = @{}
            foreach ($row in $rows) {
                if ($row -cmatch '^stageC_perf\t') {
                    if ($null -ne $replay -or $row -cnotmatch '^stageC_perf\t[0-9]+\t[1-9][0-9]*\t[0-9]+\t[0-9]+\t[0-9]+\.[0-9]{2}\t[0-9]+\t[0-9]+$') {
                        throw "Invalid replay row at ${speed}x, round $round."
                    }
                    $fields = $row -split "`t"
                    if ($fields[1] -cne $speed) { throw "Unexpected replay speed at ${speed}x, round $round." }
                    $replay = '| ' + $round + ' | ' + ($fields[1..7] -join ' | ') + ' |'
                } else {
                    if ($row -cnotmatch '^stageC_rival\t[0-9]+\.[0-9]\t-?[0-9]+\.[0-9]{2}\t[0-9]+\t[0-9]+$') {
                        throw "Invalid rival row at ${speed}x, round $round."
                    }
                    $fields = $row -split "`t"
                    $threshold = $fields[1]
                    if ($threshold -cnotin $thresholds -or $rivals.ContainsKey($threshold)) {
                        throw "Unexpected or duplicate rival threshold at ${speed}x, round $round."
                    }
                    $rivals[$threshold] = '| ' + $round + ' | ' + $speed + ' | ' + ($fields[1..4] -join ' | ') + ' |'
                }
            }
            if ($null -eq $replay -or $rivals.Count -ne $thresholds.Count) {
                throw "Missing benchmark rows at ${speed}x, round $round."
            }
            $replayRows.Add($replay)
            foreach ($threshold in $thresholds) { $rivalRows.Add($rivals[$threshold]) }
        }
    }

    $reportLines = @(
        '# Stage C performance on Windows'
        ''
        ('Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `' + ($flags -join ' ') + '`.')
        ''
        'Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.'
        ''
        '## Replay'
        ''
        '| Round | Speed | Trades | BUY | SELL | Avg. processing latency (ns) | Worst processing latency (ns) | Replay elapsed (ns) |'
        '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
        $replayRows
        ''
        '## Rival bot'
        ''
        ('| Round | Speed | Rival reaction time (' + [char]0xB5 + 's) | P&L (USDT) | Bot wins | Rival wins |')
        '| ---: | ---: | ---: | ---: | ---: | ---: |'
        $rivalRows
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

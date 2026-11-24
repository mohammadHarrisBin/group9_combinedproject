@echo off
setlocal EnableExtensions DisableDelayedExpansion
for %%P in ("%~dp0.") do set "stage=%%~fP"
for %%P in ("%~dp0..") do set "root=%%~fP"
set "rounds=%~1"
set "extra=%~2"
set "third=%~3"
setlocal EnableDelayedExpansion
set "status=1"
if /i "!rounds!"=="-Rounds" (
    set "rounds=!extra!"
    if defined third goto invalid_rounds
    set "extra="
    if not defined rounds goto invalid_rounds
) else (
    if defined extra goto invalid_rounds
    if defined third goto invalid_rounds
    if not defined rounds set "rounds=1"
)
set "value=!rounds!"
call :positive_int
if errorlevel 1 goto invalid_rounds
set "rounds=!value!"
where gcc.exe >nul 2>&1
if errorlevel 1 (
    >&2 echo GCC ^(gcc.exe^) was not found on PATH.
    exit /b 1
)
pushd "!root!" || exit /b 1
set "common=!root!\common"
set "indicators=!root!\indicators"
set "report=!stage!\stageC_perf_results_windows.md"
set "work=!stage!\.stageC-perf-!random!-!random!-!random!"
mkdir "!work!"
if errorlevel 1 goto done
set "benchmark=!work!\benchmark.exe"
set "tempReport=!work!\report.md"

echo [Stage C] Compiling with GCC -O3.
gcc.exe -std=c17 -O3 -Wall -Wextra -Werror -I "!common!" -I "!indicators!" ^
    "!stage!\main_stageC_perf.c" "!common!\fast_reader.c" "!indicators!\sma.c" "!indicators!\signal.c" -o "!benchmark!"
if errorlevel 1 (
    >&2 echo GCC failed to compile Stage C ^(exit code !errorlevel!^).
    goto cleanup
)
type nul > "!work!\replay.tsv" || goto save_failed
type nul > "!work!\rivals.tsv" || goto save_failed
for %%S in (1 10 100 1000) do (
    call :run_speed %%S
    if errorlevel 1 goto cleanup
)

>"!tempReport!" (
    echo # Stage C performance on Windows
    echo(
    echo Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -O3 -Wall -Wextra -Werror`.
    echo(
    echo Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.
    echo(
    echo ## Replay
    echo(
    echo ^| Round ^| Speed ^| Trades ^| BUY ^| SELL ^| Avg. processing latency ^(ns^) ^| Worst processing latency ^(ns^) ^| Replay elapsed ^(ns^) ^|
    echo ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^|
    type "!work!\replay.tsv"
    echo(
    echo ## Rival bot
    echo(
    echo ^| Round ^| Speed ^| Rival reaction time ^(µs^) ^| P^&L ^(USDT^) ^| Bot wins ^| Rival wins ^|
    echo ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^|
    type "!work!\rivals.tsv"
) || goto save_failed

if exist "!report!\" goto save_failed
move /y "!tempReport!" "!report!" >nul
if errorlevel 1 goto save_failed
type "!report!"
echo Saved !report!
set "status=0"
goto cleanup

:save_failed
>&2 echo Could not save "!report!".

:cleanup
del /q "!work!\*.exe" "!work!\*.tsv" "!work!\report.md" 2>nul
rd "!work!"
if errorlevel 1 set "status=1"

:done
popd
exit /b !status!

:invalid_rounds
>&2 echo Usage: %~nx0 [Rounds] or %~nx0 -Rounds N
>&2 echo Rounds must be a positive integer.
exit /b 1

:run_speed
set "round=1"
:run_round
echo [Stage C] Running %~1x, round !round!.
"!benchmark!" %~1 > "!work!\output.tsv"
set "benchmarkStatus=!errorlevel!"
rem Display replay messages while keeping timing rows out of the console output.
findstr /b /v /l /c:"stageC_perf	" /c:"stageC_rival	" "!work!\output.tsv"
if not "!benchmarkStatus!"=="0" (
    >&2 echo Stage C failed at %~1x, round !round! ^(exit code !benchmarkStatus!^).
    exit /b 1
)
findstr /b /l /c:"stageC_perf	" /c:"stageC_rival	" "!work!\output.tsv" > "!work!\summary.tsv"
if errorlevel 1 goto bad_rows
findstr /v /r /x /c:"stageC_perf	[0-9]*	[1-9][0-9]*	[0-9]*	[0-9]*	[0-9][0-9]*\.[0-9][0-9]	[0-9]*	[0-9]*" ^
    /c:"stageC_rival	[0-9][0-9]*\.[0-9]	[0-9][0-9]*\.[0-9][0-9]	[0-9][0-9]*	[0-9][0-9]*" /c:"stageC_rival	[0-9][0-9]*\.[0-9]	-[0-9][0-9]*\.[0-9][0-9]	[0-9][0-9]*	[0-9][0-9]*" "!work!\summary.tsv" >nul
if not errorlevel 1 goto bad_rows
if errorlevel 2 goto bad_rows

set "replay="
for %%T in (0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0) do set "rival[%%T]="
for /f "usebackq tokens=1-8 delims=	" %%A in ("!work!\summary.tsv") do (
    if "%%A"=="stageC_perf" (
        if "%%H"=="" goto bad_rows
        if defined replay goto bad_rows
        if not "%%B"=="%~1" goto bad_rows
        set "replay=| !round! | %%B | %%C | %%D | %%E | %%F | %%G | %%H |"
    ) else (
        set "knownThreshold="
        for %%T in (0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0) do if "%%B"=="%%T" set "knownThreshold=1"
        if not defined knownThreshold goto bad_rows
        if defined rival[%%B] goto bad_rows
        set "rival[%%B]=| !round! | %~1 | %%B | %%C | %%D | %%E |"
    )
)
if not defined replay goto bad_rows
for %%T in (0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0) do if not defined rival[%%T] goto bad_rows
>>"!work!\replay.tsv" echo(!replay!|| exit /b 1
for %%T in (0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0) do (
    >>"!work!\rivals.tsv" echo(!rival[%%T]!|| exit /b 1
)
if !round! equ !rounds! exit /b 0
set /a round+=1
goto run_round

:bad_rows
>&2 echo Invalid or incomplete Stage C output at %~1x, round !round!.
exit /b 1

rem Validate a positive signed 32-bit integer and normalize leading zeros.
:positive_int
if not defined value exit /b 1
set "remaining=!value!"
for %%D in (0 1 2 3 4 5 6 7 8 9) do if defined remaining set "remaining=!remaining:%%D=!"
if defined remaining exit /b 1
:trim_zeros
if "!value:~0,1!"=="0" (
    set "value=!value:~1!"
    goto trim_zeros
)
if not defined value exit /b 1
if not "!value:~10!"=="" exit /b 1
if not "!value:~9!"=="" if "x!value!" gtr "x2147483647" exit /b 1
exit /b 0

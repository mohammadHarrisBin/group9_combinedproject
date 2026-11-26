@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "speeds=1000"
set "optimizations=-O2 -O3"
set "verbose=0"
set "extra_flags=-DSTAGEC_SCALED_SIGNAL=1"
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
set "report=!stage!\stageC_perf_results_windows_opt.md"
set "work=!stage!\.stageC-perf-!random!-!random!-!random!"
mkdir "!work!"
if errorlevel 1 goto done
set "benchmark=!work!\benchmark.exe"
set "tempReport=!work!\report.md"

type nul > "!work!\replay.tsv" || goto save_failed
type nul > "!work!\rivals.tsv" || goto save_failed
set "optimization="
for %%O in (!optimizations!) do (
    call :run_optimization %%O
    if errorlevel 1 goto cleanup
)
if not defined optimization (
    >&2 echo Select -O2, -O3, or both in the optimizations list.
    goto cleanup
)

>"!tempReport!" (
    echo # Optimized Stage C performance on Windows
    echo(
    echo Dataset `Datasets/stress_full.csv`. SMA windows 15/100. GCC flags `-std=c17 -Wall -Wextra -Werror !extra_flags!`. Optimization levels `!optimizations!`.
    echo(
    echo Processing latency measures the per-trade SMA and signal calculations. Replay elapsed time covers the replay loop, including pacing waits and terminal and LED work. Timing excludes CSV loading, shutdown and report writing.
    echo(
    echo ## Replay
    echo(
    echo ^| Optimization ^| Round ^| Speed ^| Trades ^| BUY ^| SELL ^| Avg. processing latency ^(ns^) ^| Worst processing latency ^(ns^) ^| Replay elapsed ^(ns^) ^|
    echo ^| --- ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^|
    type "!work!\replay.tsv"
    echo(
    echo ## Rival bot
    echo(
    echo ^| Optimization ^| Round ^| Speed ^| Rival reaction time ^(µs^) ^| P^&L ^(USDT^) ^| Bot wins ^| Rival wins ^|
    echo ^| --- ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^|
    type "!work!\rivals.tsv"
) || goto save_failed

if exist "!report!\" goto save_failed
move /y "!tempReport!" "!report!" >nul
if errorlevel 1 goto save_failed
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

:run_optimization
set "optimization=%~1"
if not "!optimization!"=="-O2" if not "!optimization!"=="-O3" (
    >&2 echo Select -O2, -O3, or both in the optimizations list.
    exit /b 1
)
echo [Stage C] Compiling with GCC !optimization!.
gcc.exe -std=c17 !optimization! -Wall -Wextra -Werror !extra_flags! -I "!common!" ^
    "!stage!\main_stageC_perf_opt.c" "!common!\fast_reader.c" "!stage!\signal_opt.c" -o "!benchmark!"
if errorlevel 1 (
    >&2 echo GCC failed to compile Stage C with !optimization! ^(exit code !errorlevel!^).
    exit /b 1
)
for %%S in (!speeds!) do (
    call :run_speed %%S
    if errorlevel 1 exit /b 1
)
exit /b 0

:run_speed
set "round=1"
:run_round
echo [Stage C] Running !optimization! at %~1x, round !round!.
"!benchmark!" %~1 > "!work!\output.tsv"
set "benchmarkStatus=!errorlevel!"
if not "!benchmarkStatus!"=="0" (
    type "!work!\output.tsv" >&2
    >&2 echo Stage C !optimization! failed at %~1x, round !round! ^(exit code !benchmarkStatus!^).
    exit /b 1
)
if "!verbose!"=="1" (
    findstr /b /v /l /c:"stageC_perf	" /c:"stageC_rival	" "!work!\output.tsv"
)

set "replay="
for %%T in (0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0) do set "rival[%%T]="
for /f "delims=" %%L in ('findstr /b /l /c:"stageC_perf	" /c:"stageC_rival	" "!work!\output.tsv"') do (
    for /f "tokens=1-8 delims=	" %%A in ("%%L") do (
        if "%%A"=="stageC_perf" (
            if not "%%L"=="%%A	%%B	%%C	%%D	%%E	%%F	%%G	%%H" goto bad_rows
            if "%%H"=="" goto bad_rows
            if defined replay goto bad_rows
            if not "%%B"=="%~1" goto bad_rows
            set "tradeCount=%%C"
            if "!tradeCount:~0,1!"=="0" goto bad_rows
            set "decimal=%%F"
            set "digits=%%C%%D%%E%%G%%H"
            call :validate_number_fields
            if errorlevel 1 goto bad_rows
            set "replay=| !optimization! | !round! | %%B | %%C | %%D | %%E | %%F | %%G | %%H |"
        ) else (
            if not "%%L"=="%%A	%%B	%%C	%%D	%%E" goto bad_rows
            if "%%E"=="" goto bad_rows
            set "knownThreshold="
            for %%T in (0.1 0.5 1.0 2.0 5.0 10.0 20.0 50.0 100.0) do if "%%B"=="%%T" set "knownThreshold=1"
            if not defined knownThreshold goto bad_rows
            if defined rival[%%B] goto bad_rows
            set "decimal=%%C"
            if "!decimal:~0,1!"=="-" set "decimal=!decimal:~1!"
            set "digits=%%D%%E"
            call :validate_number_fields
            if errorlevel 1 goto bad_rows
            set "rival[%%B]=| !optimization! | !round! | %~1 | %%B | %%C | %%D | %%E |"
        )
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
type "!work!\output.tsv" >&2
>&2 echo Invalid or incomplete Stage C !optimization! output at %~1x, round !round!.
exit /b 1

:validate_number_fields
if "!decimal:~3,1!"=="" exit /b 1
if not "!decimal:~-3,1!"=="." exit /b 1
set "digits=!digits!!decimal:~0,-3!!decimal:~-2!"
for %%N in (0 1 2 3 4 5 6 7 8 9) do if defined digits set "digits=!digits:%%N=!"
if defined digits exit /b 1
exit /b 0

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

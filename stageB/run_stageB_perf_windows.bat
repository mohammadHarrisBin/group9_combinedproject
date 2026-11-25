@echo off
setlocal EnableExtensions DisableDelayedExpansion
for %%P in ("%~dp0.") do set "stage=%%~fP"
for %%P in ("%~dp0..") do set "root=%%~fP"
setlocal EnableDelayedExpansion
set "status=1"
where gcc.exe >nul 2>&1
if errorlevel 1 (
    >&2 echo GCC ^(gcc.exe^) was not found on PATH.
    exit /b 1
)
pushd "!root!" || exit /b 1
set "common=!root!\common"
set "indicators=!root!\indicators"
set "report=!stage!\stageB_perf_results_windows.md"
set "work=!stage!\.stageB-perf-!random!-!random!-!random!"
mkdir "!work!"
if errorlevel 1 goto done
set "benchmark=!work!\benchmark.exe"
set "tempReport=!work!\report.md"

set "config="
set "tradeCount="
set "variantName[naive]=Static naive"
set "variantName[running]=Static running sum"
set "variantName[fixedpoint]=Fixed-point running sum"
set "variantName[malloc]=Heap naive"
for %%V in (naive running fixedpoint malloc) do (
    echo [Stage B %%V] Compiling with -O2.
    gcc.exe -std=c17 -O2 -Wall -Wextra -Werror -I "!common!" -I "!indicators!" ^
        "!stage!\main_stageB_perf_%%V.c" "!common!\fast_reader.c" "!indicators!\vwap.c" "!indicators!\ohlc.c" "!indicators!\sma.c" "!indicators!\signal.c" -o "!benchmark!"
    if not "!errorlevel!"=="0" (
        >&2 echo GCC failed to compile %%V ^(exit code !errorlevel!^).
        goto cleanup
    )
    call :run_variant %%V
    if errorlevel 1 goto cleanup
)

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

:run_variant
"!benchmark!" --config > "!work!\output.tsv"
if not "!errorlevel!"=="0" goto bad_config
set "line="
findstr /n /r /c:".*" "!work!\output.tsv" > "!work!\numbered.tsv"
for /f "usebackq tokens=1,* delims=:" %%N in ("!work!\numbered.tsv") do (
    if not "%%N"=="1" goto bad_config
    set "line=%%O"
)
if not defined line goto bad_config
if defined config (
    if not "!line!"=="!config!" goto bad_config
) else (
    for /f "tokens=1-5 delims=	" %%A in ("!line!") do (
        set "dataset=%%A"
        set "rounds=%%B"
        set "passes=%%C"
        set "short=%%D"
        set "long=%%E"
    )
    if not "!dataset!"=="TEST20" if not "!dataset!"=="DEV" if not "!dataset!"=="STRESS" goto bad_config
    findstr /r /x /c:"!dataset!	[1-9][0-9]*	[1-9][0-9]*	[1-9][0-9]*	[1-9][0-9]*" "!work!\output.tsv" >nul
    if errorlevel 1 goto bad_config
    set "value=!rounds!"
    call :positive_int
    if errorlevel 1 goto bad_config
    set "config=!line!"
    >"!tempReport!" (
        echo # Stage B performance on Windows
        echo(
        echo Dataset !dataset!, SMA windows !short!/!long!, GCC -O2. Elapsed time is averaged over !passes! passes per round and covers only in-memory processing. Trade and signal counts are per pass.
        echo(
        echo ^| Variant ^| Round ^| Trades ^| BUY ^| SELL ^| Average elapsed ^(ns^) ^|
        echo ^| :--- ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^|
    ) || exit /b 1
)
echo [Stage B %~1] Running !dataset!.
set "round=1"
:run_round
"!benchmark!" --round !round! > "!work!\output.tsv"
if not "!errorlevel!"=="0" goto bad_result
findstr /r /x /c:"stageB_perf	!round!	[1-9][0-9]*	[0-9][0-9]*	[0-9][0-9]*	[0-9][0-9]*\.[0-9][0-9]*" "!work!\output.tsv" >nul
if errorlevel 1 goto bad_result
set "line="
findstr /n /r /c:".*" "!work!\output.tsv" > "!work!\numbered.tsv"
for /f "usebackq tokens=1,* delims=:" %%N in ("!work!\numbered.tsv") do (
    if not "%%N"=="1" goto bad_result
    set "line=%%O"
)
if not defined line goto bad_result
for /f "tokens=3-6 delims=	" %%A in ("!line!") do (
    if not defined tradeCount set "tradeCount=%%A"
    if not "%%A"=="!tradeCount!" (
        >&2 echo Inconsistent trade count for %~1, round !round!.
        exit /b 1
    )
    >>"!tempReport!" echo ^| !variantName[%~1]! ^| !round! ^| %%A ^| %%B ^| %%C ^| %%D ^||| exit /b 1
)
if !round! equ !rounds! exit /b 0
set /a round+=1
goto run_round

:bad_config
>&2 echo Invalid or inconsistent benchmark configuration for %~1.
exit /b 1

:bad_result
>&2 echo Invalid benchmark result for %~1, round !round!.
type "!work!\output.tsv" >&2
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

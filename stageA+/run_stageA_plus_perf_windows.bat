@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "levels=0 1 2 3"


for %%P in ("%~dp0.") do set "stage=%%~fP"
for %%P in ("%~dp0..") do set "root=%%~fP"
setlocal EnableDelayedExpansion
set "status=1"
set "metadata="
set "roundCount="
where gcc.exe >nul 2>&1
if errorlevel 1 (
    >&2 echo GCC ^(gcc.exe^) was not found on PATH.
    exit /b 1
)
pushd "!root!" || exit /b 1
set "common=!root!\common"
set "indicators=!root!\indicators"
set "report=!stage!\stageA_plus_perf_results_windows.md"
set "work=!stage!\.stageA-plus-perf-!random!-!random!-!random!"
mkdir "!work!"
if errorlevel 1 goto done
set "benchmark=!work!\benchmark.exe"
set "tempReport=!work!\report.md"

for %%O in (!levels!) do (
    echo [Stage A+ -O%%O] Compiling benchmark.
    gcc.exe -std=c17 -O%%O -Wall -Wextra -Werror -DBENCHMARK_PROGRESS -I "!common!" -I "!indicators!" ^
        "!stage!\main_stageA_plus_perf.c" "!common!\fast_reader.c" "!indicators!\vwap.c" "!indicators!\ohlc.c" "!indicators!\sma.c" "!indicators!\signal.c" -o "!benchmark!"
    if not "!errorlevel!"=="0" (
        >&2 echo GCC failed to compile main_stageA_plus_perf.c at -O%%O ^(exit code !errorlevel!^).
        goto cleanup
    )
    echo [Stage A+ -O%%O] Running the benchmark on the TEST20 dataset.
    "!benchmark!" > "!work!\output.tsv"
    if not "!errorlevel!"=="0" (
        >&2 echo Benchmark failed at -O%%O ^(exit code !errorlevel!^).
        type "!work!\output.tsv" >&2
        goto cleanup
    )
    findstr /b /l /c:"stageA_plus_perf	" "!work!\output.tsv" > "!work!\summary.tsv"
    call :read_summary %%O
    if errorlevel 1 (
        >&2 echo Invalid or inconsistent benchmark output at -O%%O.
        goto cleanup
    )
    echo [Stage A+ -O%%O] Measurements complete.
)

echo [Stage A+] Saving the Markdown report.
>"!tempReport!" (
    echo Each cell shows !metricNames! averaged over !runCount! runs.
    echo(
    set "header=| Round |"
    set "separator=| ---: |"
    for %%O in (!levels!) do (
        set "header=!header! -O%%O |"
        set "separator=!separator! ---: |"
    )
    echo(!header!
    echo(!separator!
    for /l %%R in (1,1,!roundCount!) do (
        set "row=| %%R |"
        for %%O in (!levels!) do (
            set "row=!row! !timing[%%O,%%R]! |"
        )
        echo(!row!
    )
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

:read_summary
set "row=0"
for /f "usebackq delims=" %%L in ("!work!\summary.tsv") do (
    set "line=%%L"
    call :split_tsv
    if errorlevel 1 exit /b 1
    if !row! equ 0 (
        if !fieldCount! lss 4 exit /b 1
        if not defined metadata (
            set "value=!field[2]!"
            call :positive_int
            if errorlevel 1 exit /b 1
            if not "!field[2]!"=="!value!" exit /b 1
            set "roundCount=!value!"
            set "value=!field[3]!"
            call :positive_int
            if errorlevel 1 exit /b 1
            if not "!field[3]!"=="!value!" exit /b 1
            set "runCount=!value!"
            set /a timingFields=fieldCount-1
            set "metricNames=!field[4]!"
            for /l %%F in (5,1,!fieldCount!) do set "metricNames=!metricNames!, !field[%%F]!"
            set "metadata=!line!"
        )
        if not "!line!"=="!metadata!" exit /b 1
    ) else (
        if not !fieldCount! equ !timingFields! exit /b 1
        if not "!field[2]!"=="!row!" exit /b 1
        set "cell=!field[3]!"
        for /l %%F in (4,1,!fieldCount!) do set "cell=!cell! / !field[%%F]!"
        set "timing[%~1,!row!]=!cell!"
    )
    set /a row+=1
)
set /a row-=1
if not defined roundCount exit /b 1
if not !row! equ !roundCount! exit /b 1
exit /b 0

rem Split a nonempty TSV row and reject missing fields.
:split_tsv
set "rest=!line!"
set "joined="
set "fieldCount=0"
:next_field
if not defined rest exit /b 1
set /a fieldCount+=1
set "next="
for /f "tokens=1,* delims=	 eol=|" %%F in ("!rest!") do (
    set "field[!fieldCount!]=%%F"
    set "next=%%G"
    if defined joined (
        set "joined=!joined!	%%F"
    ) else set "joined=%%F"
)
set "rest=!next!"
if defined rest goto next_field
if not "!joined!"=="!line!" exit /b 1
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

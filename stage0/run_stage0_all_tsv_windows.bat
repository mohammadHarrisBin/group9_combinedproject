@echo off
setlocal EnableExtensions DisableDelayedExpansion
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
set "common=!root!\common"
set "report=!stage!\stage0_all_tsv_results_windows.md"
set "work=!stage!\.stage0-all-tsv-!random!-!random!-!random!"
mkdir "!work!"
if errorlevel 1 goto done
set "benchmark=!work!\benchmark.exe"
set "tempReport=!work!\report.md"

rem Stage 0 emits one metadata row followed by the timing rows.
for %%O in (0 1 2 3) do (
    echo [Stage 0 -O%%O] Compiling benchmark.
    gcc.exe -std=c17 -O%%O -Wall -Wextra -Werror -I "!common!" "!stage!\stage0_all_tsv.c" -o "!benchmark!"
    if not "!errorlevel!"=="0" (
        >&2 echo GCC failed at -O%%O ^(exit code !errorlevel!^).
        goto cleanup
    )
    echo [Stage 0 -O%%O] Running the benchmark.
    "!benchmark!" > "!work!\summary.tsv"
    if not "!errorlevel!"=="0" (
        >&2 echo The benchmark failed at -O%%O ^(exit code !errorlevel!^).
        goto cleanup
    )
    call :read_summary %%O
    if errorlevel 1 (
        >&2 echo Invalid or inconsistent benchmark output at -O%%O.
        goto cleanup
    )
    echo [Stage 0 -O%%O] Measurements complete.
)

echo [Stage 0] Saving the Markdown report.
>"!tempReport!" (
    echo Measurements per method in each round: !runCount!.
    echo Each cell shows the iterative / recursive averages.
    echo(
    echo ^| Round ^| -O0 ^| -O1 ^| -O2 ^| -O3 ^|
    echo ^| ---: ^| ---: ^| ---: ^| ---: ^| ---: ^|
    for /l %%R in (1,1,!roundCount!) do echo ^| %%R ^| !timing[0,%%R]! ^| !timing[1,%%R]! ^| !timing[2,%%R]! ^| !timing[3,%%R]! ^|
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
exit /b !status!

:read_summary
set "row=0"
findstr /n /r /c:".*" "!work!\summary.tsv" > "!work!\numbered.tsv"
for /f "usebackq tokens=1,* delims=:" %%N in ("!work!\numbered.tsv") do (
    set "line=%%O"
    call :split_tsv
    if errorlevel 1 exit /b 1
    if !row! equ 0 (
        if not !fieldCount! equ 2 exit /b 1
        if not defined metadata (
            set "value=!field[1]!"
            call :positive_int
            if errorlevel 1 exit /b 1
            if not "!field[1]!"=="!value!" exit /b 1
            set "roundCount=!value!"
            set "value=!field[2]!"
            call :positive_int
            if errorlevel 1 exit /b 1
            if not "!field[2]!"=="!value!" exit /b 1
            set "runCount=!field[2]!"
            set "metadata=!line!"
        )
        if not "!line!"=="!metadata!" exit /b 1
    ) else (
        if not !fieldCount! equ 3 exit /b 1
        if not "!field[1]!"=="!row!" exit /b 1
        set "timing[%~1,!row!]=!field[2]! / !field[3]!"
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

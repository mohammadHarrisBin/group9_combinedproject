@echo off
setlocal enabledelayedexpansion

set "OUT=full_bench_win.log"
type nul > "%OUT%"

echo ========================================== >> "%OUT%"
echo === WINDOWS BENCHMARK SUITE (CSC1103) === >> "%OUT%"
echo ========================================== >> "%OUT%"
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"Processor^(s^)" >> "%OUT%" 2>&1
gcc --version | findstr /N "^" | findstr "^1:" >> "%OUT%" 2>&1
echo. >> "%OUT%"

REM 1. Verify test20.csv correctness first (Short=3, Long=5)
echo ========================================== >> "%OUT%"
echo === CORRECTNESS CHECK: test20.csv === >> "%OUT%"
echo ========================================== >> "%OUT%"
mingw32-make clean >> "%OUT%" 2>&1
mingw32-make test20 >> "%OUT%" 2>&1
if exist bin\test20_stageA_engine.exe (
    bin\test20_stageA_engine.exe >> "%OUT%" 2>&1
)

REM 2. Stage 0 Microbenchmarks (parta_O0..O3, partb_O0..O3)
echo ========================================== >> "%OUT%"
echo === STAGE 0: MICROBENCHMARKS === >> "%OUT%"
echo ========================================== >> "%OUT%"
for %%F in (-O0 -O1 -O2 -O3) do (
    echo --- Stage 0 (%%F) --- >> "%OUT%"
    mingw32-make clean >> "%OUT%" 2>&1
    mingw32-make OPT="%%F" stage0 >> "%OUT%" 2>&1
    for %%S in (parta_O0 parta_O1 parta_O2 parta_O3 partb_O0 partb_O1 partb_O2 partb_O3) do (
        if exist "bin\%%S.exe" (
            echo >>> Running %%S (%%F) <<< >> "%OUT%"
            "bin\%%S.exe" >> "%OUT%" 2>&1
        )
    )
)

REM 3. Full Suite Across Plain Flags (-O0, -O1, -O2, -O3)
set "ENGINES=stageA_engine stageA_plus_engine stageB_naive_engine stageB_running_engine stageB_fp_engine stageB_malloc_engine stageC_v0_engine stageC_engine"

for %%F in (-O0 -O1 -O2 -O3) do (
    echo ========================================== >> "%OUT%"
    echo === BUILDING SUITE: OPT=%%F === >> "%OUT%"
    echo ========================================== >> "%OUT%"
    mingw32-make clean >> "%OUT%" 2>&1
    mingw32-make OPT="%%F" stageA stageA_plus stageB stageC_v0 stageC >> "%OUT%" 2>&1

    for %%E in (!ENGINES!) do (
        if exist "bin\%%E.exe" (
            echo ------------------------------------------ >> "%OUT%"
            echo >>> WINDOWS (%%F): %%E <<< >> "%OUT%"
            echo ------------------------------------------ >> "%OUT%"

            for /L %%I in (1,1,5) do (
                echo --- Trial %%I (%%F, %%E) --- >> "%OUT%"
                if /I "%%E"=="stageC_engine" (
                    "bin\%%E.exe" 1000 >> "%OUT%" 2>&1
                ) else (
                    "bin\%%E.exe" >> "%OUT%" 2>&1
                )
            )
        ) else (
            echo [SKIP] bin\%%E.exe not built >> "%OUT%"
        )
    )
)

echo Done! All outputs saved to %OUT%

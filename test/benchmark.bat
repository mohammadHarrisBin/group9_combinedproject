(
echo @echo off
echo setlocal enabledelayedexpansion
echo.
echo set "OUT=full_bench_win.log"
echo type nul ^> "%%OUT%%"
echo.
echo echo ========================================== ^>^> "%%OUT%%"
echo echo === WINDOWS BENCHMARK SUITE ^(CSC1103^) === ^>^> "%%OUT%%"
echo echo ========================================== ^>^> "%%OUT%%"
echo systeminfo ^| findstr /B /C:"OS Name" /C:"OS Version" /C:"Processor^(s^)" ^>^> "%%OUT%%" 2^>^&1
echo gcc --version ^| findstr /N "^" ^| findstr "^1:" ^>^> "%%OUT%%" 2^>^&1
echo echo. ^>^> "%%OUT%%"
echo.
echo REM 1. Verify test20.csv correctness first ^(Short=3, Long=5^)
echo echo ========================================== ^>^> "%%OUT%%"
echo echo === CORRECTNESS CHECK: test20.csv === ^>^> "%%OUT%%"
echo echo ========================================== ^>^> "%%OUT%%"
echo mingw32-make clean ^>^> "%%OUT%%" 2^>^&1
echo mingw32-make test20 ^>^> "%%OUT%%" 2^>^&1
echo if exist bin\test20_stageA_engine.exe ^(
echo     bin\test20_stageA_engine.exe ^>^> "%%OUT%%" 2^>^&1
echo ^)
echo.
echo REM 2. Stage 0 Microbenchmarks ^(parta_O0..O3, partb_O0..O3^)
echo echo ========================================== ^>^> "%%OUT%%"
echo echo === STAGE 0: MICROBENCHMARKS === ^>^> "%%OUT%%"
echo echo ========================================== ^>^> "%%OUT%%"
echo for %%%%F in ^(-O0 -O1 -O2 -O3^) do ^(
echo     echo --- Stage 0 ^(%%%%F^) --- ^>^> "%%OUT%%"
echo     mingw32-make clean ^>^> "%%OUT%%" 2^>^&1
echo     mingw32-make OPT="%%%%F" stage0 ^>^> "%%OUT%%" 2^>^&1
echo     for %%%%S in ^(parta_O0 parta_O1 parta_O2 parta_O3 partb_O0 partb_O1 partb_O2 partb_O3^) do ^(
echo         if exist "bin\%%%%S.exe" ^(
echo             echo ^>^>^> Running %%%%S ^(%%%%F^) ^<^<^< ^>^> "%%OUT%%"
echo             "bin\%%%%S.exe" ^>^> "%%OUT%%" 2^>^&1
echo         ^)
echo     ^)
echo ^)
echo.
echo REM 3. Full Suite Across Plain Flags ^(-O0, -O1, -O2, -O3^)
echo set "ENGINES=stageA_engine stageA_plus_engine stageB_naive_engine stageB_running_engine stageB_fp_engine stageB_malloc_engine stageC_v0_engine stageC_engine"
echo.
echo for %%%%F in ^(-O0 -O1 -O2 -O3^) do ^(
echo     echo ========================================== ^>^> "%%OUT%%"
echo     echo === BUILDING SUITE: OPT=%%%%F === ^>^> "%%OUT%%"
echo     echo ========================================== ^>^> "%%OUT%%"
echo     mingw32-make clean ^>^> "%%OUT%%" 2^>^&1
echo     mingw32-make OPT="%%%%F" stageA stageA_plus stageB stageC_v0 stageC ^>^> "%%OUT%%" 2^>^&1
echo.
echo     for %%%%E in ^(!ENGINES!^) do ^(
echo         if exist "bin\%%%%E.exe" ^(
echo             echo ------------------------------------------ ^>^> "%%OUT%%"
echo             echo ^>^>^> WINDOWS ^(%%%%F^): %%%%E ^<^<^< ^>^> "%%OUT%%"
echo             echo ------------------------------------------ ^>^> "%%OUT%%"
echo.
echo             for /L %%%%I in ^(1,1,5^) do ^(
echo                 echo --- Trial %%%%I ^(%%%%F, %%%%E^) --- ^>^> "%%OUT%%"
echo                 if /I "%%%%E"=="stageC_engine" ^(
echo                     "bin\%%%%E.exe" 1000 ^>^> "%%OUT%%" 2^>^&1
echo                 ^) else ^(
echo                     "bin\%%%%E.exe" ^>^> "%%OUT%%" 2^>^&1
echo                 ^)
echo             ^)
echo         ^) else ^(
echo             echo [SKIP] bin\%%%%E.exe not built ^>^> "%%OUT%%"
echo         ^)
echo     ^)
echo ^)
echo.
echo echo Done! All outputs saved to %%OUT%%
) > run_full_bench_win.bat
run_full_bench_win.bat
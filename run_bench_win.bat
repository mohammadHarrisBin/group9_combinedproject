@echo off
setlocal enabledelayedexpansion

set "STAMP=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "STAMP=%STAMP: =0%"
set "WIN_LOG_DIR=bench_results\win_host_%STAMP%"

if not exist "%WIN_LOG_DIR%" mkdir "%WIN_LOG_DIR%"

echo === WINDOWS HOST SYSTEM INFO === > "%WIN_LOG_DIR%\windows_setup.txt"
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Model" /C:"Processor(s)" >> "%WIN_LOG_DIR%\windows_setup.txt" 2>&1

echo Launching WSL benchmark script...
wsl bash -lc "cd \"$(wslpath '%CD%')\" && chmod +x run_bench.sh && ./run_bench.sh"

echo Done. Windows host log saved to %WIN_LOG_DIR%\windows_setup.txt
pause
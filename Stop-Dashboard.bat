@echo off
setlocal EnableExtensions
title Stop Server Dashboard

REM ===========================================================================
REM  Stop-Dashboard.bat - stops the dashboard (scheduled task and/or process)
REM ===========================================================================

set "PORT=8080"

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  Stopping the dashboard on port %PORT%...
schtasks /End /TN "ServerDashboard" >nul 2>&1

for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:":%PORT% .*LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
    echo    Process %%P terminated.
)

REM stop the script hosts and anything left on the port (logic in a .ps1:
REM inline PowerShell with quotes breaks the batch parser)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-DashboardProcess.ps1" -Port %PORT% >nul 2>&1

echo  Done.
timeout /t 3 /nobreak >nul
endlocal

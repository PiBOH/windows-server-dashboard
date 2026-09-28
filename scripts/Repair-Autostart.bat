@echo off
REM ===========================================================================
REM  Repair-Autostart.bat
REM  Re-creates the boot task and the URL reservation, without touching
REM  anything else, so the dashboard comes up on its own after a power on,
REM  with nobody logged on to the server.
REM ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
title Server Dashboard - Repair autostart
set "PORT=8080"
set "INTERVAL=0.5"
set "TASKNAME=PiBOH Windows Server Dashboard"
REM  This script lives in scripts\: the package root is one level up.
set "ROOT=%~dp0..\"
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo  Administrative privileges required. Restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ============================================================
echo    REPAIRING THE AUTOSTART
echo  ============================================================
echo.

echo  1. URL reservation ^(so it can answer on the network^)
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-UrlAcl.ps1" -Port %PORT%`) do echo     %%A

echo.
echo  2. Boot task as SYSTEM
schtasks /Delete /TN "%TASKNAME%" /F >nul 2>&1
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0New-DashboardTask.ps1" -TaskName "%TASKNAME%" -ScriptPath "%~dp0ServerDashboard.ps1" -Port %PORT% -IntervalSeconds %INTERVAL%`) do (
    if /i "%%A"=="VERDICT" ( set "V=%%B" ) else ( echo     %%A )
)
echo.
if /i "!V!"=="STARTS-AT-BOOT" (
    echo     [OK] The task will start at boot as SYSTEM, no logon needed.
) else (
    echo     [!!] Result: !V! - run Diagnose.bat for the details.
)

echo.
echo  3. Restarting it now
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-DashboardProcess.ps1" -Port %PORT% >nul 2>&1
schtasks /Run /TN "%TASKNAME%" >nul 2>&1
timeout /t 6 /nobreak >nul
for /f "usebackq delims=" %%R in (`powershell -NoProfile -Command "try{(Invoke-WebRequest -Uri ('http://localhost:' + %PORT% + '/api/health') -UseBasicParsing -TimeoutSec 8).Content}catch{'no answer'}"`) do echo     health: %%R

echo.
echo  Done. Reboot the server without logging on to confirm.
echo.
pause
endlocal

@echo off
REM ===========================================================================
REM  Update-Now.bat
REM  Checks GitHub for a newer release and, when there is one, does the whole
REM  cycle by itself: download, stop the dashboard, install, start the
REM  dashboard again and verify that it answers. Without a new release it
REM  prints "up to date" and changes nothing.
REM
REM  The same check runs by itself at every boot, as SYSTEM, so normally you
REM  never need this file. Disable the AUTOMATIC check with:
REM      auto_update = no   in settings.txt
REM  This file keeps working anyway: it is an explicit, manual request.
REM  It restarts itself as administrator when needed: stopping and starting
REM  the scheduled task (which runs as SYSTEM) requires it.
REM ===========================================================================
setlocal
set "PORT=8080"
cd /d "%~dp0"

REM  Without admin rights the old instance cannot be stopped and the task
REM  cannot be started again: the update would look fine while the OLD
REM  version kept serving. Diagnose.bat uses the very same pattern.
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  This script restarts itself as administrator: stopping and
    echo  restarting the dashboard task needs those rights.
    echo  Restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  Checking github.com/PiBOH/windows-server-dashboard for updates...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ServerDashboard.ps1" -Port %PORT% -UpdateNow

echo.
pause
endlocal

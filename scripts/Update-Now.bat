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
REM ===========================================================================
setlocal
set "PORT=8080"
cd /d "%~dp0"

echo.
echo  Checking github.com/PiBOH/windows-server-dashboard for updates...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ServerDashboard.ps1" -Port %PORT% -UpdateNow

echo.
pause
endlocal

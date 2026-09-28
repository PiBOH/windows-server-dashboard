@echo off
REM ===========================================================================
REM  Update-Now.bat
REM  Checks GitHub for a newer release and installs it immediately, without
REM  waiting for the next start of the service. The same check runs by itself
REM  at every boot, as SYSTEM, so normally you never need this file.
REM  Disable the automatic check with:  auto_update = no  in settings.txt
REM ===========================================================================
setlocal
set "PORT=8080"
cd /d "%~dp0"

echo.
echo  Checking github.com/PiBOH/windows-server-dashboard for updates...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ServerDashboard.ps1" -Port %PORT% -CheckUpdatesOnly

echo.
pause
endlocal

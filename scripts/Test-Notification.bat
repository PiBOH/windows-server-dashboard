@echo off
REM ===========================================================================
REM  Test-Notification.bat
REM  Shows the logon notification immediately, without logging off and on.
REM  Use it to check that the notification really appears on this desktop.
REM  Details of what was tried end up in logs\ServerDashboard-notify.log
REM ===========================================================================
setlocal
set "PORT=8080"
REM  This script lives in scripts\: the package root is one level up.
set "ROOT=%~dp0..\"
cd /d "%~dp0"

echo.
echo  Showing the startup notification now...
echo  (it checks the dashboard on port %PORT% first - a few seconds)
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Show-StartupNotification.ps1" -Port %PORT% -TimeoutSeconds 10

echo.
echo  Done. If nothing appeared, open logs\ServerDashboard-notify.log: it says which
echo  display method was tried and why it failed.
echo.
pause
endlocal

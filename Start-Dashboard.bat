@echo off
setlocal EnableExtensions
title Server Dashboard - Monitoring

REM ===========================================================================
REM  Start-Dashboard.bat
REM  Starts the web monitoring dashboard on this server.
REM  Then, from any computer on the LAN:  http://<SERVER-IP>:8080
REM ===========================================================================

REM ---- CONFIGURATION --------------------------------------------------------
set "PORT=8080"
set "INTERVAL=5"
set "HIDDEN=1"
REM  HIDDEN=1 -> no console window     HIDDEN=0 -> show the live log
REM ---------------------------------------------------------------------------

cd /d "%~dp0"
set "PS1=%~dp0scripts\ServerDashboard.ps1"

if not exist "%PS1%" (
    echo [ERROR] Missing file: %PS1%
    echo Keep ServerDashboard.ps1 in the same folder as this .bat
    pause
    exit /b 1
)

if not exist "%~dp0lang\en-US.xml" (
    echo  [!] WARNING: the "lang" folder is missing or incomplete.
    echo      Copy the lang\ folder next to this file, otherwise the
    echo      dashboard will not be able to switch languages.
    echo.
)

REM ---- administrative privileges are required -------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [!] Administrative privileges required: restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  =======================================================
echo    SERVER DASHBOARD - starting
echo  =======================================================
echo    Computer : %COMPUTERNAME%
echo    Port     : %PORT%
echo.

REM ---- stop any previous instance bound to the same port --------------------
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:":%PORT% .*LISTENING"') do (
    echo    Stopping previous process PID %%P...
    taskkill /F /PID %%P >nul 2>&1
)

REM ---- reserve the URL so it can listen on every interface ------------------
netsh http add urlacl url=http://+:%PORT%/ user="NT AUTHORITY\SYSTEM" >nul 2>&1
netsh http add urlacl url=http://+:%PORT%/ user="%USERDOMAIN%\%USERNAME%" >nul 2>&1

REM ---- inbound firewall rule ------------------------------------------------
netsh advfirewall firewall show rule name="Server Dashboard %PORT%" >nul 2>&1
if errorlevel 1 (
    echo    Creating the firewall rule for port %PORT%...
    netsh advfirewall firewall add rule name="Server Dashboard %PORT%" dir=in action=allow protocol=TCP localport=%PORT% profile=any >nul 2>&1
)

REM ---- launch the PowerShell service ----------------------------------------
if "%HIDDEN%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%PS1%\"','-Port','%PORT%','-IntervalSeconds','%INTERVAL%'"
) else (
    start "Server Dashboard" powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Port %PORT% -IntervalSeconds %INTERVAL%
)

REM ---- show the access URLs -------------------------------------------------
timeout /t 4 /nobreak >nul
echo.
echo    The dashboard is reachable from the local network at:
echo.
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=* delims= " %%J in ("%%I") do echo        http://%%J:%PORT%
)
echo        http://%COMPUTERNAME%:%PORT%
echo.
echo    Log files: %~dp0logs\ServerDashboard-YYYY-MM-DD.log (one per day,
echo    kept for 14 days)
echo    To stop it:  Stop-Dashboard.bat
echo  =======================================================
echo.
if "%HIDDEN%"=="0" pause
timeout /t 8 /nobreak >nul
endlocal
exit /b 0

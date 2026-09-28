@echo off
REM ===========================================================================
REM  Diagnose.bat - thin wrapper: all the logic lives in Diagnose.ps1, because
REM  PowerShell one-liners inside a FOR /F loop break the batch parser (that is
REM  why this window used to close immediately in 1.11.1).
REM  Read only: it changes nothing on the machine.
REM ===========================================================================
setlocal
set "PORT=8080"
REM  This script lives in scripts\: the package root is one level up.
set "ROOT=%~dp0..\"
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Administrative privileges are required for the full check.
    echo  Restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%~dp0Diagnose.ps1" (
    echo.
    echo  [ERROR] Diagnose.ps1 not found next to this file.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Diagnose.ps1" -Port %PORT%

echo.
echo  Press a key to close this window...
pause >nul
endlocal

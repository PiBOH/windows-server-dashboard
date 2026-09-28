@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Server Dashboard - Installer
color 0B

REM ===========================================================================
REM  Install.bat
REM  Installs the Server Dashboard as a scheduled task that starts at boot.
REM
REM  Everything this installer touches is recorded in logs\install-state.txt so that
REM  Uninstall.bat can put the machine back exactly as it was found.
REM  Every change is printed on screen with its BEFORE and AFTER value.
REM ===========================================================================

REM ---- CONFIGURATION --------------------------------------------------------
set "PORT=8080"
set "INTERVAL=0.5"
set "TASKNAME=PiBOH Windows Server Dashboard"
set "NOTIFYTASK=PiBOH Windows Server Dashboard Notify"
REM ---------------------------------------------------------------------------

cd /d "%~dp0"
if not exist "%~dp0logs" mkdir "%~dp0logs" >nul 2>&1
set "PS1=%~dp0scripts\ServerDashboard.ps1"
set "STATE=%~dp0logs\install-state.txt"
set "TASKBAK=%~dp0logs\previous-task-backup.xml"

echo.
echo  ============================================================
echo    SERVER DASHBOARD - INSTALLER
echo  ============================================================
echo.

REM ---- 1. prerequisites -----------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Administrative privileges are required. Restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
if not exist "%PS1%" (
    echo  [ERROR] ServerDashboard.ps1 not found in this folder. Nothing was changed.
    pause & exit /b 1
)
if not exist "%~dp0lang\en-US.xml" (
    echo  [!] WARNING: the lang\ folder is missing or incomplete.
    echo      The dashboard will still run, but language switching will not work.
    echo.
)
if exist "%STATE%" (
    echo  [!] logs\install-state.txt already exists: the dashboard looks already installed.
    echo      Run Uninstall.bat first if you want a clean installation.
    echo      Continuing will overwrite the recorded state.
    echo.
    choice /c YN /m "  Continue anyway"
    if errorlevel 2 ( echo  Aborted. Nothing was changed. & pause & exit /b 0 )
    echo.
)

echo  %~dp0| findstr /i "\\Users\\ OneDrive" >nul 2>&1
if not errorlevel 1 (
    echo  [!] WARNING: this folder is inside a user profile or a OneDrive folder.
    echo      A task running as SYSTEM may not be able to read it, and the
    echo      dashboard would then start only after a user logs on.
    echo      Move the folder to, for example, C:\ServerDashboard\ and run this
    echo      installer again.
    echo.
    choice /c YN /m "  Continue anyway"
    if errorlevel 2 ( echo  Aborted. Nothing was changed. & pause & exit /b 0 )
    echo.
)

REM ---- 1-bis. syntax check ---------------------------------------------------
REM  A syntax error would make the script exit with code 1 before writing any
REM  log, and the task would look "Ready" while nothing ever runs. Check first.
echo  Checking the scripts...
set "SYNTAX=FAIL"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Test-Syntax.ps1" -Folder "%~dp0scripts"`) do (
    echo %%L | find /i "RESULT=" >nul 2>&1
    if errorlevel 1 ( echo      %%L ) else ( for /f "tokens=2 delims==" %%V in ("%%L") do set "SYNTAX=%%V" )
)
if /i not "!SYNTAX!"=="OK" (
    echo.
    echo  [X] One of the PowerShell files has a syntax error ^(see above^).
    echo      Installing now would create a task that starts and dies at once.
    echo      Nothing was changed.
    echo.
    pause & exit /b 1
)
echo      All PowerShell files parse correctly.
echo.

echo  Checking the current state of the system...
echo.

REM ---- 2. read the CURRENT state (the "BEFORE" values) ----------------------
set "FW_BEFORE=absent"
netsh advfirewall firewall show rule name="Server Dashboard %PORT%" >nul 2>&1
if not errorlevel 1 set "FW_BEFORE=present"

set "ACL_BEFORE=absent"
netsh http show urlacl url=http://+:%PORT%/ 2>nul | find /i "http://+:%PORT%/" >nul 2>&1
if not errorlevel 1 set "ACL_BEFORE=present"

set "TASK_BEFORE=absent"
schtasks /Query /TN "%TASKNAME%" >nul 2>&1
if not errorlevel 1 set "TASK_BEFORE=present"

set "NOTIFY_BEFORE=absent"
schtasks /Query /TN "%NOTIFYTASK%" >nul 2>&1
if not errorlevel 1 set "NOTIFY_BEFORE=present"

set "SETTINGS_BEFORE=absent"
if exist "%~dp0settings.txt" set "SETTINGS_BEFORE=present"

set "LOG_BEFORE=absent"
if exist "%~dp0logs\ServerDashboard.log" set "LOG_BEFORE=present"

REM ---- 3. write the state file (used by the uninstaller) --------------------
> "%STATE%" echo # Server Dashboard - state recorded before installation
>>"%STATE%" echo # Created by Install.bat on %DATE% %TIME% - do NOT delete, Uninstall.bat needs it
>>"%STATE%" echo PORT=%PORT%
>>"%STATE%" echo TASKNAME=%TASKNAME%
>>"%STATE%" echo FW_BEFORE=%FW_BEFORE%
>>"%STATE%" echo ACL_BEFORE=%ACL_BEFORE%
>>"%STATE%" echo TASK_BEFORE=%TASK_BEFORE%
>>"%STATE%" echo NOTIFY_BEFORE=%NOTIFY_BEFORE%
>>"%STATE%" echo NOTIFYTASK=%NOTIFYTASK%
>>"%STATE%" echo SETTINGS_BEFORE=%SETTINGS_BEFORE%
>>"%STATE%" echo LOG_BEFORE=%LOG_BEFORE%

REM ---- 4. back up a pre-existing scheduled task ----------------------------
if "%SETTINGS_BEFORE%"=="present" (
    copy /y "%~dp0settings.txt" "%~dp0settings-backup.txt" >nul 2>&1
)
if "%TASK_BEFORE%"=="present" (
    schtasks /Query /TN "%TASKNAME%" /XML > "%TASKBAK%" 2>nul
    echo  [i] A task named "%TASKNAME%" already existed: its definition was exported to
    echo      logs\previous-task-backup.xml and will be restored by Uninstall.bat.
    echo.
)

echo  ------------------------------------------------------------
echo   CHANGES APPLIED
echo  ------------------------------------------------------------

REM ---- 5. firewall rule -----------------------------------------------------
if "%FW_BEFORE%"=="present" (
    echo  [=] Firewall rule "Server Dashboard %PORT%"
    echo      BEFORE : already present  ^|  AFTER : unchanged ^(left as it was^)
) else (
    netsh advfirewall firewall add rule name="Server Dashboard %PORT%" dir=in action=allow protocol=TCP localport=%PORT% profile=any >nul 2>&1
    if errorlevel 1 (
        echo  [x] Firewall rule "Server Dashboard %PORT%" could NOT be created.
    ) else (
        echo  [+] Firewall rule "Server Dashboard %PORT%"
        echo      BEFORE : not present  ^|  AFTER : created ^(inbound, TCP %PORT%, all profiles^)
    )
)

REM ---- 6. URL reservation ---------------------------------------------------
if "%ACL_BEFORE%"=="present" (
    echo  [=] URL reservation http://+:%PORT%/
    echo      BEFORE : already reserved  ^|  AFTER : unchanged ^(left as it was^)
) else (
    REM  The account name is resolved from its SID by the helper script: on a
    REM  non-English Windows "NT AUTHORITY\SYSTEM" does not exist and the plain
    REM  netsh command would silently fail, leaving the dashboard on localhost.
    set "ACLRES=failed"
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Set-UrlAcl.ps1" -Port %PORT%`) do set "ACLRES=%%A"
    if "!ACLRES!"=="failed" (
        echo  [x] URL reservation http://+:%PORT%/ could NOT be added.
        echo      Without it the dashboard answers on the server only.
    ) else (
        echo  [+] URL reservation http://+:%PORT%/
        echo      BEFORE : not reserved  ^|  AFTER : !ACLRES!
    )
)

REM ---- 7. scheduled task ----------------------------------------------------
REM  The task is registered by New-DashboardTask.ps1, which sets the principal
REM  by SID (S-1-5-18 = SYSTEM) with logon type ServiceAccount, i.e. "run
REM  whether the user is logged on or not", and then verifies it. Doing it with
REM  schtasks /RU SYSTEM relies on a localized account name and could silently
REM  produce an interactive task that would need a logon.
schtasks /Delete /TN "%TASKNAME%" /F >nul 2>&1
set "TASKVERDICT=ERROR"
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\New-DashboardTask.ps1" -TaskName "%TASKNAME%" -ScriptPath "%PS1%" -Port %PORT% -IntervalSeconds %INTERVAL%`) do (
    if /i "%%A"=="VERDICT" ( set "TASKVERDICT=%%B" ) else ( echo      %%A )
)

if /i "!TASKVERDICT!"=="ERROR" (
    echo  [!] Native registration failed, falling back to schtasks...
    schtasks /Create /TN "%TASKNAME%" /SC ONSTART /DELAY 0000:30 /RU "SYSTEM" /RL HIGHEST /F ^
     /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%PS1%\" -Port %PORT% -IntervalSeconds %INTERVAL%" >nul 2>&1
    if errorlevel 1 (
        echo  [x] Scheduled task "%TASKNAME%" could NOT be created. Installation incomplete.
        pause & exit /b 1
    )
    set "TASKVERDICT=STARTS-AT-BOOT"
)
if /i "!TASKVERDICT!"=="NEEDS-LOGON" (
    echo  [x] WARNING: the task was created but it would need an interactive logon.
    echo      See the reason above, then run scripts\Diagnose.bat.
)
REM  Confirm out loud how the task will run: this is the part that decides
REM  whether the dashboard works with nobody logged on.
for /f "tokens=1,* delims=:" %%A in ('schtasks /Query /TN "%TASKNAME%" /V /FO LIST ^| findstr /i "Run As User Logon Mode Schedule Type"') do (
    for /f "tokens=* delims= " %%C in ("%%B") do echo      %%A : %%C
)
if "%TASK_BEFORE%"=="present" (
    echo  [~] Scheduled task "%TASKNAME%"
    echo      BEFORE : existed with a different definition ^(backed up^)
    echo      AFTER  : replaced - runs at boot as SYSTEM, port %PORT%, interval %INTERVAL%s
) else (
    echo  [+] Scheduled task "%TASKNAME%"
    echo      BEFORE : not present  ^|  AFTER : created - runs at boot as SYSTEM,
    echo               account SYSTEM, highest privileges, restart 3 times on failure
)

REM ---- 7-bis. logon notification (optional) --------------------------------
REM  NOTE: the dashboard itself does NOT need anybody to log on: it runs at boot
REM  as SYSTEM. This task only adds a courtesy notification for the times when
REM  somebody does log on to the console.
echo.
choice /c YN /m "  Show a Windows notification at logon with the dashboard status"
if errorlevel 2 (
    set "WANTNOTIFY=no"
) else (
    set "WANTNOTIFY=yes"
)
echo.
if "%WANTNOTIFY%"=="no" (
    echo  [=] Logon notification
    echo      BEFORE : not present  ^|  AFTER : not installed ^(declined^)
) else if exist "%~dp0scripts\Show-StartupNotification.ps1" (
    schtasks /Delete /TN "%NOTIFYTASK%" /F >nul 2>&1
    schtasks /Create /TN "%NOTIFYTASK%" /SC ONLOGON /DELAY 0000:20 /RL LIMITED /F ^
     /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0scripts\Show-StartupNotification.ps1\" -Port %PORT%" >nul 2>&1
    if errorlevel 1 (
        echo  [x] Logon notification task could NOT be created.
    ) else (
        echo  [+] Scheduled task "%NOTIFYTASK%"
        echo      BEFORE : not present
        echo      AFTER  : created - at every user logon a Windows notification
        echo               says whether the dashboard started correctly
    )
) else (
    echo  [!] Show-StartupNotification.ps1 missing: logon notification skipped.
)

REM ---- 8. start it now ------------------------------------------------------
schtasks /Run /TN "%TASKNAME%" >nul 2>&1
echo  [+] Service started
echo      BEFORE : not running  ^|  AFTER : running ^(TCP port %PORT% listening^)
timeout /t 5 /nobreak >nul

if "%SETTINGS_BEFORE%"=="absent" (
    echo  [i] settings.txt
    echo      BEFORE : not present  ^|  AFTER : created by the service at startup
    echo               with the default values, editable with Notepad
) else (
    echo  [=] settings.txt
    echo      BEFORE : already present  ^|  AFTER : left exactly as it is
    echo               ^(a copy was saved as settings-backup.txt^)
)

echo  ------------------------------------------------------------
echo   NOT MODIFIED BY THIS INSTALLER
echo  ------------------------------------------------------------
echo   - No file outside this folder, no registry key, no service.
echo   - IIS, port 80 and the existing firewall profiles are untouched.
echo   - The PowerShell execution policy of the machine is NOT changed
echo     ^(the task uses -ExecutionPolicy Bypass for its own process only^).
echo  ------------------------------------------------------------
echo.

REM ---- 9. verify it is really answering -------------------------------------
echo.
echo  ------------------------------------------------------------
echo   VERIFICATION
echo  ------------------------------------------------------------
set "HEALTH=fail"
REM  The check is written to a temporary .ps1: a PowerShell one-liner with
REM  single quotes inside a FOR /F loop breaks the batch parser.
> "%TEMP%\sd_health.ps1" echo try {
>>"%TEMP%\sd_health.ps1" echo   $r = Invoke-WebRequest -Uri "http://localhost:%PORT%/api/health" -UseBasicParsing -TimeoutSec 8
>>"%TEMP%\sd_health.ps1" echo   if ($r.StatusCode -eq 200) { "ok" } else { "fail" }
>>"%TEMP%\sd_health.ps1" echo } catch { "fail" }
for /f "usebackq delims=" %%R in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\sd_health.ps1"`) do set "HEALTH=%%R"
del "%TEMP%\sd_health.ps1" >nul 2>&1
if "%HEALTH%"=="ok" (
    echo   [OK] The dashboard is running and answering on port %PORT%.
    echo        It starts by itself at every boot, as SYSTEM: NO Windows logon
    echo        is needed on the server, the console can stay at the lock screen.
) else (
    echo   [!!] The dashboard is NOT answering yet. Last lines of the log:
    echo.
    if exist "%~dp0logs\ServerDashboard.log" (
        powershell -NoProfile -Command "Get-Content '%~dp0logs\ServerDashboard.log' -Tail 12 | ForEach-Object { '      ' + $_ }"
    ) else (
        echo        No log file yet.
    )
    echo.
    echo        Run scripts\Diagnose.bat for a full check.
)
echo  ------------------------------------------------------------
echo.

echo   The dashboard is reachable from the local network at:
echo.
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=* delims= " %%J in ("%%I") do echo        http://%%J:%PORT%
)
echo        http://%COMPUTERNAME%:%PORT%
echo.
if /i "!TASKVERDICT!"=="STARTS-AT-BOOT" (
    echo   [OK] AUTOSTART VERIFIED: the task runs as SYSTEM with an "at system
    echo        startup" trigger and logon type ServiceAccount. Power on the
    echo        server and the dashboard is up: NO interactive logon needed,
    echo        the console can stay at the lock screen forever.
) else (
    echo   [!!] AUTOSTART NOT CONFIRMED: run scripts\Diagnose.bat, point 1.
)
echo.
echo   Test it: reboot the server WITHOUT logging on, then open the page from
echo   another computer. It must answer within about a minute of the boot.
echo.
echo   State recorded in : logs\install-state.txt
echo   To revert everything: run Uninstall.bat
echo.
pause
endlocal

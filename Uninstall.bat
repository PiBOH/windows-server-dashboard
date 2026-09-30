@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Server Dashboard - Uninstaller
color 0E

REM ===========================================================================
REM  Uninstall.bat
REM  Reverts every change made by Install.bat, using the values recorded in
REM  scripts\install-state.txt: anything that already existed before the
REM  installation is left exactly as it was, anything the installer created is
REM  removed.
REM  Each step prints what is changed, how, and what it was before.
REM ===========================================================================

cd /d "%~dp0"
set "STATE=%~dp0scripts\install-state.txt"
if not exist "%STATE%" if exist "%~dp0logs\install-state.txt" set "STATE=%~dp0logs\install-state.txt"
set "TASKBAK=%~dp0logs\previous-task-backup.xml"

REM ---- defaults, used when no state file is available ----------------------
set "PORT=8080"
set "TASKNAME=PiBOH Windows Server Dashboard"
set "NOTIFYTASK=PiBOH Windows Server Dashboard Notify"
set "FW_BEFORE=absent"
set "ACL_BEFORE=absent"
set "TASK_BEFORE=absent"
set "NOTIFY_BEFORE=absent"
set "SETTINGS_BEFORE=absent"
set "LOG_BEFORE=absent"

echo.
echo  ============================================================
echo    SERVER DASHBOARD - UNINSTALLER
echo  ============================================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Administrative privileges are required. Restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM ---- 1. load the recorded state ------------------------------------------
if exist "%STATE%" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%STATE%") do set "%%A=%%B"
    echo  [i] State file found: the system will be restored to how it was
    echo      before the installation.
) else (
    echo  [!] install-state.txt not found.
    echo      Falling back to the standard values ^(port %PORT%, task %TASKNAME%^):
    echo      everything the installer normally creates will be removed.
    echo.
    choice /c YN /m "  Continue"
    if errorlevel 2 ( echo  Aborted. Nothing was changed. & pause & exit /b 0 )
)
echo.
echo  ------------------------------------------------------------
echo   CHANGES REVERTED
echo  ------------------------------------------------------------

REM ---- 2. stop the running dashboard ---------------------------------------
schtasks /End /TN "%TASKNAME%" >nul 2>&1
set "KILLED=no"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:":%PORT% .*LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
    set "KILLED=yes"
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-DashboardProcess.ps1" -Port %PORT% >nul 2>&1
if "!KILLED!"=="yes" (
    echo  [-] Dashboard process
    echo      BEFORE : running and listening on TCP %PORT%  ^|  AFTER : stopped
) else (
    echo  [=] Dashboard process
    echo      BEFORE : not running  ^|  AFTER : unchanged
)

REM ---- 3. scheduled task ----------------------------------------------------
schtasks /Query /TN "%TASKNAME%" >nul 2>&1
if errorlevel 1 (
    echo  [=] Scheduled task "%TASKNAME%"
    echo      BEFORE : not present  ^|  AFTER : unchanged
) else (
    schtasks /Delete /TN "%TASKNAME%" /F >nul 2>&1
    if "!TASK_BEFORE!"=="present" (
        if exist "%TASKBAK%" (
            schtasks /Create /TN "%TASKNAME%" /XML "%TASKBAK%" /F >nul 2>&1
            if errorlevel 1 (
                echo  [x] Scheduled task "%TASKNAME%" deleted, but the previous definition
                echo      could not be restored. Backup kept in logs\previous-task-backup.xml
            ) else (
                echo  [~] Scheduled task "%TASKNAME%"
                echo      BEFORE : a task with this name existed before the installation
                echo      AFTER  : the original definition was restored from the backup
                del "%TASKBAK%" >nul 2>&1
            )
        ) else (
            echo  [-] Scheduled task "%TASKNAME%" deleted
            echo      BEFORE : existed before the installation, but no backup was found
            echo      AFTER  : removed
        )
    ) else (
        echo  [-] Scheduled task "%TASKNAME%"
        echo      BEFORE : created by the installer ^(start at boot, SYSTEM^)
        echo      AFTER  : deleted
    )
)

REM ---- 3-bis. logon notification task ---------------------------------------
schtasks /Query /TN "%NOTIFYTASK%" >nul 2>&1
if errorlevel 1 (
    echo  [=] Scheduled task "%NOTIFYTASK%"
    echo      BEFORE : not present  ^|  AFTER : unchanged
) else (
    if "!NOTIFY_BEFORE!"=="present" (
        echo  [=] Scheduled task "%NOTIFYTASK%"
        echo      BEFORE : existed before the installation  ^|  AFTER : left in place
    ) else (
        schtasks /Delete /TN "%NOTIFYTASK%" /F >nul 2>&1
        echo  [-] Scheduled task "%NOTIFYTASK%"
        echo      BEFORE : created by the installer ^(logon notification^)
        echo      AFTER  : deleted - no notification will be shown at logon
    )
)

REM ---- 4. firewall rule -----------------------------------------------------
netsh advfirewall firewall show rule name="Server Dashboard %PORT%" >nul 2>&1
if errorlevel 1 (
    echo  [=] Firewall rule "Server Dashboard %PORT%"
    echo      BEFORE : not present  ^|  AFTER : unchanged
) else (
    if "!FW_BEFORE!"=="present" (
        echo  [=] Firewall rule "Server Dashboard %PORT%"
        echo      BEFORE : already existed before the installation
        echo      AFTER  : LEFT IN PLACE on purpose ^(not created by this tool^)
    ) else (
        netsh advfirewall firewall delete rule name="Server Dashboard %PORT%" >nul 2>&1
        echo  [-] Firewall rule "Server Dashboard %PORT%"
        echo      BEFORE : inbound allow rule created by the installer
        echo      AFTER  : deleted - port %PORT% is closed again
    )
)

REM ---- 5. URL reservation ---------------------------------------------------
netsh http show urlacl url=http://+:%PORT%/ 2>nul | find /i "http://+:%PORT%/" >nul 2>&1
if errorlevel 1 (
    echo  [=] URL reservation http://+:%PORT%/
    echo      BEFORE : not reserved  ^|  AFTER : unchanged
) else (
    if "!ACL_BEFORE!"=="present" (
        echo  [=] URL reservation http://+:%PORT%/
        echo      BEFORE : already reserved before the installation
        echo      AFTER  : LEFT IN PLACE on purpose ^(not created by this tool^)
    ) else (
        netsh http delete urlacl url=http://+:%PORT%/ >nul 2>&1
        echo  [-] URL reservation http://+:%PORT%/
        echo      BEFORE : reserved for NT AUTHORITY\SYSTEM by the installer
        echo      AFTER  : removed
    )
)

REM ---- 6. settings file -----------------------------------------------------
REM  The backup lives in .config-do-not-delete-me; versions before 1.16.1
REM  left it in the package root, so both places are checked.
set "SBAK=%~dp0.config-do-not-delete-me\settings-backup.txt"
if not exist "%SBAK%" if exist "%~dp0settings-backup.txt" set "SBAK=%~dp0settings-backup.txt"
if exist "%~dp0settings.txt" (
    if "!SETTINGS_BEFORE!"=="present" (
        if exist "%SBAK%" (
            copy /y "%SBAK%" "%~dp0settings.txt" >nul 2>&1
            del "%SBAK%" >nul 2>&1
            echo  [~] settings.txt
            echo      BEFORE : existed before the installation, changed since then
            echo      AFTER  : original file restored from the settings backup
        ) else (
            echo  [=] settings.txt
            echo      BEFORE : existed before the installation  ^|  AFTER : kept as it is
        )
    ) else (
        del "%~dp0settings.txt" >nul 2>&1
        echo  [-] settings.txt
        echo      BEFORE : created by the service after the installation
        echo      AFTER  : deleted
    )
) else (
    echo  [=] settings.txt
    echo      BEFORE : not present  ^|  AFTER : unchanged
)

REM ---- 6b. password file ----------------------------------------------------
REM The optional password file is a local secret: it is removed with the rest.
set "PWDGONE=no"
if exist "%~dp0.config-do-not-delete-me\pwd" ( del /f "%~dp0.config-do-not-delete-me\pwd" >nul 2>&1 & set "PWDGONE=yes" )
if exist "%~dp0scripts\pwd" ( del /f "%~dp0scripts\pwd" >nul 2>&1 & set "PWDGONE=yes" )
if exist "%~dp0pwd" ( del /f "%~dp0pwd" >nul 2>&1 & set "PWDGONE=yes" )
if "%PWDGONE%"=="yes" (
    echo  [-] pwd
    echo      BEFORE : the optional password file
    echo      AFTER  : deleted
) else (
    echo  [=] pwd
    echo      BEFORE : not present  ^|  AFTER : unchanged
)

REM ---- 7. log file ----------------------------------------------------------
if exist "%~dp0logs\ServerDashboard-*.log" (
    if "!LOG_BEFORE!"=="present" (
        echo  [=] the log files
        echo      BEFORE : already existed  ^|  AFTER : kept
    ) else (
        echo.
        choice /c YN /m "  Delete the log files in logs\ as well"
        if errorlevel 2 (
            echo  [=] the log files : kept on request
        ) else (
            del "%~dp0logs\ServerDashboard-*.log" >nul 2>&1
            echo  [-] logs\ServerDashboard-*.log (one file per day)
            echo      BEFORE : written by the service  ^|  AFTER : deleted
        )
    )
)

REM ---- 8. state file --------------------------------------------------------
if exist "%STATE%" (
    attrib -h -r "%STATE%" >nul 2>&1
    del /f "%STATE%" >nul 2>&1
    echo  [-] install-state.txt
    echo      BEFORE : held the pre-installation state  ^|  AFTER : deleted
)

REM ---- 8-bis. secrets folder ------------------------------------------------
REM  .config-do-not-delete-me is removed only when it is empty: its whole
REM  content (pwd, settings-backup.txt) has been handled above.
if exist "%~dp0.config-do-not-delete-me" (
    rmdir "%~dp0.config-do-not-delete-me" >nul 2>&1
    if not exist "%~dp0.config-do-not-delete-me" (
        echo  [-] .config-do-not-delete-me
        echo      BEFORE : empty after removing its files  ^|  AFTER : deleted
    )
)

echo  ------------------------------------------------------------
echo   NOT TOUCHED
echo  ------------------------------------------------------------
echo   - The program files ^(ServerDashboard.ps1, lang\, .bat, docs^) are kept:
echo     delete this folder manually if you no longer need them.
echo   - No registry key, service or system setting was ever modified,
echo     so nothing else needs to be restored.
echo  ------------------------------------------------------------
echo.
echo   Uninstall completed. The server is back to its pre-installation state.
echo.
pause
endlocal

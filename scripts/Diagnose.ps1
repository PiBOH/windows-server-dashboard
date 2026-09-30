<#
    Diagnose.ps1
    ---------------------------------------------------------------------------
    Read-only diagnostics for the Server Dashboard: it changes nothing.
    Answers the usual question: why is the dashboard not reachable, and why
    does it look like it only works after logging on to the server?

    Run it through Diagnose.bat (which elevates), or directly:
        powershell -ExecutionPolicy Bypass -File Diagnose.ps1 -Port 8080
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [string]$TaskName = 'PiBOH Windows Server Dashboard'
)

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = if ((Split-Path -Leaf $scriptDir) -eq 'scripts') { Split-Path -Parent $scriptDir } else { $scriptDir }
$issues = New-Object System.Collections.ArrayList

function Head($n, $t) {
    Write-Host ''
    Write-Host ('  ' + ('-' * 66)) -ForegroundColor DarkGray
    Write-Host ("   $n. $t") -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * 66)) -ForegroundColor DarkGray
}
function Ok($t)   { Write-Host "   [OK] $t" -ForegroundColor Green }
function Bad($t)  { Write-Host "   [X]  $t" -ForegroundColor Red;    [void]$issues.Add($t) }
function Warn($t) { Write-Host "   [!]  $t" -ForegroundColor Yellow; [void]$issues.Add($t) }
function Info($t) { Write-Host "        $t" -ForegroundColor Gray }

Write-Host ''
Write-Host '  ==================================================================' -ForegroundColor White
Write-Host '    SERVER DASHBOARD - DIAGNOSTICS' -ForegroundColor White
Write-Host '  ==================================================================' -ForegroundColor White
Write-Host ("   Folder : $root")
Write-Host ("   Port   : $Port")
Write-Host ("   Time   : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host ("   Admin  : " + $(if ($admin) { 'yes' } else { 'no (some checks will be limited)' }))

# ---------------------------------------------------------------- 1. task
Head 1 'SCHEDULED TASK'
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Bad "The task '$TaskName' does not exist: nothing will start at boot."
    Info 'Fix: run Install.bat as administrator.'
} else {
    $inf = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    $user = $task.Principal.UserId
    $logonType = $task.Principal.LogonType
    $trigger = ($task.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ', '
    Info ("State        : " + $task.State)
    Info ("Run as user  : " + $user)
    Info ("Logon type   : " + $logonType)
    Info ("Trigger      : " + $trigger)
    Info ("Last run     : " + $inf.LastRunTime)
    Info ("Last result  : " + $inf.LastTaskResult)
    Info ("Next run     : " + $inf.NextRunTime)

    if ($user -match '(?i)system') { Ok 'It runs as SYSTEM: no logon is needed.' }
    else { Bad "It runs as '$user', not SYSTEM: it will start only when that user logs on." }

    if ("$logonType" -match '(?i)ServiceAccount|S4U|Password') { Ok 'Logon type allows running with nobody logged on.' }
    else { Bad "Logon type '$logonType' requires an interactive session." }

    if ($trigger -match '(?i)Boot') { Ok 'It is triggered at system startup.' }
    else { Bad "Trigger is '$trigger', not 'at startup'." }

    $bootOk = ($user -match '(?i)system|S-1-5-18') -and
              ("$logonType" -match '(?i)ServiceAccount|S4U|Password') -and
              ($trigger -match '(?i)Boot') -and $task.Settings.Enabled
    Write-Host ''
    if ($bootOk) {
        Write-Host '   >>> STARTS WITHOUT INTERACTIVE LOGON : YES' -ForegroundColor Green
        Write-Host '       Power on the server and the dashboard is up by itself.' -ForegroundColor Green
    } else {
        Write-Host '   >>> STARTS WITHOUT INTERACTIVE LOGON : NO' -ForegroundColor Red
        Write-Host '       Fix it without reinstalling:' -ForegroundColor Red
        Write-Host ('       powershell -ExecutionPolicy Bypass -File scripts\New-DashboardTask.ps1 ' +
                    '-ScriptPath "' + (Join-Path $root 'scripts\ServerDashboard.ps1') + '" -Port ' + $Port) -ForegroundColor Red
        [void]$issues.Add('the task would need an interactive logon')
    }

    if ($inf.LastTaskResult -ne 0 -and $null -ne $inf.LastTaskResult) {
        Warn ("Last result is " + $inf.LastTaskResult + ' (0 = success). See the log at point 7.')
    }
}

# ---------------------------------------------------------------- 2. process
Head 2 'PROCESS'
$procs = @(Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" |
           Where-Object { $_.CommandLine -like '*ServerDashboard.ps1*' })
if (-not $procs.Count) {
    Bad 'No ServerDashboard.ps1 process is running.'
} else {
    Ok ("$($procs.Count) process(es) running.")
    foreach ($p in $procs) {
        $o = $p.GetOwner()
        Info ("PID $($p.ProcessId) - account: $($o.Domain)\$($o.User)")
        if ("$($o.User)" -notmatch '(?i)system') {
            Warn 'It is NOT running as SYSTEM: it will stop when that user logs off.'
        }
    }
}

# ---------------------------------------------------------------- 3. port
Head 3 "TCP PORT $Port"
$conns = @(netstat -ano | Select-String ":$Port\s" | Select-String 'LISTENING')
if (-not $conns.Count) {
    Bad "Nobody is listening on port $Port."
} else {
    foreach ($c in $conns) { Info ($c.ToString().Trim()) }
    $onlyLocal = -not (@($conns | Where-Object { $_ -match '0\.0\.0\.0:' -or $_ -match '\[::\]:' }).Count)
    if ($onlyLocal) {
        Bad 'Bound to 127.0.0.1 only: it answers on the server but NOT from the LAN.'
        Info 'This is the classic "it works only after I log on" symptom.'
        Info 'Fix: run Install.bat as administrator (it adds the URL reservation).'
    } else {
        Ok 'Listening on all addresses: reachable from the network.'
    }
}

# ---------------------------------------------------------------- 4. urlacl + firewall
Head 4 'URL RESERVATION AND FIREWALL'
$acl = (netsh http show urlacl url=("http://+:$Port/") 2>$null) -join "`n"
if ($acl -match [regex]::Escape("http://+:$Port/")) {
    Ok "URL reservation present for http://+:$Port/"
    foreach ($l in ($acl -split "`n" | Where-Object { $_ -match 'User|Listen' })) { Info $l.Trim() }
} else {
    Bad "No URL reservation for http://+:$Port/"
    $acct = $null
    try {
        $acct = (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
                ).Translate([System.Security.Principal.NTAccount]).Value
    } catch { }
    if ($acct -and $acct -ne 'NT AUTHORITY\SYSTEM') {
        Info "On this Windows the SYSTEM account is called '$acct', not 'NT AUTHORITY\SYSTEM':"
        Info 'that is why the plain netsh command found in most guides fails here.'
    }
    Info 'Fix (handles the localized name by itself):'
    Info "     powershell -ExecutionPolicy Bypass -File scripts\Set-UrlAcl.ps1 -Port $Port"
    if ($acct) { Info "  or netsh http add urlacl url=http://+:$Port/ user=`"$acct`"" }
}
$fw = (netsh advfirewall firewall show rule name=("Server Dashboard $Port") 2>$null) -join "`n"
if ($fw -match '(?i)Rule Name|Regola') { Ok "Firewall rule 'Server Dashboard $Port' present." }
else { Bad "Firewall rule 'Server Dashboard $Port' missing: the LAN cannot reach the port." }

# ---------------------------------------------------------------- 5. http answer
Head 5 'HTTP ANSWER'
try {
    $r = Invoke-WebRequest -Uri "http://localhost:$Port/api/health" -UseBasicParsing -TimeoutSec 8
    Ok ("localhost answers: " + $r.Content)
} catch {
    Bad ("localhost does not answer: " + $_.Exception.Message)
}
$ip = (Get-WmiObject Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' |
       ForEach-Object { $_.IPAddress } |
       Where-Object { $_ -and $_ -notmatch ':' -and $_ -ne '127.0.0.1' } | Select-Object -First 1)
if ($ip) {
    try {
        $r2 = Invoke-WebRequest -Uri "http://${ip}:$Port/api/health" -UseBasicParsing -TimeoutSec 8
        Ok ("http://${ip}:$Port answers: " + $r2.Content)
    } catch {
        Bad ("http://${ip}:$Port does not answer: " + $_.Exception.Message)
        Info 'If localhost answers but this does not, it is the URL reservation (point 4).'
    }
}

# ---------------------------------------------------------------- 5-bis. disks
Head '5b' 'DISKS AS THE DASHBOARD SEES THEM'
try {
    $st = Invoke-RestMethod -Uri "http://localhost:$Port/api/stats" -TimeoutSec 10
    $dk = $st.Current.Disks
    if (-not $dk) {
        Warn 'The payload carries no disk section yet (the collector may have just started).'
    } else {
        $phys = @($dk.Physical)
        $oth  = @($dk.Other)
        if (-not $phys.Count) {
            Bad 'No physical disk detected: everything will show up under "other volumes".'
            Info 'Check Win32_DiskDrive:  Get-CimInstance Win32_DiskDrive | Select Model,Index'
        } else {
            Ok ("$($phys.Count) physical disk(s) detected:")
            foreach ($d in $phys) {
                $letters = @($d.Volumes | ForEach-Object { $_.Drive }) -join ' '
                if (-not $letters) { $letters = '(no volume matched!)' }
                Info ("{0,-34} {1,8} GB  kind={2,-9} -> {3}" -f
                      $d.Model, $d.SizeGB, $d.Kind, $letters)
            }
            $noVol = @($phys | Where-Object { -not @($_.Volumes).Count -and $_.Kind -eq 'Fixed' })
            if ($noVol.Count) {
                Warn ("$($noVol.Count) fixed disk(s) with no volume matched: see the log for the mapping fallback used.")
            }
        }
        if ($oth.Count) {
            Info ("Other volumes: " + (@($oth | ForEach-Object { "$($_.Drive) [$($_.Type)]" }) -join ' '))
            $fixedOther = @($oth | Where-Object { $_.Type -eq 'Fixed' })
            if ($fixedOther.Count) {
                Bad ("$($fixedOther.Count) LOCAL volume(s) ended up in 'other volumes' instead of on their disk.")
                Info 'The log line starting with "disks:" says which mapping was attempted.'
            }
        } else {
            Ok 'No stray volume: every local volume is attached to its physical disk.'
        }
    }
} catch {
    Info ('Could not read /api/stats: ' + $_.Exception.Message)
}

# ---------------------------------------------------------------- 6. files
Head 6 'FILES'
foreach ($f in @('scripts\ServerDashboard.ps1','lang\en-US.xml','logs')) {
    if (Test-Path (Join-Path $root $f)) { Ok $f } else { Bad "$f is MISSING" }
}
if (Test-Path (Join-Path $root 'settings.txt')) { Ok 'settings.txt' }
else { Info 'settings.txt absent: the defaults will be used and the file recreated.' }
$pwdFile = Join-Path $root '.config-do-not-delete-me\pwd'
if (-not (Test-Path $pwdFile)) { $pwdFile = Join-Path $root 'pwd' }             # 1.16.0 kept it here
if (-not (Test-Path $pwdFile)) { $pwdFile = Join-Path $root 'scripts\pwd' }    # first 1.16.0 builds
if (Test-Path $pwdFile) {
    $mode = 'total'
    try {
        foreach ($ln in (Get-Content (Join-Path $root 'settings.txt') -ErrorAction SilentlyContinue)) {
            if ("$ln" -match '^\s*password_mode\s*=\s*(\S+)') { if ($Matches[1] -match '(?i)^part') { $mode = 'partial' } }
        }
    } catch { }
    $has = $false
    try { foreach ($ln in (Get-Content $pwdFile)) { if ("$ln".Trim()) { $has = $true; break } } } catch { }
    if ($has) { Ok "pwd file: a password is set ($mode mode)" }
    else { Info 'pwd file present but empty: no password, the dashboard is open' }
} else {
    Info 'pwd file absent: no password, the dashboard is open'
    Info '(the service recreates the file empty at its next start)'
}
if (Test-Path (Join-Path $root 'scripts\Set-Password.ps1')) { Ok 'scripts\Set-Password.ps1' }
else { Info 'scripts\Set-Password.ps1 missing: Install.bat cannot ask for a password' }
if (Test-Path (Join-Path $root 'scripts\install-state.txt')) {
    Ok 'install-state.txt recorded (hidden, read-only)'
} elseif (Test-Path (Join-Path $root 'logs\install-state.txt')) {
    Info 'install-state.txt found in logs\: written by a version before 1.16.0'
} else {
    Info 'install-state.txt absent: Install.bat has not been run yet'
}
if ($root -match '(?i)\\Users\\|OneDrive') {
    Warn 'The folder is inside a user profile or OneDrive.'
    Info 'A task running as SYSTEM may not be able to read it at boot:'
    Info 'move everything to C:\ServerDashboard\ and run Install.bat again.'
} else {
    Ok 'Folder location is reachable by SYSTEM.'
}

# ---------------------------------------------------------------- 6-bis. notification
Head '6b' 'LOGON NOTIFICATION'
$nt = Get-ScheduledTask -TaskName 'PiBOH Windows Server Dashboard Notify' -ErrorAction SilentlyContinue
if (-not $nt) {
    Info 'The task "PiBOH Windows Server Dashboard Notify" is not installed (it is optional).'
    Info 'Install.bat asks about it; you can also run scripts\Test-Notification.bat.'
} else {
    Ok 'Task "PiBOH Windows Server Dashboard Notify" present.'
    $ni = Get-ScheduledTaskInfo -TaskName 'ServerDashboard Notify' -ErrorAction SilentlyContinue
    Info ("Last run    : " + $ni.LastRunTime)
    Info ("Last result : " + $ni.LastTaskResult)
    if ($ni.LastTaskResult -ne 0 -and $null -ne $ni.LastTaskResult) {
        Warn 'The notification task ended with an error: see the newest ServerDashboard-notify-*.log'
    }
}
$nlog = Join-Path $root ("logs\ServerDashboard-notify-" + (Get-Date -Format 'yyyy-MM-dd') + ".log")
if (Test-Path $nlog) {
    Info 'Last lines of the newest notification log:'
    Get-Content $nlog -Tail 8 | ForEach-Object { Write-Host ("        " + $_) -ForegroundColor DarkGray }
} else {
    Info 'No notification log yet: run scripts\Test-Notification.bat to try it now.'
}

# ---------------------------------------------------------------- 7. log
Head 7 'LAST LINES OF THE LOG'
# The log is rotated daily: show the newest file of the last 14 days.
$logDir2 = Join-Path $root 'logs'
$logs = @(Get-ChildItem -Path $logDir2 -Filter 'ServerDashboard-*.log' -File -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending)
if ($logs.Count) {
    Info ("Newest log: " + $logs[0].Name + " (" + $logs.Count + " file(s) kept, one per day)")
    Get-Content $logs[0].FullName -Tail 20 | ForEach-Object { Write-Host ("   " + $_) -ForegroundColor DarkGray }
} else {
    Info 'No log file in logs\: either it never started, or logging = no.'
}

# ---------------------------------------------------------------- summary
Write-Host ''
Write-Host ('  ' + ('=' * 66)) -ForegroundColor White
if ($issues.Count -eq 0) {
    Write-Host '   RESULT: everything looks fine.' -ForegroundColor Green
    Write-Host '   The dashboard runs at boot as SYSTEM: no Windows logon needed.' -ForegroundColor Green
} else {
    Write-Host ("   RESULT: " + $issues.Count + ' problem(s) found:') -ForegroundColor Yellow
    $i = 1
    foreach ($p in $issues) { Write-Host ("     $i. $p") -ForegroundColor Yellow; $i++ }
    Write-Host ''
    Write-Host '   Most of them are fixed by running Install.bat as administrator.' -ForegroundColor Yellow
}
Write-Host ('  ' + ('=' * 66)) -ForegroundColor White
Write-Host ''

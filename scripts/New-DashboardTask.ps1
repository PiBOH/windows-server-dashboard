<#
    New-DashboardTask.ps1
    ---------------------------------------------------------------------------
    Registers the scheduled task that starts the dashboard AT BOOT, with nobody
    logged on, and then verifies that it really is configured that way.

    Why a dedicated script instead of a schtasks command line: schtasks takes
    the account by name (/RU SYSTEM), and on a localized Windows the well known
    accounts have localized names, so the task can silently end up as an
    interactive task of the current user - which would need a logon. Here the
    principal is set by SID (S-1-5-18 = SYSTEM), which is identical on every
    language, with LogonType ServiceAccount: "run whether the user is logged on
    or not", no password, no session.

    It prints one line: VERDICT=... so the caller can react.
#>
[CmdletBinding()]
param(
    [string]$TaskName = 'PiBOH Windows Server Dashboard',
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [int]$Port = 8080,
    [double]$IntervalSeconds = 5,
    [int]$BootDelaySeconds = 30
)

$ErrorActionPreference = 'Stop'

function Out-Verdict($v, $msg) {
    Write-Output "VERDICT=$v"
    if ($msg) { Write-Output $msg }
}

try {
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Port {1} -IntervalSeconds {2}' -f `
           $ScriptPath, $Port, ([double]$IntervalSeconds).ToString($inv)

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg `
                                      -WorkingDirectory (Split-Path -Parent $ScriptPath)

    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = ('PT{0}S' -f $BootDelaySeconds)      # let the network settle

    # S-1-5-18 = SYSTEM on every localized Windows.
    # LogonType ServiceAccount = "run whether the user is logged on or not".
    $principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -StartWhenAvailable -MultipleInstances IgnoreNew `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 99 `
                    -RestartInterval (New-TimeSpan -Minutes 1)
    $settings.DisallowStartOnRemoteAppSession = $false
    $settings.RunOnlyIfNetworkAvailable       = $false
    $settings.IdleSettings.StopOnIdleEnd      = $false
    $settings.Enabled                         = $true

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
                           -Principal $principal -Settings $settings -Force | Out-Null

    # Give the task a description, visible in Task Scheduler: an administrator
    # opening the library must understand at a glance what this entry is.
    try {
        $xml = Export-ScheduledTask -TaskName $TaskName
        if ($xml -notmatch '<Description>') {
            $desc = @(
                'Read-only web dashboard for this server: CPU, memory, disks, network,',
                'processes, services and event log, published on port 8080.',
                'It is a PowerShell script, not a Microsoft component: see the folder',
                'shown below and run scripts\Diagnose.bat for a full check.',
                'Starts at boot as SYSTEM, no logon needed. Remove it with Uninstall.bat.'
            ) -join ' '
            if ($xml -match '</RegistrationInfo>') {
                $xml = $xml -replace '</RegistrationInfo>', ('<Description>' + $desc + '</Description></RegistrationInfo>')
            } else {
                $xml = $xml -replace '</Task>', ('<RegistrationInfo><Description>' + $desc + '</Description></RegistrationInfo></Task>')
            }
            Register-ScheduledTask -TaskName $TaskName -Xml $xml -Force | Out-Null
        }
    } catch { }

    # ---------------- verification ----------------
    $t = Get-ScheduledTask -TaskName $TaskName
    $problems = @()

    $sid = ''
    try {
        $sid = (New-Object System.Security.Principal.NTAccount($t.Principal.UserId)
               ).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch { $sid = $t.Principal.UserId }
    if ($sid -ne 'S-1-5-18' -and $t.Principal.UserId -notmatch '(?i)system|S-1-5-18') {
        $problems += "the task runs as '$($t.Principal.UserId)' instead of SYSTEM"
    }
    if ("$($t.Principal.LogonType)" -notmatch '(?i)ServiceAccount|Password|S4U') {
        $problems += "logon type is '$($t.Principal.LogonType)': it would need an interactive session"
    }
    if (-not (@($t.Triggers | Where-Object { $_.CimClass.CimClassName -match 'Boot' }).Count)) {
        $problems += 'there is no "at system startup" trigger'
    }
    if (-not $t.Settings.Enabled) { $problems += 'the task is disabled' }

    if ($problems.Count) {
        Out-Verdict 'NEEDS-LOGON' ("Problems: " + ($problems -join '; '))
        exit 2
    }

    Out-Verdict 'STARTS-AT-BOOT' ("Principal: $($t.Principal.UserId) / $($t.Principal.LogonType) - trigger: at startup, delay ${BootDelaySeconds}s")
    exit 0
}
catch {
    Out-Verdict 'ERROR' $_.Exception.Message
    exit 1
}

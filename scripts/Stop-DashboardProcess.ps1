<#
    Stop-DashboardProcess.ps1
    Stops every PowerShell host running ServerDashboard.ps1, and anything left
    listening on the dashboard port. Used by Stop-Dashboard.bat, Uninstall.bat
    and by the updater (before installing a new version): keeping it in a real
    script file avoids the quoting problems that inline PowerShell one-liners
    cause inside a batch file. This process is never stopped, not even when its
    own command line mentions ServerDashboard.ps1 (the updater runs the same
    script with -UpdateNow, and killing it would abort the update).
#>
[CmdletBinding()]
param([int]$Port = 8080)

$ErrorActionPreference = 'SilentlyContinue'
$killed = 0

# The command line of THIS process contains ServerDashboard.ps1 too when the
# script is started with -UpdateNow (that is how an update stops the old
# instance before installing). Killing it would abort the update in the middle
# of the install, so the current process is never in the list.
$self = $PID
foreach ($p in @(Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" |
                 Where-Object { $_.CommandLine -like '*ServerDashboard.ps1*' -and
                                [int]$_.ProcessId -ne $self })) {
    Stop-Process -Id $p.ProcessId -Force
    $killed++
}

foreach ($c in @(netstat -ano | Select-String ":$Port\s" | Select-String 'LISTENING')) {
    $procId = ($c.ToString().Trim() -split '\s+')[-1]
    if ($procId -match '^\d+$' -and [int]$procId -gt 4 -and [int]$procId -ne $self) {
        Stop-Process -Id ([int]$procId) -Force
        $killed++
    }
}

if ($killed) { Write-Output "stopped $killed" } else { Write-Output 'nothing to stop' }

<#
    Stop-DashboardProcess.ps1
    Stops every PowerShell host running ServerDashboard.ps1, and anything left
    listening on the dashboard port. Used by Stop-Dashboard.bat and
    Uninstall.bat: keeping it in a real script file avoids the quoting problems
    that inline PowerShell one-liners cause inside a batch file.
#>
[CmdletBinding()]
param([int]$Port = 8080)

$ErrorActionPreference = 'SilentlyContinue'
$killed = 0

foreach ($p in @(Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" |
                 Where-Object { $_.CommandLine -like '*ServerDashboard.ps1*' })) {
    Stop-Process -Id $p.ProcessId -Force
    $killed++
}

foreach ($c in @(netstat -ano | Select-String ":$Port\s" | Select-String 'LISTENING')) {
    $procId = ($c.ToString().Trim() -split '\s+')[-1]
    if ($procId -match '^\d+$' -and [int]$procId -gt 4) {
        Stop-Process -Id ([int]$procId) -Force
        $killed++
    }
}

if ($killed) { Write-Output "stopped $killed" } else { Write-Output 'nothing to stop' }

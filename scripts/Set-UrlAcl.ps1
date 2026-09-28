<#
    Set-UrlAcl.ps1
    ---------------------------------------------------------------------------
    Adds the URL reservation the dashboard needs in order to listen on every
    address (http://+:PORT/) while running as SYSTEM.

    Why a dedicated script: the usual command

        netsh http add urlacl url=http://+:8080/ user="NT AUTHORITY\SYSTEM"

    fails on every non-English Windows, because the well known account is
    localized ("AUTORITA NT\SISTEMA" in Italian, "NT-AUTORITAT\SYSTEM" in
    German, and so on). When that command fails, nothing is reserved, the
    dashboard cannot bind the public prefix and falls back to localhost: the
    page then answers on the server only, which looks exactly like "the
    dashboard is not shared on the network".

    Here the account name is resolved from its SID (S-1-5-18), so it is always
    correct, with two further fallbacks: the raw SDDL and Everyone (S-1-1-0).
#>
[CmdletBinding()]
param([int]$Port = 8080)

$ErrorActionPreference = 'SilentlyContinue'
$url = "http://+:$Port/"

function Test-Reservation {
    $out = (netsh http show urlacl url=$url 2>$null) -join "`n"
    return ($out -match [regex]::Escape($url))
}

function Resolve-Sid([string]$sid) {
    try {
        return (New-Object System.Security.Principal.SecurityIdentifier($sid)
               ).Translate([System.Security.Principal.NTAccount]).Value
    } catch { return $null }
}

if (Test-Reservation) {
    Write-Output "already-present"
    exit 0
}

$system   = Resolve-Sid 'S-1-5-18'      # localized name of NT AUTHORITY\SYSTEM
$everyone = Resolve-Sid 'S-1-1-0'       # localized name of Everyone

$attempts = @()
if ($system)   { $attempts += @{ Label = "user=$system";   Args = @("user=$system") } }
$attempts     += @{ Label = 'sddl=S-1-5-18'; Args = @('sddl=D:(A;;GX;;;S-1-5-18)') }
if ($everyone) { $attempts += @{ Label = "user=$everyone"; Args = @("user=$everyone") } }
$attempts     += @{ Label = 'sddl=Everyone'; Args = @('sddl=D:(A;;GX;;;S-1-1-0)') }

foreach ($a in $attempts) {
    $null = netsh http add urlacl url=$url @($a.Args) 2>&1
    if (Test-Reservation) {
        Write-Output ("added (" + $a.Label + ")")
        exit 0
    }
}

Write-Output "failed"
exit 1

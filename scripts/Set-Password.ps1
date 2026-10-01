#requires -version 4.0
<#
    Set-Password.ps1
    Writes the dashboard password file
    (.config-do-not-delete-me\pwd, at the root of the package).

    The first non-empty line of the file is the password; an empty file
    means "no password". The dashboard picks the change up within ten
    seconds, no restart needed. The file is a local secret: it never goes
    to GitHub (.gitignore) and Uninstall.bat deletes it.

    Usage (from the scripts folder):
      powershell -ExecutionPolicy Bypass -File Set-Password.ps1
          Asks for the password with masked input, twice. Enter alone =
          no password (the file is written empty).

      powershell -ExecutionPolicy Bypass -File Set-Password.ps1 -KeepExisting
          Never touches a password that is already set: this is what
          Install.bat uses, so reinstalling keeps the current password.

      powershell -ExecutionPolicy Bypass -File Set-Password.ps1 -Password x
          Sets the given password without asking ('' removes it). Without
          -Mode the script also asks what the password must protect (the
          whole page or only the server options) and writes password_mode
          into settings.txt; -Mode total|partial answers the question in
          advance, for scripted use.

    Exit codes: 0 = password set (or already set), 2 = no password,
    1 = the file could not be written.
#>
[CmdletBinding()]
param(
    [string]$Password,
    [switch]$KeepExisting,
    [string]$File,
    [string]$Mode            # total | partial: written to settings.txt
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
if ((Split-Path -Leaf $root) -eq 'scripts') { $root = Split-Path -Parent $root }
# The pwd file lives in .config-do-not-delete-me at the root of the package.
$cfgDir = Join-Path $root '.config-do-not-delete-me'
if (-not $File) {
    if (-not (Test-Path -LiteralPath $cfgDir)) {
        try { [void](New-Item -ItemType Directory -Path $cfgDir -Force) } catch { }
    }
    $File = Join-Path $cfgDir 'pwd'
}

function Get-PwdText([string]$Path) {
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return '' }
        foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop)) {
            $t = "$line".Trim()
            if ($t) { return $t }
        }
    } catch { }
    return ''
}

function Get-PasswordMode {
    # what settings.txt currently says (total when missing or unreadable)
    $settings = Join-Path $root 'settings.txt'
    try {
        if (Test-Path -LiteralPath $settings) {
            foreach ($ln in (Get-Content -LiteralPath $settings)) {
                if ("$ln" -match '^\s*password_mode\s*=\s*(\S+)') {
                    if ($Matches[1] -match '(?i)^part') { return 'partial' }
                }
            }
        }
    } catch { }
    return 'total'
}

function Set-PasswordMode([string]$NewMode) {
    # writes password_mode into settings.txt; when the file does not exist
    # yet it is created with this single key and the service completes it
    # with the full template at its first start
    if ($NewMode -ne 'total' -and $NewMode -ne 'partial') { return $false }
    $settings = Join-Path $root 'settings.txt'
    $line = 'password_mode = ' + $NewMode
    try {
        if (Test-Path -LiteralPath $settings) {
            $lines = @(Get-Content -LiteralPath $settings)
            $done = $false
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ("$($lines[$i])" -match '^\s*password_mode\s*=') { $lines[$i] = $line; $done = $true; break }
            }
            if (-not $done) { $lines += $line }
            Set-Content -LiteralPath $settings -Value $lines -Encoding UTF8
        } else {
            Set-Content -LiteralPath $settings -Value @(
                '# ServerDashboard - settings (completed with every key by the service at its first start)',
                $line
            ) -Encoding UTF8
        }
        return $true
    } catch { return $false }
}

function Read-Masked([string]$Prompt) {
    $sec = Read-Host -AsSecureString $Prompt
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try     { [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# A pwd file left somewhere by an earlier version (package root, or the
# scripts folder of the first 1.16.0 builds) is moved into the
# .config-do-not-delete-me folder first, so no password is ever lost.
foreach ($legacy in @((Join-Path $PSScriptRoot 'pwd'), (Join-Path $root 'pwd'))) {
    if ($legacy -ne $File -and (Test-Path -LiteralPath $legacy) -and -not (Test-Path -LiteralPath $File)) {
        try {
            Move-Item -LiteralPath $legacy -Destination $File -Force
            Write-Host '  [i] Existing pwd file moved into .config-do-not-delete-me'
        } catch { }
    }
}

if ($KeepExisting -and ((Get-PwdText $File) -ne '')) {
    Write-Host '  [=] Password: already set - kept as it is.'
    Write-Host ('      Current mode: ' + (Get-PasswordMode) +
                ' - change it in settings.txt (password_mode = total | partial).')
    exit 0
}

if ($PSBoundParameters.ContainsKey('Password')) {
    $pw = "$Password".Trim()
    $declined = $true
} else {
    $pw = ''
    $declined = $false
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $first = (Read-Masked 'Password (Enter alone = no password)').Trim()
        if ($first -eq '') { $declined = $true; break }
        $second = (Read-Masked 'Confirm the password').Trim()
        if ($first -eq $second) { $pw = $first; break }
        Write-Host '  [!] The two passwords do not match. Try again.'
    }
}

try {
    # UTF-8 without BOM: exactly what the dashboard reads back. An empty
    # password writes a 0-byte file.
    [System.IO.File]::WriteAllText($File, $pw)
} catch {
    Write-Host ''
    Write-Host "  [x] Could not write $File : $($_.Exception.Message)"
    Write-Host '      The dashboard will recreate the file empty at its next start.'
    exit 1
}

if ($pw -eq '') {
    if (-not $declined) {
        Write-Host '  [!] Two mismatches: NO password was set. Run this script again.'
    }
    Write-Host '  [=] Password: none (the pwd file is empty, the dashboard stays open).'
    exit 2
}
Write-Host '  [+] Password: saved to .config-do-not-delete-me\pwd.'

# What must the password protect? Asked only when a password was just set
# and the caller did not answer the question in advance with -Mode.
if (-not $Mode) {
    $ans = Read-Host 'Protect the whole page or only the server options? [W]hole page (default) / [S]erver options only'
    if ("$ans".Trim() -match '^(?i)s|server') { $Mode = 'partial' } else { $Mode = 'total' }
}
if (Set-PasswordMode $Mode) {
    Write-Host ('  [+] Password mode: ' + $Mode + ' (written to settings.txt)')
} else {
    Write-Host '  [!] Could not write password_mode to settings.txt: set it by hand.'
}
Write-Host '      The dashboard picks up both within ten seconds, no restart needed.'
exit 0


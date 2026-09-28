<#
    Show-StartupNotification.ps1
    ---------------------------------------------------------------------------
    Shown at logon by the scheduled task "ServerDashboard Notify".
    Waits for the dashboard to answer on /api/health and then tells the user,
    with a Windows notification, whether it started correctly or not.

    Three ways of showing it are tried, in order:
      1. a real Windows toast   (WinRT, Action Center)
      2. a tray balloon tip     (NotifyIcon, native Windows look)
      3. a small window drawn like a Windows 10 toast, bottom right

    The text follows the Windows display language, reading the same lang\*.xml
    files used by the dashboard.
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [int]$TimeoutSeconds = 90,
    [switch]$Test           # show the notification at once, without probing the service
)

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = if ((Split-Path -Leaf $scriptDir) -eq 'scripts') { Split-Path -Parent $scriptDir } else { $scriptDir }
$logDir = Join-Path $root 'logs'
if (-not (Test-Path $logDir)) { try { [void](New-Item -ItemType Directory -Path $logDir -Force) } catch { } }
# One file per day, like the main log: the date is in the name, so the
# rotation happens by itself at midnight.
$nlog = Join-Path $logDir ("ServerDashboard-notify-" + (Get-Date -Format 'yyyy-MM-dd') + ".log")
# housekeeping: delete the notification logs older than 14 days
try {
    $limit = (Get-Date).AddDays(-14)
    foreach ($f in @(Get-ChildItem -Path $logDir -Filter 'ServerDashboard-notify-*.log' -File -ErrorAction SilentlyContinue)) {
        if ($f.LastWriteTime -lt $limit) { Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue }
    }
} catch { }

# Small log of its own: if no notification shows up, this file says which of the
# three display methods was tried and what went wrong.
function NLog([string]$t) {
    try { Add-Content -Path $nlog -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $t) -Encoding UTF8 } catch { }
}
NLog "--- notification script started (port $Port, test=$Test) ---"


# ---------------------------------------------------------------------------
# 1. Localized strings (falls back to English)
# ---------------------------------------------------------------------------
function Get-Strings {
    $keys = @{
        notif_title     = 'Server Dashboard'
        notif_ok        = 'Dashboard started successfully'
        notif_ok_body   = 'Available at {0}'
        notif_fail      = 'Dashboard is NOT running'
        notif_fail_body = 'Check the newest logs\ServerDashboard-*.log for details'
    }
    $culture = (Get-UICulture).Name
    $candidates = @((Join-Path $root "lang\$culture.xml"))
    $base = $culture.Split('-')[0]
    foreach ($f in (Get-ChildItem (Join-Path $root "lang\$base-*.xml") -ErrorAction SilentlyContinue)) { $candidates += $f.FullName }
    $candidates += (Join-Path $root "lang\en-US.xml")
    foreach ($file in $candidates) {
        if (Test-Path $file) {
            try {
                [xml]$xml = Get-Content -Path $file -Raw -Encoding UTF8
                foreach ($k in @($keys.Keys)) {
                    $node = $xml.language.string | Where-Object { $_.key -eq $k }
                    if ($node -and $node.'#text') { $keys[$k] = $node.'#text' }
                }
                break
            } catch { }
        }
    }
    return $keys
}

# ---------------------------------------------------------------------------
# 2. Wait for the dashboard to answer
# ---------------------------------------------------------------------------
function Test-Dashboard {
    param([int]$Port, [int]$TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:$Port/api/health" -UseBasicParsing -TimeoutSec 5
            if ($r.StatusCode -eq 200) { return $true }
        } catch { }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Get-DashboardUrl {
    param([int]$Port)
    $ip = $null
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
               Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
               Select-Object -First 1).IPAddress
    } catch { }
    if (-not $ip) { $ip = $env:COMPUTERNAME }
    return "http://${ip}:$Port"
}

# ---------------------------------------------------------------------------
# 3a. Real Windows toast (Action Center)
# ---------------------------------------------------------------------------
function Show-Toast {
    param([string]$Title, [string]$Body, [bool]$Ok)
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $xmlText = @"
<toast scenario="reminder" duration="short">
  <visual><binding template="ToastGeneric">
    <text>$([System.Security.SecurityElement]::Escape($Title))</text>
    <text>$([System.Security.SecurityElement]::Escape($Body))</text>
  </binding></visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($xmlText)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
        NLog 'WinRT toast shown'
        return $true
    } catch { NLog ("WinRT toast not available: " + $_.Exception.Message); return $false }
}

# ---------------------------------------------------------------------------
# 3b. Tray balloon tip (always available, native look)
# ---------------------------------------------------------------------------
function Show-Balloon {
    param([string]$Title, [string]$Body, [bool]$Ok)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $ni = New-Object System.Windows.Forms.NotifyIcon
        $ni.Icon = [System.Drawing.SystemIcons]::Information
        $ni.BalloonTipIcon = if ($Ok) { 'Info' } else { 'Error' }
        $ni.BalloonTipTitle = $Title
        $ni.BalloonTipText = $Body
        $ni.Visible = $true
        $ni.ShowBalloonTip(10000)
        NLog 'Tray balloon shown'
        Start-Sleep -Seconds 11
        $ni.Dispose()
        return $true
    } catch { NLog ("Tray balloon failed: " + $_.Exception.Message); return $false }
}

# ---------------------------------------------------------------------------
# 3c. Fallback: a window drawn like a Windows 10 toast, bottom right
# ---------------------------------------------------------------------------
function Show-FakeToast {
    param([string]$Title, [string]$Body, [bool]$Ok)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $f = New-Object System.Windows.Forms.Form
        $f.FormBorderStyle = 'None'
        $f.ShowInTaskbar = $false
        $f.TopMost = $true
        $f.BackColor = [System.Drawing.Color]::FromArgb(32,32,32)
        $f.Size = New-Object System.Drawing.Size(364,104)
        $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $f.Location = New-Object System.Drawing.Point(($wa.Right - 380), ($wa.Bottom - 124))

        $bar = New-Object System.Windows.Forms.Panel
        $bar.Size = New-Object System.Drawing.Size(4,104)
        $bar.Location = New-Object System.Drawing.Point(0,0)
        $bar.BackColor = if ($Ok) { [System.Drawing.Color]::FromArgb(63,185,80) } else { [System.Drawing.Color]::FromArgb(248,81,73) }
        $f.Controls.Add($bar)

        $lt = New-Object System.Windows.Forms.Label
        $lt.Text = $Title
        $lt.ForeColor = [System.Drawing.Color]::White
        $lt.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
        $lt.Location = New-Object System.Drawing.Point(18,14)
        $lt.Size = New-Object System.Drawing.Size(330,24)
        $f.Controls.Add($lt)

        $lb = New-Object System.Windows.Forms.Label
        $lb.Text = $Body
        $lb.ForeColor = [System.Drawing.Color]::FromArgb(205,205,205)
        $lb.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $lb.Location = New-Object System.Drawing.Point(18,42)
        $lb.Size = New-Object System.Drawing.Size(330,44)
        $f.Controls.Add($lb)

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 9000
        $timer.Add_Tick({ $f.Close() })
        $timer.Start()
        $f.Add_Click({ $f.Close() })
        NLog 'Windows 10 style window shown'
        [void]$f.ShowDialog()
        return $true
    } catch { NLog ("Fallback window failed: " + $_.Exception.Message); return $false }
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
# The task starts a few seconds after logon: wait for the shell to be ready,
# otherwise a balloon tip is posted into a desktop that cannot display it yet.
$shellWait = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $shellWait) {
    if (@(Get-Process -Name explorer -ErrorAction SilentlyContinue).Count) { break }
    Start-Sleep -Seconds 2
}
Start-Sleep -Seconds 3

$S = Get-Strings
if ($Test) {
    $ok = $true
    NLog 'test mode: skipping the health probe'
} else {
    $ok = Test-Dashboard -Port $Port -TimeoutSeconds $TimeoutSeconds
}
$url = Get-DashboardUrl -Port $Port
NLog ("dashboard reachable: $ok - url: $url")

if ($ok) {
    $title = $S.notif_ok
    $body  = ($S.notif_ok_body -replace '\{0\}', $url)
} else {
    $title = $S.notif_fail
    $body  = $S.notif_fail_body
}
$title = "$($S.notif_title) - $title"

# A native toast is nice when the Action Center is available, but on Windows
# Server it very often is not, and a tray balloon can be swallowed silently.
# So: try the native ways first and, if neither of them reported success, show
# the window styled like a Windows 10 toast, which always works on a desktop.
$shown = Show-Toast -Title $title -Body $body -Ok $ok
if (-not $shown) { $shown = Show-Balloon -Title $title -Body $body -Ok $ok }
if (-not $shown) { $shown = Show-FakeToast -Title $title -Body $body -Ok $ok }
if (-not $shown) { NLog 'NO notification could be displayed (no interactive desktop?)' }
NLog "--- done ---"

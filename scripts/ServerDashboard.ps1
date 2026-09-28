#requires -version 4.0
<#
    ServerDashboard.ps1
    Web monitoring dashboard for Windows Server 2016 (and newer).
    It publishes a small HTTP server (System.Net.HttpListener) reachable from
    any computer on the local network: http://<SERVER-IP>:<port>/

    No installation, no agent and no external module required.
    Every metric is collected through language independent CIM/WMI classes,
    so it works on any localized build of Windows.

    Typical start:  powershell -ExecutionPolicy Bypass -File ServerDashboard.ps1 -Port 8080

    The user interface is translated into 38 languages (see the \lang folder);
    the default language follows the Windows display language.
#>

[CmdletBinding()]
param(
    [int]$Port = 8080,
    [double]$IntervalSeconds = 0.5,      # sampling interval while at least one browser is connected
    [double]$IdleIntervalSeconds = 0,   # when nobody is connected: 0 = do not sample at all
    [switch]$CheckUpdatesOnly,          # look for a newer release, apply it and exit
    [string]$LogFile,
    [string]$SettingsFile
)

# ----------------------------------------------------------------------------
# Package layout (since 1.12.0)
#
#   <root>\  Install.bat  Uninstall.bat  Start-Dashboard.bat  Stop-Dashboard.bat
#            settings.txt
#            scripts\   this file and every other script
#            lang\      the 38 translations
#            docs\      README.md, CHANGELOG.md, the offline preview
#            logs\      every log file
#
# This script lives in scripts\, so the package root is its parent folder. It
# still works if somebody copies it back next to settings.txt: in that case the
# root is simply the folder of the script.
# ----------------------------------------------------------------------------
$ScriptDir = $PSScriptRoot
$Root = if ((Split-Path -Leaf $ScriptDir) -eq 'scripts') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
$LangDir = Join-Path $Root 'lang'
$LogDir  = Join-Path $Root 'logs'
if (-not $SettingsFile) { $SettingsFile = Join-Path $Root 'settings.txt' }
if (-not (Test-Path $LogDir)) { try { [void](New-Item -ItemType Directory -Path $LogDir -Force) } catch { } }

# ----------------------------------------------------------------------------
# Daily log rotation.
# One log file per day: the file name carries the date of the moment the line
# is written, so at midnight the rotation happens by itself, with no timer and
# no file ever growing without limit. Files older than $LogKeepDays days are
# deleted automatically. An explicit -LogFile parameter still wins, for tests.
# ----------------------------------------------------------------------------
$LogKeepDays = 14
$script:FixedLogFile = $null
if ($LogFile) { $script:FixedLogFile = $LogFile }

function Get-DailyLogPath {
    if ($script:FixedLogFile) { return $script:FixedLogFile }
    Join-Path $LogDir ("ServerDashboard-" + (Get-Date -Format 'yyyy-MM-dd') + ".log")
}

function Remove-OldLogs([string]$Dir) {
    try {
        $limit = (Get-Date).AddDays(-$LogKeepDays)
        foreach ($f in @(Get-ChildItem -Path $Dir -Filter '*.log' -File -ErrorAction SilentlyContinue)) {
            if ($f.LastWriteTime -lt $limit) { Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue }
        }
    } catch { }
}
Remove-OldLogs $LogDir

# The version lives in version.txt, next to this script: it is the single
# source of truth, read by the dashboard, the updater and the docs.
$DashboardVersion = '0.0.0'
try {
    $vfile = Join-Path $PSScriptRoot 'version.txt'
    if (Test-Path $vfile) { $DashboardVersion = (Get-Content $vfile -Raw).Trim() }
} catch { }
$ErrorActionPreference = 'Continue'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

# ----------------------------------------------------------------------------
# Logging switch.
# It lives ONLY in settings.txt (line "logging = yes|no") and is deliberately
# NOT exposed through the web interface: whoever watches the dashboard cannot
# turn the log on or off. It is read here, before anything is written, so that
# with logging = no the file is never created at all.
# ----------------------------------------------------------------------------
$script:LogEnabled = $true
if (Test-Path $SettingsFile) {
    try {
        foreach ($l in (Get-Content -Path $SettingsFile -Encoding UTF8 -ErrorAction Stop)) {
            $t = "$l".Trim()
            if ($t -match '^(?i)logging\s*=\s*(.+)$') {
                $script:LogEnabled = ($Matches[1].Trim() -match '(?i)^(yes|true|1|on|si|s)$')
                break
            }
        }
    } catch { }
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    if (-not $script:LogEnabled) { return }
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try { Add-Content -Path (Get-DailyLogPath) -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
}

Write-Log "=== Starting PiBOH Windows Server Dashboard v$DashboardVersion on port $Port ==="

# ----------------------------------------------------------------------------
# Windows Event Log: the dashboard introduces itself to whoever opens Event
# Viewer, with its own source name. Transparency first: an administrator must
# always be able to see what this software is, where it lives and what it does.
# ----------------------------------------------------------------------------
$BrandName = 'PiBOH Windows Server Dashboard'
try { $Host.UI.RawUI.WindowTitle = $BrandName } catch { }

function Write-DashEvent([int]$EventId, [string]$Type, [string]$Message) {
    try {
        $src = $BrandName
        if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
            New-EventLog -LogName Application -Source $src -ErrorAction Stop | Out-Null
        }
        Write-EventLog -LogName Application -Source $src -EventId $EventId -EntryType $type `
                      -Message $Message -ErrorAction Stop
    } catch { }
}

# ----------------------------------------------------------------------------
# Shared state between the collector thread and the web server
# ----------------------------------------------------------------------------
$Shared = [hashtable]::Synchronized(@{
    Data        = $null
    History     = New-Object System.Collections.ArrayList
    Running     = $true
    Started     = Get-Date
    Port        = $Port
    LogFile     = $(if ($script:FixedLogFile) { $script:FixedLogFile } else { $LogDir })
    LogFixed    = [bool]$script:FixedLogFile
    LogDir      = $LogDir
    LogKeepDays = $LogKeepDays
    Interval    = $IntervalSeconds
    IdleInterval= $IdleIntervalSeconds
    LastRequest = Get-Date
    LogEnabled  = $true
    Paused      = $false
})
$Shared.LogEnabled = $script:LogEnabled

# ----------------------------------------------------------------------------
# Server side settings (settings.json): refresh interval + visible sections.
# Browser side settings (theme, language) live in the visitor's localStorage.
# ----------------------------------------------------------------------------
$SectionKeys = @('cpu','cpu_trend','ram','ram_trend','network','net_adapters','ip_config',
                 'disks','os','processes','services','events')

function Get-DefaultSettings {
    $sec = @{}
    foreach ($k in $SectionKeys) { $sec[$k] = $true }
    return @{
        refreshSeconds = [double]$IntervalSeconds
        idleSeconds    = [double]$IdleIntervalSeconds   # 0 = no sampling while nobody is connected
        autoUpdate     = $true                           # check GitHub for a newer release at startup
        sections       = $sec
    }
}

function Read-Settings {
    # settings.txt is a plain text file, one "key = value" per line, editable
    # with Notepad. Missing keys simply keep their default value.
    $cfg = Get-DefaultSettings
    if (Test-Path $SettingsFile) {
        try {
            foreach ($line in (Get-Content -Path $SettingsFile -Encoding UTF8)) {
                $t = "$line".Trim()
                if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';')) { continue }
                $i = $t.IndexOf('=')
                if ($i -lt 1) { continue }
                $k = $t.Substring(0, $i).Trim().ToLower()
                $v = $t.Substring($i + 1).Trim()
                switch -Regex ($k) {
                    '^refresh_seconds$' {
                        [double]$n = 0
                        if ([double]::TryParse($v, [System.Globalization.NumberStyles]::Float,
                                               [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) {
                            $cfg.refreshSeconds = $n
                        }
                    }
                    '^idle_seconds$' {
                        [double]$n = 0
                        if ([double]::TryParse($v, [System.Globalization.NumberStyles]::Float,
                                               [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) {
                            $cfg.idleSeconds = $n
                        }
                    }
                    '^logging$'     { }   # handled before logging starts, kept here so it is not reported as unknown
                    '^auto_update$' { $cfg.autoUpdate = ($v -match '(?i)^(yes|true|1|on|si|s)$') }
                    '^show_(.+)$' {
                        $sec = $Matches[1]
                        if ($cfg.sections.ContainsKey($sec)) {
                            $cfg.sections[$sec] = ($v -match '(?i)^(yes|true|1|on|si|s)$')
                        }
                    }
                }
            }
            Write-Log "Settings loaded from $SettingsFile"
        } catch { Write-Log "Could not read the settings file, using defaults: $($_.Exception.Message)" 'WARN' }
    } else {
        Write-Log "No settings file found: creating $SettingsFile with the default settings"
    }
    if ($cfg.refreshSeconds -lt 0.5)  { $cfg.refreshSeconds = 0.5 }
    if ($cfg.refreshSeconds -gt 3600) { $cfg.refreshSeconds = 3600 }
    if ($cfg.idleSeconds -lt 0)       { $cfg.idleSeconds = 0 }
    return $cfg
}

# Used only to create the file the first time: the dashboard never rewrites it,
# because the settings it contains cannot be changed from the web interface.
function Write-Settings($cfg) {
    try {
        $lines = New-Object System.Collections.ArrayList
        [void]$lines.Add('# ============================================================')
        [void]$lines.Add('#  ServerDashboard - settings')
        [void]$lines.Add('# ============================================================')
        [void]$lines.Add('#  Plain text file: one "key = value" per line.')
        [void]$lines.Add('#  You can edit it with Notepad, or from the gear button of the')
        [void]$lines.Add('#  dashboard (the dashboard rewrites this file when you save).')
        [void]$lines.Add('#  Lines starting with # are comments. Delete the file to go back')
        [void]$lines.Add('#  to the default values listed below.')
        [void]$lines.Add('# ------------------------------------------------------------')
        [void]$lines.Add('')
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        [void]$lines.Add('# Default refresh interval proposed to every visitor, in seconds.')
        [void]$lines.Add('# Allowed: 0.5 - 3600. Default: 0.5. Each visitor may pick another')
        [void]$lines.Add('# value for their own browser; it changes nothing on the server.')
        [void]$lines.Add("refresh_seconds = " + ([double]$cfg.refreshSeconds).ToString($inv))
        [void]$lines.Add('')
        [void]$lines.Add('# What to do when NOBODY is watching the dashboard:')
        [void]$lines.Add('#   0  = do not sample at all (default, zero CPU cost)')
        [void]$lines.Add('#   >0 = keep sampling every N seconds, to build history')
        [void]$lines.Add("idle_seconds = " + ([double]$cfg.idleSeconds).ToString($inv))
        [void]$lines.Add('')
        [void]$lines.Add('# Write the log files in logs\: yes / no. One file per day')
        [void]$lines.Add('# (ServerDashboard-YYYY-MM-DD.log), kept for 14 days.')
        [void]$lines.Add('# This option is available HERE ONLY: it cannot be changed from the')
        [void]$lines.Add('# dashboard, so a visitor can never enable or disable logging.')
        [void]$lines.Add('# With no, the log file is never created.')
        [void]$lines.Add("logging = " + $(if ($script:LogEnabled) { 'yes' } else { 'no' }))
        [void]$lines.Add('')
        [void]$lines.Add('# Check GitHub for a newer release at every start and install it')
        [void]$lines.Add('# automatically (the dashboard restarts itself). yes / no')
        [void]$lines.Add("auto_update = " + $(if ($cfg.autoUpdate) { 'yes' } else { 'no' }))
        [void]$lines.Add('')
        [void]$lines.Add('# Sections shown on the page: yes / no')
        foreach ($k in $SectionKeys) {
            $val = if ($cfg.sections[$k]) { 'yes' } else { 'no' }
            [void]$lines.Add(("show_{0,-12} = {1}" -f $k, $val))
        }
        [void]$lines.Add('')
        [void]$lines.Add('# Theme and language are NOT stored here: they are personal')
        [void]$lines.Add('# choices, saved in the cache of each visitor browser.')
        $lines -join "`r`n" | Set-Content -Path $SettingsFile -Encoding UTF8
        Write-Log "Settings saved to $SettingsFile"
        return $true
    } catch { Write-Log "Could not save the settings: $($_.Exception.Message)" 'ERROR'; return $false }
}

$Shared.Settings = Read-Settings
$Shared.Interval = $Shared.Settings.refreshSeconds
if (-not (Test-Path $SettingsFile)) { [void](Write-Settings $Shared.Settings) }

# ----------------------------------------------------------------------------
# Self update from GitHub.
#
# At every start (the scheduled task runs at boot as SYSTEM, so no logon is
# needed) the script reads scripts/version.txt of the main branch:
#
#   https://raw.githubusercontent.com/PiBOH/windows-server-dashboard/main/scripts/version.txt
#
# When it is newer than the local one, the release tagged v<version> is
# downloaded, unpacked and copied over the current files - never touching
# settings.txt, the logs\ folder or anything that belongs to this installation
# only. The dashboard then restarts itself on the new version.
# Set auto_update = no in settings.txt to disable it, or run the script with
# -CheckUpdatesOnly to trigger a check by hand.
# ----------------------------------------------------------------------------
$UpdateRepo    = 'PiBOH/windows-server-dashboard'
$UpdateVersion = 'https://raw.githubusercontent.com/' + $UpdateRepo + '/main/scripts/version.txt'
$UpdateZipFmt  = 'https://github.com/' + $UpdateRepo + '/archive/refs/tags/v{0}.zip'
$UpdateKeep    = @('logs', 'settings.txt', 'settings-backup.txt', 'install-state.txt',
                   'previous-task-backup.xml', 'ServerDashboard-*.log', 'ServerDashboard-notify-*.log')

function Get-LatestVersion {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $v = (Invoke-WebRequest -Uri $script:UpdateVersion -UseBasicParsing -TimeoutSec 20).Content.Trim()
        if ($v -match '^\d+\.(\d+\.)?\d+$') { return $v }
    } catch { }
    return $null
}

function Test-NewerVersion([string]$Remote, [string]$Local) {
    $r = @($Remote.Split('.'))
    $l = @($Local.Split('.'))
    for ($i = 0; $i -lt [math]::Max($r.Count, $l.Count); $i++) {
        $rv = if ($i -lt $r.Count) { [int]$r[$i] } else { 0 }
        $lv = if ($i -lt $l.Count) { [int]$l[$i] } else { 0 }
        if ($rv -gt $lv) { return $true }
        if ($rv -lt $lv) { return $false }
    }
    return $false
}

function Invoke-SelfUpdate([string]$Target) {
    $zip = Join-Path $env:TEMP ("sd-update-" + $Target + '.zip')
    $dir = Join-Path $env:TEMP ("sd-update-" + $Target)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri ($script:UpdateZipFmt -f $Target) -OutFile $zip -UseBasicParsing -TimeoutSec 120
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $zip -DestinationPath $dir -Force
        # the archive unpacks into a single root folder
        $src = Get-ChildItem -Path $dir -Directory | Select-Object -First 1
        if (-not $src) { throw 'the archive is empty' }
        foreach ($item in @(Get-ChildItem -Path $src.FullName)) {
            if ($UpdateKeep -contains $item.Name) { continue }
            Copy-Item -Path $item.FullName -Destination (Join-Path $Root $item.Name) -Recurse -Force
        }
        return $true
    } catch {
        Write-Log ("Self update failed: " + $_.Exception.Message) 'ERROR'
        return $false
    } finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Update-FromGithub {
    # returns $true when a new version was installed
    if (-not $Shared.Settings.autoUpdate) { return $false }
    $latest = Get-LatestVersion
    if (-not $latest) { Write-Log 'No update information available (offline or repository unreachable).'; return $false }
    if (-not (Test-NewerVersion $latest $DashboardVersion)) {
        Write-Log "Up to date (version $DashboardVersion)."
        return $false
    }
    Write-Log "New version available on GitHub: $latest (current: $DashboardVersion). Downloading..."
    if (Invoke-SelfUpdate $latest) {
        Write-Log "Updated to $latest. Restarting on the new version."
        Write-DashEvent 2 'Information' ("$BrandName updated itself to $latest from $UpdateRepo. " +
            "The new version restarts automatically; the local settings and the logs were preserved.")
        return $true
    }
    return $false
}

# ----------------------------------------------------------------------------
# Update check at start (runs as SYSTEM at boot: no interactive logon needed).
# ----------------------------------------------------------------------------
$script:Updated = Update-FromGithub
if ($script:Updated -and -not $CheckUpdatesOnly) {
    # hand over to the new version, with the same port
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath, '-Port', "$Port"
    ) -WindowStyle Hidden
    exit 0
}
if ($CheckUpdatesOnly) {
    if ($script:Updated) {
        Write-Host ("Updated to the new version. Restart the service to run it:")
        Write-Host '  Stop-Dashboard.bat   then   schtasks /Run /TN "PiBOH Windows Server Dashboard"'
    } else {
        Write-Host "Version $DashboardVersion - up to date."
    }
    exit 0
}

# Since the file is the only way to change these values, it is watched: edit it
# with Notepad and the change is picked up within 10 seconds, no restart needed.
$script:SettingsStamp = $null
try { $script:SettingsStamp = (Get-Item $SettingsFile).LastWriteTimeUtc } catch { }
$script:SettingsCheck = Get-Date

function Update-SettingsIfChanged {
    if (((Get-Date) - $script:SettingsCheck).TotalSeconds -lt 10) { return }
    $script:SettingsCheck = Get-Date
    try {
        if (-not (Test-Path $SettingsFile)) { return }
        $st = (Get-Item $SettingsFile).LastWriteTimeUtc
        if ($script:SettingsStamp -and $st -eq $script:SettingsStamp) { return }
        $script:SettingsStamp = $st
        $new = Read-Settings
        $Shared.Settings = $new
        $Shared.Interval = $new.refreshSeconds
        $Shared.IdleInterval = $new.idleSeconds
        Write-Log ("settings.txt changed: refresh " + $new.refreshSeconds + "s, idle " + $new.idleSeconds + "s")
    } catch { }
}

# ----------------------------------------------------------------------------
# METRIC COLLECTOR (runs in its own runspace, every N seconds)
# ----------------------------------------------------------------------------
$CollectorScript = {
    param($Shared)

    [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

    function Get-CimSafe {
        param([string]$Class, [string]$Namespace = 'root\cimv2', [string]$Filter = $null)
        try {
            if ($Filter) { Get-CimInstance -ClassName $Class -Namespace $Namespace -Filter $Filter -ErrorAction Stop }
            else         { Get-CimInstance -ClassName $Class -Namespace $Namespace -ErrorAction Stop }
        } catch { $null }
    }

    # --- static data, collected once ------------------------------------------
    $os   = Get-CimSafe Win32_OperatingSystem
    $cs   = Get-CimSafe Win32_ComputerSystem
    $bios = Get-CimSafe Win32_BIOS
    $cpuInfo = @(Get-CimSafe Win32_Processor)

    $static = @{
        ComputerName   = $env:COMPUTERNAME
        Domain         = if ($cs) { $cs.Domain } else { '' }
        Manufacturer   = if ($cs) { $cs.Manufacturer } else { '' }
        Model          = if ($cs) { $cs.Model } else { '' }
        Bios           = if ($bios) { "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)" } else { '' }
        SerialNumber   = if ($bios) { $bios.SerialNumber } else { '' }
        OSName         = if ($os) { $os.Caption } else { '' }
        OSVersion      = if ($os) { $os.Version } else { '' }
        OSBuild        = if ($os) { $os.BuildNumber } else { '' }
        OSArch         = if ($os) { $os.OSArchitecture } else { '' }
        OSInstall      = if ($os -and $os.InstallDate) { $os.InstallDate.ToString('dd/MM/yyyy HH:mm') } else { '' }
        CpuName        = if ($cpuInfo.Count) { $cpuInfo[0].Name.Trim() } else { 'N/A' }
        CpuSockets     = $cpuInfo.Count
        CpuCores       = ($cpuInfo | Measure-Object -Property NumberOfCores -Sum).Sum
        CpuLogical     = ($cpuInfo | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        CpuMaxMhz      = if ($cpuInfo.Count) { [int]$cpuInfo[0].MaxClockSpeed } else { 0 }
        TotalRamBytes  = if ($cs) { [double]$cs.TotalPhysicalMemory } else { 0 }
    }
    if (-not $static.CpuLogical) { $static.CpuLogical = [int]$env:NUMBER_OF_PROCESSORS }

    # --- physical memory modules ----------------------------------------------
    $static.MemoryModules = @(
        foreach ($m in @(Get-CimSafe Win32_PhysicalMemory)) {
            @{
                Slot     = $m.DeviceLocator
                SizeGB   = [math]::Round($m.Capacity / 1GB, 1)
                SpeedMhz = $m.Speed
                Type     = $m.Manufacturer
            }
        }
    )

    function Write-CollectorLog($sh, $text) {
        if (-not $sh.LogEnabled) { return }
        $line = "{0} [INFO] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text
        # Same rule as the main log: one file per day, the date is in the name,
        # so the rotation happens by itself at midnight. A fixed -LogFile
        # (used by the tests) wins over the daily rotation.
        $p = if ($sh.LogFixed) { $sh.LogFile }
             else { Join-Path $sh.LogDir ("ServerDashboard-" + (Get-Date -Format 'yyyy-MM-dd') + ".log") }
        try { Add-Content -Path $p -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
    }

    # delete the log files older than the retention, once a day
    $lastPurge = Get-Date

    # --- previous sample, used to compute deltas ------------------------------
    $prevNet  = @{}
    $prevTime = $null

    # --- Windows event log cache (refreshed at most once a minute) ------------
    $evCache = @()
    $evStamp = (Get-Date).AddYears(-1)

    # ------------------------------------------------------------------------
    # TIERED SAMPLING - this is what keeps the CPU cost low.
    # Cheap counters (CPU, memory, network) are read on every cycle, so the page
    # can refresh once per second; everything expensive is read on its own, much
    # slower schedule and served from cache in between. Going from 5s to 1s
    # therefore costs almost nothing, because the heavy queries do not speed up.
    # ------------------------------------------------------------------------
    $old = (Get-Date).AddYears(-1)
    $dkCache = $null; $dkStamp = $old      # disks      : every 10 s
    $prCache = $null; $prStamp = $old      # processes  : every 5 s
    $svCache = $null; $svStamp = $old      # services   : every 30 s
    $ipCache = $null; $ipStamp = $old      # IP config  : every 60 s
    $script:lastMapSource = 'associators'

    function Get-RecentEvents {
        $out = @()
        try {
            $filter = @{
                LogName   = @('System','Application')
                Level     = @(1,2,3)                       # 1=Critical 2=Error 3=Warning
                StartTime = (Get-Date).AddHours(-24)
            }
            foreach ($e in @(Get-WinEvent -FilterHashtable $filter -MaxEvents 150 -ErrorAction Stop)) {
                $msg = ''
                try { $msg = ($e.Message -replace '\s+', ' ').Trim() } catch { }
                if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + '...' }
                $out += @{
                    Time    = $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                    Level   = [int]$e.Level
                    Log     = $e.LogName
                    Source  = $e.ProviderName
                    EventId = [int]$e.Id
                    Message = $msg
                }
            }
        } catch {
            # Fallback for hosts where Get-WinEvent is unavailable or the query fails
            try {
                foreach ($log in @('System','Application')) {
                    foreach ($e in @(Get-EventLog -LogName $log -EntryType Error,Warning -Newest 50 -ErrorAction Stop)) {
                        $msg = ''
                        try { $msg = ($e.Message -replace '\s+', ' ').Trim() } catch { }
                        if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + '...' }
                        $out += @{
                            Time    = $e.TimeGenerated.ToString('yyyy-MM-dd HH:mm:ss')
                            Level   = $(if ($e.EntryType -eq 'Error') { 2 } else { 3 })
                            Log     = $log
                            Source  = $e.Source
                            EventId = [int]$e.InstanceId
                            Message = $msg
                        }
                    }
                }
            } catch { }
        }
        return ,@($out | Sort-Object { $_.Time } -Descending | Select-Object -First 150)
    }

    while ($Shared.Running) {
        $t0 = Get-Date
        try {
            $snap = @{ Timestamp = $t0.ToString('yyyy-MM-dd HH:mm:ss'); Static = $static }

            # ================== CPU =========================================
            $perCore = @()
            $cpuTotal = 0.0
            $perf = @(Get-CimSafe Win32_PerfFormattedData_PerfOS_Processor)
            if ($perf.Count) {
                foreach ($p in ($perf | Where-Object { $_.Name -ne '_Total' } | Sort-Object { [int]($_.Name -replace '\D','0') })) {
                    $perCore += @{
                        Core    = $p.Name
                        Load    = [math]::Round([double]$p.PercentProcessorTime, 1)
                        User    = [math]::Round([double]$p.PercentUserTime, 1)
                        Privil  = [math]::Round([double]$p.PercentPrivilegedTime, 1)
                        Idle    = [math]::Round([double]$p.PercentIdleTime, 1)
                        Interr  = [double]$p.InterruptsPersec
                    }
                }
                $tot = $perf | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
                if ($tot) { $cpuTotal = [math]::Round([double]$tot.PercentProcessorTime, 1) }
                elseif ($perCore.Count) { $cpuTotal = [math]::Round((($perCore | Measure-Object Load -Average).Average), 1) }
            }
            if (-not $perf.Count) {
                $lp = @(Get-CimSafe Win32_Processor)
                if ($lp.Count) { $cpuTotal = [math]::Round((($lp | Measure-Object LoadPercentage -Average).Average), 1) }
            }

            # real clock speed in GHz
            $curMhz = 0; $maxMhz = $static.CpuMaxMhz
            $procInfo = @(Get-CimSafe Win32_PerfFormattedData_Counters_ProcessorInformation)
            $tot2 = $procInfo | Where-Object { $_.Name -like '*_Total' } | Select-Object -First 1
            if ($tot2 -and $tot2.PercentProcessorPerformance -and $maxMhz) {
                $curMhz = [int]($maxMhz * ([double]$tot2.PercentProcessorPerformance / 100))
            } else {
                $lp = @(Get-CimSafe Win32_Processor)
                if ($lp.Count) { $curMhz = [int]$lp[0].CurrentClockSpeed }
            }

            # temperature (only if the BIOS/ACPI exposes it)
            $temps = @()
            foreach ($tz in @(Get-CimSafe MSAcpi_ThermalZoneTemperature 'root\wmi')) {
                if ($tz.CurrentTemperature -gt 0) {
                    $temps += @{
                        Sensor  = ($tz.InstanceName -replace '.*_', '')
                        Celsius = [math]::Round(($tz.CurrentTemperature / 10) - 273.15, 1)
                    }
                }
            }
            # Fallback 1: Core Temp (needs its free "Core Temp WMI provider" add-on,
            # which publishes root\CoreTemp -> CoreTempInfo with one reading per core)
            if (-not $temps.Count) {
                try {
                    $ct = Get-CimInstance -Namespace 'root\CoreTemp' -ClassName 'CoreTempInfo' -ErrorAction Stop |
                          Select-Object -First 1
                    if ($ct) {
                        $readings = @($ct.GetCoreTemp)
                        $offset   = 0.0
                        if ($null -ne $ct.TjMax -and @($ct.TjMax).Count) { $offset = 0.0 }
                        $i = 0
                        foreach ($r in $readings) {
                            $val = [double]$r
                            if ($ct.IsFahrenheit) { $val = ($val - 32) / 1.8 }      # normalize to Celsius
                            if ($val -gt 0 -and $val -lt 150) {
                                $temps += @{ Sensor = "Core $i"; Celsius = [math]::Round($val + $offset, 1) }
                            }
                            $i++
                        }
                        if ($temps.Count) { $Shared.TempSource = 'Core Temp' }
                    }
                } catch { }
            }

            # Fallback 2: OpenHardwareMonitor / LibreHardwareMonitor when installed
            if (-not $temps.Count) {
                foreach ($ns in @('root\OpenHardwareMonitor','root\LibreHardwareMonitor')) {
                    foreach ($s in @(Get-CimSafe Sensor $ns)) {
                        if ($s.SensorType -eq 'Temperature' -and $s.Value) {
                            $temps += @{ Sensor = $s.Name; Celsius = [math]::Round([double]$s.Value,1) }
                        }
                    }
                    if ($temps.Count) { break }
                }
            }

            # Fallback 3: HWiNFO shared WMI provider (optional feature of HWiNFO)
            if (-not $temps.Count) {
                foreach ($s in @(Get-CimSafe SensorInfo 'root\HWiNFO')) {
                    if ($s.SensorType -eq 'Temperature' -and $s.SensorValue) {
                        $temps += @{ Sensor = $s.SensorName; Celsius = [math]::Round([double]$s.SensorValue,1) }
                    }
                }
            }

            $snap.Cpu = @{
                TotalLoad   = $cpuTotal
                PerCore     = $perCore
                CurrentMhz  = $curMhz
                MaxMhz      = $maxMhz
                CurrentGHz  = [math]::Round($curMhz / 1000, 2)
                MaxGHz       = [math]::Round($maxMhz / 1000, 2)
                Temperatures = $temps
                QueueLength  = 0
            }

            # ================== RAM =========================================
            $os2 = Get-CimSafe Win32_OperatingSystem
            $totalKB = if ($os2) { [double]$os2.TotalVisibleMemorySize } else { 0 }
            $freeKB  = if ($os2) { [double]$os2.FreePhysicalMemory } else { 0 }
            $usedKB  = $totalKB - $freeKB
            $snap.Memory = @{
                TotalGB   = [math]::Round($totalKB / 1MB, 2)
                UsedGB    = [math]::Round($usedKB / 1MB, 2)
                FreeGB    = [math]::Round($freeKB / 1MB, 2)
                Percent   = if ($totalKB) { [math]::Round(($usedKB / $totalKB) * 100, 1) } else { 0 }
                SwapTotGB = if ($os2) { [math]::Round(([double]$os2.TotalVirtualMemorySize - $totalKB) / 1MB, 2) } else { 0 }
                SwapFreeGB= if ($os2) { [math]::Round(([double]$os2.FreeVirtualMemory - $freeKB) / 1MB, 2) } else { 0 }
                Modules   = $static.MemoryModules
            }

            # ================== DISKS (tier: every 10 s) ====================
            $dkEvery = [math]::Max(10, $Shared.Interval)
            if ((-not $dkCache) -or (((Get-Date) - $dkStamp).TotalSeconds -ge $dkEvery)) {
            try {
            # Per-volume I/O counters (language independent WMI class)
            $ioMap = @{}
            foreach ($io in @(Get-CimSafe Win32_PerfFormattedData_PerfDisk_LogicalDisk)) {
                if ($io.Name -match '^[A-Za-z]:$') {
                    $ioMap["$($io.Name)".ToUpper()] = @{
                        ReadKBs  = [math]::Round([double]$io.DiskReadBytesPersec / 1KB, 1)
                        WriteKBs = [math]::Round([double]$io.DiskWriteBytesPersec / 1KB, 1)
                        BusyPct  = [math]::Round(100 - [double]$io.PercentIdleTime, 1)
                    }
                }
            }

            # Every volume / partition, keyed by drive letter
            $volMap = @{}
            foreach ($d in @(Get-CimSafe Win32_LogicalDisk -Filter 'DriveType=2 OR DriveType=3 OR DriveType=4 OR DriveType=5')) {
                $size = [double]$d.Size; $free = [double]$d.FreeSpace
                $type = switch ([int]$d.DriveType) { 2 {'Removable'} 3 {'Fixed'} 4 {'Network'} 5 {'CD/DVD'} default {'Other'} }
                $key  = "$($d.DeviceID)".ToUpper()
                $vol  = @{
                    Drive      = $d.DeviceID
                    Label      = $d.VolumeName
                    FileSystem = $d.FileSystem
                    Type       = $type
                    TotalGB    = [math]::Round($size / 1GB, 2)
                    UsedGB     = [math]::Round(($size - $free) / 1GB, 2)
                    FreeGB     = [math]::Round($free / 1GB, 2)
                    Percent    = if ($size -gt 0) { [math]::Round((($size - $free) / $size) * 100, 1) } else { 0 }
                    ReadKBs    = 0.0
                    WriteKBs   = 0.0
                    BusyPct    = 0.0
                }
                if ($ioMap.ContainsKey($key)) {
                    $vol.ReadKBs  = $ioMap[$key].ReadKBs
                    $vol.WriteKBs = $ioMap[$key].WriteKBs
                    $vol.BusyPct  = $ioMap[$key].BusyPct
                }
                $volMap[$key] = $vol
            }

            # Extra details (bus and media type) from the Storage module, when available
            $pdInfo = @{}
            try {
                foreach ($x in @(Get-PhysicalDisk -ErrorAction Stop)) {
                    $pdInfo["$($x.DeviceId)"] = @{
                        BusType   = "$($x.BusType)"
                        MediaType = "$($x.MediaType)"
                    }
                }
            } catch { }

            # Second source for the disk -> volume mapping.
            # The ASSOCIATORS queries used below are the classic way, but they fail
            # on several RAID / storage drivers: when that happens every volume ends
            # up in "other volumes" and the disks look empty. The Storage module
            # (MSFT_Partition) gives the same information in a far more reliable way,
            # so it is prepared here and used as a fallback per disk.
            $partMap = @{}        # disk number -> @('C:','D:')
            try {
                foreach ($pt in @(Get-CimInstance -Namespace 'root/Microsoft/Windows/Storage' `
                                                  -ClassName MSFT_Partition -ErrorAction Stop)) {
                    if ($pt.DriveLetter -and "$($pt.DriveLetter)".Trim() -and "$($pt.DriveLetter)" -ne "`0") {
                        $dn = "$($pt.DiskNumber)"
                        if (-not $partMap.ContainsKey($dn)) { $partMap[$dn] = @() }
                        $partMap[$dn] += ("$($pt.DriveLetter)".Trim() + ':').ToUpper()
                    }
                }
            } catch { }
            if (-not $partMap.Count) {
                try {
                    foreach ($pt in @(Get-Partition -ErrorAction Stop)) {
                        if ($pt.DriveLetter) {
                            $dn = "$($pt.DiskNumber)"
                            if (-not $partMap.ContainsKey($dn)) { $partMap[$dn] = @() }
                            $partMap[$dn] += ("$($pt.DriveLetter)" + ':').ToUpper()
                        }
                    }
                } catch { }
            }

            # Physical drives, each one carrying its own partitions (and their I/O).
            # Removable, virtual and optical units are flagged so the dashboard can list
            # them apart from the real fixed disks of the server.
            $assigned = @{}
            $physical = @()
            $mapSource = 'associators'
            foreach ($pd in @(Get-CimSafe Win32_DiskDrive)) {
                $vols = @()
                try {
                    foreach ($pt in @(Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($pd.DeviceID.Replace('\','\\'))'} WHERE AssocClass=Win32_DiskDriveToDiskPartition" -ErrorAction Stop)) {
                        foreach ($ld in @(Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($pt.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition" -ErrorAction Stop)) {
                            $k = "$($ld.DeviceID)".ToUpper()
                            if ($volMap.ContainsKey($k) -and -not $assigned.ContainsKey($k)) {
                                $vols += $volMap[$k]
                                $assigned[$k] = $true
                            }
                        }
                    }
                } catch { }

                # Fallback A: the disk got no volume from the associators, ask the
                # Storage module for the letters that live on this disk number.
                if (-not $vols.Count -and $partMap.Count) {
                    $dn = "$($pd.Index)"
                    if ($partMap.ContainsKey($dn)) {
                        foreach ($k in $partMap[$dn]) {
                            if ($volMap.ContainsKey($k) -and -not $assigned.ContainsKey($k)) {
                                $vols += $volMap[$k]
                                $assigned[$k] = $true
                                $mapSource = 'storage-module'
                            }
                        }
                    }
                }

                $rd = 0.0; $wr = 0.0; $bs = 0.0
                foreach ($v in $vols) {
                    $rd += [double]$v.ReadKBs; $wr += [double]$v.WriteKBs
                    if ([double]$v.BusyPct -gt $bs) { $bs = [double]$v.BusyPct }
                }
                # --- classify the device ---------------------------------
                # A device is listed apart ONLY when it clearly is not a disk of
                # the server: USB / removable media, optical drives and network or
                # card-reader units. Virtual disks (Hyper-V, VMware, VirtualBox,
                # KVM, iSCSI) ARE the disks of a virtualized server, so they stay
                # in the main list - only their badge says they are virtual.
                $model = "$($pd.Model)"
                $iface = "$($pd.InterfaceType)"
                $media = "$($pd.MediaType)"
                $idx   = "$($pd.Index)"
                $bus   = ''
                $mtype = ''
                if ($pdInfo.ContainsKey($idx)) { $bus = $pdInfo[$idx].BusType; $mtype = $pdInfo[$idx].MediaType }

                $kind = 'Fixed'
                if ($media -match '(?i)removable' -or $iface -eq 'USB' -or $bus -eq 'USB' -or
                    $model -match '(?i)card\s*reader|flash\s*(disk|drive)|\bsd\s*card\b') {
                    $kind = 'Removable'
                } elseif ($media -match '(?i)optical|cd-rom|dvd' -or $model -match '(?i)\b(cd|dvd|bd)[\s-]?(rom|rw)\b') {
                    $kind = 'Optical'
                }

                # informative only: it does NOT move the disk out of the main list
                $isVirtual = ($model -match '(?i)virtual|vmware|vbox|virtualbox|qemu|kvm|hyper-?v|msft|iscsi' -or
                              $bus   -match '(?i)virtual|iscsi|file\s*backed')

                                $physical += @{
                    Model      = $model
                    Interface  = $iface
                    BusType    = $bus
                    MediaType  = $(if ($mtype -and $mtype -ne 'Unspecified') { $mtype } else { $media })
                    Kind       = $kind
                    IsVirtual  = [bool]$isVirtual
                    SizeGB     = [math]::Round([double]$pd.Size / 1GB, 2)
                    Partitions = $pd.Partitions
                    Status     = $pd.Status
                    Volumes    = @($vols | Sort-Object { $_.Drive })
                    ReadKBs    = [math]::Round($rd, 1)
                    WriteKBs   = [math]::Round($wr, 1)
                    BusyPct    = [math]::Round($bs, 1)
                }
            }

            # Fallback B: local fixed volumes still unassigned. If the server has a
            # single physical disk they obviously belong to it; with more than one we
            # cannot guess, so they stay in "other volumes" but the log says why.
            $leftFixed = @(foreach ($k in ($volMap.Keys | Sort-Object)) {
                if (-not $assigned.ContainsKey($k) -and $volMap[$k].Type -eq 'Fixed') { $k }
            })
            if ($leftFixed.Count) {
                $fixedDisks = @($physical | Where-Object { $_.Kind -eq 'Fixed' })
                if ($fixedDisks.Count -eq 1) {
                    foreach ($k in $leftFixed) {
                        $fixedDisks[0].Volumes += $volMap[$k]
                        $assigned[$k] = $true
                    }
                    $fixedDisks[0].Volumes = @($fixedDisks[0].Volumes | Sort-Object { $_.Drive })
                    $mapSource = 'single-disk'
                } else {
                    Write-CollectorLog $Shared ("disks: " + $leftFixed.Count +
                        " fixed volume(s) could not be matched to a physical disk (" +
                        ($leftFixed -join ',') + "); listed under 'other volumes'")
                }
            }

            # Fallback C: no physical disk at all (some virtual machines and storage
            # drivers expose nothing through Win32_DiskDrive). Rather than showing an
            # empty card, group the local volumes under one entry.
            if (-not $physical.Count) {
                $localVols = @(foreach ($k in ($volMap.Keys | Sort-Object)) {
                    if ($volMap[$k].Type -eq 'Fixed') { $assigned[$k] = $true; $volMap[$k] }
                })
                if ($localVols.Count) {
                    $tot = 0.0
                    foreach ($v in $localVols) { $tot += [double]$v.TotalGB }
                    $physical += @{
                        Model      = 'Local disks'
                        Interface  = ''
                        BusType    = ''
                        MediaType  = ''
                        Kind       = 'Fixed'
                        IsVirtual  = $false
                        SizeGB     = [math]::Round($tot, 2)
                        Partitions = $localVols.Count
                        Status     = 'OK'
                        Volumes    = $localVols
                        ReadKBs    = [math]::Round((($localVols | Measure-Object ReadKBs -Sum).Sum), 1)
                        WriteKBs   = [math]::Round((($localVols | Measure-Object WriteKBs -Sum).Sum), 1)
                        BusyPct    = [math]::Round((($localVols | Measure-Object BusyPct -Maximum).Maximum), 1)
                    }
                    $mapSource = 'no-physical-disk'
                }
            }

            if ($mapSource -ne 'associators' -and $mapSource -ne $script:lastMapSource) {
                Write-CollectorLog $Shared "disks: volume mapping resolved through '$mapSource'"
                $script:lastMapSource = $mapSource
            }

            # Volumes not bound to a physical drive (network shares, optical, virtual)
            $other = @(foreach ($k in ($volMap.Keys | Sort-Object)) { if (-not $assigned.ContainsKey($k)) { $volMap[$k] } })

            $snap.Disks = @{
                Physical = @($physical | Sort-Object @{Expression={ if ($_.Kind -eq 'Fixed') {0} else {1} }}, Model)
                Other    = $other
                Volumes  = @($volMap.Keys | Sort-Object | ForEach-Object { $volMap[$_] })   # flat list, kept for the API
            }

            $dkCache = $snap.Disks; $dkStamp = Get-Date
            } catch { Write-CollectorLog $Shared "disks: $($_.Exception.Message) (collector line $($_.InvocationInfo.ScriptLineNumber))"
                      if ($dkCache) { $snap.Disks = $dkCache } }
            } else { $snap.Disks = $dkCache }

            # ================== NETWORK =====================================
            $now = Get-Date
            $nics = @()
            $totUp = 0.0; $totDown = 0.0
            $adapters = @()
            try { $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -ne 'Not Present' }) } catch { }
            if (-not $adapters.Count) { try { $adapters = @(Get-NetAdapter -ErrorAction Stop) } catch { } }

            if ($adapters.Count) {
                foreach ($a in $adapters) {
                    $st = $null
                    try { $st = Get-NetAdapterStatistics -Name $a.Name -ErrorAction Stop } catch { }
                    if (-not $st) { continue }
                    $rx = [double]$st.ReceivedBytes; $tx = [double]$st.SentBytes
                    $dn = 0.0; $up = 0.0
                    if ($prevNet.ContainsKey($a.Name) -and $prevTime) {
                        $dt = ($now - $prevTime).TotalSeconds
                        if ($dt -gt 0) {
                            $dn = [math]::Max(0, ($rx - $prevNet[$a.Name].Rx) / $dt)
                            $up = [math]::Max(0, ($tx - $prevNet[$a.Name].Tx) / $dt)
                        }
                    }
                    $prevNet[$a.Name] = @{ Rx = $rx; Tx = $tx }
                    $totDown += $dn; $totUp += $up
                    $nics += @{
                        Name        = $a.Name
                        Description = $a.InterfaceDescription
                        Mac         = $a.MacAddress
                        Status      = $a.Status
                        LinkMbps    = [math]::Round([double]$a.LinkSpeed.Split(' ')[0], 0)
                        LinkSpeed   = "$($a.LinkSpeed)"
                        DownKBs     = [math]::Round($dn / 1KB, 1)
                        UpKBs       = [math]::Round($up / 1KB, 1)
                        TotalRxGB   = [math]::Round($rx / 1GB, 2)
                        TotalTxGB   = [math]::Round($tx / 1GB, 2)
                    }
                }
            } else {
                # fallback for systems without the NetAdapter module
                foreach ($n in @(Get-CimSafe Win32_PerfFormattedData_Tcpip_NetworkInterface)) {
                    $nics += @{
                        Name        = $n.Name
                        Description = $n.Name
                        Mac         = ''
                        Status      = 'Up'
                        LinkMbps    = [math]::Round([double]$n.CurrentBandwidth / 1MB, 0)
                        LinkSpeed   = ''
                        DownKBs     = [math]::Round([double]$n.BytesReceivedPersec / 1KB, 1)
                        UpKBs       = [math]::Round([double]$n.BytesSentPersec / 1KB, 1)
                        TotalRxGB   = 0
                        TotalTxGB   = 0
                    }
                    $totDown += [double]$n.BytesReceivedPersec
                    $totUp   += [double]$n.BytesSentPersec
                }
            }
            $prevTime = $now

            # IP configuration
            $ipconf = @()
            foreach ($c in @(Get-CimSafe Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE')) {
                $ipconf += @{
                    Description = $c.Description
                    Mac         = $c.MACAddress
                    IPv4        = (@($c.IPAddress) | Where-Object { $_ -notmatch ':' }) -join ', '
                    IPv6        = (@($c.IPAddress) | Where-Object { $_ -match ':' }) -join ', '
                    Subnet      = (@($c.IPSubnet) | Where-Object { $_ -notmatch ':' }) -join ', '
                    Gateway     = (@($c.DefaultIPGateway)) -join ', '
                    Dns         = (@($c.DNSServerSearchOrder)) -join ', '
                    Dhcp        = [bool]$c.DHCPEnabled
                    DhcpServer  = $c.DHCPServer
                }
            }
            $tcpConn = 0
            try { $tcpConn = @(Get-NetTCPConnection -State Established -ErrorAction Stop).Count } catch { }

            $snap.Network = @{
                Adapters      = $nics
                IpConfig      = $ipconf
                TotalDownKBs  = [math]::Round($totDown / 1KB, 1)
                TotalUpKBs    = [math]::Round($totUp / 1KB, 1)
                Connections   = $tcpConn
            }

            # ================== PROCESSES (tier: every 5 s) =================
            $prEvery = [math]::Max(5, $Shared.Interval)
            if ((-not $prCache) -or (((Get-Date) - $prStamp).TotalSeconds -ge $prEvery)) {
            try {
            $nCpu = [math]::Max(1, [int]$static.CpuLogical)
            $procs = @()

            # Real image names: the performance counter class reports "chrome" or
            # "chrome#1", never the file name, so Win32_Process is used to get the
            # executable with its extension and its full path.
            $imgMap = @{}
            foreach ($wp in @(Get-CimSafe Win32_Process)) {
                $imgMap["$($wp.ProcessId)"] = @{
                    File = "$($wp.Name)"                 # e.g. "sqlservr.exe"
                    Path = "$($wp.ExecutablePath)"       # e.g. "C:\Program Files\...\sqlservr.exe"
                }
            }

            $pp = @(Get-CimSafe Win32_PerfFormattedData_PerfProc_Process)
            if ($pp.Count) {
                foreach ($p in ($pp | Where-Object { $_.Name -ne '_Total' -and $_.IDProcess -ne 0 } |
                                Sort-Object { [double]$_.PercentProcessorTime } -Descending)) {
                    $key  = "$([int]$p.IDProcess)"
                    $file = $null
                    $path = ''
                    if ($imgMap.ContainsKey($key)) { $file = $imgMap[$key].File; $path = $imgMap[$key].Path }
                    if (-not $file) {
                        # last resort: counter name without the #n suffix, plus .exe
                        $file = ($p.Name -replace '#\d+$', '')
                        if ($file -notmatch '\.[A-Za-z0-9]{2,4}$') { $file = "$file.exe" }
                    }
                    $procs += @{
                        Name    = $file
                        Path    = $path
                        Pid     = [int]$p.IDProcess
                        CpuPct  = [math]::Round([double]$p.PercentProcessorTime / $nCpu, 1)
                        RamMB   = [math]::Round([double]$p.WorkingSetPrivate / 1MB, 1)
                        Threads = [int]$p.ThreadCount
                        Handles = [int]$p.HandleCount
                    }
                }
            } else {
                foreach ($p in (Get-Process | Sort-Object WorkingSet64 -Descending)) {
                    $key  = "$($p.Id)"
                    $file = if ($imgMap.ContainsKey($key)) { $imgMap[$key].File } else { "$($p.ProcessName).exe" }
                    $path = if ($imgMap.ContainsKey($key)) { $imgMap[$key].Path } else { '' }
                    $procs += @{ Name=$file; Path=$path; Pid=$p.Id; CpuPct=0;
                                 RamMB=[math]::Round($p.WorkingSet64/1MB,1);
                                 Threads=$p.Threads.Count; Handles=$p.HandleCount }
                }
            }

            $prCache = $procs; $prStamp = Get-Date
            } catch { Write-CollectorLog $Shared "processes: $($_.Exception.Message) (collector line $($_.InvocationInfo.ScriptLineNumber))"
                      $procs = @($prCache) }
            } else { $procs = $prCache }

            # ================== SERVICES / SYSTEM (tier: every 30 s) ========
            $svEvery = [math]::Max(30, $Shared.Interval)
            if ((-not $svCache) -or (((Get-Date) - $svStamp).TotalSeconds -ge $svEvery)) {
            try {
            $svcAll = @(Get-CimSafe Win32_Service)
            $svcStopped = @($svcAll | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } |
                ForEach-Object { @{ Name = $_.Name; Display = $_.DisplayName; State = $_.State } })

            # FULL service list (running ones first, then alphabetically)
            $svList2 = @(
                foreach ($sv in ($svcAll | Sort-Object @{Expression={ if ($_.State -eq 'Running') {0} else {1} }}, DisplayName)) {
                    @{
                        Name      = $sv.Name
                        Display   = $sv.DisplayName
                        State     = $sv.State
                        StartMode = $sv.StartMode
                        Pid       = [int]$sv.ProcessId
                        Account   = $sv.StartName
                        Path      = $sv.PathName
                    }
                }
            )

            $svCache = @{
                List    = $svList2
                Stopped = $svcStopped
                Total   = $svcAll.Count
                Run     = @($svcAll | Where-Object { $_.State -eq 'Running' }).Count
                Manual  = @($svcAll | Where-Object { $_.StartMode -eq 'Manual' }).Count
                Disab   = @($svcAll | Where-Object { $_.StartMode -eq 'Disabled' }).Count
                Users   = (@(Get-CimSafe Win32_LogonSession -Filter 'LogonType=2 OR LogonType=10').Count)
            }
            $svStamp = Get-Date
            } catch { Write-CollectorLog $Shared "services: $($_.Exception.Message) (collector line $($_.InvocationInfo.ScriptLineNumber))" }
            }
            if (-not $svCache) { $svCache = @{ List=@(); Stopped=@(); Total=0; Run=0; Manual=0; Disab=0; Users=0 } }
            $svcList = $svCache.List

            $lastBoot = if ($os2) { $os2.LastBootUpTime } else { $null }
            $uptime = if ($lastBoot) { (Get-Date) - $lastBoot } else { New-TimeSpan }

            $snap.System = @{
                Uptime        = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
                LastBoot      = if ($lastBoot) { $lastBoot.ToString('dd/MM/yyyy HH:mm:ss') } else { 'N/A' }
                ProcessCount  = $procs.Count
                ThreadCount   = ($procs | Measure-Object Threads -Sum).Sum
                ServicesTotal = $svCache.Total
                ServicesRun   = $svCache.Run
                ServicesDown  = $svCache.Stopped
                ServicesManual= $svCache.Manual
                ServicesDisab = $svCache.Disab
                LoggedUsers   = $svCache.Users
                DashboardUp   = [math]::Round(((Get-Date) - $Shared.Started).TotalMinutes, 0)
            }

            $snap.Processes = $procs
            $snap.Services  = $svcList

            # ================== WINDOWS EVENTS ==============================
            # Reading the event log is comparatively expensive: refresh it at most once a minute.
            if (((Get-Date) - $evStamp).TotalSeconds -ge 60) {
                try { $evCache = Get-RecentEvents }
                catch { Write-CollectorLog $Shared "events: $($_.Exception.Message)" }
                $evStamp = Get-Date
            }
            $snap.Events = $evCache

            # ================== LOG RETENTION ===============================
            if (((Get-Date) - $lastPurge).TotalHours -ge 24) {
                $lastPurge = Get-Date
                try {
                    $limit = (Get-Date).AddDays(-$Shared.LogKeepDays)
                    foreach ($f in @(Get-ChildItem -Path $Shared.LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue)) {
                        if ($f.LastWriteTime -lt $limit) { Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue }
                    }
                } catch { }
            }

            # ================== CHART HISTORY ===============================
            $Shared.Data = $snap
            $point = @{
                t    = $t0.ToString('HH:mm:ss')
                cpu  = $cpuTotal
                ram  = $snap.Memory.Percent
                dn   = $snap.Network.TotalDownKBs
                up   = $snap.Network.TotalUpKBs
            }
            [void]$Shared.History.Add($point)
            while ($Shared.History.Count -gt 120) { $Shared.History.RemoveAt(0) }
        }
        catch {
            # Never lose a whole cycle because of one metric: log where it broke
            # (message + line number) and publish whatever was collected so far,
            # so the dashboard keeps showing the sections that do work.
            Write-CollectorLog $Shared ("[COLLECTOR-ERROR] " + $_.Exception.Message +
                                        " (collector line " + $_.InvocationInfo.ScriptLineNumber + ")")
            try {
                if ($snap -and $snap.Timestamp) {
                    if (-not $snap.Disks -and $dkCache) { $snap.Disks = $dkCache }
                    if (-not $snap.Processes)           { $snap.Processes = @($prCache) }
                    if (-not $snap.Services -and $svCache) { $snap.Services = $svCache.List }
                    if (-not $snap.Events)              { $snap.Events = $evCache }
                    $Shared.Data = $snap
                }
            } catch { }
        }

        # --------------------------------------------------------------------
        # Pacing.
        #
        # "Nobody is watching" means no /api/stats request for longer than a few
        # refresh intervals (at least 15 seconds). In that state the collector
        # does NOT sample at all: it just checks four times a second whether a
        # browser came back, which costs nothing measurable. Sampling restarts
        # within a quarter of a second of the first request.
        #
        # Set idle_seconds to a value greater than zero in settings.txt if you
        # prefer to keep sampling in the background to build up history.
        # --------------------------------------------------------------------
        $watchWindow = [math]::Max(15, $Shared.Interval * 5)
        $idleFor = ((Get-Date) - $Shared.LastRequest).TotalSeconds

        if ($idleFor -gt $watchWindow -and $Shared.IdleInterval -le 0) {
            # ---- nobody is watching: stop sampling completely ----------------
            if (-not $Shared.Paused) {
                $Shared.Paused = $true
                Write-CollectorLog $Shared "No client connected: sampling paused"
            }
            while ($Shared.Running -and ((Get-Date) - $Shared.LastRequest).TotalSeconds -gt $watchWindow) {
                Start-Sleep -Milliseconds 250
            }
            if ($Shared.Paused) {
                $Shared.Paused = $false
                Write-CollectorLog $Shared "Client connected: sampling resumed"
            }
            continue          # sample immediately, the visitor is waiting
        }

        $Shared.Paused = $false
        $target = if ($idleFor -gt $watchWindow) { $Shared.IdleInterval } else { $Shared.Interval }
        $elapsed = ((Get-Date) - $t0).TotalSeconds
        $sleep = [math]::Max(0.05, $target - $elapsed)
        # Sleep in small slices, so that 0.5 s and 1 s refreshes are accurate and
        # a returning browser is noticed straight away.
        $deadline = (Get-Date).AddSeconds($sleep)
        $wasIdle  = ($target -ne $Shared.Interval)
        while ($Shared.Running -and (Get-Date) -lt $deadline) {
            $left = ($deadline - (Get-Date)).TotalMilliseconds
            Start-Sleep -Milliseconds ([math]::Max(10, [math]::Min(100, $left)))
            if ($wasIdle -and ((Get-Date) - $Shared.LastRequest).TotalSeconds -lt 2) { break }
        }
    }
}

# ----------------------------------------------------------------------------
# Start the collector runspace
# ----------------------------------------------------------------------------
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = 'MTA'
$runspace.ThreadOptions  = 'ReuseThread'
$runspace.Open()
$runspace.SessionStateProxy.SetVariable('Shared', $Shared)
$ps = [powershell]::Create()
$ps.Runspace = $runspace
[void]$ps.AddScript($CollectorScript).AddArgument($Shared)
$handle = $ps.BeginInvoke()
$idleTxt = if ($Shared.IdleInterval -le 0) { 'paused when nobody is connected' } else { "$($Shared.IdleInterval)s when nobody is connected" }
Write-Log "Metric collector thread started (every $($Shared.Interval)s while watched, $idleTxt)."

# wait for the first sample
$wait = 0
while (-not $Shared.Data -and $wait -lt 30) { Start-Sleep -Milliseconds 500; $wait++ }

# ----------------------------------------------------------------------------
# HTML PAGE (dashboard)
# ----------------------------------------------------------------------------
$Html = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dashboard - __HOST__</title>
<style>
:root, html[data-theme="dark"]{
  --bg:#0d1117; --panel:#161b22; --panel2:#1c2330; --border:#283040;
  --txt:#e6edf3; --muted:#8b949e; --accent:#58a6ff;
  --ok:#3fb950; --warn:#d29922; --crit:#f85149;
  --head:linear-gradient(90deg,#161b22,#1c2b45); --input:#21262d; --hover:#2d3748;
  --track:#0b0f16; --thead:#1c2330; --sortbg:#232c3c; --scroll:#30363d;
}
html[data-theme="light"]{
  --bg:#eef1f6; --panel:#ffffff; --panel2:#f2f5fa; --border:#d3dae3;
  --txt:#1b2430; --muted:#5b6774; --accent:#0969da;
  --ok:#1a7f37; --warn:#9a6700; --crit:#cf222e;
  --head:linear-gradient(90deg,#ffffff,#dce9fb); --input:#f0f3f8; --hover:#e3ebf6;
  --track:#e6eaf0; --thead:#f2f5fa; --sortbg:#e3ebf6; --scroll:#b9c2cd;
}
html{transition:background .2s}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',Tahoma,sans-serif;font-size:14px;padding:16px}
header{display:flex;flex-wrap:wrap;align-items:center;gap:14px;margin:-16px -16px 16px;
  background:var(--head);border-bottom:1px solid var(--border);padding:12px 18px;
  position:sticky;top:0;z-index:30;backdrop-filter:blur(6px);box-shadow:0 2px 12px rgba(0,0,0,.28)}
header h1{font-size:19px;font-weight:600}
header h1 span{color:var(--accent)}
.badge{background:var(--input);border:1px solid var(--border);border-radius:20px;padding:4px 12px;font-size:12px;color:var(--muted)}
.badge b{color:var(--txt)}
.dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--ok);margin-right:6px;animation:pulse 2s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.35}}
.grid{display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(330px,1fr))}
.card{background:var(--panel);border:1px solid var(--border);border-radius:10px;padding:14px 16px}
.card.wide{grid-column:1/-1}
.card h2{font-size:13px;text-transform:uppercase;letter-spacing:.7px;color:var(--muted);margin-bottom:12px;
  display:flex;justify-content:space-between;align-items:center;gap:10px;border-bottom:1px solid var(--border);padding-bottom:8px}
.big{font-size:34px;font-weight:700;line-height:1}
.big small{font-size:14px;color:var(--muted);font-weight:400}
.sub{color:var(--muted);font-size:12px;margin-top:4px}
.bar{height:8px;background:var(--track);border-radius:5px;overflow:hidden;margin:7px 0}
.bar > i{display:block;height:100%;border-radius:5px;transition:width .5s ease,background .5s}
.row{display:flex;justify-content:space-between;gap:10px;padding:3px 0}
.row span:first-child{color:var(--muted)}
.kv{display:grid;grid-template-columns:auto 1fr;gap:4px 14px;font-size:13px}
.kv b{color:var(--muted);font-weight:400;white-space:nowrap}
.kv span{text-align:right;word-break:break-all}
table{width:100%;border-collapse:collapse;font-size:12.5px}
th{text-align:left;color:var(--muted);font-weight:500;padding:6px 8px;border-bottom:1px solid var(--border);
  position:sticky;top:0;background:var(--panel)}
td{padding:5px 8px;border-bottom:1px solid var(--border)}
tr:hover td{background:var(--hover)}
.num{text-align:right;font-variant-numeric:tabular-nums}
.cores{display:grid;grid-template-columns:repeat(auto-fill,minmax(86px,1fr));gap:8px;margin-top:6px}
.core{background:var(--panel2);border-radius:6px;padding:6px 8px}
.core div:first-child{font-size:10.5px;color:var(--muted)}
.core b{font-size:15px}
canvas{width:100%;height:120px;display:block}
.scroll{max-height:330px;overflow:auto}
.scroll-proc{height:360px;overflow-y:scroll;overflow-x:auto;border:1px solid var(--border);border-radius:8px;
  background:var(--panel2)}
.scroll-proc table{border-collapse:separate;border-spacing:0}
#tev td:last-child{max-width:640px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--muted)}
#tev tr.crit td:first-child{box-shadow:inset 3px 0 0 var(--crit)}
#tev tr.warn td:first-child{box-shadow:inset 3px 0 0 var(--warn)}
.scroll-proc th{position:sticky;top:0;z-index:2;background:var(--thead);box-shadow:0 1px 0 var(--border)}
th.sortable{cursor:pointer;user-select:none;-webkit-user-select:none;white-space:nowrap;transition:color .15s,background .15s}
th.sortable:hover{color:var(--txt);background:var(--hover)}
th.sortable .arr{display:inline-block;width:11px;font-size:10px;color:var(--accent);margin-left:3px;vertical-align:middle}
th.sorted{color:var(--txt);background:var(--sortbg)}
.tag{display:inline-block;padding:1px 7px;border-radius:4px;font-size:11px;background:var(--input);border:1px solid var(--border)}
.ok{color:var(--ok)} .warn{color:var(--warn)} .crit{color:var(--crit)}
input,select{background:var(--input);color:var(--txt);border:1px solid var(--border);border-radius:5px;
  padding:3px 8px;font-size:12px;text-transform:none;font-family:inherit}
footer{margin-top:18px;display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:12px;
  color:var(--muted);font-size:12px;padding:12px 4px;border-top:1px solid var(--border)}
footer .fside{display:flex;align-items:center;gap:10px}
footer .fside.right{justify-content:flex-end}
footer .fcenter{text-align:center;white-space:nowrap}
footer .fcenter b{color:var(--txt)}
@media(max-width:700px){footer{grid-template-columns:1fr;justify-items:center}footer .fside.right{justify-content:center}}
#langbtn,#themebtn,#setbtn{cursor:pointer;background:var(--input);border:1px solid var(--border);color:var(--txt);border-radius:6px;
  padding:5px 12px;font-size:12px;display:inline-flex;align-items:center;gap:6px;direction:ltr}
#langbtn:hover,#themebtn:hover,#setbtn:hover{background:var(--hover);border-color:var(--accent)}
.modal{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.65);z-index:50;
  align-items:center;justify-content:center;padding:20px}
.modal.on{display:flex}
.setbody{padding:16px 18px;overflow:auto;display:grid;gap:16px}
.setrow{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap}
.setrow.col{display:block}
.setrow label{display:flex;flex-direction:column;gap:2px;font-size:13.5px;color:var(--txt)}
.setrow .hint{font-size:11px;color:var(--muted)}
.setrow select{min-width:230px;padding:6px 10px;font-size:13px}
.seclist{margin-top:10px;display:grid;gap:8px;grid-template-columns:repeat(auto-fill,minmax(190px,1fr))}
.seclist label{flex-direction:row;align-items:center;gap:8px;background:var(--panel2);border:1px solid var(--border);
  border-radius:7px;padding:7px 10px;cursor:pointer;font-size:13px}
.seclist label:hover{border-color:var(--accent)}
.seclist input{accent-color:var(--accent);width:15px;height:15px}
.seclist input[disabled] + span, .seclist label.ro{opacity:.65;cursor:not-allowed}
.setrow select[disabled]{opacity:.65;cursor:not-allowed}
.modal-foot{padding:12px 18px;border-top:1px solid var(--border);display:flex;align-items:center;gap:10px}
.modal-foot .ok{flex:1;color:var(--ok);font-size:12.5px}
.btn{cursor:pointer;background:var(--input);border:1px solid var(--border);color:var(--txt);
  border-radius:6px;padding:7px 14px;font-size:13px;font-family:inherit}
.btn:hover{background:var(--hover);border-color:var(--accent)}
.btn.primary{background:var(--accent);border-color:var(--accent);color:#fff;font-weight:600}
.btn.primary:hover{filter:brightness(1.12)}
.modal-box{background:var(--panel);border:1px solid var(--border);border-radius:12px;width:min(760px,100%);
  max-height:82vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.6);direction:ltr;text-align:left}
.modal-box h3{padding:14px 18px;border-bottom:1px solid var(--border);font-size:15px;display:flex;
  justify-content:space-between;align-items:center}
.modal-box .close{cursor:pointer;color:var(--muted);font-size:20px;line-height:1;padding:0 4px}
.modal-box .close:hover{color:var(--crit)}
.langgrid{overflow:auto;padding:14px 18px;display:grid;gap:8px;grid-template-columns:repeat(auto-fill,minmax(230px,1fr))}
.langitem{cursor:pointer;background:var(--panel2);border:1px solid var(--border);border-radius:7px;padding:8px 11px;
  font-size:13px;transition:all .15s;text-align:left}
.langitem:hover{background:var(--hover);border-color:var(--accent)}
.langitem.cur{border-color:var(--accent);background:var(--sortbg)}
.langitem .en{color:var(--muted);font-size:11.5px}
.modal-note{padding:10px 18px;border-top:1px solid var(--border);color:var(--muted);font-size:11.5px}
/* --- physical disk boxes containing their partitions --- */
.dgroup{margin:16px 0 8px;font-size:12px;text-transform:uppercase;letter-spacing:.7px;color:var(--muted);border-top:1px solid var(--border);padding-top:10px}
.dbox.secondary{opacity:.85}
.dbox.secondary .dhead .name{font-size:14px;font-weight:500}
.dbox{background:var(--panel2);border:1px solid var(--border);border-radius:10px;padding:12px 14px;margin-bottom:12px}
.dhead{display:flex;flex-wrap:wrap;align-items:center;gap:10px;margin-bottom:10px;
  padding-bottom:8px;border-bottom:1px dashed var(--border)}
.dhead .name{font-size:15px;font-weight:600}
.dhead .meta{color:var(--muted);font-size:12px}
.dhead .io{margin-left:auto;font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums}
.parts{display:grid;gap:10px;grid-template-columns:repeat(auto-fit,minmax(255px,1fr))}
.part{background:var(--panel);border:1px solid var(--border);border-radius:8px;padding:10px 12px}
.part .pt{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:4px}
.part .pt b{font-size:15px}
.part .io{display:flex;justify-content:space-between;gap:8px;margin-top:6px;padding-top:6px;
  border-top:1px dashed var(--border);font-size:11.5px;color:var(--muted);font-variant-numeric:tabular-nums}
::-webkit-scrollbar{width:9px;height:9px}
::-webkit-scrollbar-thumb{background:var(--scroll);border-radius:5px}
</style>
</head>
<body>
<header>
  <h1>&#128421; <span data-i18n="app_title">Dashboard</span> <span id="host">__HOST__</span></h1>
  <div class="badge"><span class="dot"></span><span id="conn">-</span></div>
  <div class="badge"><span data-i18n="uptime">Uptime</span> <b id="uptime">-</b></div>
  <div class="badge"><span data-i18n="last_update">Last update</span> <b id="ts">-</b></div>
  <div class="badge" style="margin-left:auto"><span data-i18n="refresh_every">Refresh every</span>
    <select id="rate"></select>
  </div>
</header>

<div class="grid">
  <div data-sec="cpu" class="card">
    <h2><span data-i18n="cpu">CPU</span> <span id="cpuname" style="text-transform:none;letter-spacing:0"></span></h2>
    <div class="big"><span id="cpupct">-</span><small>%</small></div>
    <div class="bar"><i id="cpubar" style="width:0%"></i></div>
    <div class="row"><span data-i18n="frequency">Frequency</span><b id="cpughz">-</b></div>
    <div class="row"><span data-i18n="cores">cores</span><b id="cpucores">-</b></div>
    <div class="row"><span data-i18n="temperature">Temperature</span><b id="cputemp">-</b></div>
    <div class="cores" id="corelist"></div>
  </div>

  <div data-sec="ram" class="card">
    <h2 data-i18n="ram">Memory (RAM)</h2>
    <div class="big"><span id="rampct">-</span><small>%</small></div>
    <div class="bar"><i id="rambar" style="width:0%"></i></div>
    <div class="row"><span data-i18n="used">Used</span><b id="ramused">-</b></div>
    <div class="row"><span data-i18n="free">Free</span><b id="ramfree">-</b></div>
    <div class="row"><span data-i18n="total">Total</span><b id="ramtot">-</b></div>
    <div class="row"><span data-i18n="pagefile">Page file</span><b id="ramswap">-</b></div>
    <div class="sub" id="rammod"></div>
  </div>

  <div data-sec="network" class="card">
    <h2 data-i18n="network">Network</h2>
    <div style="display:flex;gap:24px">
      <div><div class="sub">&#11015; <span data-i18n="download">Download</span></div>
        <div class="big" style="font-size:26px"><span id="netdn">-</span></div></div>
      <div><div class="sub">&#11014; <span data-i18n="upload">Upload</span></div>
        <div class="big" style="font-size:26px"><span id="netup">-</span></div></div>
    </div>
    <canvas id="netchart"></canvas>
    <div class="row"><span data-i18n="tcp_conn">Active TCP connections</span><b id="tcp">-</b></div>
  </div>

  <div data-sec="cpu_trend" class="card">
    <h2><span data-i18n="cpu_trend">CPU trend</span> <span id="cpunow" style="text-transform:none;letter-spacing:0"></span></h2>
    <canvas id="cpuchart" style="height:150px"></canvas>
    <div class="sub"><span style="color:#58a6ff">&#9632;</span> <span data-i18n="usage_cpu_legend"></span></div>
  </div>

  <div data-sec="ram_trend" class="card">
    <h2><span data-i18n="ram_trend">RAM trend</span> <span id="ramnow" style="text-transform:none;letter-spacing:0"></span></h2>
    <canvas id="ramchart" style="height:150px"></canvas>
    <div class="sub"><span style="color:#bc8cff">&#9632;</span> <span data-i18n="usage_ram_legend"></span></div>
  </div>

  <div data-sec="disks" class="card wide">
    <h2 data-i18n="disks">Disks and partitions</h2>
    <div id="disks"></div>
  </div>

  <div data-sec="os" class="card">
    <h2 data-i18n="os">Operating system</h2>
    <div class="kv" id="osinfo"></div>
  </div>

  <div data-sec="ip_config" class="card">
    <h2 data-i18n="ip_config">IP configuration</h2>
    <div class="scroll" id="ipinfo"></div>
  </div>

  <div data-sec="net_adapters" class="card">
    <h2 data-i18n="net_adapters">Network adapters</h2>
    <div class="scroll">
      <table><thead><tr>
        <th data-i18n="adapter_c">Adapter</th><th data-i18n="status">Status</th>
        <th class="num">&#11015; KB/s</th><th class="num">&#11014; KB/s</th>
        <th class="num" data-i18n="total_rx">Total RX</th><th class="num" data-i18n="total_tx">Total TX</th>
      </tr></thead><tbody id="nics"></tbody></table>
    </div>
  </div>

  <div data-sec="processes" class="card wide">
    <h2><span data-i18n="processes">Active processes</span>
      <span id="procount" style="text-transform:none;letter-spacing:0;flex:1"></span>
      <input id="pfilter" type="text" data-i18n-ph="filter_ph" autocomplete="off" style="width:180px">
    </h2>
    <div class="scroll-proc">
      <table id="tproc"><thead><tr>
        <th class="sortable" data-k="Name"><span data-i18n="process">Process</span><span class="arr"></span></th>
        <th class="sortable num" data-k="Pid"><span data-i18n="pid">PID</span><span class="arr"></span></th>
        <th class="sortable num" data-k="CpuPct"><span data-i18n="cpu_pct">CPU %</span><span class="arr"></span></th>
        <th class="sortable num" data-k="RamMB"><span data-i18n="ram_mb">RAM (MB)</span><span class="arr"></span></th>
        <th class="sortable num" data-k="Threads"><span data-i18n="threads_c">Threads</span><span class="arr"></span></th>
        <th class="sortable num" data-k="Handles"><span data-i18n="handles">Handles</span><span class="arr"></span></th>
      </tr></thead><tbody id="procs"></tbody></table>
    </div>
  </div>

  <div data-sec="services" class="card wide">
    <h2><span data-i18n="services">Services</span>
      <span id="svccount" style="text-transform:none;letter-spacing:0;flex:1"></span>
      <span style="display:flex;gap:6px;align-items:center">
        <select id="sstate">
          <option value="" data-i18n="all_states">All states</option>
          <option value="run" data-i18n="only_running">Running only</option>
          <option value="stop" data-i18n="only_stopped">Stopped only</option>
          <option value="prob" data-i18n="auto_not_started">Automatic not started</option>
        </select>
        <input id="sfilter" type="text" data-i18n-ph="filter_ph" autocomplete="off" style="width:180px">
      </span>
    </h2>
    <div class="scroll-proc">
      <table id="tsvc"><thead><tr>
        <th class="sortable" data-k="Display"><span data-i18n="display_name">Display name</span><span class="arr"></span></th>
        <th class="sortable" data-k="Name"><span data-i18n="service_name">Service name</span><span class="arr"></span></th>
        <th class="sortable" data-k="State"><span data-i18n="status">Status</span><span class="arr"></span></th>
        <th class="sortable" data-k="StartMode"><span data-i18n="startup">Startup</span><span class="arr"></span></th>
        <th class="sortable num" data-k="Pid"><span data-i18n="pid">PID</span><span class="arr"></span></th>
        <th class="sortable" data-k="Account"><span data-i18n="account">Account</span><span class="arr"></span></th>
      </tr></thead><tbody id="svclist"></tbody></table>
    </div>
    <div class="sub" style="margin-top:8px" id="svcsummary"></div>
  </div>

  <div data-sec="events" class="card wide">
    <h2><span data-i18n="events">Events</span>
      <span id="evcount" style="text-transform:none;letter-spacing:0;flex:1"></span>
      <span style="display:flex;gap:6px;align-items:center">
        <select id="evlevel">
          <option value="" data-i18n="all_levels">All levels</option>
          <option value="1" data-i18n="lvl_critical">Critical</option>
          <option value="2" data-i18n="lvl_error">Error</option>
          <option value="3" data-i18n="lvl_warning">Warning</option>
        </select>
        <input id="evfilter" type="text" data-i18n-ph="filter_ph" autocomplete="off" style="width:180px">
      </span>
    </h2>
    <div class="scroll-proc">
      <table id="tev"><thead><tr>
        <th class="sortable" data-k="Time"><span data-i18n="ev_time">Time</span><span class="arr"></span></th>
        <th class="sortable" data-k="Level"><span data-i18n="ev_level">Level</span><span class="arr"></span></th>
        <th class="sortable" data-k="Log"><span data-i18n="ev_log">Log</span><span class="arr"></span></th>
        <th class="sortable" data-k="Source"><span data-i18n="ev_source">Source</span><span class="arr"></span></th>
        <th class="sortable num" data-k="EventId"><span data-i18n="ev_id">Event ID</span><span class="arr"></span></th>
        <th class="sortable" data-k="Message"><span data-i18n="ev_message">Message</span><span class="arr"></span></th>
      </tr></thead><tbody id="evlist"></tbody></table>
    </div>
  </div>

</div>

<footer>
  <div class="fside left">
    <button id="setbtn" title="Dashboard settings">&#9881; <span id="setlabel">Settings</span></button>
    <button id="langbtn" title="Choose the dashboard language">&#127760; Language: <b id="curlang">English</b></button>
  </div>
  <div class="fcenter">ServerDashboard <b id="ver">__VERSION__</b></div>
  <div class="fside right">
    <span id="err" class="crit"></span>
    <button id="themebtn" title="Switch light / dark theme"><span id="themeicon">&#9788;</span> <span id="themelabel">Light theme</span></button>
  </div>
</footer>

<div id="setmodal" class="modal">
  <div class="modal-box">
    <h3>&#9881; <span data-i18n="settings">Settings</span> <span class="close" id="setclose">&times;</span></h3>
    <div class="setbody">
      <div class="setrow">
        <label><span data-i18n="theme">Theme</span>
          <span class="hint" data-i18n="stored_browser"></span></label>
        <select id="settheme">
          <option value="dark" data-i18n="theme_dark">Dark theme</option>
          <option value="light" data-i18n="theme_light">Light theme</option>
        </select>
      </div>
      <div class="setrow">
        <label><span data-i18n="language">Language</span>
          <span class="hint" data-i18n="stored_browser"></span></label>
        <select id="setlang"></select>
      </div>
      <div class="setrow">
        <label><span data-i18n="refresh_interval">Refresh interval</span>
          <span class="hint" data-i18n="stored_browser"></span></label>
        <select id="setrate"></select>
      </div>
      <div class="setrow col">
        <label><span data-i18n="sections">Visible sections</span>
          <span class="hint"><span data-i18n="stored_server"></span> &mdash;
            <b data-i18n="readonly_server"></b></span></label>
        <div id="setsections" class="seclist"></div>
      </div>
    </div>
    <div class="modal-foot">
      <button id="setreset" class="btn" data-i18n="restore_defaults">Restore defaults</button>
      <span id="setmsg" class="ok"></span>
      <button id="setcancel" class="btn" data-i18n="cancel">Cancel</button>
      <button id="setsave" class="btn primary" data-i18n="save">Save</button>
    </div>
  </div>
</div>

<div id="langmodal" class="modal">
  <div class="modal-box">
    <h3>&#127760; Select language <span class="close" id="langclose">&times;</span></h3>
    <div class="langgrid" id="langgrid"></div>
    <div class="modal-note">The language is detected automatically from the Windows display language
      (<b id="syslang">-</b>). Your choice is saved in this browser.</div>
  </div>
</div>

<script>
/* ===================== i18n ===================== */
var SYSLANG = "__SYSLANG__";
var VERSION = "__VERSION__";
var INTERVAL = "__INTERVAL__";
var LANGS = [];          /* [{code,native,english,dir}] */
var STR = {};            /* dizionario corrente */
var CURLANG = "en-US";

function T(k){ return (STR[k] !== undefined && STR[k] !== "") ? STR[k] : k; }

function pickLang(){
  var saved = LOCAL.lang;
  var codes = LANGS.map(function(l){ return l.code; });
  if (saved && codes.indexOf(saved) >= 0) return saved;
  if (codes.indexOf(SYSLANG) >= 0) return SYSLANG;                 /* es. it-IT */
  var pre = (SYSLANG || 'en').split('-')[0].toLowerCase();         /* es. it    */
  for (var i = 0; i < LANGS.length; i++){
    if (LANGS[i].code.split('-')[0].toLowerCase() === pre) return LANGS[i].code;
  }
  return codes.indexOf('en-US') >= 0 ? 'en-US' : (codes[0] || 'en-US');
}

function applyStatic(){
  try { DECSEP = (1.1).toLocaleString(CURLANG).replace(/1/g, '') || '.'; } catch (e) { DECSEP = '.'; }
  var els = document.querySelectorAll('[data-i18n]');
  for (var i = 0; i < els.length; i++){ els[i].textContent = T(els[i].getAttribute('data-i18n')); }
  var ph = document.querySelectorAll('[data-i18n-ph]');
  for (var j = 0; j < ph.length; j++){ ph[j].placeholder = T(ph[j].getAttribute('data-i18n-ph')); }
  document.title = T('app_title') + ' - ' + (document.getElementById('host').textContent || '');
  var cur = null;
  for (var k = 0; k < LANGS.length; k++){ if (LANGS[k].code === CURLANG) cur = LANGS[k]; }
  if (cur){
    document.getElementById('curlang').textContent = cur.native + ' (' + cur.english + ')';
    document.documentElement.dir = cur.dir || 'ltr';
    document.documentElement.lang = cur.code;
  }
  document.getElementById('themelabel').textContent = (THEME === 'dark') ? T('theme_light') : T('theme_dark');
  document.getElementById('setlabel').textContent = T('settings');
  paintConn();
  if (LANGS.length) { fillRates(); }
  paintHeaders('tproc'); paintHeaders('tsvc'); paintHeaders('tev');
}

function parseLangXml(txt){
  var d = new DOMParser().parseFromString(txt, 'text/xml');
  var out = {}, n = d.getElementsByTagName('string');
  for (var i = 0; i < n.length; i++){ out[n[i].getAttribute('key')] = n[i].textContent; }
  return out;
}

function setLang(code, save){
  return fetchLang(code).then(function(dict){
    STR = dict; CURLANG = code;
    if (save){ LOCAL.lang = code; saveLocal(); }
    applyStatic(); buildLangGrid();
    forceRepaint = true;
    if (lastData) render(lastData);
    forceRepaint = false;
    drawProcs(); drawSvcs(); drawEvents();
  });
}

function fetchLangList(){
  return fetch('api/languages?v=' + VERSION).then(function(r){ return r.json(); });
}

function fetchLang(code){
  return fetch('lang/' + code + '.xml?v=' + VERSION).then(function(r){ return r.text(); }).then(parseLangXml);
}

function buildLangGrid(){
  document.getElementById('langgrid').innerHTML = LANGS.map(function(l){
    return '<button class="langitem' + (l.code === CURLANG ? ' cur' : '') + '" data-code="' + l.code + '">' +
           '<div>' + l.native + '</div><div class="en">' + l.english + ' &bull; ' + l.code + '</div></button>';
  }).join('');
  var items = document.querySelectorAll('.langitem');
  for (var i = 0; i < items.length; i++){
    items[i].onclick = function(){ setLang(this.getAttribute('data-code'), true); closeLang(); };
  }
}

/* ===================== settings =====================
   Browser side  (localStorage key "dashsettings"): theme + language.
   Server side   (settings.json next to the script): refresh interval + visible sections.
   When no settings are found the defaults apply: dark theme, Windows display language,
   5 second refresh (the collector slows down to 15 minutes when nobody is connected),
   every section visible.                                                              */
var SECTIONS = ['cpu','cpu_trend','ram','ram_trend','network','net_adapters','ip_config',
                'disks','os','processes','services','events'];
var RATES = [0.5,1,2,5,10,15,30,60,300];
var SRV = { refreshSeconds: 0.5, idleSeconds: 0, sections: {} };
/* decimal separator of the chosen language, used for values like 0,5 */
var DECSEP = ',';   /* server settings */
var LOCAL = { theme: 'dark', lang: null, refresh: null };   /* refresh: null = use the server default */                         /* browser settings */

function loadLocal(){
  try {
    var raw = localStorage.getItem('dashsettings');
    if (raw) { var o = JSON.parse(raw); if (o && typeof o === 'object') {
      if (o.theme) LOCAL.theme = o.theme;
      if (o.lang)  LOCAL.lang  = o.lang;
      if (o.refresh != null && !isNaN(parseFloat(o.refresh))) LOCAL.refresh = parseFloat(o.refresh);
    } }
  } catch(e){ }
  return LOCAL;
}
function saveLocal(){ try { localStorage.setItem('dashsettings', JSON.stringify(LOCAL)); } catch(e){ } }

function loadServer(){
  /* If the server has no settings file (or it cannot be read) the built-in
     defaults below are used, so the panel always opens. */
  return fetch('api/settings?_=' + Date.now()).then(function(r){ return r.json(); })
    .then(function(o){
      if (o && o.refreshSeconds) { SRV = o; }
      if (!SRV.sections) { SRV.sections = {}; }
      return SRV;
    })
    .catch(function(){ if (!SRV.sections) SRV.sections = {}; return SRV; });
}
/* The server side settings (refresh interval and visible sections) are
   READ ONLY from the browser: they live in settings.txt and only somebody with
   access to the server can change them. Nothing is ever posted back. */
function saveServer(){ return Promise.resolve(SRV); }

function applySections(){
  var els = document.querySelectorAll('[data-sec]');
  for (var i = 0; i < els.length; i++){
    var k = els[i].getAttribute('data-sec');
    els[i].style.display = (SRV.sections && SRV.sections[k] === false) ? 'none' : '';
  }
}
/* The interval each visitor actually uses: their own choice if they made one,
   otherwise the default configured on the server in settings.txt. It only
   changes how often THIS browser asks for data - it does not touch the server
   settings, and it does not affect anybody else. */
function effRate(){
  return (LOCAL.refresh != null) ? LOCAL.refresh : SRV.refreshSeconds;
}
function applyRate(){
  clearInterval(timer);
  var sel = document.getElementById('rate');
  if (sel) sel.value = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  var s2 = document.getElementById('setrate');
  if (s2) s2.value = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  if (document.hidden) return;         /* nobody is watching: do not poll at all */
  timer = setInterval(load, Math.max(0.5, effRate()) * 1000);
}
function rateLabel(sec){
  if (sec >= 60) { var m = sec / 60; return m + ' ' + ((m === 1) ? T('minute') : T('minutes')); }
  if (sec < 1) return String(sec).replace('.', DECSEP) + ' ' + T('seconds');
  return sec + ' ' + ((sec === 1) ? T('second') : T('seconds'));
}
function fillRates(){
  var html = '<option value="">' + T('server_default') + ' (' + rateLabel(SRV.refreshSeconds) + ')</option>' +
             RATES.map(function(v){ return '<option value="'+v+'">'+rateLabel(v)+'</option>'; }).join('');
  var cur = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  ['rate','setrate'].forEach(function(id){
    var el = document.getElementById(id);
    if (el) { el.innerHTML = html; el.value = cur; }
  });
}
function fillSettings(){
  document.getElementById('settheme').value = THEME;
  document.getElementById('setlang').innerHTML = LANGS.map(function(l){
    return '<option value="'+l.code+'"'+(l.code===CURLANG?' selected':'')+'>'+l.native+' ('+l.english+')</option>';
  }).join('');
  document.getElementById('setrate').value = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  document.getElementById('setsections').innerHTML = SECTIONS.map(function(k){
    var on = !(SRV.sections && SRV.sections[k] === false);
    return '<label class="ro"><input type="checkbox" disabled data-sec-key="'+k+'"'+
           (on?' checked':'')+'> <span>'+T(k)+'</span></label>';
  }).join('');
  document.getElementById('setmsg').textContent = '';
}
function openLang(){ buildLangGrid(); document.getElementById('langmodal').className = 'modal on'; }
function closeLang(){ document.getElementById('langmodal').className = 'modal'; }
function openSettings(){ fillSettings(); document.getElementById('setmodal').className = 'modal on'; }
function closeSettings(){ document.getElementById('setmodal').className = 'modal'; }

function applySettings(){
  /* Only the personal, browser side choices can be saved: the refresh interval
     and the visible sections belong to the server and are not touched here. */
  var th = document.getElementById('settheme').value;
  var lg = document.getElementById('setlang').value;
  var rv = document.getElementById('setrate').value;
  LOCAL.theme = th;
  LOCAL.refresh = (rv === '') ? null : parseFloat(rv);
  saveLocal();
  applyRate();
  applyTheme(th, true);
  var p = (lg !== CURLANG) ? setLang(lg, true) : Promise.resolve();
  return p.then(function(){
    fillRates();
    document.getElementById('setmsg').textContent = T('saved_ok');
    setTimeout(function(){ var m = document.getElementById('setmsg'); if (m) m.textContent = ''; }, 2500);
  });
}
function resetSettings(){
  /* resets the personal choices only: dark theme, language of Windows and the
     refresh interval back to the one configured on the server */
  LOCAL.theme = 'dark'; LOCAL.lang = null; LOCAL.refresh = null; saveLocal();
  applyTheme('dark', true);
  applyRate();
  setLang(pickLang(), false).then(function(){ fillRates(); fillSettings(); });
}

/* ===================== theme (dark / light) ===================== */
var THEME = 'dark';
function applyTheme(t, save){
  THEME = (t === 'light') ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', THEME);
  document.getElementById('themeicon').innerHTML = (THEME === 'dark') ? '&#9788;' : '&#9789;';
  document.getElementById('themelabel').textContent = (THEME === 'dark') ? T('theme_light') : T('theme_dark');
  if (save) { LOCAL.theme = THEME; saveLocal(); }
  draw();
}
function initTheme(){ applyTheme(LOCAL.theme || 'dark', false); }
function cssVar(n){
  return (getComputedStyle(document.documentElement).getPropertyValue(n) || '').trim();
}

/* ===================== helpers ===================== */
var hist = [], lastData = null;
function col(v){ return v < 60 ? '#3fb950' : (v < 85 ? '#d29922' : '#f85149'); }
function cls(v){ return v < 60 ? 'ok' : (v < 85 ? 'warn' : 'crit'); }
function esc(s){ return String(s==null?'':s).replace(/[<>&]/g, function(c){return {'<':'&lt;','>':'&gt;','&':'&amp;'}[c];}); }
function fmt(n,d){ return (n==null?0:n).toFixed(d===undefined?1:d); }
function tState(v){ return v === 'Running' ? T('st_running') : (v === 'Stopped' ? T('st_stopped') : v); }
function tMode(v){ return v === 'Auto' ? T('sm_auto') : (v === 'Manual' ? T('sm_manual')
                 : (v === 'Disabled' ? T('sm_disabled') : v)); }

if (!Element.prototype.closest) {
  Element.prototype.closest = function(sel){
    var el = this;
    while (el && el.nodeType === 1) {
      if ((el.matches || el.msMatchesSelector).call(el, sel)) return el;
      el = el.parentElement;
    }
    return null;
  };
}

/* ===================== table sorting ===================== */
var lastProcs = [], lastSvcs = [], lastEvents = [];
/* Signatures of the last painted payload: the process, service, event and disk
   sections are re-rendered only when the server actually sent new data. With a
   1 second refresh this avoids rebuilding hundreds of rows every second, both
   on the browser and (through smaller work) on the server. */
var sig = { proc:'', svc:'', ev:'', disk:'' };
function quickSig(a){
  if (!a || !a.length) return '0';
  var s = a.length + '|';
  for (var i = 0; i < a.length; i += Math.max(1, Math.floor(a.length / 12))) {
    var o = a[i];
    s += (o.Pid || o.Name || o.EventId || o.Model || '') + ':' +
         (o.CpuPct != null ? o.CpuPct : (o.State || o.Time || o.BusyPct || '')) + ';';
  }
  return s;
}
var NUMKEYS = {Pid:1, CpuPct:1, RamMB:1, Threads:1, Handles:1, EventId:1, Level:1};
var DEFSORT = { tproc: {k:'CpuPct', d:-1}, tsvc: {k:'State', d:1}, tev: {k:'Time', d:-1} };
var sortState = { tproc: null, tsvc: null, tev: null };

function loadSort(id){
  if (sortState[id]) return sortState[id];
  var st = null;
  try { st = JSON.parse(localStorage.getItem('sort_' + id)); } catch(e){ }
  if (!st || !st.k) { st = { k: DEFSORT[id].k, d: DEFSORT[id].d }; }
  sortState[id] = st; return st;
}
function saveSort(id){ try { localStorage.setItem('sort_' + id, JSON.stringify(sortState[id])); } catch(e){ } }
function sortRows(rows, id){
  var st = loadSort(id), k = st.k, d = st.d;
  return rows.slice().sort(function(a,b){
    var x = a[k], y = b[k], r;
    if (k === 'State')      { x = (a.State === 'Running' ? 0 : 1); y = (b.State === 'Running' ? 0 : 1); }
    else if (k === 'StartMode') { var o = {Auto:0, Manual:1, Disabled:2};
                                  x = (o[a.StartMode] === undefined ? 3 : o[a.StartMode]);
                                  y = (o[b.StartMode] === undefined ? 3 : o[b.StartMode]); }
    if (NUMKEYS[k] || typeof x === 'number') { r = (parseFloat(x)||0) - (parseFloat(y)||0); }
    else { r = String(x==null?'':x).toLowerCase().localeCompare(String(y==null?'':y).toLowerCase()); }
    if (r === 0) { var sa = (a.Display || a.Name || ''), sb = (b.Display || b.Name || '');
                   return sa.toLowerCase().localeCompare(sb.toLowerCase()); }
    return r * d;
  });
}
function paintHeaders(id){
  var st = loadSort(id), ths = document.querySelectorAll('#' + id + ' th.sortable');
  for (var i = 0; i < ths.length; i++){
    var th = ths[i], on = (th.getAttribute('data-k') === st.k);
    th.className = th.className.replace(/\s*sorted/g, '') + (on ? ' sorted' : '');
    th.querySelector('.arr').innerHTML = on ? (st.d === 1 ? '&#9650;' : '&#9660;') : '';
  }
}
function initSort(id, redraw){
  var ths = document.querySelectorAll('#' + id + ' th.sortable');
  for (var i = 0; i < ths.length; i++){
    (function(th){
      th.onclick = function(){
        var k = th.getAttribute('data-k'), st = loadSort(id);
        if (st.k === k) { st.d = -st.d; } else { st.k = k; st.d = NUMKEYS[k] ? -1 : 1; }
        saveSort(id); paintHeaders(id); redraw();
      };
    })(ths[i]);
  }
  paintHeaders(id);
}

/* ===================== tables ===================== */
function drawProcs(){
  var box = document.getElementById('procs').closest('.scroll-proc');
  var top = box ? box.scrollTop : 0;
  var f = (document.getElementById('pfilter').value || '').toLowerCase();
  var rows = sortRows(lastProcs.filter(function(p){
      if (!f) return true;
      return ((p.Name || '') + ' ' + (p.Path || '')).toLowerCase().indexOf(f) >= 0;
  }), 'tproc');
  document.getElementById('procs').innerHTML = rows.length ? rows.map(function(p){
     /* always the real image name, extension included; full path in the tooltip */
     var nm = '<td title="'+esc(p.Path || p.Name).replace(/"/g,'&quot;')+'">'+esc(p.Name)+'</td>';
     return '<tr>'+nm+'<td class="num">'+p.Pid+'</td>'+
            '<td class="num '+cls(p.CpuPct)+'">'+fmt(p.CpuPct)+'</td>'+
            '<td class="num">'+fmt(p.RamMB)+'</td><td class="num">'+p.Threads+'</td><td class="num">'+p.Handles+'</td></tr>';
  }).join('') : '<tr><td colspan="6" class="sub">'+T('no_match_proc')+'</td></tr>';
  if (box) box.scrollTop = top;
}

function drawSvcs(){
  var box = document.getElementById('svclist').closest('.scroll-proc');
  var top = box ? box.scrollTop : 0;
  var f = (document.getElementById('sfilter').value || '').toLowerCase();
  var st = document.getElementById('sstate').value;
  var rows = lastSvcs.filter(function(v){
    if (f && (v.Display+' '+v.Name).toLowerCase().indexOf(f) < 0) return false;
    if (st === 'run'  && v.State !== 'Running') return false;
    if (st === 'stop' && v.State === 'Running') return false;
    if (st === 'prob' && !(v.StartMode === 'Auto' && v.State !== 'Running')) return false;
    return true;
  });
  rows = sortRows(rows, 'tsvc');
  document.getElementById('svccount').textContent = '\u2014 ' + rows.length + ' ' + T('shown_of') + ' ' + lastSvcs.length;
  document.getElementById('svclist').innerHTML = rows.length ? rows.map(function(v){
    var run = v.State === 'Running', bad = (v.StartMode === 'Auto' && !run);
    return '<tr><td>'+esc(v.Display)+'</td><td class="sub">'+esc(v.Name)+'</td>'+
           '<td><span class="tag '+(run?'ok':(bad?'crit':'warn'))+'">'+esc(tState(v.State))+'</span></td>'+
           '<td>'+esc(tMode(v.StartMode))+'</td><td class="num">'+(v.Pid?v.Pid:'-')+'</td>'+
           '<td class="sub">'+esc(v.Account||'-')+'</td></tr>';
  }).join('') : '<tr><td colspan="6" class="sub">'+T('no_match_svc')+'</td></tr>';
  if (box) box.scrollTop = top;
}

function evLevelName(n){
  return n === 1 ? T('lvl_critical') : (n === 2 ? T('lvl_error')
       : (n === 3 ? T('lvl_warning') : T('lvl_info')));
}
function evLevelCls(n){ return n === 1 ? 'crit' : (n === 2 ? 'crit' : (n === 3 ? 'warn' : 'ok')); }

function drawEvents(){
  var box = document.getElementById('evlist').closest('.scroll-proc');
  var top = box ? box.scrollTop : 0;
  var f = (document.getElementById('evfilter').value || '').toLowerCase();
  var lv = document.getElementById('evlevel').value;
  var rows = lastEvents.filter(function(e){
    if (lv && String(e.Level) !== lv) return false;
    if (f && ((e.Source||'')+' '+(e.Message||'')+' '+(e.Log||'')+' '+e.EventId).toLowerCase().indexOf(f) < 0) return false;
    return true;
  });
  rows = sortRows(rows, 'tev');
  document.getElementById('evcount').textContent =
      '\u2014 ' + rows.length + ' ' + T('shown_of') + ' ' + lastEvents.length + ' \u2014 ' + T('ev_recent');
  document.getElementById('evlist').innerHTML = rows.length ? rows.map(function(e){
    var c = evLevelCls(e.Level);
    return '<tr class="'+c+'"><td>'+esc(e.Time)+'</td>'+
           '<td><span class="tag '+c+'">'+esc(evLevelName(e.Level))+'</span></td>'+
           '<td>'+esc(e.Log)+'</td><td>'+esc(e.Source)+'</td>'+
           '<td class="num">'+e.EventId+'</td>'+
           '<td title="'+esc(e.Message).replace(/"/g,'&quot;')+'">'+esc(e.Message)+'</td></tr>';
  }).join('') : '<tr><td colspan="6" class="sub">'+T('no_match_ev')+'</td></tr>';
  if (box) box.scrollTop = top;
}

/* ===================== charts ===================== */
function chart(id, series, maxFixed){
  var c = document.getElementById(id); if(!c) return;
  var w = c.clientWidth, h = c.clientHeight;
  if(c.width !== w) c.width = w; if(c.height !== h) c.height = h;
  if (!c.getContext) return;
  var x = c.getContext('2d'); if (!x) return;
  x.clearRect(0,0,w,h);
  var max = maxFixed || 1;
  if(!maxFixed){ series.forEach(function(s){ s.data.forEach(function(v){ if(v>max) max=v; }); }); max*=1.2; }
  x.strokeStyle=cssVar('--border')||'#283040'; x.lineWidth=1;
  for(var g=0; g<=4; g++){ var y=h*g/4; x.beginPath(); x.moveTo(0,y); x.lineTo(w,y); x.stroke(); }
  series.forEach(function(s){
    var d=s.data, n=d.length; if(n<2) return;
    var step = w/(n-1);
    x.beginPath();
    d.forEach(function(v,i){ var y=h-(v/max)*h*0.95; if(i===0)x.moveTo(0,y); else x.lineTo(i*step,y); });
    x.strokeStyle=s.color; x.lineWidth=2; x.stroke();
    x.lineTo(w,h); x.lineTo(0,h); x.closePath();
    x.fillStyle=s.fill; x.fill();
  });
  x.fillStyle=cssVar('--muted')||'#8b949e'; x.font='10px Segoe UI';
  x.fillText(maxFixed?'100%':(max>1024? (max/1024).toFixed(1)+' MB/s' : Math.round(max)+' KB/s'), 4, 11);
}
function draw(){
  try {
  chart('cpuchart', [{data: hist.map(function(p){return p.cpu;}), color:'#58a6ff', fill:'rgba(88,166,255,.15)'}], 100);
  chart('ramchart', [{data: hist.map(function(p){return p.ram;}), color:'#bc8cff', fill:'rgba(188,140,255,.15)'}], 100);
  chart('netchart', [
    {data: hist.map(function(p){return p.dn;}), color:'#3fb950', fill:'rgba(63,185,80,.15)'},
    {data: hist.map(function(p){return p.up;}), color:'#f0883e', fill:'rgba(240,136,62,.12)'}]);
  } catch (e) { /* charts are optional: never let them break the page */ }
}

/* ===================== disks ===================== */
function partBox(v){
  var io = (v.ReadKBs != null)
      ? '<div class="io"><span>&#9660; '+fmt(v.ReadKBs)+' KB/s</span>'+
        '<span>&#9650; '+fmt(v.WriteKBs)+' KB/s</span>'+
        '<span class="'+cls(v.BusyPct)+'">'+T('busy')+' '+fmt(v.BusyPct)+'%</span></div>' : '';
  return '<div class="part">'+
    '<div class="pt"><b>'+esc(v.Drive)+' '+esc(v.Label||'')+'</b>'+
      '<span class="tag">'+esc(v.FileSystem||v.Type)+'</span></div>'+
    '<div class="bar" style="height:10px"><i style="width:'+v.Percent+'%;background:'+col(v.Percent)+'"></i></div>'+
    '<div class="row"><span>'+T('used')+'</span><b class="'+cls(v.Percent)+'">'+fmt(v.UsedGB,2)+' GB ('+fmt(v.Percent)+'%)</b></div>'+
    '<div class="row"><span>'+T('free')+'</span><b>'+fmt(v.FreeGB,2)+' GB</b></div>'+
    '<div class="row"><span>'+T('total')+'</span><b>'+fmt(v.TotalGB,2)+' GB</b></div>'+ io +
  '</div>';
}

function diskBox(p){
  var parts = (p.Volumes && p.Volumes.length)
      ? p.Volumes.map(partBox).join('')
      : '<div class="part sub" style="text-align:center">&mdash;</div>';
  var io = (p.ReadKBs != null)
      ? '<span class="io">'+T('activity')+': &#9660; '+fmt(p.ReadKBs)+' KB/s &nbsp; &#9650; '+
        fmt(p.WriteKBs)+' KB/s &nbsp; <span class="'+cls(p.BusyPct)+'">'+T('busy')+' '+fmt(p.BusyPct)+'%</span></span>' : '';
  var badges = [p.BusType, p.MediaType, p.Interface].filter(function(x){
      return x && x !== 'Unspecified' && x !== 'Other'; });
  if (p.IsVirtual) badges.push('virtual');
  var icon = (p.Kind === 'Removable') ? '&#128189;'
           : ((p.Kind === 'Optical') ? '&#128191;' : (p.IsVirtual ? '&#9729;' : '&#128190;'));
  return '<div class="dbox'+((p.Kind && p.Kind !== 'Fixed') ? ' secondary' : '')+'"><div class="dhead">'+
    '<span class="name">'+icon+' '+esc(p.Model)+'</span>'+
    '<span class="meta">'+esc(badges.join(' \u2022 '))+' &bull; '+fmt(p.SizeGB,1)+' GB &bull; '+
      p.Partitions+' '+T('partitions')+'</span>'+
    '<span class="tag '+(p.Status=='OK'?'ok':'warn')+'">'+esc(p.Status)+'</span>'+ io +
    '</div><div class="parts">'+parts+'</div></div>';
}

function renderDisks(dk){
  var all = dk.Physical || [];
  if (!all.length && !((dk.Other||[]).length)) {
    return '<div class="sub" style="padding:14px 2px">' + T('no_data') + '</div>';
  }
  var fixed = [], extra = [];
  all.forEach(function(p){
    var k = p.Kind || 'Fixed';
    /* Only removable and optical units are listed apart: a virtual disk is a
       real disk of a virtualized server, so it belongs to the main list. */
    (k === 'Removable' || k === 'Optical' ? extra : fixed).push(p);
  });
  var out = fixed.map(diskBox).join('');
  if (extra.length){
    out += '<div class="dgroup">' + T('other_devices') + '</div>' + extra.map(diskBox).join('');
  }
  if ((dk.Other||[]).length){
    out += '<div class="dgroup">' + T('other_volumes') + '</div>' +
           '<div class="dbox secondary"><div class="parts">' + dk.Other.map(partBox).join('') + '</div></div>';
  }
  return out;
}

/* ===================== render ===================== */
var forceRepaint = false;
function render(d){
  lastData = d;
  document.getElementById('host').textContent = d.Static.ComputerName;
  document.getElementById('ts').textContent = d.Timestamp.split(' ')[1];
  document.getElementById('uptime').textContent = d.System.Uptime;

  var c = d.Cpu;
  document.getElementById('cpuname').textContent = d.Static.CpuName;
  document.getElementById('cpupct').textContent = fmt(c.TotalLoad);
  var b = document.getElementById('cpubar'); b.style.width = Math.min(100,c.TotalLoad)+'%'; b.style.background = col(c.TotalLoad);
  document.getElementById('cpughz').textContent = fmt(c.CurrentGHz,2)+' GHz / '+T('max')+' '+fmt(c.MaxGHz,2)+' GHz';
  document.getElementById('cpucores').textContent = d.Static.CpuCores+' '+T('cores')+', '+d.Static.CpuLogical+' '+
      T('threads_w')+' ('+d.Static.CpuSockets+' '+T('sockets')+')';
  document.getElementById('cputemp').textContent = (c.Temperatures && c.Temperatures.length)
      ? c.Temperatures.map(function(t){return fmt(t.Celsius)+' \u00b0C';}).join(' | ') : T('temp_na');
  document.getElementById('cpunow').innerHTML = '<span class="'+cls(c.TotalLoad)+'">'+fmt(c.TotalLoad)+'%</span>';
  document.getElementById('corelist').innerHTML = (c.PerCore||[]).map(function(x){
     return '<div class="core"><div>'+T('core')+' '+esc(x.Core)+'</div><b class="'+cls(x.Load)+'">'+fmt(x.Load)+'%</b>'+
            '<div class="bar" style="margin:4px 0 0"><i style="width:'+Math.min(100,x.Load)+'%;background:'+col(x.Load)+'"></i></div></div>';
  }).join('');

  var m = d.Memory;
  document.getElementById('rampct').textContent = fmt(m.Percent);
  var rb = document.getElementById('rambar'); rb.style.width = m.Percent+'%'; rb.style.background = col(m.Percent);
  document.getElementById('ramnow').innerHTML = '<span class="'+cls(m.Percent)+'">'+fmt(m.Percent)+'%</span>';
  document.getElementById('ramused').textContent = fmt(m.UsedGB,2)+' GB';
  document.getElementById('ramfree').textContent = fmt(m.FreeGB,2)+' GB';
  document.getElementById('ramtot').textContent  = fmt(m.TotalGB,2)+' GB';
  document.getElementById('ramswap').textContent = fmt(m.SwapTotGB - m.SwapFreeGB,2)+' / '+fmt(m.SwapTotGB,2)+' GB';
  document.getElementById('rammod').innerHTML = (m.Modules||[]).map(function(x){
      return '<span class="tag">'+esc(x.Slot)+': '+x.SizeGB+' GB @ '+x.SpeedMhz+' MHz</span>'; }).join(' ');

  var n = d.Network;
  document.getElementById('netdn').innerHTML = (n.TotalDownKBs>1024? fmt(n.TotalDownKBs/1024,2)+' <small>MB/s</small>' : fmt(n.TotalDownKBs)+' <small>KB/s</small>');
  document.getElementById('netup').innerHTML = (n.TotalUpKBs>1024? fmt(n.TotalUpKBs/1024,2)+' <small>MB/s</small>' : fmt(n.TotalUpKBs)+' <small>KB/s</small>');
  document.getElementById('tcp').textContent = n.Connections;
  document.getElementById('nics').innerHTML = (n.Adapters||[]).map(function(a){
     return '<tr><td>'+esc(a.Name)+'<div class="sub">'+esc(a.Description)+' &bull; '+esc(a.LinkSpeed)+'</div></td>'+
            '<td><span class="tag '+(a.Status=='Up'?'ok':'crit')+'">'+esc(a.Status)+'</span></td>'+
            '<td class="num">'+fmt(a.DownKBs)+'</td><td class="num">'+fmt(a.UpKBs)+'</td>'+
            '<td class="num">'+fmt(a.TotalRxGB,2)+' GB</td><td class="num">'+fmt(a.TotalTxGB,2)+' GB</td></tr>';
  }).join('');
  document.getElementById('ipinfo').innerHTML = (n.IpConfig||[]).map(function(i){
     return '<div style="margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid #283040">'+
       '<b>'+esc(i.Description)+'</b><div class="kv" style="margin-top:4px">'+
       '<b>'+T('ipv4')+'</b><span>'+esc(i.IPv4)+'</span>'+
       '<b>'+T('subnet')+'</b><span>'+esc(i.Subnet)+'</span>'+
       '<b>'+T('gateway')+'</b><span>'+esc(i.Gateway||'-')+'</span>'+
       '<b>'+T('dns')+'</b><span>'+esc(i.Dns||'-')+'</span>'+
       '<b>'+T('mac')+'</b><span>'+esc(i.Mac)+'</span>'+
       '<b>'+T('dhcp')+'</b><span>'+(i.Dhcp?T('yes')+' ('+esc(i.DhcpServer||'')+')':T('no_static'))+'</span>'+
       '<b>'+T('ipv6')+'</b><span>'+esc(i.IPv6||'-')+'</span></div></div>';
  }).join('');

  document.getElementById('disks').innerHTML = renderDisks(d.Disks);

  var s = d.Static, sy = d.System;
  document.getElementById('osinfo').innerHTML =
    [[T('os'),s.OSName],[T('version_build'),s.OSVersion+' ('+T('build')+' '+s.OSBuild+')'],
     [T('architecture'),s.OSArch],[T('computer_name'),s.ComputerName],[T('domain'),s.Domain],
     [T('manufacturer'),s.Manufacturer+' '+s.Model],[T('bios'),s.Bios],[T('serial'),s.SerialNumber],
     [T('installed_on'),s.OSInstall],[T('last_boot'),sy.LastBoot],[T('uptime'),sy.Uptime],
     [T('processes'),sy.ProcessCount],[T('sessions'),sy.LoggedUsers]]
    .map(function(r){ return '<b>'+esc(r[0])+'</b><span>'+esc(r[1])+'</span>'; }).join('');

  lastProcs = d.Processes || [];
  document.getElementById('procount').textContent = '\u2014 ' + lastProcs.length + ' ' + T('procs_running');
  drawProcs();

  lastSvcs = d.Services || [];
  var down = (sy.ServicesDown||[]).length;
  document.getElementById('svcsummary').innerHTML =
      T('st_running')+': <b class="ok">'+sy.ServicesRun+'</b> &nbsp;&bull;&nbsp; '+
      T('st_stopped')+': <b>'+(sy.ServicesTotal-sy.ServicesRun)+'</b> &nbsp;&bull;&nbsp; '+
      T('auto_not_started')+': <b class="'+(down?'crit':'ok')+'">'+down+'</b> &nbsp;&bull;&nbsp; '+
      T('sm_manual')+': <b>'+sy.ServicesManual+'</b> &nbsp;&bull;&nbsp; '+
      T('sm_disabled')+': <b>'+sy.ServicesDisab+'</b> &nbsp;&bull;&nbsp; '+
      T('total')+': <b>'+sy.ServicesTotal+'</b>';
  drawSvcs();

  lastEvents = d.Events || [];
  var se = quickSig(lastEvents);
  if (se !== sig.ev || forceRepaint) { sig.ev = se; drawEvents(); }
}

/* ===================== polling ===================== */
/* The connection state is kept as a key, not as text: this way a language
   change repaints it immediately instead of waiting for the next poll (which
   with a 5 minute interval would mean staring at the old language for ages). */
var CONN = 'offline';
var CONNEXTRA = '';
function setConn(key, extra){
  CONN = key; CONNEXTRA = extra || '';
  paintConn();
}
function paintConn(){
  var el = document.getElementById('conn');
  if (el) el.textContent = T(CONN) + CONNEXTRA;
}

function load(){
  fetch('api/stats?_=' + Date.now()).then(function(r){ return r.json(); }).then(function(j){
    setConn('online');
    document.getElementById('err').textContent = '';
    hist = j.History || [];
    render(j.Current); draw();
  }).catch(function(e){
    setConn('offline');
    document.getElementById('err').textContent = T('error_l') + ': ' + e;
  });
}

var timer = setInterval(load, 5000);

document.getElementById('pfilter').addEventListener('input', drawProcs);
document.getElementById('sfilter').addEventListener('input', drawSvcs);
document.getElementById('sstate').addEventListener('change', drawSvcs);
document.getElementById('evfilter').addEventListener('input', drawEvents);
document.getElementById('evlevel').addEventListener('change', drawEvents);
document.getElementById('rate').onchange = function(){
  LOCAL.refresh = (this.value === '') ? null : parseFloat(this.value);
  saveLocal(); applyRate();
};
document.getElementById('setbtn').onclick = openSettings;
document.getElementById('setclose').onclick = closeSettings;
document.getElementById('setcancel').onclick = closeSettings;
document.getElementById('setsave').onclick = function(){ applySettings(); };
document.getElementById('setreset').onclick = resetSettings;
document.getElementById('setmodal').onclick = function(e){ if (e.target === this) closeSettings(); };
document.getElementById('themebtn').onclick = function(){ applyTheme(THEME === 'dark' ? 'light' : 'dark', true); };
document.getElementById('langbtn').onclick = function(){ document.getElementById('langmodal').className = 'modal on'; };
document.getElementById('langclose').onclick = function(){ document.getElementById('langmodal').className = 'modal'; };
document.getElementById('langmodal').onclick = function(e){ if (e.target === this) this.className = ''; };
window.addEventListener('resize', draw);
initSort('tproc', drawProcs);
initSort('tsvc', drawSvcs);
initSort('tev', drawEvents);
document.getElementById('syslang').textContent = SYSLANG;
loadLocal();
initTheme();

/* boot sequence: language list -> chosen language -> data */
loadServer().then(function(){
  try { applySections(); applyRate(); } catch (e) { }
  return fetchLangList();
}).catch(function(){ return []; }).then(function(list){
  LANGS = (list && list.length) ? list : [{code:'en-US', native:'English', english:'English', dir:'ltr'}];
  return setLang(pickLang(), false);
}).catch(function(){ }).then(function(){
  try { fillRates(); } catch (e) { }
  load();
});
</script>
</body>
</html>
'@

# Windows display language (e.g. it-IT): used as the dashboard default language
$SysLang = 'en-US'
try { $SysLang = (Get-UICulture).Name } catch { }
if (-not $SysLang) { try { $SysLang = (Get-Culture).Name } catch { } }
Write-Log "Windows display language detected: $SysLang"

$Html = $Html.Replace('__HOST__', $env:COMPUTERNAME).
              Replace('__INTERVAL__', "$IntervalSeconds").
              Replace('__SYSLANG__', $SysLang).
              Replace('__VERSION__', $DashboardVersion)

# ---------------------------------------------------------------------------
# Catalog of the available languages (the \lang folder of the package)
# ---------------------------------------------------------------------------
function Get-LanguageCatalog {
    $list = @()
    if (Test-Path $LangDir) {
        foreach ($f in (Get-ChildItem -Path $LangDir -Filter '*.xml' -File | Sort-Object Name)) {
            try {
                [xml]$x = Get-Content -Path $f.FullName -Raw -Encoding UTF8
                $list += @{
                    code    = $x.language.code
                    native  = $x.language.nativeName
                    english = $x.language.englishName
                    dir     = $(if ($x.language.dir) { $x.language.dir } else { 'ltr' })
                }
            } catch { Write-Log "Invalid language file: $($f.Name)" 'WARN' }
        }
    }
    if (-not $list.Count) { Write-Log "No language file found in $LangDir" 'WARN' }
    return ,$list
}
$LangCatalog = Get-LanguageCatalog
Write-Log "Available languages: $($LangCatalog.Count)"
$LangJson = $LangCatalog | ConvertTo-Json -Depth 3 -Compress
if ($LangCatalog.Count -eq 1) { $LangJson = "[$LangJson]" }
if (-not $LangJson) { $LangJson = '[]' }

# ----------------------------------------------------------------------------
# WEB SERVER
# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------
# Web server startup.
#
# At boot this script runs as SYSTEM before anybody logs on, and at that moment
# the network stack and the HTTP service (http.sys) may still be starting: the
# very first bind attempt often fails. Failing over to localhost there would be
# wrong - the dashboard would answer only on the server itself, which is exactly
# what made it look like "it works only after I log on".
#
# So: wait for the network, then keep retrying the real prefix for several
# minutes. localhost is used only for a genuine permission problem (no urlacl
# and not elevated), never because the machine is simply still booting.
# ----------------------------------------------------------------------------
$prefix = "http://+:$Port/"

# 1. wait for at least one usable IPv4 address (max 120 s)
$netDeadline = (Get-Date).AddSeconds(120)
do {
    $hasIp = $false
    # Fast check first (no WMI involved), then the CIM query as a second opinion:
    # if WMI is not answering yet we must not stay stuck here.
    try { $hasIp = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable() } catch { }
    if (-not $hasIp) {
        try {
            $hasIp = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' |
                       ForEach-Object { $_.IPAddress } |
                       Where-Object { $_ -and $_ -notmatch ':' -and $_ -ne '127.0.0.1' }).Count -gt 0
        } catch { }
    }
    if ($hasIp) { break }
    Write-Log "Waiting for the network stack to come up..."
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $netDeadline)

# 2. bind, retrying for up to 5 minutes
$listener  = $null
$attempt   = 0
$maxWait   = (Get-Date).AddMinutes(5)
$denied    = $false
$aclTried  = $false
while (-not $listener -and (Get-Date) -lt $maxWait) {
    $attempt++
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add($prefix)
        $l.Start()
        $listener = $l
        Write-Log "Web server listening on $prefix (attempt $attempt)"
    } catch {
        $m = $_.Exception.Message
        # 5 = access denied: the URL reservation is missing (or we are not elevated)
        if ($m -match 'Access is denied|accesso negato|5\)') {
            # Self-healing: running as SYSTEM we are allowed to create the
            # reservation ourselves. The account name is resolved from its SID,
            # because "NT AUTHORITY\SYSTEM" does not exist on a localized Windows.
            if (-not $aclTried) {
                $aclTried = $true
                Write-Log "Bind refused: trying to create the URL reservation automatically..." 'WARN'
                try {
                    $acct = (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
                            ).Translate([System.Security.Principal.NTAccount]).Value
                    $null = netsh http add urlacl url=$prefix user="$acct" 2>&1
                } catch { }
                $chk = (netsh http show urlacl url=$prefix 2>$null) -join "`n"
                if ($chk -notmatch [regex]::Escape($prefix)) {
                    $null = netsh http add urlacl url=$prefix sddl='D:(A;;GX;;;S-1-5-18)' 2>&1
                    $chk = (netsh http show urlacl url=$prefix 2>$null) -join "`n"
                }
                if ($chk -match [regex]::Escape($prefix)) {
                    Write-Log "URL reservation created. Retrying the bind..."
                    Start-Sleep -Seconds 1
                    continue
                }
                Write-Log "Could not create the URL reservation automatically." 'ERROR'
            }
            $denied = $true; break
        }
        Write-Log "Bind attempt $attempt failed ($m). Retrying in 5 s..." 'WARN'
        Start-Sleep -Seconds 5
    }
}

if (-not $listener) {
    if ($denied) {
        Write-Log "Access denied on $prefix - the URL reservation is missing." 'ERROR'
        Write-Log "Run Install.bat as administrator, or: netsh http add urlacl url=$prefix user=`"NT AUTHORITY\SYSTEM`"" 'ERROR'
        Write-Log "Falling back to localhost only: the dashboard will NOT be reachable from the LAN." 'WARN'
        try {
            $listener = New-Object System.Net.HttpListener
            $listener.Prefixes.Add("http://localhost:$Port/")
            $listener.Start()
        } catch {
            Write-Log "Startup failed: $($_.Exception.Message)" 'ERROR'
            exit 1
        }
    } else {
        # Still not bindable after 5 minutes (port busy, http.sys not ready...).
        # Exit with an error so the scheduled task restarts us automatically.
        Write-Log "Could not bind $prefix after $attempt attempts. Exiting so the task can restart." 'ERROR'
        exit 1
    }
}

$ips = @()
try { $ips = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' |
        ForEach-Object { $_.IPAddress } | Where-Object { $_ -and $_ -notmatch ':' -and $_ -ne '127.0.0.1' }) } catch { }
foreach ($ip in $ips) { Write-Log "Dashboard reachable at: http://${ip}:$Port/" }

# Say who we are in the Windows event log, so an administrator opening Event
# Viewer knows exactly what this process is and where to look.
Write-DashEvent 1 'Information' (@(
    "$BrandName v$DashboardVersion started.",
    '',
    'What it is : a read-only web dashboard that shows CPU, memory, disks,',
    '             network, processes, services and event log of this server.',
    'How        : a PowerShell script (this process) serves an embedded page',
    '             on port ' + $Port + ' and reads Windows counters through CIM/WMI.',
    '             It installs nothing else and runs no external command.',
    'Files      : ' + $Root,
    'Script     : ' + $PSCommandPath,
    'Task       : PiBOH Windows Server Dashboard (at system startup, as SYSTEM)',
    'Log        : ' + $LogDir + ' (one file per day, kept for ' + $LogKeepDays + ' days)',
    'Updates    : downloaded from github.com/' + $UpdateRepo + ' at every start',
    'Remove     : run Uninstall.bat in ' + $Root
) -join "`r`n")

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        try {
            $res.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate')
            $res.Headers.Add('Access-Control-Allow-Origin', '*')
            $path = $req.Url.AbsolutePath.ToLower()
            Update-SettingsIfChanged

            # Only real page/data requests count as "somebody is watching": a
            # language file or the favicon must not wake the collector up.
            if ($path -match '^/(api/stats/?|)$') { $Shared.LastRequest = Get-Date }

            switch -Regex ($path) {
                '^/api/settings/?$' {
                    # READ ONLY on purpose.
                    # What this endpoint returns is the server configuration:
                    # refresh_seconds is the DEFAULT interval suggested to the
                    # visitors, while the visible sections and the logging switch
                    # are decided here and here only. A visitor may choose a
                    # different refresh rate for their own browser, but nothing
                    # they do can change the configuration of the server, so any
                    # write attempt is refused and logged.
                    if ($req.HttpMethod -ne 'GET') {
                        Write-Log ("Refused a $($req.HttpMethod) on /api/settings from $($req.RemoteEndPoint.Address): settings are read-only") 'WARN'
                        $res.StatusCode = 403
                        $res.ContentType = 'application/json; charset=utf-8'
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"read-only: edit settings.txt on the server"}')
                    } else {
                        $res.ContentType = 'application/json; charset=utf-8'
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Shared.Settings | ConvertTo-Json -Depth 5 -Compress))
                    }
                }
                '^/api/stats/?$' {
                    $payload = @{
                        Current = $Shared.Data
                        History = @($Shared.History)
                    } | ConvertTo-Json -Depth 8 -Compress
                    $res.ContentType = 'application/json; charset=utf-8'
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
                }
                '^/api/languages/?$' {
                    $res.ContentType = 'application/json; charset=utf-8'
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($LangJson)
                }
                '^/lang/[a-z0-9\-]+\.xml$' {
                    $file = Join-Path $LangDir ([System.IO.Path]::GetFileName($req.Url.AbsolutePath))
                    if (Test-Path $file) {
                        $res.ContentType = 'application/xml; charset=utf-8'
                        $bytes = [System.IO.File]::ReadAllBytes($file)
                    } else {
                        $res.StatusCode = 404
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes('<error>language file not found</error>')
                    }
                }
                '^/api/health/?$' {
                    $res.ContentType = 'text/plain; charset=utf-8'
                    $state = if ($Shared.Paused) { 'IDLE (sampling paused, nobody watching)' } else { 'SAMPLING' }
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes("OK $($env:COMPUTERNAME) v$DashboardVersion $state $(Get-Date -Format 'HH:mm:ss')")
                }
                '^/favicon.ico$' {
                    $res.StatusCode = 204
                    $bytes = [byte[]]@()
                }
                default {
                    $res.ContentType = 'text/html; charset=utf-8'
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Html)
                }
            }

            $res.ContentLength64 = $bytes.Length
            if ($bytes.Length) { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
        } catch {
            Write-Log "Request error: $($_.Exception.Message)" 'WARN'
        } finally {
            try { $res.OutputStream.Close() } catch { }
        }
    }
}
finally {
    Write-Log 'Shutting down...'
    $Shared.Running = $false
    try { $listener.Stop(); $listener.Close() } catch { }
    try { $ps.Stop(); $ps.Dispose(); $runspace.Close() } catch { }
    Write-Log '=== ServerDashboard stopped ==='
}

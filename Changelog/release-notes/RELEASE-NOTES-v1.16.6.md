# PiBOH Windows Server Dashboard v1.16.6

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`,
done. It works on 32-bit and 64-bit Windows: it is one PowerShell script,
run by whichever Windows PowerShell the machine has.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. When asked, type the optional password (or just press Enter for none)
   and choose what it protects: the whole page or only the server options
4. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.16.6

- **The CPU temperature now says where it comes from.** The reading is
  followed by the name of the source that produced it (Core Temp, Core
  Temp (log file), BIOS/ACPI, LibreHardwareMonitor, OpenHardwareMonitor,
  HWiNFO), `/api/stats` carries it as `Cpu.TempSource`, and the log gets
  one line the moment that source appears, changes or disappears -
  including the list of everything that was tried when nobody answers. A
  temperature is never shown without its source, and a missing one is no
  longer silent: it is one line in the log, not a guess.
- **Core Temp's own log file is a source of its own.** Turn Core Temp's
  logging on (Options > Enable logging) and the dashboard reads the
  newest `CT-Log*.csv` of its folder, by column name and only the "Cur."
  columns, so a different set of sensors keeps working. It needs no
  add-on and no plugin, and it works across logon sessions - the case the
  plain shared memory cannot cover, because that block belongs to the
  session of the user who started Core Temp while the installed dashboard
  runs as SYSTEM in session 0. Only fresh files are used (three logging
  periods, never less than a minute): an old log is a session that ended,
  and it is never shown as a current reading. New key in settings.txt:
  `coretemp_log`, the full path, when the log folder was moved.
- **CoreTempMappingObjectEx** is read too, the shared memory block of
  current Core Temp versions, together with the `Global\` copies created
  by "enable global shared memory" in its Advanced options - those are
  the ones a dashboard running as a service in another session can see.
- **The log and `/api/health` say which engine is running** ("32-bit
  engine on 64-bit Windows", ...): the same script serves 32-bit and
  64-bit Windows, and a support request can be answered without guessing.
- **A second CI job starts the whole dashboard with the 32-bit Windows
  PowerShell** (`%WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`)
  on every push: listener, CIM/WMI, temperature chain, JSON and the page
  are all checked there, so "it works on 32-bit" cannot break unnoticed.

- **The process list opens in name order** (A to Z, on the friendly name
  the column shows) instead of by CPU: with about two hundred rows a list
  that reorders itself at every refresh is hard to read. Clicking any
  column header still sorts by that column, and the choice is remembered
  per browser.
- **The Operating system card names the Windows release**: "Microsoft
  Windows 11 Home 25H2" (from DisplayVersion, or the ReleaseId on the
  older builds) and the version row carries the full revision,
  "10.0.26200.9457 (build 26200)". Win32_OperatingSystem reports neither
  of the two, and its ProductName still says "Windows 10" on Windows 11,
  so the name keeps coming from the Caption.

Fixed:

- **The dashboard used a lot more memory than it needed.** Two calls were
  behind it. The Disks section called `Get-PhysicalDisk` and
  `Get-Partition`, the Network section called `Get-NetAdapter`,
  `Get-NetAdapterStatistics` and `Get-NetTCPConnection`: those five load
  the Storage, NetAdapter and NetTCPIP modules, and the assemblies of
  those modules stay in the process for the rest of its life - 33, 12 and
  8 MB that `Remove-Module` does not give back (it returns 2 MB of them).
  They are replaced by the WMI classes the cmdlets read themselves
  (`MSFT_PhysicalDisk`, `MSFT_Partition`, `MSFT_NetAdapter`,
  `MSFT_NetAdapterStatisticsSettingData`, `MSFT_NetTCPConnection`), which
  answer through CIM - already loaded for every other metric - with the
  same values, and the words the cmdlets added are put back from the
  documented Windows values, so the page shows exactly what it showed
  before. Measured on a real Windows 11 machine with Core Temp running and
  a browser refreshing every 0.5 s, over nine minutes: **Task Manager's
  Memory column swung between 35.5 and 203.9 MB before, and now stays
  between 15.2 and 127.1 MB**, while private bytes went from 202.7-239.7 MB
  to 156.0-159.8 MB. The request loop also releases the wait handle and the
  response it creates per request now (handle count steady at 664-710
  against 804-960 before), `/api/stats` is serialized once per collector
  cycle instead of once per request (median fetch and parse: 4.7 ms against
  10.2 ms), and the memory trim no longer compiles a C# assembly at runtime
  to reach `EmptyWorkingSet` (that compilation alone was about 5 MB of
  working set; assigning the process its own `MaxWorkingSet` trims the same
  way, at least as well, with nothing to compile).
- **The dashboard could not update itself.** The stop helper also killed
  the process that was running the update (its own command line contains
  `ServerDashboard.ps1` with `-UpdateNow`), so the update died between
  "Stopping the dashboard..." and the install. It is never stopped now -
  neither by process list nor by port.
- **On a machine with no scheduled task, an update installed the new
  files and left nothing running**: the last-resort launch passed
  `-WindowStyle` twice, PowerShell refused to bind that, and the error
  was swallowed by a `catch`. The new version is running again after an
  update now.

Everything else stays as before: temperature chain with the sources above
(Core Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, self update from GitHub
(`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

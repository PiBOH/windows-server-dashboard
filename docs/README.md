==============================================================================
  SERVER DASHBOARD - web monitoring for Windows Server 2016
  Version 1.16.18
==============================================================================

A monitoring dashboard you can open from any computer on the local network by
simply typing the server IP address in a browser:

    http://192.168.1.10:8080

No installation, no agent, no third-party software: one .bat file and a
PowerShell script that starts a web server built into Windows. The interface
is translated into 38 languages and has a light and a dark theme.


------------------------------------------------------------------------------
1. FILES
------------------------------------------------------------------------------

Everything you normally need is in the root folder; the rest is tidied away.

    ServerDashboard\
    |
    +-- Install.bat              install and start (run as administrator)
    +-- Uninstall.bat            undo exactly what the installer changed
    +-- Start-Dashboard.bat      manual start, installs nothing
    +-- Stop-Dashboard.bat       stop the dashboard
    +-- settings.txt             server settings, editable with Notepad
    |
    +-- .config-do-not-delete-me\  the local secrets of this installation:
    |                             pwd (the password file, empty = none) and
    |                             settings-backup.txt (written by Install.bat)
    |
    +-- scripts\                 everything that runs
    |   +-- ServerDashboard.ps1          the engine
    |   +-- Diagnose.bat / Diagnose.ps1  read-only diagnostics
    |   +-- Repair-Autostart.bat         rebuild task + URL reservation
    |   +-- Test-Notification.bat        show the logon notification now
    |   +-- Update-Now.bat               check GitHub for a new version now
    |   +-- version.txt                  the version: single source of truth
    |   +-- Test-Syntax.ps1              parse check of every script
    |   +-- Test-Languages.ps1           lang\ folder: keys, placeholders,
    |                                    encoding
    |   +-- New-DashboardTask.ps1        registers the boot task as SYSTEM
    |   +-- Set-UrlAcl.ps1               URL reservation, localized names
    |   +-- Show-StartupNotification.ps1 the notification itself
    |   +-- Stop-DashboardProcess.ps1    stops the script and frees the port
    |   +-- Set-Password.ps1            set / change / remove the password
    |   +-- install-state.txt           what the installer changed (hidden,
    |                                    read-only; used by Uninstall.bat)
    |
    +-- lang\                    the 38 translations, one XML each
    |
    +-- screenshots\           the images used by the GitHub page
    |
    +-- Changelog\              CHANGELOG.md: the only changelog file
    |   |
    |   +-- release-notes\       RELEASE-NOTES-vX.Y.Z.md, one per release
    |
    +-- docs\                    README.md (this manual), logo.png,
    |                            Dashboard-Preview.html (offline preview,
    |                            generated - do not edit it here)
    |
    +-- logs\                    one file per day, kept 14 days:
                                 ServerDashboard-YYYY-MM-DD.log
                                 ServerDashboard-notify-YYYY-MM-DD.log
                                 previous-task-backup.xml

The four files you use day to day are in the root. Everything under scripts\
is called by them; you never need to open it, but nothing stops you. The logs\
folder is created automatically and stays empty when logging = no in
settings.txt.

------------------------------------------------------------------------------
2. SETUP (3 MINUTES)
------------------------------------------------------------------------------

1. Copy the whole folder to the server, for example C:\ServerDashboard\ - all
   files must stay together, including the lang\ subfolder.
2. Right-click Install.bat and choose "Run as administrator".
3. The installer inspects the machine, applies only the missing changes and
   prints a report with the BEFORE and AFTER value of each one:

       [+] Firewall rule "PiBOH Windows Server Dashboard 8080"
           BEFORE : not present  |  AFTER : created (inbound, TCP 8080)
       [=] URL reservation http://+:8080/
           BEFORE : already reserved  |  AFTER : unchanged
       [+] Scheduled task "PiBOH Windows Server Dashboard"
           BEFORE : not present  |  AFTER : created, runs at boot as SYSTEM

   The installer also asks whether to set an optional password: type it
   (masked, twice) or just press Enter for none. Right after, it asks what
   the password must protect - the whole page (total) or only the server
   options (partial) - and writes password_mode into settings.txt. The
   file .config-do-not-delete-me\pwd is always created: an empty file
   simply means "no password". Both can be changed at any time with
   scripts\Set-Password.ps1.

4. From another computer on the LAN open http://SERVER-IP:8080. The name
   of the server works too: http://SERVER-NAME:8080. Keep the http:// part
   (or at least the two slashes: //SERVER-NAME:8080): a bare
   SERVER-NAME:8080 is read by the browser as a web search, not as an
   address. That is a rule of every browser: no web server can change it.
   Two tricks make it shorter: after the first complete address the
   browser autocompletes it from the history while you type, and a name
   that contains a dot, like SRV01.COMPANY.LOCAL:8080, is accepted even
   without http:// (a single-word name never is; localhost:8080 is the
   only exception).

For a quick test without installing anything, use Start-Dashboard.bat.

To uninstall: right-click Uninstall.bat and choose "Run as administrator".
It reads install-state.txt and undoes exactly what was done: the task is
deleted (or the task that existed before is restored from previous-task-
backup.xml), the firewall rule and the URL reservation are removed only if the
installer created them, settings.txt is deleted only if it did not exist
before. Program files are never deleted.


------------------------------------------------------------------------------
3. WHAT THE DASHBOARD SHOWS
------------------------------------------------------------------------------

HEADER (always visible)
  The top bar is sticky: server name, connection state, uptime, last update
  and the refresh selector stay on screen while you scroll.

CPU
  Total load %, load per single core with bars, real clock speed in GHz and
  maximum frequency, socket/core/thread count, processor model, temperature,
  plus a dedicated trend chart.

  The dashboard never starts Core Temp and never keeps it alive: it only reads
  what Core Temp publishes by itself, and only while a Core Temp process is
  running. With Core Temp closed its sources are skipped entirely - its log
  file included, because a CT-Log that stopped being written is a session that
  ended - and the log says so once. When Core Temp runs, what decides it is
  Core Temp's own "start with Windows" option, never this dashboard.

  When Core Temp appears or disappears, the log says so and also names who
  started it: the parent process when it still exists, and the scheduled task
  that starts the same program, because the launcher of Core Temp is often
  already gone by the time the dashboard looks at it:

      Core Temp is running: ... (pid 15904, started by explorer.exe pid 9620)
      Core Temp is running: ... (pid 15904, started by pid 16212, which had
      already exited); a scheduled task starts the same program: "\Core Temp
      Autostart Utente"

  That line is the answer to "why does Core Temp keep coming back?": nothing
  in the dashboard launches anything but powershell.exe. What does, in almost
  every case, is Core Temp's own "start with Windows" option, which registers
  a task named like the one above: switch it off in Core Temp > Options, or
  delete that task.

  Temperature sources, tried in this order. The order matters: the programs
  that actually read the processor are asked first, and the ACPI thermal zone
  - a zone of the board, not the CPU - only as the last resort, so that a
  machine with Core Temp installed never shows a board zone in place of its
  processor. Except the Core Temp WMI add-on, which is off unless you ask for
  it, none of them needs an add-on, a plug-in or anything installed inside the
  dashboard:
    1. Core Temp, the plain program from alcpu.com: while it runs, Core
       Temp always publishes its readings in a shared memory block and the
       dashboard reads it directly - the 32-bit and the 64-bit build
       alike, one reading per core, Fahrenheit converted to Celsius
       automatically. Both the current block (CoreTempMappingObjectEx)
       and the older name (CoreTempMappingObject) are read. Install Core
       Temp and let it run: that is all. The plain block belongs to the
       logon session of Core Temp, so a dashboard started with
       Start-Dashboard.bat sees it, while the installed one (a boot task
       running as SYSTEM in session 0) needs either "enable global shared
       memory" in Core Temp > Options > Advanced, or one of the sources
       below.
    3. Core Temp's own log file: with logging enabled in Core Temp
       (Options > Enable logging) the same readings are also written to a
       CT-Log*.csv file in its folder, and the dashboard reads the newest
       one - by COLUMN NAME, only the "Cur." columns, which carry the
       current temperature of every core. This works across logon
       sessions and again needs no add-on: it is the source to pick when
       the dashboard runs as a service and Core Temp runs on the logged
       on desktop. Only fresh files are used (three logging periods,
       taken from Core Temp's own interval, never less than a minute): an
       old log is a session that ended, not a reading from now. If the
       log folder was moved in Core Temp's options, write the full path
       of the file in settings.txt:

           coretemp_log = C:\MyLogs\CT-Log 2026-10-13 18-42-37.csv

    3. Core Temp with its free "Core Temp WMI provider" add-on (namespace
       root\CoreTemp): same readings, but through WMI, which also works
       when Core Temp runs in another logon session than the dashboard.
       This one is OFF and stays off unless settings.txt says
       coretemp_wmi = yes. Why: a query to that namespace is the only
       thing the dashboard does that goes through Core Temp's own
       registration - the provider the add-on installed - instead of
       reading a block of shared memory or a CSV file that Core Temp
       publishes by itself, so it is the only Core Temp related thing
       worth being suspicious of on a machine where Core Temp's window
       keeps coming back. The two sources above cover the same ground
       without it: "enable global shared memory" in Core Temp > Options
       > Advanced makes the block readable from session 0 as well, and
       Core Temp's own logging works across sessions by design. If you
       had temperatures from this source and they are gone after updating,
       either turn it back on here or switch one of those two on.
    4. LibreHardwareMonitor or OpenHardwareMonitor, with the WMI option
       enabled (namespaces root\LibreHardwareMonitor and
       root\OpenHardwareMonitor).
    5. HWiNFO with its shared WMI provider enabled (root\HWiNFO).
    6. The ACPI thermal zone (MSAcpi_ThermalZoneTemperature), asked last and
       only when nothing above answered. It is not the CPU and it is not the
       BIOS either: it is a zone of the board, often the chassis, and the page
       and the log both show it for what it is - "ACPI thermal zone, not the
       CPU" - instead of passing it off as a reading of the processor. Many
       Dell, HP and Lenovo servers do not expose it at all, and a machine that
       does may still refuse it to a non-elevated process.
  The page prints the reading together with the name of the source it came
  from - Core Temp, Core Temp (log file), Core Temp (WMI add-on),
  LibreHardwareMonitor, OpenHardwareMonitor, HWiNFO, ACPI thermal zone, not
  the CPU - and /api/stats carries it as Cpu.TempSource. Next to the reading
  the page writes the unit asked for in settings.txt (temperature_unit):
  auto, the default, follows the language of Windows, C and F force it. Only
  the writing follows that choice - Cpu.Temperatures and the chart are always
  Celsius. If none of the sources answers, the dashboard writes "not
  available (no temperature source found)" instead of a wrong number, and
  the log gets one line naming every source that was tried: when a
  temperature is missing, that line is the first thing to read. The log
  says the same thing whenever the source appears, changes or disappears.
  Next to that message the page shows a small circular "?": it opens the
  short panel that explains why the reading can be missing, why the BIOS
  and the ACPI zone are not the answer, and links the download pages of
  the programs above. With a real reading the "?" is not drawn: there is
  nothing to explain.
  MSI Afterburner is deliberately not read: without a plugin it publishes
  no CPU temperature at all, only the graphics card, and this chain is
  about the CPU.

MEMORY
  Used, free and total in GB, percentage, page file, installed modules (slot,
  size, speed), plus its own trend chart.

DISKS AND PARTITIONS
  One box per physical drive (model, bus and media type, size, partition
  count, health status and live I/O) containing the boxes of its own
  partitions:

      [ disk ( partition 1 )( partition 2 ) ]

  Each partition shows drive letter, label, file system, used/free/total space
  with a coloured bar and its own read / write / busy activity.
  How a volume is matched to its disk: the classic WMI associators first, then
  the Storage module (MSFT_Partition / Get-Partition) when those return
  nothing, which happens with several RAID and storage drivers. If local
  volumes are still unmatched and the server has a single physical disk they
  are attached to it; if no physical disk is exposed at all, the local volumes
  are grouped under one entry called "Local disks". The log says which route
  was used ("disks: volume mapping resolved through ..."), and
  scripts\Diagnose.bat prints, disk by disk, which letters were matched.

  Only devices that are really not disks of the server - USB sticks, card
  readers and optical drives - are listed apart, at the bottom, under the
  heading "Other devices". Virtual disks (Hyper-V, VMware, VirtualBox, KVM,
  iSCSI) stay in the main list, because on a virtual machine they ARE the
  disks of the server: they simply carry a "virtual" badge and a cloud icon.
  Volumes with no physical drive, such as mapped network drives, are grouped
  under "Other volumes".

NETWORK
  Real-time download/upload (KB/s or MB/s), history chart, per-adapter
  figures, total RX/TX, link speed, status, MAC and the number of active TCP
  connections.

IP CONFIGURATION
  Per adapter: IPv4, subnet mask, gateway, DNS servers, IPv6, MAC, DHCP yes/no
  with its server.

OPERATING SYSTEM
  Name, version and build, architecture, computer name, domain, server
  manufacturer and model, BIOS, serial number, install date, last boot,
  uptime, user sessions.
  The name carries the release everybody knows ("Microsoft Windows 11 Home
  25H2", or "... Server 2022", from DisplayVersion, ReleaseId on the older
  builds) and the version row carries the full revision, build included
  ("10.0.26200.9457 (build 26200)"). Win32_OperatingSystem reports neither
  of the two: its Version stops at the build number, and its ProductName
  still says "Windows 10" on Windows 11, which is why the name comes from
  the Caption.

PROCESSES
  All running processes, in a scrollable pane with sticky headers. The
  main line of the first column is the friendly name of the executable
  ("Windows Explorer" for explorer.exe, "Task Manager" for taskmgr.exe),
  read from the version info of the file itself: it comes already in the
  language of the server, exactly like Task Manager shows it. The real
  image name, extension included (sqlservr.exe, w3wp.exe, svchost.exe),
  sits right under it in gray; when an executable has no friendly name the
  image name alone is shown. The dashboard itself is listed under its own
  name: the engine, which would otherwise be just another powershell.exe,
  is tagged "PiBOH Windows Server Dashboard", so it can be found in its own
  list. Hover a name to see the full path of the executable; the filter
  searches the image name, the friendly name and the path, so you can
  type "task manager", "exe" or a folder name too.
  The list opens sorted by that shown name, A to Z; clicking any column
  header sorts by it (and clicking the Process column sorts on the name it
  shows, the friendly one). The choice is remembered per browser.

SERVICES
  The complete service list with display name, internal name, state, startup
  type, PID and log-on account; text search plus a state filter (all / running
  / stopped / automatic not started) and a summary line.

BOTH TABLES: THE RIGHT-CLICK MENU
  A right click on a row of the process table or of the service table opens a
  small menu next to the pointer, naming the row it belongs to and offering:
  "Search the web" (a search for the image name, or for the service name, in a
  new browser tab), "Properties" (a panel with what the dashboard has about
  that row - a process: image name, friendly name, PID, CPU, memory, threads,
  handles and the full path; a service: display name, internal name, state,
  startup type, PID, log-on account and the path), "Copy name" and, when the
  row has a process behind it, "Copy PID". The copy confirms itself inside the
  menu, which then closes; on a plain http address, where the browser does not
  offer the clipboard to a page, it copies the old way and still works.
  Nothing in this menu kills a process or stops a service: the dashboard
  cannot do either, so it does not offer to. Escape, a click elsewhere, a
  resize or a scroll of the table close it, and anywhere outside those two
  tables the menu of the browser stays exactly what it always was.

EVENTS
  Critical, error and warning entries of the System and Application Windows
  event logs of the last 24 hours (up to 150), with timestamp, level, log,
  source, event ID and message (hover a row to read the full text). Text
  filter, level filter and sortable columns; newest first by default. Reading
  the event log is expensive, so this section is refreshed once a minute
  regardless of the dashboard refresh rate. To include other logs, such as
  Security, edit the LogName list in the Get-RecentEvents function inside
  ServerDashboard.ps1.

TABLE SORTING
  In every table you sort by clicking the column header, exactly like Windows
  File Explorer: click to sort, click again to reverse; a triangle marks the
  active column. The choice is stored in the browser. Numeric columns sort by
  value, text columns alphabetically.

BROWSER TAB
  The tab shows the logo of the package (docs\logo.png): the dashboard answers
  /favicon.ico with that file, read once and then served from memory like the
  page itself. Nothing is started and nothing is written to serve an icon, and
  the offline preview uses the same logo, so the tab looks the same on the
  server and in docs\Dashboard-Preview.html. If the file is missing the request
  is answered with the empty 204 the route gave before, and the tab falls back
  to the generic icon.


------------------------------------------------------------------------------
4. LANGUAGES
------------------------------------------------------------------------------

The dashboard is translated into 38 languages: every language Windows Server
2016 is fully localized in (Multilingual User Interface).

    ar-SA  bg-BG  cs-CZ  da-DK  de-DE  el-GR  en-GB  en-US  es-ES
    es-MX  et-EE  fi-FI  fr-CA  fr-FR  he-IL  hr-HR  hu-HU  it-IT
    ja-JP  ko-KR  lt-LT  lv-LV  nb-NO  nl-NL  pl-PL  pt-BR  pt-PT
    ro-RO  ru-RU  sk-SK  sl-SI  sr-Latn-RS  sv-SE  th-TH  tr-TR
    uk-UA  zh-CN  zh-TW

- Default language = Windows language. At startup the script reads Get-
  UICulture and the dashboard opens in that language. If the exact culture is
  missing the base language is used (de-CH becomes de-DE); if that is missing
  too it falls back to English.
- The footer button "Language" is always in English, so it stays recognizable
  in any translation. It opens an overlay window listing every language in its
  own script followed by the English name, for example "Italiano (Italian)" or
  "Nihongo (Japanese)". Click a language to apply it, press Escape or click
  outside to close.
- The choice is saved in the browser: every computer can read the dashboard in
  its own language without touching the server.
- Arabic and Hebrew switch the layout to right-to-left automatically.

Each language is an independent XML file in lang\ :

    <language code="it-IT" nativeName="Italiano"
              englishName="Italian" dir="ltr">
      <string key="cpu">CPU</string>
      ...
    </language>

To fix a translation edit the string and restart the service. To add a
language copy an existing file, change code, nativeName and englishName,
translate the values and restart: it shows up in the picker by itself, because
the catalog is read from the folder.

A language file carries the keys of lang\en-US.xml - no more, no less. A
missing key shows English text to somebody; a key nothing asks for is a string
kept for nothing. scripts\Test-Languages.ps1 is that contract, one rule per
line: every file parses, keeps UTF-8 with no BOM and CRLF endings, carries
exactly the keys of en-US.xml, has no empty value and keeps the placeholders
({0}, {1}, ...) of the English sentence. A language file that drifts fails it,
and the syntax check on GitHub runs it on every push, so the drift comes back
only as a red build.


------------------------------------------------------------------------------
5. THEME AND SETTINGS PANEL
------------------------------------------------------------------------------

The footer has three areas: settings and language buttons on the left,
"PiBOH Windows Server Dashboard <version>" in the centre, the light/dark theme
switch on the right. Dark is the default.

Clicking that centre line, the version, opens the **About** panel: who wrote
the dashboard, a link to the portfolio, the e-mail address, the repository and
the release list, and the changelog. The changelog is **not** shipped with the
package and not stored anywhere: it is read from
`raw.githubusercontent.com/PiBOH/windows-server-dashboard` every time the panel
opens, with a key that is never the same twice, so the browser never answers
from its own cache. The one cache that cannot be switched off is GitHub's own
CDN, which serves a file for up to five minutes before it re-reads the
repository: a change pushed a minute ago can therefore show up a few minutes
later. The panel needs internet access from the browser; when GitHub cannot be
reached it says so and shows nothing stale. What it reads is escaped before it is shown, so a change
on the remote file cannot inject markup into the page.

The gear button opens the settings panel:

| Option            | Stored where                 | Who can change it      |
|-------------------|------------------------------|------------------------|
| Theme             | browser cache (localStorage) | every visitor          |
| Language          | browser cache (localStorage) | every visitor          |
| Refresh interval  | browser cache (localStorage) | every visitor          |
| Default interval  | server, settings.txt         | on the server, or from |
|                   |                              | the panel with the pwd |
| Visible sections  | server, settings.txt         | (same as above)        |
| Logging           | server, settings.txt         | (same as above)        |
| Automatic updates | server, settings.txt         | (same as above)        |

Defaults: dark theme, language of Windows, half a second refresh, everything
visible, logging on.

- Theme, language and refresh interval are personal: every workstation keeps
  its own choice in its browser cache, and they are what the settings panel
  changes.
- The refresh interval offered by default is the one in settings.txt, shown in
  the list as "server default (5 seconds)". A visitor can pick any other value,
  from half a second to five minutes: it only changes how often THEIR browser
  asks for data, it does not touch the server and it does not affect the other
  viewers. Choosing "server default" again gives back the configured value.
- The server options (default interval, visible sections, logging, automatic
  updates) belong to the server, and what the panel lets you do depends on
  the password (see section 9):

      no password set    -> editable: Save writes these options into
                            settings.txt on the server, so nobody has to
                            open the file on the machine. Whoever can see
                            the page can change them, which is what the
                            password is for; every write is logged with the
                            address of the caller, and a write coming from
                            somebody else's page is refused (see section 9).
      password, partial  -> the options look normal: the password is asked
                            by a small popup the moment one of them is
                            clicked, never before. The server checks it
                            immediately (a wrong one is refused in red,
                            inside the popup); after that the options stay
                            editable and Save writes them to settings.txt.
      password, total    -> you already typed the password to open the page,
                            so the server options are editable directly.
- To change them, use the panel (see above) or edit settings.txt on the server
  with Notepad. The file is watched: the change is applied within ten seconds,
  no restart needed.
- settings.txt is created automatically at the first start, already filled
  with the default values, so the settings panel works from the very first
  start. It is a plain text
  file with one "key = value" per line, so you can also change it with Notepad
  and restart the service:

      refresh_seconds = 0.5      (0.5 - 3600, dot as decimal separator)
      idle_seconds    = 0        (0 = do not sample when nobody watches)
      mem_budget      = 20       (working set budget in MB, what Task Manager
                                  shows: over it the pages not in use are
                                  released. 0 = no budget)
      logging         = no       (never create a log file)
      coretemp_log    =          (full path of Core Temp's CT-Log*.csv,
                                  empty = search its install folders)
      coretemp_wmi    = no       (yes = also ask Core Temp's WMI add-on,
                                  see section on the temperature sources:
                                  off by default)
      temperature_unit = auto    (unit of the CPU temperature on the page:
                                  auto = the language of Windows decides,
                                  C or F force it. Only how the reading is
                                  written: the API is always Celsius)
      password_mode   = total    (with a pwd file: total = whole page,
                                  partial = server options only)
      show_cpu        = yes
      show_events     = no

  Unknown or misspelled keys are ignored, missing keys keep their default, and
  a deleted file is recreated with the defaults at the next start.
- Logging on/off follows the same rule as the other server options: it is in
  the panel and in settings.txt alike. With no password set, whoever can see
  the page can change it; with a password, only whoever knows it.
  The log is rotated every day: each day has its own file
  (logs\ServerDashboard-YYYY-MM-DD.log), so no file ever grows without
  limit, and the files older than 14 days are deleted automatically. With
  logging = no no log file is ever created. The setting is read before the
  first line would be written, and it survives every save made from the panel.
- If no settings are found (first run, or browser cache cleared) the defaults
  above are applied automatically. "Restore defaults" resets everything from
  the panel itself.
- Twelve sections can be hidden: CPU, CPU trend, Memory, RAM trend, Network,
  Network adapters, IP configuration, Disks and partitions, Operating system,
  Processes, Services, Events.

REFRESH RATE
  The refresh interval can be set to 0.5, 1, 2, 5, 10, 15, 30 seconds, 1
  minute or 5 minutes. Half a second gives a live view of CPU, memory and
  network; thanks to the tiered sampling described below, choosing 0.5 instead
  of 5 seconds does not multiply the load on the server.

TIERED SAMPLING (WHY IT IS CHEAP)
  Not all metrics cost the same, so they are not read at the same pace. Cheap
  performance counters are refreshed on every cycle, while the expensive
  queries run on their own slower schedule and are served from memory in
  between:

    +----------------------------+-------------------------------+
    | Metric                     | Read every                    |
    +----------------------------+-------------------------------+
    | CPU, memory, network       | every cycle (0.5 s by default) |
    | Processes                  | 5 seconds                     |
    | Disks and partitions       | 10 seconds                    |
    | Services, sessions         | 30 seconds                    |
    | Windows events             | 60 seconds                    |
    | OS, BIOS, CPU model, RAM   | once at startup               |
    +----------------------------+-------------------------------+

  The browser does its part too: the process, service, event and disk tables
  are rebuilt only when the data actually changed, and polling stops
  completely while the tab is in the background.

NOBODY WATCHING = NOTHING RUNNING
  When no browser has asked for data for a few refresh intervals (at least 15
  seconds), the collector stops sampling completely: it only checks four times
  a second whether somebody came back, which costs nothing. Sampling restarts
  within a quarter of a second of the first request, so the first page you
  open is already up to date.

  A browser tab moved to the background stops polling too, and says "Paused"
  in the header, so leaving the dashboard open on a forgotten tab does not
  keep the server busy.

  If you would rather keep collecting in the background, to have a continuous
  history, set idle_seconds in settings.txt to the number of seconds you want
  (for example 900 for a sample every 15 minutes). The default, 0, means "do
  not sample at all".

  The engine keeps its own footprint small too, and what decides when is the
  figure Task Manager shows, not a clock: as soon as the process goes over the
  working set budget (mem_budget in settings.txt, 20 MB by default) the pages
  it is not using are released on the spot. Nothing that is still needed is
  freed, and a page comes back by itself the moment the engine touches it
  again.

  What the engine keeps for itself, in exchange for all of that, is measured
  rather than assumed. Since 1.16.6 nothing here loads the Storage, NetAdapter
  or NetTCPIP module: the disk list, the partitions, the network adapters and
  the TCP connection count come from the same WMI classes the Get-PhysicalDisk,
  Get-Partition, Get-NetAdapter, Get-NetAdapterStatistics and Get-NetTCPConnection
  cmdlets read, without paying for the modules they live in - those stay in the
  process for its whole life (33, 12 and 8 MB) and Remove-Module gives back 2 MB
  of them. The JSON the browsers receive is built once per collector cycle and
  not once per request, so a page refreshing twice a second no longer builds the
  same 115 KB document twice a second. The memory trim does not compile a C#
  assembly any more either: EmptyWorkingSet had to be declared with Add-Type,
  and that compilation alone cost about 5 MB of working set, while assigning
  the process its own MaxWorkingSet trims the same way with nothing to compile.
  Measured on a Windows 11 machine with Core Temp running and a real browser
  refreshing every 0.5 s (220 processes, 279 services): the median time to fetch
  and parse a full /api/stats is 4.7 ms against 10.2 ms, and the handle count is
  steady at 664-710 against 804-960. What the working set does is measured
  separately, because it is the number Task Manager shows.

  That measurement was a side by side one: two builds of this dashboard on the
  same machine, each answering the same request stream at 0.5 s for seven
  minutes (840 requests each, 116 KB of JSON per reply, none failed), with the
  working set sampled four times a second. With the old five minute timer Task
  Manager's Memory column ran 21.4-156.5 MB, median 118.6, private bytes up to
  192.0 MB, 6.2% of a core; with the budget at its 20 MB default it ran 7.7-67.9
  MB, median 44.6, private bytes up to 158.4 MB, 11.8% of a core. A real browser
  tab on the same build is the friendlier case - it asks once a second, because
  a browser throttles the timers of a window that is not focused - and there the
  column ran 5.4-73.6 MB, median 21.1, 6.0% of a core.

  So the budget does what it says - the second after a trim really is 4-15 MB,
  and with nobody watching the process sits at 11 MB - but 20 MB is NOT held
  while a page is refreshing: 83% of the samples are above it (54% even in the
  friendlier browser case), by +24.6 MB at the median. The cause was measured as
  well: one sampling cycle puts a median of 30.0 MB (up to 42.5) back into the
  working set in under a second, and those are the pages that cycle needs
  resident - CIM machinery, managed heap, its own code - not the 116 KB reply,
  which at two requests a second is 0.23 MB/s. That they are pages and not
  retained heap was checked the same way: the private bytes of the process are
  the same 119.8 MB at the trough right after a trim and at the peak of the
  cycle that follows, while the working set swings by 64 MB in between. The
  committed heap does not move with the sawtooth, which is why no reduction of
  the per-cycle churn would bring the figure down. A budget under what a cycle
  touches means the engine releases and re-reads the same pages at every cycle:
  it doubles the CPU (6.2% -> 11.8%), it leaves about 80 trims a minute, and a
  request landing in the second after a trim costs 27% more (3.7 ms against
  2.9 ms median, on the request path). With the budget at 90 MB, same protocol,
  the number settles at a median of 72.9 MB (p95 88.2, 1.2% of the samples over
  90) with about 6 trims a minute and the CPU back to 6.2%: that is what the
  setting is for, capping the peak instead of asking for a figure the engine
  cannot hold.

  The trim is not free on its own either: it costs 26-36 ms to run and makes
  the first read of the pages it sent away about 23% slower (303 -> 373 ms on a
  deliberately touched 96 MB block), which is why it never runs on the request
  path. The same was done for the friendly
  names of the executables, which looked like the biggest remaining item: on the
  test server 210 processes map to only 46 distinct paths, so the once-per-path
  cache already avoids 57 of the 103 possible reads, and the whole set of
  descriptions - strings and cache together - retains 1.9 MB. It was left as it
  is, because it is not what the process is holding.


5-bis. SELF UPDATE
------------------------------------------------------------------------------

  At every start - including the automatic one at boot, which runs as SYSTEM
  without any logon - the dashboard reads scripts\version.txt from the main
  branch of github.com/PiBOH/windows-server-dashboard. If the published
  version is newer, the release tagged v<version> is downloaded, unpacked and
  copied over the current files, without ever touching settings.txt,
  the .config-do-not-delete-me folder, the logs folder or the local
  backups. The dashboard then restarts itself on the new version, and
  writes both a log line and an entry in the Windows event log.

  Since 1.16.0 the check is ALSO repeated every 24 hours while the dashboard
  runs, so a server that stays on for months does not need a reboot to
  receive an update: the running instance launches, detached, the very same
  cycle used by Update-Now.bat (download, stop, install, start), and a marker
  file keeps a manual run and the automatic one out of each other's way.

  Two more safety nets came with 1.16.0. Before handing over to a new version
  the script verifies that version.txt on disk really changed: if an install
  ever fails to land, the dashboard stays up on the current version instead
  of restarting in a loop. And every start removes the leftover folders of
  the pre-1.15.1 updater bug (the scripts\scripts nesting), which is what
  made updates look stuck on servers updated with an old version: run
  scripts\Update-Now.bat once with 1.16.0 and the installation cleans
  itself.

  Since 1.16.4 version.txt in every release carries a second line, the
  build commit written by the release workflow. The rule stays "the
  newer version wins", but when the version is the SAME and the commit
  differs the dashboard updates anyway: republishing the same number,
  which used to need a hand with the version file, now reaches every
  server by itself. The main branch keeps the one-line file, so every
  older version keeps reading it. The startup log also says which
  build commit is running.

  Since 1.16.2 the order is "page first": the update check runs after the
  web server is already answering, so a slow network can no longer keep
  the port closed at boot. And an update always ends with a running
  dashboard: the updater waits for the old instance to release the port,
  asks the task to start again and again and, as a last resort, launches
  the engine directly; when a hand over at boot cannot launch the new
  version, the current instance keeps serving instead of exiting.

  - The automatic check is switched on and off in settings.txt
    (auto_update = yes, the default, or no), and from the settings panel of
    the page: with no password whoever is looking at it, with a password
    only after typing it.
  - scripts\Update-Now.bat is the manual way: it checks GitHub and, when a
    new release exists, does the whole cycle by itself - download, stop the
    dashboard, install, start the dashboard again and wait for its answer.
    With no new release it prints "up to date" and changes nothing. It works
    even with auto_update = no, because it is an explicit request. Since
    1.16.4 it restarts itself as administrator, exactly like Diagnose.bat:
    stopping and starting the scheduled task, which runs as SYSTEM, needs
    those rights, and without them the old version would keep serving
    while the update looked successful.
  - ServerDashboard.ps1 -CheckUpdatesOnly only reports whether a new release
    exists (exit code 3 = available) and touches nothing.
  - Releases must be tagged v<version> for the updater to find them.


5-ter. LOGON NOTIFICATION
------------------------------------------------------------------------------

At every user logon a Windows notification says whether the dashboard started
correctly, in the Windows display language: the text is translated into all
the 38 languages, reading the same lang\*.xml files used by the page. It is
produced by Show-StartupNotification.ps1, run by the
scheduled task "PiBOH Windows Server Dashboard Notify" that Install.bat creates.

- The script waits up to 90 seconds for the service to answer on /api/health,
  because at logon the machine is still starting, then shows one of two
  messages, in the language of Windows:

      PiBOH Windows Server Dashboard - Dashboard started successfully
      Available at http://192.168.1.10:8080

      PiBOH Windows Server Dashboard - Dashboard is NOT running
      Check the newest logs\ServerDashboard-*.log for details

  The title is always the English product name: only the message under it
  follows the language of Windows.

- Three display methods are tried in order: a real Windows toast in the Action
  Center, a tray balloon tip, and finally a window drawn like a Windows 10
  toast in the bottom right corner, which always works on a desktop. Windows
  Server often has no Action Center, so the last one is what you usually see.
- The script waits for the shell (explorer.exe) before showing anything, and
  writes what it tried in the daily logs\ServerDashboard-notify-*.log.
- scripts\Test-Notification.bat shows the notification immediately, without logging
  off and on, so you can check it in five seconds.

- To disable it: schtasks /Delete /TN "PiBOH Windows Server Dashboard Notify" /F, or set
  startup_notification = no in settings.txt and remove the task.


------------------------------------------------------------------------------
5-quater. DO I HAVE TO LOG ON TO THE SERVER?
------------------------------------------------------------------------------

No, and since 1.11.4 the installer proves it to you: after creating the task it
reads it back and prints

    [OK] AUTOSTART VERIFIED: the task runs as SYSTEM with an "at system
         startup" trigger and logon type ServiceAccount.

The dashboard is a scheduled task that starts AT BOOT and runs as SYSTEM,
so it works with the server sitting at the lock screen, with no session open
and nobody logged on. After a reboot the page is already there: just open
http://SERVER-IP:8080 from your computer.

- The only thing that needs a logon is the courtesy notification described
  above, simply because a notification has to be shown to somebody: if no one
  logs on, nothing happens and the dashboard keeps running. The installer asks
  whether you want it, and you can answer N.

- To check the state without logging on to the console: Install.bat itself
  prints the result of a health check at the end of the installation, and from
  any computer you can open http://SERVER-IP:8080/api/health or run schtasks
  /Query /TN "PiBOH Windows Server Dashboard" /V /FO LIST from a remote shell.

- Start-Dashboard.bat is the only script that runs inside your session, and it
  exists just for a quick manual test: it stops when you log off. The
  installed task does not.

TASK "READY" BUT LAST RESULT 1, AND NO LOG FILE
  That combination always means the same thing: PowerShell could not even
  compile the script, so it exited with code 1 before writing anything. Run
  Test-Syntax.ps1 (Install.bat now runs it automatically before installing and
  refuses to continue if a file does not parse):

      powershell -ExecutionPolicy Bypass -File scripts\Test-Syntax.ps1

  It prints the file, the line and the column of every syntax error.

NOTIFICATION TASK WITH LAST RESULT 267011
  That code (0x41303) is not an error: it means "the task has never run yet".
  The notification is triggered at logon, so it will appear at the next one.
  To see it immediately, run scripts\Test-Notification.bat.

IF IT REALLY WORKS ONLY AFTER A LOGON
  Run scripts\Diagnose.bat (it elevates by itself, keeps the window open and, if you
prefer, can be run directly as powershell -ExecutionPolicy Bypass -File
Diagnose.ps1). It changes nothing and reports the task state (Run As
  User, Logon Mode), the process and its account, what is listening on the
  port, the URL reservation, the firewall rule, the answer of /api/health and
  the last lines of the log. The cause is almost always one of these three:

  1. The URL reservation is missing. Without it the script cannot bind
     http://+:8080/ and, up to version 1.11.0, it fell back to localhost: the
     page answered on the server only. Fix: run Install.bat as administrator.
     Since 1.11.1 that fallback happens only on a real permission error, and
     the log prints the netsh command to run.

  2. The folder is inside a user profile or a OneDrive folder, which a task
     running as SYSTEM may not be able to read at boot. Move it to
     C:\ServerDashboard\ and install again; the installer now warns you before
     doing anything.

  3. The task runs as your user instead of SYSTEM, or with "run only when the
     user is logged on". In Diagnose.bat, Run As User must be SYSTEM and Logon
     Mode must be "Background only".


------------------------------------------------------------------------------
6. HOW IT WORKS
------------------------------------------------------------------------------

- A background thread samples the metrics and keeps them in memory, so pages
  load instantly and the load on the server stays negligible: with the tiered
  sampling the average cost is well below 1% CPU even at a 1 second refresh,
  for about 40 MB of RAM.
- The web server is System.Net.HttpListener, a native Windows component: IIS
  is not installed and port 80 is left alone.
- The HTML page is embedded in ServerDashboard.ps1 (the $Html block) and
  served from memory; the language XML files and settings.txt are the only
  files read from disk at runtime. In the repository the page is edited as
  three files under _build\web\ (page.html, page.css, page.js) and
  spliced into that block by _build\Embed-Page.ps1, which the syntax
  check runs with -Check on every push; _build\ is not part of the package.
  The same build writes the offline preview in docs\ from those three files
  plus _build\preview\preview.js (the sample data, the 38 dictionaries and
  the answers that stand in for the server), so the preview and the served
  page are one page: there is no copy of the interface to keep in step.
- All metrics use CIM/WMI classes whose property names are always English, so
  the script works on any localized Windows.

  Endpoints:

| Endpoint         | Purpose                                    |
|------------------|--------------------------------------------|
| /                | the dashboard page                         |
| /api/stats       | full JSON, handy for Zabbix or Grafana     |
| /api/languages   | language catalog                           |
| /lang/<code>.xml | one dictionary                             |
| /api/settings    | GET reads; POST writes, see section 9      |
| /api/health      | state and version (never password asked)   |


------------------------------------------------------------------------------
7. CUSTOMIZATION
------------------------------------------------------------------------------

Open the .bat files with Notepad and edit the first lines:

    set "PORT=8080"      REM change the port
    set "INTERVAL=5"     REM seconds between two samples
    set "HIDDEN=1"       REM 0 = show the console with the live log

After changing the port run Uninstall.bat and then Install.bat again, so the
old firewall rule and URL reservation are cleaned up. The refresh interval can
also be changed at runtime from the settings panel; delete settings.txt to go
back to the defaults.


------------------------------------------------------------------------------
8. TROUBLESHOOTING
------------------------------------------------------------------------------

| Symptom                         | Fix                                    |
|---------------------------------|----------------------------------------|
| Works locally, not from the LAN | Firewall rule missing: run as admin    |
| Log says localhost ONLY         | Missing privileges: run as admin       |
| Port already in use             | netstat -ano | findstr :8080           |
| Updates never install, a       | The pre-1.15.1 updater left a          |
|   scripts\scripts folder       | scripts\scripts nest: update once by  |
|   exists                        | hand with Update-Now.bat (1.16.0       |
|                                 | removes the nest by itself)            |
| Temperature not available       | Read the "CPU temperature" line of the |
|                                 | log: it names every source that was    |
|                                 | tried. Let Core Temp run (the plain    |
|                                 | program is enough) or turn its logging |
|                                 | on, then see the source list above.    |
| Page does not refresh           | Check the newest logs\ServerDashboard-*.log |
| Browser never asks the password | password_mode = partial opens |
|                                 | the page BY DESIGN: run       |
|                                 | scripts\Diagnose.bat, it      |
|                                 | checks file and running       |
|                                 | service end to end            |
| Check the task state            | schtasks /Query /TN "PiBOH Windows Server Dashboard" /V |
| Uninstall                       | Run Uninstall.bat as administrator     |
| How do I find the dashboard     | It runs as powershell.exe (the name    |
| in Task Manager?                | "Windows PowerShell" belongs to        |
|                                 | the file): in the Details tab enable   |
|                                 | the "Command line" column and look     |
|                                 | for ServerDashboard.ps1                |


------------------------------------------------------------------------------
9. SECURITY
------------------------------------------------------------------------------

No command can be executed through the dashboard and nothing on the machine is
changed by looking at it: it only reads. The one thing a visitor can write is
the dashboard's own options in settings.txt (default interval, visible
sections, logging, automatic updates), and only from the settings panel. With
no password set, anyone on the LAN who can reach port 8080 can see the data
and change those options; the optional password is what limits that. A page of
another site is not enough: a write whose Origin is not the dashboard itself is
refused and logged, so a browser tab left open somewhere cannot reconfigure the
server. The check is on the browser, not on the wire: a script or another
program on the LAN that posts to /api/settings by itself is still accepted
while no password is set.
An optional password can close the whole page or just the server options.

OPTIONAL PASSWORD

The password lives in a plain text file called "pwd" (no file extension)
in the .config-do-not-delete-me folder at the root of the package, next
to the settings backup: .config-do-not-delete-me\pwd. The file always
exists - Install.bat asks for the password during the installation and
creates it, and the dashboard itself recreates it empty whenever it is
missing. An empty file simply means "no password". To set or change it
later run scripts\Set-Password.ps1 (masked input, Enter alone = no
password) or edit the file with Notepad: the password goes on the first
line. Empty the file (or delete it) to remove the password. Every change
applies within ten seconds, no restart needed. The key password_mode in
settings.txt decides what it protects:

    total   (default)  the whole dashboard asks for the password: the
                       browser opens its standard login window, and without
                       the password nothing at all is served.
    partial            everybody can look at the dashboard. The server
                       options look normal in the panel and a popup asks
                       for the password the moment one of them is clicked,
                       not before.

Worth knowing:

- The password itself is never sent to the browsers: /api/settings only
  reports whether one is set and in which mode. It is never written to the
  log either, and Diagnose.bat only reports whether it is set.
- No browser will ever offer to save this password - not Chrome, Edge,
  Safari or any other Chromium / WebKit browser, desktop or mobile, and
  not Firefox: where supported the popup field is technically not a
  password field at all (it only looks like one), elsewhere it belongs to
  no form and is never submitted. What you type stays in a JavaScript
  variable for the request only: never in the browser storage, never on
  disk.
- /api/health always stays open, even in total mode: the updater,
  Repair-Autostart.bat and the logon notification poll it to see whether
  the service answers, and it only carries the version number.
- A wrong password is logged with the address of the caller: for the page
  in total mode, and for a refused settings change in partial mode.
- In total mode any user name is accepted: only the password is checked.
- The pwd file is preserved by every update, is never published on GitHub
  (it is in .gitignore, so it is not in the release zip either) and is
  deleted by Uninstall.bat. Updating from 1.16.0 moves it automatically
  from the package root into the .config-do-not-delete-me folder.
- WARNING: like everything else in the dashboard, the password travels
  unencrypted on the local network (HTTP Basic authentication). It keeps
  curious colleagues out; it is no defense against somebody who can sniff
  the traffic or attack the server itself.

If the server is ever exposed to the Internet, restrict the firewall rule to
the local subnet:

    netsh advfirewall firewall set rule ^
          name="PiBOH Windows Server Dashboard 8080" ^
          new remoteip=192.168.1.0/24


------------------------------------------------------------------------------
10. VERSIONING
------------------------------------------------------------------------------

The current version is shown in the centre of the footer and returned by
/api/health. Changes follow Semantic Versioning (MAJOR.MINOR.PATCH); see
Changelog\CHANGELOG.md.

Current version: 1.16.18

==============================================================================
  SERVER DASHBOARD - web monitoring for Windows Server 2016
  Version 1.15.1
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
    +-- scripts\                 everything that runs
    |   +-- ServerDashboard.ps1          the engine
    |   +-- Diagnose.bat / Diagnose.ps1  read-only diagnostics
    |   +-- Repair-Autostart.bat         rebuild task + URL reservation
    |   +-- Test-Notification.bat        show the logon notification now
    |   +-- Update-Now.bat               check GitHub for a new version now
    |   +-- version.txt                  the version: single source of truth
    |   +-- Test-Syntax.ps1              parse check of every script
    |   +-- New-DashboardTask.ps1        registers the boot task as SYSTEM
    |   +-- Set-UrlAcl.ps1               URL reservation, localized names
    |   +-- Show-StartupNotification.ps1 the notification itself
    |   +-- Stop-DashboardProcess.ps1    stops the script and frees the port
    |
    +-- lang\                    the 38 translations, one XML each
    |
    +-- screenshots\           the images used by the GitHub page
    |
    +-- Changelog\              CHANGELOG.md: the only changelog file
    |
    +-- docs\                    README.md (this manual),
    |                            RELEASE-NOTES-vX.Y.Z.md, logo.png,
    |                            Dashboard-Preview.html (offline preview)
    |
    +-- logs\                    one file per day, kept 14 days:
                                 ServerDashboard-YYYY-MM-DD.log
                                 ServerDashboard-notify-YYYY-MM-DD.log
                                 install-state.txt, previous-task-backup.xml

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

       [+] Firewall rule "Server Dashboard 8080"
           BEFORE : not present  |  AFTER : created (inbound, TCP 8080)
       [=] URL reservation http://+:8080/
           BEFORE : already reserved  |  AFTER : unchanged
       [+] Scheduled task "PiBOH Windows Server Dashboard"
           BEFORE : not present  |  AFTER : created, runs at boot as SYSTEM

4. From another computer on the LAN open http://SERVER-IP:8080

For a quick test without installing anything, use Start-Dashboard.bat.

To uninstall: right-click Uninstall.bat and choose "Run as administrator".
It reads install-state.txt and undoes exactly what was done: the task is
deleted (or the task that existed before is restored from previous-task-
backup.xml), the firewall rule and the URL reservation are removed only if the
installer created them, settings.json is deleted only if it did not exist
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

  Temperature sources, tried in this order:
    1. BIOS/ACPI sensor (MSAcpi_ThermalZoneTemperature). Many Dell, HP and
       Lenovo servers do not expose it.
    2. Core Temp, through its free "Core Temp WMI provider" add-on (namespace
       root\CoreTemp). Install Core Temp, then its WMI provider plug-in, and
       make sure Core Temp starts with Windows: the dashboard picks it up
       automatically, one reading per core, and converts Fahrenheit to Celsius
       if needed.
    3. LibreHardwareMonitor or OpenHardwareMonitor, with the WMI option
       enabled (namespaces root\LibreHardwareMonitor and
       root\OpenHardwareMonitor).
    4. HWiNFO with its shared WMI provider enabled (root\HWiNFO).
  If none of them is available the dashboard writes "not available (no ACPI
  sensor)" instead of a wrong number.

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

PROCESSES
  All running processes with the real image name, extension included
  (sqlservr.exe, w3wp.exe, svchost.exe), PID, CPU %, RAM (MB), threads and
  handles, in a scrollable pane with sticky headers. Under every image name
  the dashboard also shows the friendly name of the executable ("Task
  Manager" under taskmgr.exe, "Windows Explorer" under explorer.exe), read
  from the version info of the file itself: it comes already in the language
  of the server, exactly like Task Manager shows it. Hover a name to see the
  full path of the executable; the filter searches the image name, the
  friendly name and the path, so you can type "task manager", "exe" or a
  folder name too.

SERVICES
  The complete service list with display name, internal name, state, startup
  type, PID and log-on account; text search plus a state filter (all / running
  / stopped / automatic not started) and a summary line.

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


------------------------------------------------------------------------------
5. THEME AND SETTINGS PANEL
------------------------------------------------------------------------------

The footer has three areas: settings and language buttons on the left,
"ServerDashboard <version>" in the centre, the light/dark theme switch on the
right. Dark is the default.

The gear button opens the settings panel:

| Option            | Stored where                 | Who can change it  |
|-------------------|------------------------------|--------------------|
| Theme             | browser cache (localStorage) | every visitor      |
| Language          | browser cache (localStorage) | every visitor      |
| Refresh interval  | browser cache (localStorage) | every visitor      |
| Default interval  | server, settings.txt         | only on the server |
| Visible sections  | server, settings.txt         | only on the server |
| Logging           | server, settings.txt         | only on the server |

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
- The visible sections and the logging switch belong to the server. The panel
  shows them greyed out with the note "read-only: set on the server in
  settings.txt", and the dashboard never posts them back: the API accepts GET
  only and refuses any write with 403, logging the address of the caller. So
  the restriction holds even against a handcrafted request, not only against
  the user interface.
- To change them, edit settings.txt on the server with Notepad. The file is
  watched: the change is applied within ten seconds, no restart needed.
- settings.txt is created automatically at the first start, already filled
  with the default values, so the settings panel works from the very first
  start. It is a plain text
  file with one "key = value" per line, so you can also change it with Notepad
  and restart the service:

      refresh_seconds = 0.5      (0.5 - 3600, dot as decimal separator)
      idle_seconds    = 0        (0 = do not sample when nobody watches)
      logging         = no       (never create a log file)
      show_cpu        = yes
      show_events     = no

  Unknown or misspelled keys are ignored, missing keys keep their default, and
  a deleted file is recreated with the defaults at the next start.
- logging = yes/no is available in settings.txt ONLY, on purpose: it is not
  shown in the settings panel, so nobody watching the dashboard can turn the
  log on or off. The log is rotated every day: each day has its own file
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


5-bis. SELF UPDATE
------------------------------------------------------------------------------

  At every start - including the automatic one at boot, which runs as SYSTEM
  without any logon - the dashboard reads scripts\version.txt from the main
  branch of github.com/PiBOH/windows-server-dashboard. If the published
  version is newer, the release tagged v<version> is downloaded, unpacked and
  copied over the current files, without ever touching settings.txt, the logs
  folder or the local backups. The dashboard then restarts itself on the new
  version, and writes both a log line and an entry in the Windows event log.

  - The automatic check is switched on and off ONLY in settings.txt
    (auto_update = yes, the default, or no): the settings panel of the page
    shows it but cannot change it, and no visitor can.
  - scripts\Update-Now.bat is the manual way: it checks GitHub and, when a
    new release exists, does the whole cycle by itself - download, stop the
    dashboard, install, start the dashboard again and wait for its answer.
    With no new release it prints "up to date" and changes nothing. It works
    even with auto_update = no, because it is an explicit request.
  - ServerDashboard.ps1 -CheckUpdatesOnly only reports whether a new release
    exists (exit code 3 = available) and touches nothing.
  - Releases must be tagged v<version> for the updater to find them.


5-ter. LOGON NOTIFICATION
------------------------------------------------------------------------------

At every user logon a Windows notification says whether the dashboard started
correctly. It is produced by Show-StartupNotification.ps1, run by the
scheduled task "PiBOH Windows Server Dashboard Notify" that Install.bat creates.

- The script waits up to 90 seconds for the service to answer on /api/health,
  because at logon the machine is still starting, then shows one of two
  messages, in the language of Windows:

      Server Dashboard - Dashboard started successfully
      Available at http://192.168.1.10:8080

      Server Dashboard - Dashboard is NOT running
      Check the newest logs\ServerDashboard-*.log for details

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
  served from memory; the language XML files and settings.json are the only
  files read from disk at runtime.
- All metrics use CIM/WMI classes whose property names are always English, so
  the script works on any localized Windows.

  Endpoints:

| Endpoint         | Purpose                                    |
|------------------|--------------------------------------------|
| /                | the dashboard page                         |
| /api/stats       | full JSON, handy for Zabbix or Grafana     |
| /api/languages   | language catalog                           |
| /lang/<code>.xml | one dictionary                             |
| /api/settings    | GET reads, POST writes the server settings |
| /api/health      | state and version                          |


------------------------------------------------------------------------------
7. CUSTOMIZATION
------------------------------------------------------------------------------

Open the .bat files with Notepad and edit the first lines:

    set "PORT=8080"      REM change the port
    set "INTERVAL=5"     REM seconds between two samples
    set "HIDDEN=1"       REM 0 = show the console with the live log

After changing the port run Uninstall.bat and then Install.bat again, so the
old firewall rule and URL reservation are cleaned up. The refresh interval can
also be changed at runtime from the settings panel; delete settings.json to go
back to the defaults.


------------------------------------------------------------------------------
8. TROUBLESHOOTING
------------------------------------------------------------------------------

| Symptom                         | Fix                                    |
|---------------------------------|----------------------------------------|
| Works locally, not from the LAN | Firewall rule missing: run as admin    |
| Log says localhost ONLY         | Missing privileges: run as admin       |
| Port already in use             | netstat -ano | findstr :8080           |
| Temperature not available       | Install Core Temp + its WMI provider   |
| Page does not refresh           | Check the newest logs\ServerDashboard-*.log |
| Check the task state            | schtasks /Query /TN "PiBOH Windows Server Dashboard" /V |
| Uninstall                       | Run Uninstall.bat as administrator     |


------------------------------------------------------------------------------
9. SECURITY
------------------------------------------------------------------------------

The dashboard has no password: anyone on the LAN who can reach port 8080 can
see the data (system information, process, service and event lists - read
only, no command can be executed). If the server is ever exposed to the
Internet, restrict the firewall rule to the local subnet:

    netsh advfirewall firewall set rule name="Server Dashboard 8080" ^
          new remoteip=192.168.1.0/24


------------------------------------------------------------------------------
10. VERSIONING
------------------------------------------------------------------------------

The current version is shown in the centre of the footer and returned by
/api/health. Changes follow Semantic Versioning (MAJOR.MINOR.PATCH); see
Changelog\CHANGELOG.md.

Current version: 1.15.1

==============================================================================
  SERVER DASHBOARD - CHANGELOG
==============================================================================

Versioning follows Semantic Versioning: MAJOR.MINOR.PATCH.
- MAJOR - breaking changes, for instance a new language-file format.
- MINOR - new backward compatible features.
- PATCH - fixes and tweaks that add no feature.

------------------------------------------------------------------------------
  1.15.1 - 2026-09-28
------------------------------------------------------------------------------

Added:
  - Project logo (docs/logo.png), shown at the top of the GitHub page and
    shipped inside the release zip.

Fixed:
  - Self update no longer digs a nested hole. Up to 1.15.0, the updater
    copied the "scripts" folder INSIDE the existing scripts\ folder (and the
    same for lang, docs, ...), because Copy-Item nests a source folder into
    an existing destination folder: the result was scripts\scripts\,
    one level deeper at every update, with the new files landing in the
    wrong place and the running version never changing. The updater now
    copies the CONTENTS of every folder, so an update lands exactly where
    the old files are, and it also removes the nesting left behind by the
    previous versions.
  - Update-Now.bat now does the whole cycle by itself: check, download,
    stop the dashboard, install, start the dashboard again and wait for its
    answer on /api/health. Before, it installed the files while the old
    dashboard kept running and then asked the user to stop and restart the
    service by hand.
  - The manual update works even with auto_update = no: it is an explicit
    request, so the settings switch only gates the AUTOMATIC check at boot.
    Before, with auto_update = no the manual updater lied "up to date"
    without even looking at GitHub.
  - -CheckUpdatesOnly now only checks and reports (exit code 3 when a new
    release exists), without installing anything.
  - The update package is unpacked through GetTempPath(), which never comes
    back empty, instead of the TEMP environment variable.
  - If launching the new version after a self update fails, the error is
    logged instead of stopping the script: the service will come back at
    the next task run.

------------------------------------------------------------------------------
  1.15.0 - 2026-09-28
------------------------------------------------------------------------------

Added:
  - The process list shows the friendly name of every executable too, right
    under the image name: "Task Manager" under taskmgr.exe, "Windows
    Explorer" under explorer.exe, exactly like Task Manager does. The
    description is read from the version info of the executable itself, so
    it is already in the language of the server, and it is cached per path:
    while a process runs, its description cannot change, so the file is
    read only once. The filter of the section searches the description as
    well, and the full path stays in the tooltip.

Changed:
  - The changelog moved to its own folder: Changelog\CHANGELOG.md is now the
    only changelog file of the project.
  - .gitignore also ignores the local folder .ignore\.
  - The process collector is more robust: when a CIM class cannot be
    queried at all, the answer used to look like "one empty element" and
    the Get-Process fallback never ran, leaving the process list empty.
    A null answer is now filtered out, so the fallback works again (this
    was visible only where CIM is missing, never on a healthy Windows).

------------------------------------------------------------------------------
  1.14.0 - 2026-09-28
------------------------------------------------------------------------------

Added:
  - Daily log rotation. The log file now carries the date in its name
    (logs\ServerDashboard-YYYY-MM-DD.log): at midnight the rotation happens
    by itself, with no timer and no file ever growing without limit. The
    log files older than 14 days are deleted automatically, at every start
    and once a day while running. The notification log rotates the same way
    (logs\ServerDashboard-notify-YYYY-MM-DD.log). An explicit -LogFile
    parameter still forces one fixed file, for tests.
  - Automatic release workflow (.github/workflows/auto-release.yml), in the
    style of the other PiBOH repositories: a push to main whose commit
    message starts with "v", or a manual run from the Actions tab, builds
    the release zip from the tracked files only - excluding the development
    folders (.github, .config, _build, screenshots) and the repository
    housekeeping files - validates its content, computes the SHA-512
    checksum and publishes the GitHub release with the tag v<version>.

Changed:
  - The screenshots moved from docs\screenshots to screenshots\ in the
    root of the repository, regenerated with the interface in English.
  - Diagnose, Install and Uninstall read the newest daily log
    (ServerDashboard-*.log) instead of one fixed file.
  - The release zip does not carry settings.txt any more: the file is
    gitignored on purpose, and the engine already writes it with the
    default values at the first start.

------------------------------------------------------------------------------
  1.13.0 - 2026-09-28
------------------------------------------------------------------------------

Added:
  - Self update: at every start (the boot task runs as SYSTEM, so no logon is
    needed) the dashboard reads scripts/version.txt from the main branch on
    GitHub, compares it with the local version and, when newer, downloads the
    release tagged v<version>, unpacks it and copies it over the current files
    - never touching settings.txt, the logs or the local backups - then
    restarts itself. Disable with auto_update = no; force a check with the new
    scripts\Update-Now.bat or with -CheckUpdatesOnly.
  - The version is now read from scripts/version.txt, the single source of
    truth: the dashboard, the updater and the health endpoint all take it from
    there.
  - The software identifies itself: the scheduled task is named "PiBOH Windows
    Server Dashboard" with a description visible in Task Scheduler, and at
    every start an entry is written in the Windows event log (source "PiBOH
    Windows Server Dashboard") explaining what the software is, how it works,
    where its files are and where the updates come from.

Changed:
  - Default refresh interval lowered from 5 seconds to 0.5 seconds: the
    dashboard is live out of the box. Each visitor can still pick their own
    interval, and the default remains a server side setting in settings.txt.
  - .gitignore reduced to the essentials: logs/ and settings.txt, both
    recreated automatically on the server.
  - Two Italian comments left in the page source were translated, and a full
    audit confirmed that everything outside the lang translations is now
    English.

------------------------------------------------------------------------------
  1.12.1 - 2026-09-27
------------------------------------------------------------------------------

Fixed:
  - Disks: local volumes could all end up under "other volumes", leaving the
    physical disks empty. The mapping relied only on the WMI associators
    (Win32_DiskDriveToDiskPartition + Win32_LogicalDiskToPartition), which
    fail on several RAID and storage drivers; the failure was swallowed
    silently. Three fallbacks were added, tried in order: the Storage module
    (MSFT_Partition, then Get-Partition) matched by disk number; if local
    volumes are still unmatched and there is exactly one physical disk, they
    are attached to it; if Win32_DiskDrive exposes no disk at all, the local
    volumes are grouped under a single entry named "Local disks". The route
    actually used is written to the log, and unmatched volumes are listed
    there by letter.
  - The connection state in the header ("in linea", "online", ...) did not
    follow a language change: it was plain text, rewritten only by the next
    successful poll, so with a long refresh interval it stayed in the previous
    language. It is now stored as a key and repainted immediately when the
    language changes.
  - The disks card can no longer render empty: with no data it shows "No data
    available" instead of an empty box.

Added:
  - Diagnose: new section "DISKS AS THE DASHBOARD SEES THEM" that reads
    /api/stats and prints every physical disk with the drive letters matched
    to it, warns about fixed disks with no volume, and flags local volumes
    that ended up under "other volumes".

Language files:
  - New key no_data, translated in all 38 languages.

------------------------------------------------------------------------------
  1.12.0 - 2026-09-27
------------------------------------------------------------------------------

Changed (package layout):
  - The root folder now contains only what you actually use: Install.bat,
    Uninstall.bat, Start-Dashboard.bat, Stop-Dashboard.bat and settings.txt.
  - scripts\ holds every script: ServerDashboard.ps1, Diagnose.bat and .ps1,
    Repair-Autostart.bat, Test-Notification.bat, Test-Syntax.ps1, New-
    DashboardTask.ps1, Set-UrlAcl.ps1, Show-StartupNotification.ps1 and Stop-
    DashboardProcess.ps1.
  - docs\ holds README.md, CHANGELOG.md and the offline preview; lang\ keeps
    the 38 translations where they were.
  - logs\ collects every log: ServerDashboard.log, ServerDashboard-notify.log,
    plus install-state.txt and the backup of a pre-existing scheduled task.
    The folder is created automatically and a short README.txt inside explains
    what lands there.
  - Every script finds the package root by itself: it walks one level up when
    it lives in scripts\, and still works if you copy it back next to
    settings.txt.
  - All the .bat files, the installer and the diagnostics were updated to the
    new paths, and the whole thing was started for real to confirm it: log
    written in logs\, settings read from the root, 38 languages loaded, every
    endpoint answering and no collector error.

------------------------------------------------------------------------------
  1.11.7 - 2026-09-27
------------------------------------------------------------------------------

Fixed (critical):
  - The dashboard did not start at all. A line of dashes left over from an
    edit in 1.7.0 had stayed in the middle of the collector, where PowerShell
    read it as a sequence of -- operators: the file did not compile, so the
    script exited with code 1 before writing a single line of log. From the
    outside it looked like a working task ("Ready", last result 1) with no
    process, no port, no log and no notification - exactly the symptoms
    reported. All the .ps1 files are now checked with the official PowerShell
    parser.
  - A failure in one metric no longer wipes out the whole sample. Disks,
    processes, services and events each have their own guard: the section
    keeps its previous data, the error is logged with its section name and
    line, and the rest of the dashboard carries on. The outer handler also
    publishes the partial sample instead of discarding it.
  - Null-safe access to the CIM properties used as strings (DeviceID, counter
    names): a null value used to raise "You cannot call a method on a null-
    valued expression" and kill the disk section.
  - Network detection at boot no longer depends on WMI alone:
    NetworkInterface.GetIsNetworkAvailable() is tried first, so a slow or
    broken WMI cannot hold the startup for two minutes.

Added:
  - Test-Syntax.ps1: parses every PowerShell file of the package and reports
    file, line and column of each error.
  - Install.bat runs that check before touching anything and refuses to
    install if a script does not parse, so a task that starts and dies
    immediately can no longer be created.

Verified by actually running it:
  - The service was started for real, and every endpoint checked: the page is
    served, /api/health answers, /api/stats returns all ten sections,
    /api/languages lists the 38 languages, /lang/it-IT.xml is served, a POST
    on /api/settings is refused with 403, and the log shows "sampling paused"
    then "sampling resumed" when a client comes back.

------------------------------------------------------------------------------
  1.11.6 - 2026-09-27
------------------------------------------------------------------------------

Changed:
  - The refresh interval is editable by the visitors again, but as a personal
    choice: it is stored in the browser cache together with theme and
    language, and it only changes how often that browser asks for data. The
    value in settings.txt is now the DEFAULT offered to everybody, shown in
    the list as "server default (5 seconds)"; picking that entry again drops
    the personal override.
  - The selector is back in the header and enabled in the settings panel, with
    the hint "saved in this browser". Restore defaults also clears the
    personal interval.
  - Unchanged from 1.11.5: the visible sections and the logging switch remain
    server-only, greyed out in the panel, and /api/settings still accepts GET
    only, refusing any write with 403. Nothing a visitor does can change the
    configuration of the server.

Language files:
  - New key server_default, translated in all 38 languages.

------------------------------------------------------------------------------
  1.11.5 - 2026-09-27
------------------------------------------------------------------------------

Changed (security):
  - The server side settings can no longer be changed by whoever watches the
    dashboard. /api/settings accepts GET only: a POST is refused with 403 and
    written to the log together with the address of the caller, so the
    restriction holds against a handcrafted request too, not just against the
    user interface.
  - In the settings panel the refresh interval and the section checkboxes are
    disabled and carry the note "read-only: set on the server in
    settings.txt". The panel saves theme and language only, and Restore
    defaults resets those two alone.
  - The refresh selector in the header is now a plain label showing the value
    chosen on the server.

Added:
  - settings.txt is watched: edit it with Notepad and the new values are
    picked up within ten seconds, without restarting the service.

Language files:
  - New key readonly_server, translated in all 38 languages.

------------------------------------------------------------------------------
  1.11.4 - 2026-09-27
------------------------------------------------------------------------------

Changed:
  - The boot task is no longer created with a schtasks command line but by the
    new New-DashboardTask.ps1, which sets the principal by SID (S-1-5-18 =
    SYSTEM) with logon type ServiceAccount, that is "run whether the user is
    logged on or not". Passing the account by name, as schtasks /RU SYSTEM
    does, depends on the localized account name and could end up producing an
    interactive task that would start only after a logon. The old command line
    is kept as a fallback.
  - After registering it, the installer reads the task back and verifies four
    things: principal SYSTEM, non-interactive logon type, boot trigger and
    task enabled. It then prints AUTOSTART VERIFIED, or a warning with the
    reason.

Added:
  - Diagnose.ps1 prints an explicit verdict: "STARTS WITHOUT INTERACTIVE LOGON
    : YES/NO", with the command to fix it when the answer is no.
  - Repair-Autostart.bat: rebuilds the URL reservation and the boot task,
    restarts the service and checks /api/health, without reinstalling and
    without touching anything else.

------------------------------------------------------------------------------
  1.11.3 - 2026-09-27
------------------------------------------------------------------------------

Fixed:
  - The dashboard was not reachable from the network on localized versions of
    Windows. The installer created the URL reservation with user="NT
    AUTHORITY\SYSTEM", an account name that simply does not exist on a non-
    English system (in Italian it is "AUTORITA NT\SISTEMA"): netsh failed,
    nothing was reserved, and the service fell back to listening on localhost
    only. The new Set-UrlAcl.ps1 resolves the account from its SID (S-1-5-18),
    with SDDL and Everyone as further fallbacks, and Install.bat reports which
    form worked.
  - The dashboard now repairs this by itself: when a bind is refused it
    creates the reservation (it runs as SYSTEM, so it may) and retries,
    instead of silently degrading to localhost.
  - The logon notification could pass unnoticed. Windows Server often has no
    Action Center, and a tray balloon posted before the shell is ready is
    lost. The script now waits for explorer.exe, checks whether each method
    really displayed something, and falls through to the window styled like a
    Windows 10 toast, which always shows on a desktop.

Added:
  - Test-Notification.bat: shows the notification immediately, no logoff
    needed.
  - ServerDashboard-notify.log: the notification script records which display
    method was tried and why it failed.
  - Diagnose.ps1 now also checks the notification task and its log, and when
    the URL reservation is missing it prints the localized SYSTEM account name
    and the exact command to run.
  - A failed health check at the end of Install.bat prints the last 12 lines
    of the log immediately.

------------------------------------------------------------------------------
  1.11.2 - 2026-09-27
------------------------------------------------------------------------------

Fixed:
  - Diagnose.bat opened and closed immediately. Three of its checks used a
    PowerShell one-liner inside a FOR /F loop, and those one-liners contain
    single quotes (for instance 'http://localhost:8080/api/health'): the batch
    parser treats the first inner quote as the end of the command, the whole
    block fails to parse and cmd closes the window before reaching the pause.
    All the logic moved to Diagnose.ps1, and Diagnose.bat is now a thin
    wrapper that elevates, runs the script and waits for a key press.
  - The same pattern was fixed in Install.bat, where the post-install health
    check used an inline one-liner in FOR /F: it now writes a small temporary
    script and reads it back with usebackq.
  - Stop-Dashboard.bat and Uninstall.bat no longer embed a quoted PowerShell
    command either: they call the new Stop-DashboardProcess.ps1, which stops
    the script hosts and frees the port.

Added:
  - Diagnose.ps1 gives a colour-coded report (green OK, red problem, yellow
    warning), verifies that the task really runs as SYSTEM with a boot trigger
    and a non-interactive logon type, tests /api/health both on localhost and
    on the LAN address, and ends with a numbered list of the problems found.

------------------------------------------------------------------------------
  1.11.1 - 2026-09-27
------------------------------------------------------------------------------

Fixed:
  - The dashboard could end up reachable only after somebody logged on to the
    server. At boot the task starts before http.sys and the network stack are
    ready, so the first bind of http://+:8080/ failed and the script fell back
    to listening on localhost only: the page answered on the server itself but
    not from the LAN, until a manual start after logon fixed it by accident.
    The script now waits for the network (up to 120 s), retries the real
    prefix for up to 5 minutes, and falls back to localhost only on a genuine
    access-denied error, logging the exact netsh command to run. If it still
    cannot bind it exits with an error, so the task restarts it.
  - The scheduled task is created with a 30 second delay after boot, restart
    on failure 99 times every minute, StartWhenAvailable and IgnoreNew, so a
    port that is busy for a moment can no longer leave the dashboard down
    until the next logon.

Added:
  - Diagnose.bat: read-only diagnostics reporting the task state (including
    Run As User and Logon Mode), whether the process runs and under which
    account, what listens on the port and whether it is bound to localhost
    only, the URL reservation, the firewall rule, the /api/health answer, the
    files and the last 20 log lines.
  - Install.bat warns when the folder is inside a user profile or OneDrive,
    and prints how the task will really run (Run As User, Logon Mode, Schedule
    Type).

------------------------------------------------------------------------------
  1.11.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Half a second refresh: the interval list starts at 0.5 s. Intervals are
    decimal numbers now, written with an invariant decimal point in
    settings.txt and shown with the decimal separator of the chosen language
    (0,5 in Italian).
  - logging = yes/no in settings.txt: with no, the script writes nothing and
    ServerDashboard.log is never created. The switch is read before the first
    log line, is deliberately absent from the settings panel and from
    /api/settings, and is preserved when the dashboard rewrites the file.

Changed:
  - When nobody is watching, nothing runs. After a few refresh intervals
    without a data request the collector stops sampling completely and only
    polls a flag four times a second; it resumes within 250 ms of the first
    request. The old behaviour (a slow sample every 15 minutes) is still
    available by setting idle_seconds greater than zero; the default is now 0.
  - A background tab stops polling and shows "Paused" in the header, which in
    turn lets the server go quiet.
  - /api/health also reports whether sampling is active or paused.
  - Language files, favicon and settings requests no longer count as "somebody
    is watching": only the page and /api/stats do.

Language files:
  - New key paused, translated in all 38 languages.

------------------------------------------------------------------------------
  1.10.0 - 2026-09-27
------------------------------------------------------------------------------

Changed:
  - Processes are listed with their real image name, extension included
    (sqlservr.exe instead of sqlservr, svchost.exe instead of svchost#3). The
    performance counter class never reports the file name, so the list is now
    joined with Win32_Process by PID, which also provides the full path of the
    executable: it is shown in the tooltip of the name and is searched by the
    filter.
  - The logon notification is now optional: the installer asks whether to
    create the task, and states clearly that the dashboard itself never needs
    anybody to log on to the server.

Added:
  - Install.bat performs a health check at the end of the installation and
    prints whether the dashboard is really answering on its port, so you can
    verify the installation without logging on again.
  - New README chapter "Do I have to log on to the server?" explaining that
    the task starts at boot as SYSTEM, with the console at the lock screen.

------------------------------------------------------------------------------
  1.9.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - One second refresh: the interval list is now 1, 2, 5, 10, 15, 30 seconds,
    1 minute and 5 minutes, and the collector paces itself with millisecond
    precision instead of two second steps.
  - Logon notification: the new Show-StartupNotification.ps1, started by the
    scheduled task "ServerDashboard Notify" created by Install.bat, waits for
    the service to answer on /api/health and shows a Windows notification
    saying whether the dashboard started correctly, with the access URL. It
    tries a real WinRT toast first, then a tray balloon tip, then a window
    drawn like a Windows 10 toast. Texts follow the Windows language, read
    from the same lang XML files. Uninstall.bat removes the task.

Changed (lower CPU usage):
  - Tiered sampling. Expensive queries no longer run on every cycle: processes
    every 5 s, disks every 10 s, services and sessions every 30 s, events
    every 60 s, while CPU, memory and network keep refreshing on every cycle.
    Raising the refresh rate to 1 second therefore costs almost nothing.
  - Duplicated queries removed: the process count now reuses the process list
    instead of calling Get-Process again, and the service counters are
    computed once per tier instead of five times per cycle.
  - The browser repaints the process, service, event and disk sections only
    when their data actually changed, and stops polling entirely while the tab
    is in the background.

Language files:
  - New keys notif_title, notif_ok, notif_ok_body, notif_fail,
    notif_fail_body, second and minute, translated in all 38 languages (also
    used to write "1 second" and "1 minute" correctly).

------------------------------------------------------------------------------
  1.8.0 - 2026-09-27
------------------------------------------------------------------------------

Changed:
  - Settings are now stored in settings.txt instead of settings.json: a plain
    text file with one "key = value" per line and comments, readable and
    editable with Notepad. Keys: refresh_seconds, idle_seconds and one
    show_<section> = yes/no per section.
  - settings.txt is shipped inside the package already filled with the default
    values, and the script recreates it at startup if it is missing, so the
    settings panel can never fail because the file is not there.
  - Virtual disks (Hyper-V, VMware, VirtualBox, KVM, iSCSI) are back in the
    main disk list: on a virtual server they are the real disks. Previously
    the 1.7.0 heuristic moved them all into "Other devices", which left the
    disk list of a virtual machine empty. Only USB, card readers and optical
    drives are listed apart now; virtual units keep a "virtual" badge and a
    cloud icon.

Fixed:
  - A canvas failure inside draw() could throw during startup and abort the
    whole boot sequence, leaving the page without languages and without
    settings. Chart drawing is now guarded, and the boot chain survives the
    failure of any single step.
  - The settings panel no longer depends on a successful server response: if
    the settings cannot be read or written, the built-in defaults are used and
    the panel still opens.

Verified:
  - The whole interface was tested in a real DOM (jsdom): language dialog
    opening with its 38 entries and closing with Escape, language switch (it-
    IT to ja-JP and back), theme switch with persistence, settings panel with
    12 sections, hiding a section, changing the refresh rate, restore
    defaults, plus the rendering of 7 disk boxes, 138 processes, 214 services
    and 46 events. No JavaScript error.

------------------------------------------------------------------------------
  1.7.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Core Temp support for the CPU temperature, through its free "Core Temp WMI
    provider" add-on (namespace root\CoreTemp): one reading per core, with
    automatic Fahrenheit to Celsius conversion. HWiNFO (root\HWiNFO) was added
    as a further fallback. The order is now BIOS/ACPI, Core Temp,
    LibreHardwareMonitor / OpenHardwareMonitor, HWiNFO.
  - Physical devices are classified as Fixed, Removable, Virtual or Optical,
    using the media type, the interface and the bus type reported by Get-
    PhysicalDisk. Bus and media type (SATA, SAS, NVMe, SSD, HDD) are shown as
    badges in the disk header.

Changed:
  - USB sticks, card readers, optical drives and virtual or iSCSI units are no
    longer mixed with the real disks of the server: they are listed at the
    bottom under the heading "Other devices", with a dimmed style and their
    own icon. Real fixed disks always come first.
  - README.md and CHANGELOG.md rewritten so they are readable in Windows
    Notepad: CRLF line endings, lines wrapped at 78 columns and tables padded
    so the columns line up in a monospaced font. Every text file of the
    package (.ps1, .bat, .xml, .md) now uses CRLF.

Fixed:
  - The language picker did not open. When the modal windows were refactored
    in 1.4.0 the language dialog lost its "modal" CSS class when shown, so the
    rule that makes it visible never matched and nothing appeared. It is now a
    proper overlay again, it can be closed with Escape or by clicking outside,
    and the settings dialog shares the same behaviour.

Language files:
  - New key other_devices translated in all 38 languages.

------------------------------------------------------------------------------
  1.6.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Events section: critical, error and warning entries of the System and
    Application event logs of the last 24 hours (up to 150), with timestamp,
    level, log, source, event ID and message, colour coded, with text filter,
    level filter and sortable columns.
  - The event log is read at most once a minute, with a Get-EventLog fallback.
  - New "events" entry in the visible sections settings.

Language files:
  - 14 new keys translated in all 38 languages.

------------------------------------------------------------------------------
  1.5.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Install.bat: a real installer that inspects the machine, applies only the
    missing changes (firewall rule, URL reservation, scheduled task) and
    prints every change with its BEFORE and AFTER value. The previous state is
    recorded in install-state.txt and an existing task with the same name is
    exported to previous-task-backup.xml.
  - Uninstall.bat: reverts exactly what the installer changed, restoring
    anything that already existed and reporting every step with BEFORE and
    AFTER values.

Changed:
  - Install-AutoStart.bat replaced by Install.bat; Start-Dashboard.bat is now
    only the "run once, without installing" helper.

------------------------------------------------------------------------------
  1.4.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Settings panel in the footer: theme and language stored in the browser
    cache, refresh interval and visible sections stored on the server in
    settings.json, plus a "Restore defaults" button.
  - Adaptive sampling: 5 seconds while a browser is connected, 15 minutes when
    nobody is, with the new -IdleIntervalSeconds parameter.
  - New endpoint GET/POST /api/settings.

Changed:
  - Default sampling interval raised from 3 to 5 seconds.

Language files:
  - 13 new keys translated in all 38 languages.

------------------------------------------------------------------------------
  1.3.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Light and dark theme switch in the footer, dark by default, stored per
    browser.
  - Footer reorganised in three areas, with the version in the centre.
  - Sticky header: the top bar stays visible while scrolling.

Changed:
  - Disk activity merged into "Disks and partitions": each physical drive is a
    box containing the boxes of its partitions, with read, write and busy
    figures at both levels.
  - The "data refreshed every N seconds" sentence was removed from the footer.
  - All file names, code comments and documentation are now in English.

Language files:
  - New keys other_volumes, activity, theme_dark, theme_light; obsolete key
    footer_refresh removed.

------------------------------------------------------------------------------
  1.2.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Multilingual interface in 38 languages, one XML file each in lang\.
  - Automatic detection of the Windows display language, with fallback to the
    base language and finally to English.
  - Language button in the footer, always in English, listing every language
    as "Native name (English name)".
  - Right-to-left support for Arabic and Hebrew.
  - Endpoints /api/languages and /lang/<code>.xml; version number in the
    footer and in /api/health.

------------------------------------------------------------------------------
  1.1.3 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Sorting of the Processes and Services tables by clicking the column
    headers, File Explorer style, with the preference saved in the browser.

------------------------------------------------------------------------------
  1.1.2 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Services section with the complete list, text filter and state filter.

Changed:
  - Full process list, no longer only the top 40.

------------------------------------------------------------------------------
  1.1.1 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - Scrollable process pane with sticky headers, name filter and scroll
    position kept across refreshes.

------------------------------------------------------------------------------
  1.1.0 - 2026-09-27
------------------------------------------------------------------------------

Changed:
  - CPU and RAM charts split into two separate cards.

------------------------------------------------------------------------------
  1.0.0 - 2026-09-27
------------------------------------------------------------------------------

Added:
  - First release: built-in web server (HttpListener); CPU, memory, disk,
    network, IP, operating system, process and service metrics; auto-start
    through a scheduled task; firewall rule; history charts.

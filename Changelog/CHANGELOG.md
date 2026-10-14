==============================================================================
  SERVER DASHBOARD - CHANGELOG
==============================================================================

Versioning follows Semantic Versioning: MAJOR.MINOR.PATCH.
- MAJOR - breaking changes, for instance a new language-file format.
- MINOR - new backward compatible features.
- PATCH - fixes and tweaks that add no feature.  1.16.16 - 2026-10-14
  Fixed: after an update the dashboard comes back on its own. Two faults kept
    it on the old build: the hand over launched the new version with
    -WindowStyle written twice, which PowerShell refuses, and the net against
    the update loop compared the version NUMBER only, so a release published
    again under the same version was taken for an update that never landed.
    Both are corrected, and the same duplicate is gone from the periodic 24 h
    check, which never ran at all.
  Changed: the log names who started Core Temp, instead of printing a pid that
    answers nothing: the parent when it still exists, and the scheduled task
    that starts the same program.

  1.16.15 - 2026-10-14
 Added: the browser tab shows the logo of the package -
    /favicon.ico serves docs\logo.png (the empty 204 comes back when the file
    is missing). Changed: the README screenshots were taken again, in English.

  1.16.14 - 2026-10-14 Changed: docs\Dashboard-Preview.html is generated from
    _build\web\ by _build\Embed-Page.ps1, which fails when the copies do not
    match; the preview takes its version from scripts\version.txt.

  1.16.13 - 2026-10-14 Changed: Core Temp's WMI add-on is queried only with
    the new coretemp_wmi = yes, off by default, and the log names the process
    that started Core Temp. A machine whose reading came only from that source
    shows an empty temperature row until coretemp_wmi = yes, or Core Temp's
    global shared memory, or its own log.

  1.16.12 - 2026-10-14 Fixed: the bounds are doubles, so a fractional refresh
    or idle interval reaches settings.txt as it was sent (2.5 s was stored as
    2, and 0.5 s switched idle sampling off); the same rounding fixed in the
    network rates.

  1.16.11 - 2026-10-14 Changed: the page is edited as three files in
    _build\web\, spliced into the engine by _build\Embed-Page.ps1 -Check, so
    the sources and the page the server answers with can no longer drift
    apart.

  1.16.10 - 2026-10-14 Fixed: the offline preview and the comments no longer
    describe the settings as read-only (stale since 1.16.7); the unused
    readonly_server string left all 38 language files.

  1.16.9 - 2026-10-13 Fixed: the 32-bit CI job waits for the CPU section
    instead of failing on a slow runner. The dashboard itself is unchanged.

  1.16.8 - 2026-10-13 Fixed: a settings write coming from another site's page
    is refused with 403 and logged with its origin; the documentation
    corrected.

  1.16.7 - 2026-10-13 Fixed: the scroll bar arrow buttons are drawn again
    (Chromium drops them as soon as ::-webkit-scrollbar is styled); Core Temp
    sources are read only while a Core Temp process is running. Changed: with
    no password the settings panel writes the server options to settings.txt
    from the page.

  1.16.6 - 2026-10-13 Added: the temperature row names its source
    (Cpu.TempSource) and Core Temp's own CT-Log CSV is a source; the log and
    /api/health state the 32/64-bit engine; a CI job runs the whole dashboard
    with the 32-bit engine. Fixed: memory from ~200 MB to a mem_budget of 20
    MB by default, replacing five cmdlets with their CIM classes, releasing
    the per-request wait handle and response, and trimming without Add-Type;
    self update works again (the updater no longer stops itself, the fallback
    launch binds its parameters). Changed: /api/stats JSON built once per
    cycle (10.2 -> 4.7 ms), the static lists read once, Processes in name
    order, the OS card names the release.

  1.16.5 - 2026-10-12 Added: legend and coloured headline values on the
    network chart; the dashboard's own row highlighted in the Processes table.
    Fixed: the personal refresh interval survives a browser that refuses
    localStorage (cookie fallback, and the panel says so when both fail).

  1.16.4 - 2026-10-01 Changed: version.txt carries the build commit on a
    second line, so republishing a version does update running dashboards; the
    startup log names that commit. Fixed: manual update (Update-Now.bat
    elevates) and the restart after it (the port is waited for, the
    last-resort launch reserves the URL first).

  1.16.3 - 2026-10-01 Changed: the friendly name is the main line in the
    process list; the tab title is back to "<server> - Dashboard"; a five
    minute memory trim. Fixed: pre-1.16.0 leftovers are removed from docs\ at
    the first start (a logo.png in the root is a personal file and stays).

  1.16.2 - 2026-10-01 Fixed: the page answers before the update check (slow
    start at boot, "I have to install twice"); updates start reliably again
    (port wait, retries, direct launch); the installer asks for password_mode;
    the software identifies itself everywhere with its full name.

  1.16.1 - 2026-09-30 Changed: local files moved to .config-do-not-delete-me
    (pwd, settings-backup.txt); partial password mode asks only when an option
    is clicked; install-state.txt hidden in scripts\. Added: the password is
    asked during the installation and never offered for saving by a browser;
    the popups close by clicking outside them.

  1.16.0 - 2026-09-29 Added: optional password (file pwd, password_mode
    total|partial) protecting the whole page or only the server options, never
    logged and never sent to the browser. Changed: the update check repeats
    every 24 hours; settings.txt and pwd are reloaded within ten seconds even
    with nobody connected; CI parses with Windows PowerShell 5.1. Fixed: the
    endless update loop when an install failed (version.txt is verified before
    handing over) and the nested scripts\scripts folders.

  1.15.2 - 2026-09-28 Changed: release notes moved to
    Changelog\release-notes\; Core Temp is read from the shared memory block
    it publishes (no add-on needed), the WMI one after it. Fixed: multi-socket
    core labels use Floor instead of a rounding [int] cast.

  1.15.1 - 2026-09-28 Added: project logo (docs/logo.png), shipped inside the
    zip. Fixed: the updater copied every folder inside itself
    (scripts\scripts) - it now copies the contents and cleans the nesting;
    Update-Now.bat runs the whole cycle; a manual update works with
    auto_update = no.

  1.15.0 - 2026-09-28 Added: the friendly name of every executable under the
    image name, cached per path and searched by the filter. Changed: the
    changelog moved to Changelog\; .ignore\ gitignored; a null CIM answer no
    longer leaves the process list empty.

  1.14.0 - 2026-09-28 Added: daily log rotation with 14 days retention; the
    automatic release workflow (auto-release.yml) that builds, validates and
    publishes the zip. Changed: screenshots moved to screenshots\; the zip no
    longer carries settings.txt.

  1.13.0 - 2026-09-28 Added: self update from GitHub at every start
    (auto_update = no to disable, Update-Now.bat to force); the version comes
    from scripts/version.txt only; the task and the event log identify the
    software. Changed: default refresh 5 s -> 0.5 s; every comment and file
    name in English.

  1.12.1 - 2026-09-27 Fixed: local volumes could all end up under "other
    volumes" (three fallbacks, the route used is logged); the header state
    follows a language change; the disks card never renders empty. Added: the
    "DISKS AS THE DASHBOARD SEES THEM" section of Diagnose; key no_data in 38
    languages.

  1.12.0 - 2026-09-27 Changed: the package layout - only the .bat files and
    settings.txt in the root, scripts\ for every script, docs\ for the manual
    and the preview, logs\ for every log; every script finds the root by
    itself.

  1.11.7 - 2026-09-27 Fixed (critical): the dashboard did not start at all - a
    line of dashes left over from 1.7.0 broke the parse; a failing metric no
    longer wipes the sample; null-safe CIM strings; network detection no
    longer waits on WMI. Added: Test-Syntax.ps1, run by Install.bat before it
    touches anything.

  1.11.6 - 2026-09-27 Changed: the refresh interval is a per-browser choice
    again, with the value in settings.txt offered as "server default".

  1.11.5 - 2026-09-27 Changed: /api/settings accepts GET only (a POST is
    refused 403 and logged) and the panel is read-only for the server options;
    settings.txt is picked up within ten seconds without restarting.

  1.11.4 - 2026-09-27 Changed: the boot task is created by
    New-DashboardTask.ps1 (SYSTEM by SID, non-interactive) and read back to
    verify principal, logon type, boot trigger and state. Added: Diagnose
    prints "STARTS WITHOUT INTERACTIVE LOGON: YES/NO"; Repair-Autostart.bat
    rebuilds reservation, task and service.

  1.11.3 - 2026-09-27 Fixed: the URL reservation used the English SYSTEM
    account name and failed on localized Windows (Set-UrlAcl.ps1 resolves it
    by SID, and the dashboard repairs it itself); the logon notification falls
    through to a toast-styled window. Added: Test-Notification.bat,
    ServerDashboard-notify.log and more Diagnose checks.

  1.11.2 - 2026-09-27 Fixed: Diagnose.bat and Install.bat closed immediately
    (inline PowerShell inside FOR /F); the logic moved to Diagnose.ps1, which
    reports in colour and ends with the numbered list of problems.

  1.11.1 - 2026-09-27 Fixed: the dashboard could be reachable only after a
    logon (up to 5 minutes of retries, localhost only on a real
    access-denied); the task retries on failure. Added: Diagnose.bat;
    Install.bat warns when the folder is inside a user profile or OneDrive.

  1.11.0 - 2026-09-27 Added: half a second refresh with the decimal separator
    of the language; logging = yes/no. Changed: nothing runs while nobody
    watches (idle_seconds = 0 by default); a background tab shows "Paused";
    /api/health says whether sampling is on.

  1.10.0 - 2026-09-27 Changed: processes listed with the real image name,
    joined to Win32_Process for the full path; the logon notification is
    optional. Added: Install.bat ends with a health check; a manual chapter
    "Do I have to log on to the server?".

  1.9.0 - 2026-09-27 Added: one second refresh; the logon notification
    (Show-StartupNotification.ps1, toast then balloon then window) in the
    Windows language. Changed: tiered sampling (processes 5 s, disks 10 s,
    services and sessions 30 s, events 60 s); duplicated queries removed; the
    page repaints a section only when its data changed.

  1.8.0 - 2026-09-27 Changed: settings in settings.txt (key = value, shipped
    filled in and recreated at startup if missing); virtual disks back in the
    main list with a "virtual" badge. Fixed: a canvas failure no longer aborts
    the boot; the panel opens with the built-in defaults when the server does
    not answer.

  1.7.0 - 2026-09-27 Added: Core Temp support through its WMI add-on, HWiNFO
    as a further fallback (order: BIOS/ACPI, Core Temp, LHM/OHM, HWiNFO);
    fixed, removable, virtual and optical devices classified with bus and
    media badges. Changed: USB, card readers and optical drives listed apart
    under "Other devices"; README and CHANGELOG wrapped at 78 columns with
    CRLF endings. Fixed: the language picker did not open (it had lost the
    modal class in 1.4.0).

  1.6.0 - 2026-09-27 Added: the Events section (System and Application, last
    24 hours, up to 150 entries, filters and sorting), read at most once a
    minute.

  1.5.0 - 2026-09-27 Added: Install.bat (applies only the missing changes,
    prints BEFORE and AFTER, records the previous state) and Uninstall.bat,
    which reverts exactly that.

  1.4.0 - 2026-09-27 Added: settings panel - theme and language in the
    browser, refresh interval and visible sections on the server, plus Restore
    defaults; adaptive sampling; /api/settings. Changed: default interval 3 s
    -> 5 s.

  1.3.0 - 2026-09-27 Added: light and dark theme (dark by default, per
    browser), three-area footer with the version in the centre, sticky header.
    Changed: disk activity merged into "Disks and partitions"; every file
    name, comment and document in English.

  1.2.0 - 2026-09-27 Added: the interface in 38 languages (one XML file each
    in lang\), automatic detection of the Windows language, the language
    button, right-to-left support, /api/languages and /lang/<code>.xml.

  1.1.3 - 2026-09-27 Added: sorting of the Processes and Services tables by
    clicking the column headers, remembered by the browser.

  1.1.2 - 2026-09-27 Added: the Services section with text and state filters.
    Changed: the full process list instead of the top 40.

  1.1.1 - 2026-09-27 Added: scrollable process pane with sticky headers, a
    name filter and the scroll position kept across refreshes.

  1.1.0 - 2026-09-27 Changed: the CPU and RAM charts split into two separate
    cards.

  1.0.0 - 2026-09-27 Added: first release - built-in web server, CPU, memory,
    disk, network, IP, operating system, process and service metrics,
    auto-start task, firewall rule, history charts.

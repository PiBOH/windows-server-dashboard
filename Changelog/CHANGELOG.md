==============================================================================
  SERVER DASHBOARD - CHANGELOG
==============================================================================

Versioning follows Semantic Versioning: MAJOR.MINOR.PATCH.
- MAJOR - breaking changes, for instance a new language-file format.
- MINOR - new backward compatible features.
- PATCH - fixes and tweaks that add no feature.

------------------------------------------------------------------------------
  1.16.14 - 2026-10-14
------------------------------------------------------------------------------

Changed:
  - docs\Dashboard-Preview.html is generated, not a second copy to look after.
    The offline page used to be maintained by hand: its interface had to be
    re-copied from the page the script serves at every change of that page, and
    it had drifted - 1.16.10 had to bring its settings panel back to the 1.16.7
    behaviour, and its title and footer still announced 1.16.10 while the
    dashboard was at 1.16.12. There is now one copy of the interface, the three
    sources in _build\web\, and the preview is built from them plus the preview
    block, which moved into _build\preview\preview.js: the sample data, the 38
    dictionaries and the six functions that answer without a server.
  - _build\Embed-Page.ps1 writes both copies and -Check fails when either of
    them is not what the sources produce, so the syntax workflow now refuses a
    preview that was not regenerated. The preview also takes its version from
    scripts\version.txt - title, footer and the VERSION the code uses - so it
    cannot announce a release it does not belong to. The file carries a
    generated-file banner at the top saying which sources to edit instead.
    Nothing about the dashboard changes: the same page is served from the same
    here-string, and _build\ is still left out of the release archive.

------------------------------------------------------------------------------
  1.16.13 - 2026-10-14
------------------------------------------------------------------------------

Changed:
  - The dashboard no longer asks Core Temp's WMI add-on anything unless
    settings.txt asks for it. The temperature chain ended with a query to the
    namespace root\CoreTemp, the one Core Temp's free "Core Temp WMI provider"
    add-on registers - and that query is the only thing in the whole script
    that goes through Core Temp's own registration instead of reading
    something Core Temp publishes by itself (a block of shared memory, its own
    CSV log, its ini file, its process). On a machine where Core Temp's window
    kept coming back, it is also the only Core Temp related action worth ruling
    out, so it is off by default: the new key coretemp_wmi = yes turns it back
    on, for the machine where neither the shared memory nor the log answers
    and only WMI does. Nothing else about the chain changed: the shared memory
    is still looked for under the Global\ names as well - which is what a
    dashboard running as a boot task needs - and Core Temp's CSV log is still
    read across sessions. An installation that gets its temperature from that
    WMI source and nothing else shows an empty temperature row after updating
    until coretemp_wmi = yes is written in settings.txt, or "enable global
    shared memory" is switched on in Core Temp > Options > Advanced, or Core
    Temp's own logging is enabled (see the manual).
  - The log now names the process that started Core Temp. The line written
    when Core Temp appears already said that the dashboard never starts it;
    it now carries the process id of Core Temp, the id of its parent and the
    parent's name when it still exists:

        Core Temp is running: ... (pid 15904, started by explorer.exe pid 9620)

    Nothing in the script launches anything but powershell.exe, so that parent
    is the answer to "why does Core Temp keep coming back?" on a machine where
    it does - asked from the log of the machine itself, instead of from a
    guess. The line written when no source answers now lists what was really
    tried, the WMI add-on included and only when coretemp_wmi allows it.

------------------------------------------------------------------------------
  1.16.12 - 2026-10-14
------------------------------------------------------------------------------

Fixed:
  - The interval saved from the settings panel is the interval that was asked
    for. The bounds of the accepted values were written with integer literals -
    3600 for the refresh interval, 0 and 3600 for the idle one - and PowerShell
    then resolves Min/Max to the Int32 overload, which throws the fraction
    away: 2.5 seconds was written and used as 2, 1.25 as 1, and 0.5 as 0.
    That last one did not show: 0 is below the lower bound of
    refresh_seconds, so it was read back as 0.5 and the panel looked right
    while settings.txt held a value that does not exist. For idle_seconds the
    same rounding was worse, because there 0 is a meaning of its own - "do not
    sample at all while nobody is watching" - so choosing half a second
    switched idle sampling off. The bounds are doubles now (3600.0, 0.0).
    Nothing else moved: a value under the lower bound is still lifted to it, a
    value over an hour is still cut to 3600, the range of accepted values is
    exactly what it was, and the other settings are untouched.
  - The same shape was found and fixed in the per-adapter network rates. The
    down and up rate of every network card was clamped with
    [math]::Max(0, $rate), and that integer zero made PowerShell choose
    Max(Int32, Int32) again: the rate was rounded to the nearest byte per
    second (invisible on the page, which shows tenths of a kilobyte) and,
    above 2 GB/s inside one cycle - a 25 GbE card, or a counter that jumps -
    the call threw instead of returning, so that cycle was published without
    its network section and a collector line said why. The bound is a double
    here too; the values are the same, and there is nothing left to round.

------------------------------------------------------------------------------
  1.16.11 - 2026-10-14
------------------------------------------------------------------------------

Changed:
  - The dashboard page is edited as three real files instead of being written
    inside the engine. The markup, the stylesheet and the script now live in
    _build\web\ (page.html, page.css, page.js): page.html carries the two
    marker lines that say where the other two go, and _build\Embed-Page.ps1
    splices them into the single here-string that ServerDashboard.ps1 ships and
    serves from memory. Nothing changes at runtime, and the page the server
    answers with is byte for byte the one it answered with before: the engine
    keeps the page inside itself, so an installation is still one script and
    nothing new is read from disk.
  - _build\ is a development folder, like the other folders the release
    workflow leaves out: it is not part of the release archive and the updater
    never copies it onto a server. The syntax workflow now parses the build
    script and runs it with -Check on every push, so the embedded copy and the
    sources can no longer drift apart: changing one without the other fails
    the build.

------------------------------------------------------------------------------
  1.16.10 - 2026-10-14
------------------------------------------------------------------------------

Fixed:
  - The documentation and the comments tell the truth about the server options
    again. Since 1.16.7 the settings panel writes them to settings.txt from the
    page when no password is set, but four places still described the old,
    read-only panel: the offline preview in docs\ (its panel showed "read-only:
    set on the server in settings.txt" and greyed the controls out), the string
    behind that note in all 38 language files, and two comments inside the
    script that placed the settings in a settings.json with a 5 second refresh.
  - docs\Dashboard-Preview.html is now the page the script serves, with the
    sample data and the dictionaries embedded: the same markup, the same CSS
    (including the scroll bar arrows of 1.16.7) and the same code, so its panel
    shows "Unlocked: Save writes these options to settings.txt on the server"
    with the controls live, exactly like a fresh install.
  - The unused readonly_server string is gone from all 38 language files, and
    the comments left in ServerDashboard.ps1 about where the settings live and
    what the defaults are have been corrected.

Changed:
  - Nothing else changes: the dashboard writes the same settings.txt, answers
    the same requests and draws the same page as 1.16.9.

------------------------------------------------------------------------------
  1.16.9 - 2026-10-13
------------------------------------------------------------------------------

Fixed:
  - The check that starts the dashboard with the 32-bit engine no longer
    fails on a slow runner. It asked /api/stats once, right after /api/health
    answered; the CPU section appears only once the first sampling cycle has
    finished, and on a busy runner that cycle takes longer than the health
    answer - so the same commit went red once and then passed on a re-run.
    The check now waits, up to a minute, for the CPU section and keeps the
    same assertions afterwards: the field must be there, the temperature
    source must be there, the page must carry the temperature row, and the
    log must name the engine and the temperature chain. The dashboard itself
    is unchanged.

------------------------------------------------------------------------------
  1.16.8 - 2026-10-13
------------------------------------------------------------------------------

Fixed:
  - A settings change coming from another site's page is refused. Since 1.16.7
    the settings panel writes the server options straight from the browser
    when no password is set, and the API accepted such a write from whoever
    asked: a page of another site, left open in a browser that can reach the
    dashboard, could switch automatic updates on and have the server fetch
    and install a release (the zip is used as it comes, without a checksum).
    The write is now accepted only when the request shows it comes from the
    dashboard itself - the Origin header browsers send, and Sec-Fetch-Site
    when they know it - and anything else is answered 403 and written to the
    log with the address and the origin it came from. A request with no
    Origin at all (a script, curl, a monitoring probe) still works, and with
    a password set nothing changes: those rules are the same as before, and a
    foreign page has nothing to prove anyway.
  - The refusal line in the log names the origin, not only the address, so
    the log says which page tried it.

Changed:
  - The documentation now describes what the dashboard does. README.md still
    said the server options were "only on the server" and that the settings
    API "answers 403 to any write attempt", which stopped being true in
    1.16.7; the API table of the manual repeated it. The comment blocks in
    the script that described the logging switch and the settings file were
    stale as well - including the one the dashboard writes into the user's
    settings.txt at every save.

------------------------------------------------------------------------------
  1.16.7 - 2026-10-13
------------------------------------------------------------------------------

Fixed:
  - The scroll bars had no arrow buttons. The page styles
    ::-webkit-scrollbar to give the bars its own colours, and Chromium stops
    drawing the little arrow buttons as soon as that pseudo-element is
    styled: the bars ended up with a thumb and nothing else. The four
    buttons (up, down, left, right) are drawn again, in the theme's colours,
    and the bars are 12 px wide instead of 9 so the arrows are clickable.
  - A closed Core Temp is left completely alone. The temperature chain
    reads what Core Temp publishes by itself - its shared memory, its own
    CSV log, its WMI add-on - and it now does so only while a Core Temp
    process is running, instead of trying and failing at every cycle. It
    was never the dashboard that opened Core Temp (there is no code here
    that starts it, in any version: the only process this script ever
    starts is a new copy of itself during an update), but the log now says
    which of the two situations it is in, once, when it changes: "Core Temp
    is running: reading what it publishes, and the dashboard never starts
    it", or "Core Temp is not running: its sources are skipped and nothing
    is started (Core Temp opens only by its own autostart)". A CT-Log that
    stopped being written is a session that ended, and it is no longer read
    on a machine where Core Temp has been closed.

Changed:
  - The server options can be changed from the browser with no password set.
    The settings panel used to grey them out with "read-only: set on the
    server in settings.txt" and the API refused every write with 403; now
    Save writes refresh interval, visible sections, logging and automatic
    updates into settings.txt from the page, and there is no need to open
    the file on the machine. Whoever can see the page can change them, which
    is exactly what the optional password is for: with a password the same
    panel asks for it instead (partial mode) or relies on the login that
    opened the page (total mode), and every write is still logged with the
    address of the caller. The options are the dashboard's own - no command
    can be run through the page either way.
  - The note in the panel says the same thing in all three cases now
    ("Unlocked: Save writes these options to settings.txt on the server"),
    reusing the string that was already translated in all 38 languages.

------------------------------------------------------------------------------
  1.16.6 - 2026-10-13
------------------------------------------------------------------------------

Added:
  - The CPU temperature says where it comes from: the page prints the name
    of the source after the reading (Core Temp, Core Temp (log file),
    BIOS/ACPI, LibreHardwareMonitor, OpenHardwareMonitor, HWiNFO), the
    payload of /api/stats carries it as Cpu.TempSource, and the log gets
    one line the moment the source appears, changes or disappears -
    naming every source that was tried when none of them answers. A
    reading is never shown without its source, and a missing temperature
    is no longer silent.
  - Core Temp's own log file is a temperature source: the newest
    CT-Log*.csv of the Core Temp folder is read by COLUMN NAME (the "Cur."
    columns only, one per core), so a different set of sensors or a new
    Core Temp keeps working, and only while the file is being written -
    three logging periods taken from Core Temp's own LogInt, never less
    than a minute - because an old log is a session that ended, not a
    current reading. This covers what the shared memory cannot: Core Temp
    started by the logged on user while the dashboard runs as SYSTEM in
    another logon session. New key in settings.txt: coretemp_log = the
    full path of that file (empty = look in the Core Temp folders).
  - CoreTempMappingObjectEx is read as well, the shared memory block of
    current Core Temp versions, together with the Global\ copies that
    "enable global shared memory" creates in its Advanced options: those
    are the ones a dashboard running as a service in another session can
    see. The Fahrenheit flag is read at the offset of the structure the
    opened name belongs to (2684 ANSI, 2784 Unicode).
  - The log and /api/health state which engine is running ("32-bit engine
    on 64-bit Windows"): the same script serves 32-bit and 64-bit Windows,
    and the answer to "which one is it?" no longer needs a guess.
  - A second CI job starts the whole dashboard with the 32-bit Windows
    PowerShell (%WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe)
    on every push - listener, CIM/WMI, temperature chain, JSON, page - so
    the 32-bit path cannot break unnoticed.

Fixed:
  - The dashboard used far more memory than it needed, and the cause was
    measured one step at a time on a real Windows 11 machine with Core
    Temp running (220 processes, 279 services, refresh every 0.5 s).
    With a real browser refreshing every 0.5 s and nine minutes of
    observation, Task Manager's Memory column swung between 35.5 and 203.9
    MB and the private bytes sat between 202.7 and 239.7 MB; on the same
    machine and the same protocol, with the trim still on its old timer,
    the same build stayed between 15.2 and 127.1 MB of Memory and between
    156.0 and 159.8 MB of private bytes (the budget that replaced that
    timer is measured in the Changed entry below). Two
    calls were
    responsible. The Disks section called Get-PhysicalDisk and
    Get-Partition, and the Network section called Get-NetAdapter,
    Get-NetAdapterStatistics and Get-NetTCPConnection: those five cmdlets
    load the Storage, NetAdapter and NetTCPIP modules, and the assemblies
    of those modules stay in the process for the rest of its life - 33, 12
    and 8 MB respectively, of which Remove-Module gives back only 2 MB.
    They are replaced by the WMI classes the cmdlets themselves read
    (MSFT_PhysicalDisk, MSFT_Partition, MSFT_NetAdapter,
    MSFT_NetAdapterStatisticsSettingData, MSFT_NetTCPConnection), which
    answer through CIM - already loaded for every other metric - with the
    same values. The words the cmdlets added are put back from the
    documented Windows values (BusType 11 = SATA, MediaType 4 = SSD,
    InterfaceOperationalStatus 1 = Up, State 5 = Established,
    ReceiveLinkSpeed in bits per second), so the page and /api/stats show
    exactly what they showed before; a number that is not in those tables
    stays a number instead of being guessed into a word.
  - The request loop released neither the kernel wait handle it creates
    for every request nor the response object (only its output stream).
    Both are released now: over a nine-minute run the handle count of the
    process is steady at 664-710, against 804-960 before.
  - The memory trim no longer compiles anything. EmptyWorkingSet lives in
    psapi.dll and had to be declared with Add-Type, which compiles a small
    C# assembly at runtime: measured on a real server that compilation
    alone is about 5 MB of working set (62.2 -> 68.1 MB on an otherwise
    empty engine). Assigning the process its own MaxWorkingSet asks
    Windows for exactly the same trim with no compilation at all, and
    measured it trims at least as well (7.3 MB against 13.5 MB on the same
    deliberately fattened process). The trim is not free either way: it
    costs 26-36 ms to run and makes the first read of the pages it sent
    away about 23% slower (303 -> 373 ms on a deliberately touched 96 MB
    block), which is why it never runs on the request path. When it runs
    is the budget, changed in this release (see below).
  - What the descriptions of the executables cost was measured instead of
    assumed, because it looked like the biggest remaining item: on the
    test server 210 processes map to only 46 distinct executable paths, so
    the once-per-path cache already avoids 57 of the 103 possible reads,
    and the whole set of descriptions - strings and cache together -
    retains 1.9 MB, 124 ms to read. It was left alone: it is not what the
    process is holding.
  - The dashboard could not update itself: Stop-DashboardProcess.ps1 also
    stopped the process RUNNING the update, because its command line
    contains ServerDashboard.ps1 with -UpdateNow. The update died between
    "Stopping the dashboard..." and the install, so the files of the new
    version were never copied. That process is never stopped now, neither
    by process list nor by port.
  - With no scheduled task installed, an update copied the new files and
    left nothing running: the last-resort launch passed -WindowStyle
    twice, PowerShell refused to bind that parameter, and the error was
    swallowed by the catch. The new version is running again after an
    update now.

Changed:
  - The memory trim is a budget now, not a timetable: as soon as the
    process goes over mem_budget in settings.txt (20 MB by default, 0 =
    never) the pages it is not using are released, checked once per
    sampling cycle, instead of every five minutes whatever the number
    says. Measured side by side on a real Windows 11 machine, both builds
    answering the same request stream at 0.5 s for seven minutes (840
    requests each, 116 KB of JSON per reply, working set sampled four
    times a second): with the timer Task Manager's Memory column ran
    21.4-156.5 MB, median 118.6, 6.2% of a core; with the budget 7.7-67.9
    MB, median 44.6, 11.8% of a core. The 20 MB asked for is NOT held
    while a page refreshes - 83% of the samples are over it, by +24.6 MB
    at the median (a real browser tab, which asks once a second because a
    browser throttles an unfocused window, is the friendlier case at 54%)
    - because one sampling cycle puts a median of 30.0 MB back into the
    working set in under a second. Those MB are pages, not retained heap:
    across every trim and refill the private bytes of the process do not
    move at all (the same 119.8 MB at the trough right after a trim and at
    the peak of the cycle that follows, against a 64 MB swing of the
    working set), so no reduction of the per-cycle churn would bring the
    figure down. A budget under that figure re-reads
    the same pages at every cycle, which is where the doubled CPU, the 80
    trims a minute and the 27% slower request landing in the second after
    a trim (3.7 against 2.9 ms) come from. At 90 MB, same protocol, the
    number settles at a median of 72.9 MB (p95 88.2, 1.2% of the samples
    over it) with about 6 trims a minute and the CPU back to 6.2%: the
    setting caps the peak, and settings.txt says so in its own comment.
  - /api/stats no longer rebuilds its 115 KB JSON document at every
    request. The collector serializes the snapshot once per cycle and the
    web thread serves those exact bytes, so a page refreshing twice a
    second no longer builds the same document twice a second. Measured on
    the same machine, the median time to fetch and parse a full /api/stats
    went from 10.2 ms to 4.7 ms. The fallback stays for the very first
    requests, before the first cycle has finished.
  - The disk list, the adapter list and the partition-to-disk map are read
    once and reused: they do not change while the machine runs, so asking
    CIM for them again every ten seconds bought nothing.
  - "not available (no ACPI sensor)" became "not available (no temperature
    source found)" in English and Italian: with six sources tried, naming
    ACPI alone had stopped being true. The other 36 languages keep their
    wording until a translator revisits them.
  - The Processes table opens in name order (A to Z, on the friendly name
    the column shows) instead of by CPU. With about two hundred rows, a
    list that reorders itself at every refresh is hard to read, and the
    name is what gets looked up. Every column can still be clicked and the
    Process column still sorts on the name it shows; the choice stays in
    the browser, per visitor.
  - The Operating system card names the Windows release too: the OS row
    now reads "Microsoft Windows 11 Home 25H2" (DisplayVersion, or the
    ReleaseId on the older builds) and the version row carries the full
    revision, "10.0.26200.9457 (build 26200)". Win32_OperatingSystem
    reports neither of them, and its ProductName still says "Windows 10"
    on Windows 11, so the name keeps coming from the Caption. The registry
    keys read the same in the 32-bit and in the 64-bit engine.

------------------------------------------------------------------------------
  1.16.5 - 2026-10-12
------------------------------------------------------------------------------

Added:
  - Network card: a legend under the traffic chart (green square =
    Download, orange square = Upload, the same colours as the two lines),
    the headline values are coloured to match, and the adapter table
    spells the words out instead of an arrow alone ("Download KB/s",
    "Upload KB/s"). The totals keep their RX / TX names. Everything
    reuses the download and upload keys already translated in all 38
    languages, so no new string was needed for the chart and the columns.
  - The Processes table highlights the dashboard's own row (left bar and
    tinted background, the same treatment as the event rows). With about
    two hundred processes sorted by CPU the engine was findable only
    through the filter box. The server marks the row with a new "Self"
    field in /api/stats, so nothing depends on a name written twice.

Changed:
  - The Process column now sorts by the name it SHOWS: the friendly name
    ("Windows Explorer") instead of the image name (explorer.exe), which
    is what the column displays as its main line since 1.16.3. The
    tie-break uses it too. Services and Events are untouched: they keep
    sorting on the value of their own column (service name, message time).

Fixed:
  - The personal refresh interval could be lost without a trace: it was
    kept in localStorage only, and a browser that refuses localStorage
    (privacy mode, storage policy) silently dropped it, so the next visit
    showed the server default again with no explanation. The choice is
    now written to a cookie as well and read from it when localStorage
    comes back empty; when neither store accepts a write, the settings
    panel says so under the refresh interval instead of losing the choice.

Language files:
  - New key storwarn, translated in all 38 languages.

------------------------------------------------------------------------------
  1.16.4 - 2026-10-01
------------------------------------------------------------------------------

Changed:
  - version.txt in every release now carries a second line, the build
    commit written by the release workflow. When the same version is
    published again with different content the commit changes, and
    every dashboard updates anyway instead of waiting for a number
    that will never come. The main branch keeps the one-line file, so
    every older version keeps reading it.
  - The startup log now says which build commit the running version is.

Fixed:
  - Manual update: scripts\Update-Now.bat now restarts itself as
    administrator, like Diagnose.bat. Without those rights the old
    instance could not be stopped and the task could not be started
    again: the update looked successful while the OLD version kept
    serving, and the new one only appeared at the next boot.
  - The restart after an update got two more safeties: if the port
    never frees, the log now says that the old version is still the
    one answering; and the direct launch of the last resort reserves
    the URL first, so it can really listen.

------------------------------------------------------------------------------
  1.16.3 - 2026-10-01
------------------------------------------------------------------------------

Changed:
  - Process list: the friendly name ("Windows Explorer") is now the main
    line of the column and the image name (explorer.exe) sits right under
    it, grayed; an executable without a friendly name shows the image name
    alone. Filtering and sorting work exactly as before.
  - The browser tab title is back to plain "Dashboard", in the language
    of the page as before 1.16.2, and now shows the server name first:
    "<server> - Dashboard". The full product name stays in the footer,
    in the process list, in the logon notification, in the scheduled
    task and in the event log.
  - The engine keeps its memory footprint small: every 5 minutes it
    collects its garbage and asks Windows to move the pages it is not
    using out of the working set. Task Manager then shows the memory the
    dashboard really needs, instead of the ~80 MB of pages accumulated
    while running.

Fixed:
  - Servers that auto-updated to 1.16.2 carry a few pre-1.16.0 leftovers
    in their docs folder (an old manual and old screenshots): they are
    removed at the first start. A logo.png kept in the root is a personal
    file and is never touched.

------------------------------------------------------------------------------
  1.16.2 - 2026-10-01
------------------------------------------------------------------------------
Fixed:
  - Slow start at boot and "I have to install twice": up to 1.16.1 the
    GitHub update check ran BEFORE the web server was started, so on a
    slow network the port stayed closed for up to half a minute at every
    boot and right after an installation. The dashboard looked like "it
    does not start by itself" and the installer reported it as not
    answering - which is why a second run of Install.bat looked like "now
    it works". Since 1.16.2 the page answers first and the update check
    runs after it; the installer also keeps checking the health for up to
    45 seconds instead of failing after a fixed 5.
  - After an update the new version now starts reliably. The old instance
    may need a moment to release the port, and a task whose previous
    instance is still "Running" silently refuses to start a new one: the
    updater now waits for the port to be free, asks for the start again
    and again and, as a last resort, launches the engine directly, so the
    dashboard is never left down. When the hand over at boot cannot launch
    the new version, the current instance keeps serving instead of exiting.
  - Total password mode looked broken ("the browser never asks for the
    password") when settings.txt still carried password_mode = partial
    from an earlier experiment: the installer had no way to choose. It now
    asks, right after the password, what it must protect - the whole page
    or only the server options - and writes password_mode into
    settings.txt; scripts\Set-Password.ps1 asks the same when run alone
    or takes -Mode total|partial. A settings.txt reduced to that single
    key is completed with the full template at the first start.
  - The software did not fully identify itself as "PiBOH Windows Server
    Dashboard": the browser tab said "Dashboard", the page footer said
    "ServerDashboard" and the logon notification was titled "Server
    Dashboard". All of them now carry the full name; in the Processes
    table every process running ServerDashboard.ps1 is tagged with it
    too, so the dashboard is finally visible in its own list - with the
    same name the scheduled task and the event log always used. The
    firewall rule is renamed as well (the old one is migrated by
    Install.bat and removed by Uninstall.bat), together with the window
    titles of the .bat files and the header of settings.txt.

Changed:
  - Diagnose now also compares the password state reported by the running
    service with the pwd file, and says exactly what to do when the two
    disagree.
  - The manual states that the logon notification is translated into all
    the 38 languages: it reads the same lang\*.xml files of the page.
  - Diagnose recognizes a firewall rule still named the pre-1.16.2 way
    and says to run Install.bat once to rename it.

------------------------------------------------------------------------------
  1.16.1 - 2026-09-30
------------------------------------------------------------------------------

Changed:
  - The local files of an installation now live together in the
    .config-do-not-delete-me folder at the root of the package: the
    password file (pwd) and the settings backup written by Install.bat
    (settings-backup.txt). The existing pwd file is moved there
    automatically at the first start of the new version (from the
    package root, where 1.16.0 kept it), so no password is ever lost.
    An empty file still means "no password" and everything else works
    exactly as before.
  - Partial password mode, reworked: the settings panel no longer shows
    a lock. The server options look normal and a small popup asks for
    the password only at the moment one of them is clicked, never
    before; the server checks it immediately (a wrong one is refused in
    red, inside the popup) and after that the options stay editable and
    Save writes them to settings.txt.
  - install-state.txt (the file Uninstall.bat uses to revert everything)
    moved from logs\ into the scripts folder, created hidden and
    read-only so that it is not deleted or edited by mistake. The
    uninstaller still finds it in the old location too.
  - The self updater no longer copies the repository folders that are
    not part of the package (.github, screenshots, ...) when it
    downloads the GitHub archive of a release.

Added:
  - Install.bat asks whether to set the password during the installation
    (masked input, Enter alone = none) and never overwrites a password
    that is already set; scripts\Set-Password.ps1 sets, changes or
    removes it at any time.
  - No browser will ever offer to save the password - Chrome, Edge,
    Safari, Firefox, desktop and mobile: where supported the popup field
    is technically not a password field at all (it only looks like one),
    elsewhere it belongs to no form and is never submitted.
  - The password popup and the language window close also by clicking
    outside them, like the settings window always did.

Fixed:
  - Language window: closing it with a click on the dark background
    around it (instead of the X button) left an empty copy of the window
    at the bottom of the page. It now disappears, exactly like a close
    with the X button.

------------------------------------------------------------------------------
  1.16.0 - 2026-09-29
------------------------------------------------------------------------------

Added:
  - Optional password, stored in a plain text file called "pwd" (no file
    extension) next to settings.txt: create the file, write the password on
    the first line, done - no restart needed, changes apply within ten
    seconds. password_mode in settings.txt decides what it protects:
    total (default) asks the password for the whole dashboard (standard
    browser login window, /api/health stays open for the updater and
    Repair-Autostart.bat), partial leaves the page open to everybody and
    locks only the server options, which become editable from the settings
    panel after typing the password. Without the file everything works
    exactly as before: the API stays read-only and every write is refused
    with 403 and logged. The password is never sent to the browsers, never
    written to the log, preserved by every update, excluded from GitHub
    (.gitignore) and deleted by Uninstall.bat. New UI strings translated
    into all the 38 languages.

Changed:
  - The automatic update check now also repeats every 24 hours while the
    dashboard runs, so a server that stays on for months receives updates
    without a reboot: it launches the same cycle used by Update-Now.bat,
    and a marker file (.update-running) keeps a manual run and the
    automatic one from racing each other.
  - The main loop now wakes up once per second even with nobody connected:
    settings.txt and the pwd file are reloaded within ten seconds in every
    condition, not only when a request arrives.
  - The CI syntax check now parses the scripts with Windows PowerShell 5.1
    (the engine the scheduled task really uses) instead of PowerShell 7.

Fixed:
  - Endless update loop: up to 1.15.0 a failed install left version.txt
    untouched, so every start saw the same "new" release, reinstalled it,
    spawned itself and exited, over and over, with the port never opening -
    the dashboard looked like "it does not start by itself" and no update
    ever landed. Before handing over to a new version the script now
    verifies that version.txt on disk really changed; if it did not, it
    stays up on the current version, logs the error and writes it to the
    Windows event log.
  - Leftover nested folders: the scripts\scripts (and lang\lang, ...)
    copies created by the pre-1.15.1 updater are now removed at every
    start, in every start mode, however deep they are nested.

------------------------------------------------------------------------------
  1.15.2 - 2026-09-28
------------------------------------------------------------------------------

Changed:
  - The release notes moved under the changelog folder: they now live in
    Changelog\\release-notes\\RELEASE-NOTES-vX.Y.Z.md, one file per
    release, next to the only changelog file.
  - Core Temp compatibility no longer needs anything but Core Temp itself:
    up to 1.15.1 the dashboard only understood Core Temp through its
    optional "WMI provider" add-on, now it reads the shared memory block
    that the plain program publishes while it runs - no add-on, no server
    plug-in, nothing to enable. The block holds a fixed C struct without
    pointers, so it is read the same way on 32-bit and 64-bit (Core Temp
    and the dashboard may even mix bitnesses), with one reading per core,
    multi-socket labels (CPU0 Core0, CPU1 Core0, ...) and Fahrenheit
    converted back to Celsius automatically. The WMI provider add-on is
    still read, right after the plain one, because WMI also crosses logon
    sessions.
  - Out-of-range readings (0 or above 150 degrees) and incoherent headers
    are discarded instead of being shown as a temperature.

Fixed:
  - Multi-socket label rounding: a PowerShell [int] cast rounds 1.5 to 2,
    which would print "CPU2 Core1" on a two-socket machine; the label now
    uses Floor.

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

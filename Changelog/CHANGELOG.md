# Changelog

All notable changes to this project will be documented in this file.

The format is based on [keepachangelog.com](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## Unreleased

### Added
### Changed
### Fixed
### Security

---

## [1.16.21] - 2026-10-15

### Added
- 📱 Phone layout: grid cards adapt to widths up to 480px (phone) and 900px (touch screen), no horizontal scrolling
- 📊 Wide tables as blocks: processes, services, events and adapters display as labelled value blocks, fully readable without dragging
- 🔍 Table headers as pinned chips: sort by clicking CPU %, memory, etc. arrow indicates sort direction
- 🎯 Touch target improvements: half-press on row opens menu with search, Properties, copy commands; 10px travel or second finger cancels
- ♿ Accessibility: value labels are real elements read by screen readers with column context (e.g. "PID 15688"); no `aria-sort` used

### Changed
- 🎨 About panel: emoji replaced with inline SVG marks (follow theme colour); "read live from GitHub" line and unclear Releases label removed
- 🌡️ Temperature "not available" line: English in Latin-alphabet languages, translated in others; one less key to maintain
- 📄 docs\\README.md: documents phone layout of wide tables and long-press row menu

### Fixed
- 🔧 CPU %: computed from raw counters instead of formatted WMI classes (was showing wall of zeros)
- 📈 Disk busy %: same fix - raw counters, rate computed from two samples
- 🔄 Process table refresh: CPU %, memory, threads and handles read every cycle; names/paths on 30s tier

---

## [1.16.20] - 2026-10-15

### Added
- 📊 Raw counter sampling: CPU and disk percentages now use underlying counters instead of formatted classes
- 🔧 First sample defence: initial page load uses two samples 300ms apart, no zero wall

### Changed
- 📈 Process table opens busiest first (like Task Manager), sorted by CPU % descending
- 🎨 About panel: GitHub logo, globe, envelope as inline SVG (theme-colour, consistent across servers); "i" caption, "read live from..." line, and ambiguous Releases label removed
- 🌡️ Temperature panel: stays open until user closes (X, Escape, or click on dark background); refresh no longer dismisses it
- 🌐 Temperature "not available" line: English in 27 Latin-alphabet languages, translated in 11 others (Arabic, Bulgarian, Greek, Hebrew, Japanese, Korean, Russian, Thai, Ukrainian, Chinese)

### Fixed
- 🐛 CPU % wall of zeros: fixed by reading raw performance counters
- 🛑 Disk busy % stuck at same value: fixed by reading raw counters

---

## [1.16.19] - 2026-10-15

### Changed
- 🔌 Single refresh frequency control: with no password, one control in settings panel; saved choice ignored if older browser cache exists
- 🔐 With password: header selector and settings panel row both present, each browser keeps its own choice; server value protected by password

### Fixed
- 🐛 Settings selector mismatch: browser-saved interval no longer preferred over `settings.txt` when no password

---

## [1.16.18] - 2026-10-15

### Added
- 🌡️ Temperature source selector: "?" next to CPU temperature opens list of working sources (Core Temp, LibreHardwareMonitor, OpenHardwareMonitor, HWiNFO)
- 📋 Row menu on long press: half-second press on process/service row opens menu with web search, Properties, copy commands
- 🌡️ Temperature unit follows language; `temperature_unit` in settings.txt forces it
- 🏷️ 33 new labels translated into all 38 languages

### Changed
- 🌡️ Temperature row: names the source that answered; ACPI thermal zone shown for what it is (board zone, not CPU); empty row when nobody answers
- 🔒 Without password: one refresh frequency for server and page together

---

## [1.16.17] - 2026-10-14

### Added
- 📋 About panel: reached via version line in footer; author, portfolio, e-mail, repository and release links; changelog read from GitHub each time (never cached)

### Changed
- 📝 Changelog format: every release and every Added/Fixed/Changed/Removed line gets its own line

---

## [1.16.16] - 2026-10-14

### Fixed
- 🔄 Dashboard update loop: two faults corrected - duplicate `-WindowStyle` flag and version number-only comparison
- 📝 Log names who started Core Temp: parent process when available, and scheduled task

---

## [1.16.15] - 2026-10-14

### Added
- 🖼️ Browser tab logo: `/favicon.ico` serves `docs\\logo.png`

### Changed
- 📸 README screenshots: taken in English

---

## [1.16.14] - 2026-10-14

### Changed
- 📄 Dashboard preview: generated from `_build\\web\\` by `_build\\Embed-Page.ps1`; fails when copies do not match

---

## [1.16.13] - 2026-10-14

### Changed
- 🔌 Core Temp WMI add-on: queried only with `coretemp_wmi = yes` (off by default); log names the process that started Core Temp

---

## [1.16.12] - 2026-10-14

### Fixed
- ⚖️ Fractional rounding: bounds as doubles; 2.5s stored as 2, 0.5s switches idle sampling off; same fix applied to network rates

---

## [1.16.11] - 2026-10-14

### Changed
- 📄 Page editing: three files in `_build\\web\\`, spliced by `_build\\Embed-Page.ps1` - sources and server page can no longer drift apart

---

## [1.16.10] - 2026-10-14

### Fixed
- 📝 Offline preview: no longer describes settings as read-only (stale since 1.16.7); unused `readonly_server` string removed from all 38 language files

---

## [1.16.9] - 2026-10-13

### Fixed
- 🖥️ 32-bit CI: waits for CPU section instead of failing on slow runner

---

## [1.16.8] - 2026-10-13

### Fixed
- 🚫 Cross-site settings write: refused with 403 and logged with origin; documentation corrected

---

## [1.16.7] - 2026-10-13

### Fixed
- 📉 Scroll bar arrows: drawn again (Chromium drops them when `::-webkit-scrollbar` is styled)
- 🌡️ Core Temp sources: read only while a Core Temp process is running

### Changed
- 💾 Settings write: from no-password page writes to `settings.txt`

---

## [1.16.6] - 2026-10-13

### Added
- 🌡️ Temperature row: names its source (Cpu.TempSource); Core Temp's own CT-Log CSV is a source
- 🏥 Health endpoint: `/api/health` states 32/64-bit engine
- 🖥️ 32-bit CI job: runs the whole dashboard with the 32-bit engine

### Fixed
- 💾 Memory: reduced from ~200 MB to default 20 MB (replacing five cmdlets with CIM classes, releasing per-request wait handles, trimming without Add-Type)
- 🔄 Self update: works again (updater no longer stops itself, fallback launch binds its parameters)

### Changed
- 📊 JSON stats: built once per cycle (10.2 → 4.7 ms); static lists read once; Processes in name order; OS card names the release

---

## [1.16.5] - 2026-10-12

### Added
- 📊 Network chart: legend and coloured headline values
- 🏷️ Dashboard row highlighted in Processes table

### Fixed
- 🔄 Personal refresh interval: survives browser that refuses localStorage (cookie fallback, panel reports it)

---

## [1.16.4] - 2026-10-01

### Changed
- 📝 version.txt: carries build commit on second line; republishing a version updates running dashboards; startup log names that commit

### Fixed
- 🔄 Manual update: Update-Now.bat elevates; restart waits for port; last-resort launch reserves URL first

---

## [1.16.3] - 2026-10-01

### Changed
- 👯 Friendly name: main line in process list; tab title back to `"<server> - Dashboard"`; five minute memory trim

### Fixed
- 🧹 Pre-1.16.0 leftovers removed from docs\\

---

## [1.16.2] - 2026-10-01

### Fixed
- ⏱️ Page answers before update check: reliable updates again (port wait, retries, direct launch)
- 📝 Installer: asks for password_mode
- 🏷️ Software identifies itself everywhere with full name

---

## [1.16.1] - 2026-09-30

### Added
- 📁 Local files moved to `.config-do-not-delete-me`
- 🔐 Partial password mode: asks only when an option is clicked
- 📂 Install-state.txt: hidden in scripts\\

### Changed
- 🔑 Password asked during installation only; never offered for browser saving
- ⬜ Popups close by clicking outside them

---

## [1.16.0] - 2026-09-29

### Added
- 🔐 Optional password: `file pwd`, `password_mode total|partial` - protects whole page or only server options, never logged, never sent to browser
- ⏰ Update check: repeats every 24 hours; settings.txt and pwd reloaded within ten seconds; CI parses with Windows PowerShell 5.1

### Fixed
- 🔄 Endless update loop: when install failed (version.txt verified before handover); nested scripts\\scripts folders

---

## [1.15.2] - 2026-09-28

### Changed
- 📝 Release notes moved to Changelog\\release-notes\\
- 🌡️ Core Temp: read from shared memory block it publishes (no add-on needed); WMI as fallback

### Fixed
- 🧮 Multi-socket core labels: use Floor instead of rounding [int] cast

---

## [1.15.1] - 2026-09-28

### Added
- 🎨 Project logo (docs\\logo.png), shipped inside the zip

### Fixed
- 🔧 Updater: copied every folder inside itself (scripts\\scripts) - now copies contents and cleans nesting
- 🔄 Update-Now.bat: runs whole cycle; manual update works with auto_update = no

---

## [1.15.0] - 2026-09-28

### Added
- 🏷️ Friendly name of every executable: cached per path and searched by filter

### Changed
- 📝 Changelog moved to Changelog\\; .ignore\\ gitignored; null CIM answer no longer leaves process list empty

---

## [1.14.0] - 2026-09-28

### Added
- 📝 Daily log rotation with 14 days retention
- 🚀 Automatic release workflow (auto-release.yml) that builds, validates and publishes the zip

### Changed
- 📸 Screenshots moved to screenshots\\; zip no longer carries settings.txt

---

## [1.13.0] - 2026-09-28

### Added
- 🔄 Self update from GitHub at every start (auto_update = no to disable; Update-Now.bat to force)
- 📝 Version from scripts/version.txt only; task and event log identify the software

### Changed
- ⏱️ Default refresh: 5 s → 0.5 s; every comment and file name in English

---

## [1.12.1] - 2026-09-27

### Fixed
- 🌐 Local volumes not all under "other volumes" (three fallbacks, route logged); header state follows language change; disks card never renders empty

### Added
- 📊 Diagnose: "STARTS WITHOUT INTERACTIVE LOGON: YES/NO"

---

## [1.12.0] - 2026-09-27

### Changed
- 📁 Package layout: only .bat files and settings.txt in root; scripts\\ for every script; docs\\ for manual and preview; logs\\ for every log; every script finds root by itself

---

## [1.11.7] - 2026-09-27

### Fixed
- 🐛 Critical: dashboard did not start at all - line of dashes left over from 1.7.0 broke parse; failing metric no longer wipes sample; null-safe CIM strings; network detection no longer waits on WMI

### Added
- 🧪 Test-Syntax.ps1: run by Install.bat before it touches anything

---

## [1.11.6] - 2026-09-27

### Changed
- ⏱️ Refresh interval: per-browser choice again, with settings.txt value offered as "server default"

---

## [1.11.5] - 2026-09-27

### Changed
- 🔒 /api/settings: GET only; POST refused 403 and logged; panel read-only for server options; settings.txt picked up within ten seconds without restart

---

## [1.11.4] - 2026-09-27

### Changed
- 🛠️ Boot task: created by New-DashboardTask.ps1 (SYSTEM by SID, non-interactive); reads back principal, logon type, boot trigger and state
- 🛠️ Repair-Autostart.bat: rebuilds reservation, task and service
- 📝 Diagnose: prints "STARTS WITHOUT INTERACTIVE LOGON: YES/NO"

### Added
- 🛠️ Diagnose-Bat, ServerDashboard-notify.log and more Diagnose checks

---

## [1.11.3] - 2026-09-27

### Fixed
- 🌐 URL reservation: used English SYSTEM account name, failed on localized Windows; resolved by SID; logon notification falls through to toast-styled window

### Added
- 🧪 Test-Notification.bat, ServerDashboard-notify.log and more Diagnose checks

---

## [1.11.2] - 2026-09-27

### Fixed
- 🛠️ Diagnose.bat and Install.bat: closed immediately (inline PowerShell inside FOR / F); logic moved to Diagnose.ps1, which reports in colour and ends with numbered problems list

---

## [1.11.1] - 2026-09-27

### Fixed
- 🌐 Dashboard reachable only after logon (up to 5 minutes of retries, localhost only on real access-denied); task retries on failure

### Added
- 🛠️ Diagnose.bat; Install.bat warns when folder is inside user profile or OneDrive

---

## [1.11.0] - 2026-09-27

### Added
- ⏱️ Half-second refresh with decimal separator of the language; logging = yes/no
- 🛌 Nothing runs while nobody watches (idle_seconds = 0 by default); background tab shows "Paused"; /api/health says whether sampling is on

---

## [1.10.0] - 2026-09-27

### Added
- 📦 Install.bat: applies only missing changes, prints BEFORE and AFTER, records previous state; Uninstall.bat reverts exactly that

### Changed
- 📦 Processes: listed with real image name, joined to Win32_Process for full path; logon notification optional

### Added
- 📄 /api/languages and /lang/<code>.xml

---

## [1.9.0] - 2026-09-27

### Added
- ⏱️ One second refresh
- 📢 Logon notification (Show-StartupNotification.ps1: toast then balloon then window) in Windows language

### Changed
- 📊 Tiered sampling: processes 5 s, disks 10 s, services and sessions 30 s, events 60 s; duplicated queries removed; page repaints section only when data changed

---

## [1.8.0] - 2026-09-27

### Changed
- ⚙️ Settings in settings.txt (key = value, shipped filled in and recreated at startup if missing); virtual disks back in main list with "virtual" badge

### Fixed
- 🖼️ Canvas failure no longer aborts boot; panel opens with built-in defaults when server does not answer

---

## [1.7.0] - 2026-09-27

### Added
- 🌡️ Core Temp support through WMI add-on; HWiNFO as further fallback (order: BIOS/ACPI, Core Temp, LHM/OHM, HWiNFO)
- 🖥️ Fixed, removable, virtual and optical devices classified with bus and media badges

### Changed
- 📦 USB, card readers and optical drives listed apart under "Other devices"; README and CHANGELOG wrapped at 78 columns with CRLF endings

### Fixed
- 🚫 Language picker did not open (lost modal class in 1.4.0)

---

## [1.6.0] - 2026-09-27

### Added
- 📜 Events section (System and Application, last 24 hours, up to 150 entries, filters and sorting); read at most once a minute

---

## [1.5.0] - 2026-09-27

### Added
- 📦 Install.bat (applies only missing changes, prints BEFORE and AFTER, records previous state); Uninstall.bat reverts exactly that

---

## [1.4.0] - 2026-09-27

### Added
- ⚙️ Settings panel: theme and language in browser, refresh interval and visible sections on server, plus Restore defaults; adaptive sampling; /api/settings

### Changed
- ⏱️ Default interval: 3 s → 5 s

---

## [1.3.0] - 2026-09-27

### Added
- 🌙 Light and dark theme (dark by default, per browser); three-area footer with version in centre; sticky header

### Changed
- 💾 Disk activity merged into "Disks and partitions"; every file name, comment and document in English

---

## [1.2.0] - 2026-09-27

### Added
- 🌐 Interface in 38 languages (one XML file each in lang\\); automatic detection of Windows language; language button; right-to-left support; /api/languages and /lang/<code>.xml

---

## [1.1.3] - 2026-09-27

### Added
- 📊 Sorting of Processes and Services tables by clicking column headers, remembered by browser

---

## [1.1.2] - 2026-09-27

### Added
- 🛠️ Services section with text and state filters

### Changed
- 📦 Full process list instead of top 40

---

## [1.1.1] - 2026-09-27

### Added
- 📜 Scrollable process pane with sticky headers, a name filter and scroll position kept across refreshes

---

## [1.1.0] - 2026-09-27

### Changed
- ⚡ CPU and RAM charts split into two separate cards

---

## [1.0.0] - 2026-09-27

### Added
- 🚀 First release - built-in web server, CPU, memory, disk, network, IP, operating system, process and service metrics, auto-start task, firewall rule, history charts
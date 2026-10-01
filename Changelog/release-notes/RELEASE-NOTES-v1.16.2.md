# PiBOH Windows Server Dashboard v1.16.2

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`,
done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. When asked, type the optional password (or just press Enter for none)
   and choose what it protects: the whole page or only the server options
4. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.16.2

- **Answers right away at boot**: the update check no longer runs before
  the web server, so a slow network can no longer keep the port closed
  for half a minute. This also fixes "I have to run Install.bat twice":
  the installer now waits for the dashboard properly (up to 45 seconds of
  retries) instead of failing after five.
- **The update always ends with a running dashboard**: the updater waits
  for the old instance to release the port, asks the task to start again
  and again and, as a last resort, launches the engine directly. No more
  "updated but not running" after an automatic update.
- **The installer asks what the password must protect** - the whole page
  (total) or only the server options (partial) - right after asking for
  the password, and writes `password_mode` accordingly. This also cures
  "the browser never asks for the password": that happened when
  `settings.txt` still said `partial` from an earlier experiment, and the
  page opens by design in that mode.
- **Diagnose checks the password end to end**: it compares what the
  running service reports with the pwd file and says exactly what to do
  when the two disagree.
- The logon notification is confirmed translated into all the 38
  languages: it reads the very same `lang\*.xml` files of the dashboard.
- **It identifies itself everywhere now**: the browser tab and the footer
  said "Dashboard" and "ServerDashboard", the logon notification was
  titled "Server Dashboard", and in the Processes table the engine was
  just another powershell.exe. Tab title, footer, notification and
  process row now all say "PiBOH Windows Server Dashboard", exactly
  like the scheduled task always did. The firewall rule and the window
  titles of the .bat files carry the full name too: Install.bat renames
  the existing rule, Uninstall.bat removes both names.

Everything else stays as before: temperature chain with 5 sources (Core
Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, self update from GitHub
(`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

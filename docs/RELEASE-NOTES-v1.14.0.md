# PiBOH Windows Server Dashboard v1.14.0

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`, done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.14.0

- **One log file per day**: the log name carries the date
  (`logs\ServerDashboard-YYYY-MM-DD.log`), so at midnight the rotation
  happens by itself — no timer, no file ever growing without limit. Files
  older than 14 days are deleted automatically, at every start and once a
  day while running.
- **Automatic releases**: pushing a commit whose message starts with `v`
  (or running the workflow by hand) now builds and publishes the GitHub
  release by itself — zip built from the tracked files only, content
  validated, SHA-512 checksum attached, tag `v<version>` created.
- The screenshots live in `screenshots\` at the root of the repository and
  were regenerated with the interface in English.

## What you get

CPU (per core, GHz, temperature), memory, disks and partitions with live I/O,
network, IP configuration, operating system, processes, services and the
Windows event log of the last 24 hours; sortable tables, trend charts, light
and dark theme, **38 languages**, zero cost on the server while nobody is
watching. Self update from GitHub at every start
(`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

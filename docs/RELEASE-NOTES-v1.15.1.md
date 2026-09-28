# PiBOH Windows Server Dashboard v1.15.1

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`, done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.15.1

- Project logo on the GitHub page, shipped in the zip as well.
- **Self update fixed**: up to 1.15.0 the updater copied the `scripts` folder
  inside the existing `scripts\` folder, digging a nested hole one level
  deeper at every update (`scripts\scripts\scripts\...`). It now copies the
  contents of every folder, so an update lands exactly where the old files
  are — and it also cleans up the nesting left behind by the old versions.
- **Update-Now.bat does the whole cycle**: check GitHub, download, stop the
  dashboard, install, start the dashboard again and verify that it answers.
  With no new release it prints "up to date" and changes nothing.
- The manual update now works even with `auto_update = no` (the switch in
  settings.txt gates only the automatic check at boot), and
  `-CheckUpdatesOnly` only reports, without installing.

## What you get

CPU (per core, GHz, temperature), memory, disks and partitions with live I/O,
network, IP configuration, operating system, processes with their friendly
names, services and the Windows event log of the last 24 hours; sortable
tables, trend charts, light and dark theme, **38 languages**, daily logs kept
14 days, zero cost on the server while nobody is watching. Self update from
GitHub at every start (`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

# PiBOH Windows Server Dashboard v1.13.0

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`, done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.13.0

- **Self update**: at every start the dashboard checks this repository, and
  when a newer release is tagged it downloads and installs it by itself, then
  restarts. No logon required: it runs as SYSTEM at boot. Disable with
  `auto_update = no` in settings.txt.
- **Live by default**: the refresh interval is now 0.5 seconds out of the box
  (each visitor can still choose their own, from 0.5 s to 5 min).
- **Transparent by design**: the scheduled task is named "PiBOH Windows Server
  Dashboard" with a description in Task Scheduler, and every start is announced
  in the Windows event log with a full explanation of what the software does.
- The version now lives in `scripts/version.txt`, the single source of truth.

## What you get

CPU (per core, GHz, temperature), memory, disks and partitions with live I/O,
network, IP configuration, operating system, processes, services and the
Windows event log of the last 24 hours; sortable tables, trend charts, light
and dark theme, **38 languages**, zero cost on the server while nobody is
watching.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

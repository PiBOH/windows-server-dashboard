# PiBOH Windows Server Dashboard v1.15.2

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`, done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.15.2

- **Core Temp needs nothing but Core Temp.** Up to 1.15.1 the dashboard only
  understood Core Temp through its optional "WMI provider" add-on; now it
  reads the shared memory block that the plain program publishes while it
  runs: no add-on, no server plug-in, nothing to enable. One reading per
  core, multi-socket labels (`CPU0 Core0`, `CPU1 Core0`, ...) and Fahrenheit
  converted back to Celsius automatically.
- **32-bit and 64-bit alike**: the shared memory block is a fixed structure
  without pointers, so its layout is identical everywhere - Core Temp and
  the dashboard may even run with different bitnesses.
- The optional WMI provider add-on is still read, right after the plain
  one, because WMI also crosses logon sessions.
- Out-of-range readings and incoherent headers are discarded instead of
  being shown as a temperature, and a multi-socket label now rounds down
  correctly instead of printing `CPU2` on a two-socket machine.
- The release notes now live in `Changelog\release-notes\`, next to
  `Changelog\CHANGELOG.md`.

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

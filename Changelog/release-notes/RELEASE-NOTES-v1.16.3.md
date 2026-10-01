# PiBOH Windows Server Dashboard v1.16.3

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

## What's new in 1.16.3

- **Process list, new order**: the friendly name ("Windows Explorer") is
  the main line of the column and the image name (explorer.exe) sits
  right under it, grayed; without a friendly name the image name is
  shown alone. Filtering and sorting work exactly as before.
- **The browser tab shows the server name first**, "<server> -
  Dashboard", translated like before 1.16.2: the full product name
  stays in the page footer, in the process list, in the logon
  notification, in the scheduled task and in the event log.
- **Less memory**: every 5 minutes the engine releases the memory pages
  it is not using (working set trim), so Task Manager shows what the
  dashboard really needs instead of the pages accumulated since the
  start (about 80 MB until now).
- Servers that auto-updated to 1.16.2 received a few pre-1.16.0
  leftovers in their docs folder: the first start of 1.16.3 removes
  them. A logo.png kept in the root is a personal file and is never
  touched.

Everything else stays as before: temperature chain with 5 sources (Core
Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, self update from GitHub
(`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

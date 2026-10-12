# PiBOH Windows Server Dashboard v1.16.5

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

## What's new in 1.16.5

- **Network: download and upload are finally unmistakable**. The traffic
  chart carries a legend (green = Download, orange = Upload), the two
  headline figures use the same colours, and the adapter table spells the
  words out instead of an arrow alone ("Download KB/s", "Upload KB/s").
- **The Process column sorts by the name it shows**: the friendly name
  ("Windows Explorer") instead of the image name (explorer.exe) that sat
  grayed under it. Services and Events keep sorting on their own column.
- **The dashboard finds itself**: its own row in the Processes table is
  highlighted with a left bar and a tinted background, so with two hundred
  processes sorted by CPU you no longer need the filter box to spot it.
- **The personal refresh interval cannot vanish silently any more**: it is
  now stored in a cookie as well as in the browser cache, so a browser
  that refuses localStorage keeps your choice after a reload; and if no
  store accepts the write, the settings panel says so under the refresh
  interval instead of quietly falling back to the server default.

Everything else stays as before: temperature chain with 5 sources (Core
Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, self update from GitHub
(`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

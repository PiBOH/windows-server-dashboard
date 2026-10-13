# PiBOH Windows Server Dashboard v1.16.7

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`,
done. It works on 32-bit and 64-bit Windows: it is one PowerShell script,
run by whichever Windows PowerShell the machine has.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. When asked, type the optional password (or just press Enter for none)
   and choose what it protects: the whole page or only the server options
4. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.16.7

- **The scroll bars have their arrows back.** The page gives the bars its own
  colours through `::-webkit-scrollbar`, and Chromium stops drawing the little
  arrow buttons the moment that pseudo-element is styled - so the bars had a
  thumb and nothing else. The four buttons are drawn again in the theme's
  colours (with a hover shade), and the bars are 12 px wide instead of 9 so
  the arrows are clickable.
- **The server options are editable from the browser with no password set.**
  The panel used to grey them out with "read-only: set on the server in
  settings.txt" and the API refused every write with 403; now Save writes the
  refresh interval, the visible sections, logging and automatic updates into
  settings.txt from the page, so there is no need to open the file on the
  machine. Whoever can see the page can change them, which is exactly what the
  optional password is for: with a password the same panel asks for it
  (partial mode) or relies on the login that opened the page (total mode), and
  every write is logged with the address of the caller. Nothing else changed:
  no command can be run through the page, and the options are the dashboard's
  own.
- **A closed Core Temp is left completely alone.** The temperature chain reads
  what Core Temp publishes by itself (its shared memory, its own CSV log, its
  WMI add-on), and it now does that only while a Core Temp process is running,
  instead of trying and failing at every cycle. A CT-Log that stopped being
  written is a session that ended, and on a machine where Core Temp has been
  closed it is no longer read at all. The dashboard has never opened Core Temp
  - there is no code in any version of this script that starts it: the only
  process it ever starts is a new copy of itself during an update - which is
  why Core Temp opens only when Core Temp's own "start with Windows" says so.
  The log now states which of the two situations it found, once, when it
  changes: *"Core Temp is running: reading what it publishes, and the
  dashboard never starts it"*, or *"Core Temp is not running: its sources are
  skipped and nothing is started (Core Temp opens only by its own
  autostart)"*.

Everything else stays as before: temperature chain with the sources above, the
working set budget (`mem_budget`), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, self update from GitHub
(`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

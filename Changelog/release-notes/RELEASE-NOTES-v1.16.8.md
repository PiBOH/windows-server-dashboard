# PiBOH Windows Server Dashboard v1.16.8

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

## What's new in 1.16.8

- **A page of another site cannot change the options any more.** Since 1.16.7
  the settings panel writes the server options from the browser when no
  password is set, and the API accepted such a write from anybody who asked:
  a page left open in your browser - any site, not just the dashboard - could
  post to `/api/settings`, switch automatic updates on and have the server
  fetch and install a release. A write is now accepted only when the request
  shows it comes from the dashboard itself, through the `Origin` header that
  browsers send on every POST (and `Sec-Fetch-Site` when they know it);
  anything else is answered `403` and written to the log with the address and
  the origin it came from. Saving from the panel still needs no password, a
  script or a monitoring probe with no `Origin` still works, and with a
  password set nothing changed at all: partial and total mode behave exactly
  as they did before.
- **The documentation tells the truth about it.** README.md still said the
  server options were "only on the server" and that the settings API
  "answers 403 to any write attempt" - no longer true since 1.16.7 - and the
  API table of the manual repeated it. Those lines, the stale comment blocks
  in the script and the comment the dashboard writes into `settings.txt` at
  every save now describe what the code does, including the one limit of the
  origin check: it is a check on the browser, so a program that speaks HTTP
  by itself is still accepted while no password is set.

Everything else stays as before: temperature chain with Core Temp read only
while it runs, the working set budget (`mem_budget`), tiered sampling, no
sampling while nobody watches, scroll bars with their arrow buttons,
per-browser refresh and theme, self update from GitHub (`auto_update = no` to
disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

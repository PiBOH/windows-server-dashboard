# PiBOH Windows Server Dashboard v1.16.15

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

## What's new in 1.16.15

**The tab shows the logo of the package.** Until now the browser showed the
generic icon next to the page title: the dashboard answered `/favicon.ico`
with an empty `204` on purpose, so nothing was ever sent. It now answers with
`docs\logo.png` - the same logo the README and the manual show - read once,
kept in memory and served exactly like the page itself, with a one day cache
so the browser does not ask again at every refresh. Nothing is started and
nothing is written to serve it, and if the file is not there the answer is the
same empty `204` as before: a package without `docs\logo.png` loses the icon
and nothing else.

**The screenshots of the README are the interface you actually get.** The five
images were still the ones taken at 1.15.2 and showed a page that no longer
exists; they were taken again from the offline preview, in English, every one
of them from the top of the page and at a 1600x900 window (the dark one covers
the whole page). They are not part of the archive - `screenshots\` never was -
so this is about the repository, not about the update.

Nothing else changed: same temperature chain with Core Temp read only while it
runs, same settings panel, same updater. If you use 1.16.14 there is no
functional reason to update.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

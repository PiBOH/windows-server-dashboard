# PiBOH Windows Server Dashboard v1.16.14

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

## What's new in 1.16.14

**The dashboard itself is unchanged.** This release is about
`docs\Dashboard-Preview.html`, the offline page that shows what the dashboard
looks like without installing anything.

- **The offline preview is generated now, instead of copied by hand.** Its
  interface had to be re-copied from the page the script serves every time that
  page changed, and it had drifted more than once - its settings panel had to be
  brought back to the current behaviour in 1.16.10, and its title and footer
  still said 1.16.10 while the dashboard was at 1.16.12. There is one copy of
  the interface now, the three sources under `_build\web\`, and the preview is
  built from them with the preview block (the sample data, the 38 embedded
  languages and the six functions that answer without a server). The build step
  fails when the preview on disk is not what the sources produce, and the check
  runs on every push, so the two can no longer say different things.
- **The preview carries the version it belongs to**, taken from
  `scripts\version.txt`: its title, its footer and the version its own code
  uses are that number now, not a hand-typed one.
- **The file says what it is.** Whoever opens `docs\Dashboard-Preview.html` in
  an editor finds a banner at the top naming the sources to edit and the command
  to run, instead of a 330 KB page that looks editable.

If you are on 1.16.13 there is nothing to update for: your dashboard behaves
exactly as it did. The preview inside the release archive is the only file that
changed.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

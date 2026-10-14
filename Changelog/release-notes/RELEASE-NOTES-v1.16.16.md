# PiBOH Windows Server Dashboard v1.16.16

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

## What's new in 1.16.16

**The dashboard comes back by itself after an update.** It did not, in two
different ways, and both were silent:

- the hand over that launches the new version passed `-WindowStyle` to
  `Start-Process` twice, which PowerShell refuses as an error. The error was
  written to the log and swallowed, so the new files were installed and the
  OLD dashboard kept serving;
- the check that protects against the endless update loop compared the version
  NUMBER only. A release published again under the same number - supported on
  purpose since 1.16.4, and recognised by the updater as a new build - was
  therefore mistaken for an update that never landed, and the dashboard stayed
  on the old build for good.

The second one is what any update to 1.16.15 looked like from the outside: the
download and the install succeeded, the log said so, and nothing restarted.
Both are fixed, and the same duplicated switch is gone from the periodic 24 h
check, which was failing before it even started.

**The log now names who started Core Temp.** The dashboard never starts it - it
only reads what Core Temp publishes while it runs - but the log line used to
print a bare process id, which answers nothing when the launcher has already
exited, as an installer does. It now names the parent when it still exists, and
the scheduled task that starts the same program: Core Temp's own "start with
Windows" option registers one, and on a machine where its window keeps coming
back that task is the answer instead of a guess.

Everything else is unchanged. If you are on 1.16.15, updating is worth it: it
is the release that could not update itself.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

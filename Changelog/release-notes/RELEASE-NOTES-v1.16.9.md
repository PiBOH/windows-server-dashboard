# PiBOH Windows Server Dashboard v1.16.9

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

## What's new in 1.16.9

**The dashboard itself is unchanged.** This release only fixes the automated
check added with the 32-bit test: it asked `/api/stats` once, immediately
after `/api/health` answered, and failed the build with *"carries no CPU
section"* when the first sampling cycle had not finished yet - which is what
happened once on a busy runner, while the same commit passed on a re-run.
The check now waits, up to a minute, for the CPU section and then asserts
exactly what it did before: the CPU section, `Cpu.TempSource`, the temperature
row in the page, and the engine and the temperature chain in the log.

Nothing else changed: if you use 1.16.8 there is no reason to update.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

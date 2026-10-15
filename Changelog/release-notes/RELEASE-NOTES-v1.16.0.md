# PiBOH Windows Server Dashboard v1.16.0

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

## What's new in 1.16.0

🔐 **Optional password:** `file pwd`, `password_mode total|partial` - protects whole page or only server options, never logged, never sent to browser

⏰ **Update check:** repeats every 24 hours; settings.txt and pwd reloaded within ten seconds; CI parses with Windows PowerShell 5.1

🔄 **Endless update loop:** when install failed (version.txt verified before handover); nested scripts\\scripts folders
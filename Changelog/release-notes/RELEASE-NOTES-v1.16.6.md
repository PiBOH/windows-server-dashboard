# PiBOH Windows Server Dashboard v1.16.6

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

## What's new in 1.16.6

🌡️ **Temperature row:** names its source (Cpu.TempSource); Core Temp's own CT-Log CSV is a source

🏥 **Health endpoint:** `/api/health` states 32/64-bit engine

🖥️ **32-bit CI job:** runs the whole dashboard with the 32-bit engine

💾 **Memory:** reduced from ~200 MB to default 20 MB (replacing five cmdlets with CIM classes, releasing per-request wait handles, trimming without Add-Type)

🔄 **Self update:** works again (updater no longer stops itself, fallback launch binds its parameters)

📊 **JSON stats:** built once per cycle (10.2 → 4.7 ms); static lists read once; Processes in name order; OS card names the release
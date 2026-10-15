# PiBOH Windows Server Dashboard v1.7.0

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

## What's new in 1.7.0

🌡️ **Core Temp support** through WMI add-on; HWiNFO as further fallback (order: BIOS/ACPI, Core Temp, LHM/OHM, HWiNFO)

🖥️ **Fixed, removable, virtual and optical devices** classified with bus and media badges

📦 **USB, card readers and optical drives** listed apart under "Other devices"; README and CHANGELOG wrapped at 78 columns with CRLF endings

🚫 **Language picker** did not open (lost modal class in 1.4.0)
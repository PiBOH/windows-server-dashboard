# PiBOH Windows Server Dashboard v1.16.21

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

## What's new in 1.16.21

📱 **Phone layout:** grid cards adapt to widths up to 480px (phone) and 900px (touch screen), no horizontal scrolling

📊 **Wide tables as blocks:** processes, services, events and adapters display as labelled value blocks, fully readable without dragging

🔍 **Table headers as pinned chips:** sort by clicking CPU %, memory, etc.; arrow indicates sort direction

🎯 **Touch target improvements:** half-press on row opens menu with search, Properties, copy commands; 10px travel or second finger cancels

♿ **Accessibility:** value labels are real elements read by screen readers with column context (e.g. "PID 15688"); no `aria-sort` used

---

# PiBOH Windows Server Dashboard v1.16.20

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

## What's new in 1.16.20

📊 **Raw counter sampling:** CPU and disk percentages now use underlying counters instead of formatted classes

🔧 **First sample defence:** initial page load uses two samples 300ms apart, no zero wall

📈 **Process table opens busiest first:** like Task Manager, sorted by CPU % descending

🎨 **About panel:** GitHub logo, globe, envelope as inline SVG (theme-colour, consistent across servers); "i" caption, "read live from..." line, and ambiguous Releases label removed

🌡️ **Temperature panel:** stays open until user closes (X, Escape, or click on dark background); refresh no longer dismisses it

🌐 **Temperature "not available" line:** English in 27 Latin-alphabet languages, translated in 11 others (Arabic, Bulgarian, Greek, Hebrew, Japanese, Korean, Russian, Thai, Ukrainian, Chinese)

---

# PiBOH Windows Server Dashboard v1.16.19

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

## What's new in 1.16.19

🔌 **Single refresh frequency control:** with no password, one control in settings panel; saved choice ignored if older browser cache exists

🔐 **With password:** header selector and settings panel row both present, each browser keeps its own choice; server value protected by password

---

# PiBOH Windows Server Dashboard v1.16.18

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

## What's new in 1.16.18

🌡️ **Temperature source selector:** "?" next to CPU temperature opens list of working sources (Core Temp, LibreHardwareMonitor, OpenHardwareMonitor, HWiNFO)

📋 **Row menu on long press:** half-second press on process/service row opens menu with web search, Properties, copy commands

🌡️ **Temperature unit follows language:** `temperature_unit` in settings.txt forces it

🏷️ **33 new labels translated** into all 38 languages
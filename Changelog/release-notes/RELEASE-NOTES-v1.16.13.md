# PiBOH Windows Server Dashboard v1.16.13

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

## What's new in 1.16.13

- **The dashboard stops asking Core Temp's WMI add-on anything.** The
  temperature chain ended with a query to the namespace `root\CoreTemp`, the
  one Core Temp's free *Core Temp WMI provider* add-on registers. That query
  was the only thing in the dashboard that goes through Core Temp's own
  registration instead of reading something Core Temp publishes by itself - a
  block of shared memory, its own CSV log, its ini file - so on a machine where
  Core Temp's window kept coming back it was the one Core Temp related action
  worth ruling out. It is **off by default** now. Write
  `coretemp_wmi = yes` in `settings.txt` to turn it back on, for the machine
  where neither the shared memory nor the log answers and only WMI does.
- **If you had temperature from that source only, the row is empty after
  updating.** Two ways back, both of them passive reads that ask Core Temp
  nothing: switch on *enable global shared memory* in Core Temp > Options >
  Advanced, so its block can be read from session 0 as well; or switch on Core
  Temp's own logging (Options > Enable logging) and let the dashboard read the
  newest `CT-Log*.csv`, which it looks for by itself in the install folders.
  The manual explains both.
- **The log now names the process that started Core Temp.** The line written
  when Core Temp appears already said the dashboard never starts it; it now
  carries Core Temp's process id, the id of its parent and the parent's name
  when that process still exists:

      Core Temp is running: ... (pid 15904, started by explorer.exe pid 9620)

  Nothing in the dashboard launches anything but `powershell.exe`, so that
  parent is the answer to *why does Core Temp keep coming back?* - written by
  the machine that does it, not promised by a manual. If you are chasing that
  on a machine of yours: update, open `logs\ServerDashboard-*.log`, and search
  for *Core Temp is running*.

Everything else stays as before: the same temperature sources tried in the
same order (BIOS/ACPI, Core Temp's shared memory, Core Temp's own CSV log,
LibreHardwareMonitor or OpenHardwareMonitor, HWiNFO, and Core Temp's WMI add-on
only when asked), the same page, the same settings, the same endpoints.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

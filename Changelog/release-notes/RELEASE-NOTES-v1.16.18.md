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

**The temperature now says where it comes from, or says nothing.** The
dashboard does not measure anything itself and it starts nothing: it reads
what a program that does measure it publishes. That was already true, but the
row did not say so. It does now, in three ways:

- the reading carries the name of the source that answered, next to the
  numbers, so a figure is never shown without saying who published it;
- the ACPI thermal zone is read **last**, and only when nothing else answers.
  It is not the processor: it is a zone of the board, often the chassis. It
  used to be taken first, which meant a server that had Core Temp installed
  could keep showing a board zone and calling it a CPU temperature;
- when no source answers at all, the row says so - *not available (no
  temperature source found)* - instead of leaving a gap that looks like a
  fault.

**A "?" next to that row opens the answer.** When the temperature is missing,
a small button appears beside it: it opens a panel that names the four
programs whose readings this dashboard can read - Core Temp,
LibreHardwareMonitor, OpenHardwareMonitor and HWiNFO - each with the link to
its download page and one line on what it needs, and it explains why counting
on the BIOS or on the ACPI zone does not work here. If one of them already
runs on the server and the reading is still missing, the panel says where to
look: the dashboard's own log names every source it tried. No add-on, no
plug-in, nothing to install inside the dashboard.

**Right-click a process or a service.** The rows of both tables now answer to
the right mouse button with four commands: *Search the web*, *Properties*,
*Copy name*, *Copy PID*. The Properties panel shows what the dashboard already
knows about that row - the executable path, the account, the start mode for a
service - and nothing else: no owner and no start time are invented when
Windows does not give them. The copy commands answer in place, and when the
browser refuses the clipboard they say which panel to select the text from
instead.

**One refresh frequency, when nobody set a password.** Without a password
there was nothing for a personal setting to be different from, so the server
value and the page value are now the same control: changing it changes how
often the server samples and how often the page reloads. With the password
back, the two are separate again, as before.

**And the labels are translated.** The new texts - the About panel, the
temperature help, the context menu and the Properties panel, the frequency
label - are in all 38 languages, each one following the wording already used
by that language file rather than a word-for-word copy of the English. The
repository now carries a check, `scripts\Test-Languages.ps1`, that fails the
build when a language file loses a key, gains one nothing asks for, carries an
empty value or drops a placeholder: a missing translation is a red build
instead of English text on somebody's screen.

**What the temperature reads in** follows the language of Windows: the default
`temperature_unit = auto` shows Fahrenheit on a display language from a region
that reads Fahrenheit (English (United States)) and Celsius everywhere else.
`C` or `F` in `settings.txt` decides it for the whole server regardless. Only
the way the reading is written: `/api/stats` is always Celsius.

Everything else is unchanged. If you are on 1.16.17, this is a small, safe
release: nothing you have configured changes, and `settings.txt` needs no new
line.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

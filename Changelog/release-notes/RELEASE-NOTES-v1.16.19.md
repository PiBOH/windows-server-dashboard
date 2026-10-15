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

**One refresh frequency, when nobody set a password.** 1.16.18 already made the
server value and the page value one control in the settings panel, but the
selector in the header was still there, and it wrote a choice of its own: a
browser that had used it kept asking for data at its own pace while the panel
said the interval belonged to the server. Nothing was broken on screen - the
two simply disagreed - which is the worst way for a fault to look.

Now, with no password, that selector is not in the page at all, and a
frequency an older visit saved in the browser cache is ignored instead of
being silently preferred to the one in `settings.txt`. There is one command,
in the settings panel, and the server and every open page follow it: change it
and the sampling and the refresh move together at the next click of Save.

**With a password, nothing changes.** The selector in the header and the row in
the settings panel are both back, both keep a choice of that browser alone,
from half a second to five minutes, and neither touches the server or the other
viewers - as in 1.16.18. The server value stays behind the password, and typing
it still unlocks the row that writes `settings.txt`.

Everything else is unchanged, and no new line is needed in `settings.txt`: if
you are on 1.16.18, this is a small, safe release. The one comment that
described the old behaviour was corrected in the file the dashboard writes
when `settings.txt` is missing or incomplete; an existing file keeps its own
comments until the next Save from the panel.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

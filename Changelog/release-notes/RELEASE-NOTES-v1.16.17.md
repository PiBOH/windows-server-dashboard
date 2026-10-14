# PiBOH Windows Server Dashboard v1.16.17

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

## What's new in 1.16.17

**An About panel, one click away.** The line in the centre of the footer -
the version - is now a button. It opens a panel with the author, a link to the
portfolio, the e-mail address, the repository and the release list.

The panel also carries the changelog, and that part is not shipped with the
package: it is read from GitHub every time the panel opens, never cached, so
what you read is always the published history and never a copy of it that
travelled with an old zip. A *Reload* button does the same on demand. Because
it comes from the network, that panel needs internet access from the browser;
when GitHub cannot be reached the panel says so instead of showing something
older. What arrives is escaped before it is displayed, so the remote file
cannot put markup into the page.

**The changelog reads one release per line.** Every release and every *Added*,
*Fixed*, *Changed* or *Removed* line now sits on its own line, which is what
makes the About panel readable. Nothing was cut: the same entries, the same
categories, only laid out again - and the first entry, 1.16.16, no longer runs
into the paragraph that explains what MAJOR, MINOR and PATCH mean.

Everything else is unchanged. Coming from 1.16.16 this is a small release.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

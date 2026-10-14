# PiBOH Windows Server Dashboard v1.16.11

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

## What's new in 1.16.11

**Nothing changes on the server, and nothing in what you download changes
either: this release is about how the page is edited in the repository.**

The dashboard page - markup, stylesheet and JavaScript, about 70 KB - used to
be written inside `ServerDashboard.ps1`, so touching a colour or a line of the
interface meant editing a 4000 line script. It is now three real files in
`_build\web\`:

```
_build\web\page.html    the markup, with a marker line where the stylesheet
                        and one where the script go
_build\web\page.css     the stylesheet
_build\web\page.js      the script
_build\Embed-Page.ps1   splices the three into the engine
```

The page still ships *inside* the script and is still served from memory:
`Embed-Page.ps1` writes it into the same here-string as before, so an
installation stays one script that reads nothing new from disk. **The page the
server answers with is byte for byte the one 1.16.10 answered with** - same
70029 bytes, same sha256 - and `_build\` is a development folder like the
other folders the release workflow leaves out: it is not in the release
archive, and the updater never copies it onto a server.

The syntax workflow now parses the build script and runs it with `-Check` on
every push: if somebody changes `_build\web\page.css` (or the page inside the
script) without the other, the build fails with the first differing line
instead of shipping two versions of the page that disagree.

Nothing else changed: same `settings.txt`, same requests, same page. If you
use 1.16.10 there is nothing to gain by updating.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

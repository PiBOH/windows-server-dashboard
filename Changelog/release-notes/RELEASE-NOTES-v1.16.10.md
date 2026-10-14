# PiBOH Windows Server Dashboard v1.16.10

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

## What's new in 1.16.10

**The dashboard itself is unchanged.** This release makes the documentation
tell the truth about the server options again.

Since 1.16.7 the settings panel writes the server options to `settings.txt`
straight from the browser when no password is set, and the manual and the
comments had been updated for that - but four places still described the old,
read-only panel, which is what a reader would have found by looking:

- **`docs\Dashboard-Preview.html`, the offline preview, was two versions
  behind**: its settings panel showed *"read-only: set on the server in
  settings.txt"* and greyed the controls out, so anyone who read the file to
  see what the panel looks like was shown the behaviour that 1.16.7 removed.
  It is now the page the script serves, with the sample data and the 38
  dictionaries embedded: same markup, same CSS (including the scroll bar
  arrows of 1.16.7), same code. Its panel shows *"Unlocked: Save writes these
  options to settings.txt on the server"* with the interval, the sections, the
  logging and the automatic updates live, exactly like a fresh install.
- **The `readonly_server` string is gone from all 38 language files.** Nothing
  has displayed it since 1.16.7, and it said the opposite of what the panel
  does.
- **Two comments inside the script** still placed the settings in a
  `settings.json` with a 5 second default refresh and a 15 minute idle
  sampling: settings live in `settings.txt`, the default refresh is 0.5 s and
  `idle_seconds = 0` means no sampling at all while nobody is watching. They
  say so now, and the status-note comment in the panel code lists the two
  states that really exist - unlocked and password needed - instead of the
  retired read-only one.
- **The manual's endpoint table** pointed `POST /api/settings` at a note that
  is no longer under the table; it points at section 9, where the write rules
  (no password, partial, total, and the refusal of a write coming from another
  site's page) are written out.

Nothing else changed: same `settings.txt`, same requests, same page. If you
use 1.16.9 there is nothing to gain by updating - it is worth it only if you
read the files.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

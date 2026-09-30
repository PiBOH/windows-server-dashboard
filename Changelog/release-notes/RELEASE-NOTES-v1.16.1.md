# PiBOH Windows Server Dashboard v1.16.1

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`,
done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. When asked, type the optional password (or just press Enter for none)
4. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.16.1

- **The local secrets now live in `.config-do-not-delete-me\`**: the
  password file (`pwd`) and the settings backup (`settings-backup.txt`)
  are kept together in one folder at the root of the package, with a name
  that says what happens if you delete it. Your existing password is
  moved there automatically at the first start, from wherever 1.16.0
  kept it. An empty file still means "no password".
- **Password asked during the installation**: `Install.bat` offers to set
  it (masked input, Enter alone = none) and never overwrites one that is
  already set; `scripts\Set-Password.ps1` changes or removes it at any
  time.
- **Partial mode reworked**: no more lock in the settings panel. The
  options look normal, and a small popup asks for the password only at
  the moment one of them is clicked - never before. The server checks it
  immediately; after that the options are editable and Save writes them.
- **No browser will ever offer to save the password** - Chrome, Edge,
  Safari, Firefox, desktop and mobile: where supported the popup field is
  not a password field at all (it only looks like one), elsewhere it is
  never part of a form and never submitted.
- **Fixed: the language window left a ghost copy at the bottom of the
  page** when it was closed by clicking on the dark background instead of
  the X. The click-outside closing now works for the password popup too.
- **`install-state.txt` is now hidden and read-only inside `scripts\`** -
  harder to delete or edit by mistake; `Uninstall.bat` also still finds
  the file where the versions before it left it (`logs\`).
- The self updater no longer copies the repository folders that are not
  part of the package (`.github`, `screenshots`, ...) over an
  installation.

Everything else stays as before: temperature chain with 5 sources (Core
Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, 38 languages, self update from
GitHub (`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

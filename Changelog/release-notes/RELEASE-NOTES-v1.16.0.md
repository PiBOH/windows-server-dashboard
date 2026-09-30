# PiBOH Windows Server Dashboard v1.16.0

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`,
done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.16.0

- **Optional password.** Create a plain text file called `pwd` (no file
  extension) next to `settings.txt`, write the password on the first line,
  save: no restart needed, it applies within ten seconds. `password_mode`
  in `settings.txt` decides what it protects:
  - **total** (default) - the whole dashboard asks for the password: the
    browser opens its standard login window and without the password
    nothing at all is served (`/api/health` stays open for the updater and
    `Repair-Autostart.bat`, it only carries the version number);
  - **partial** - everybody can look at the dashboard, but the server
    options (default refresh, visible sections, logging, automatic
    updates) can be changed from the settings panel only after typing the
    password: the panel shows a lock, you unlock, edit, save.
- Without a `pwd` file everything works exactly as before: the settings
  stay read-only and every write attempt is refused with 403 and logged.
- The password is never sent to the browsers, never written to the log,
  preserved by every update, never published on GitHub (`.gitignore`) and
  deleted by `Uninstall.bat`. New UI strings translated into all the
  38 languages.
- **Updates also arrive while the server stays on**: the GitHub check now
  repeats every 24 hours at runtime, not only at boot, so a server that
  runs for months no longer needs a reboot to receive a new release.
- **Endless update loop fixed**: up to 1.15.0, when an install failed to
  replace the files the dashboard would see the same "new" version at
  every start, reinstall it, spawn itself and exit, over and over, with
  the port never opening - it looked like "it does not start by itself"
  and no update ever landed. The script now verifies that the version on
  disk really changed before restarting, and stays up otherwise.
- **Leftover `scripts\scripts` folders are removed automatically** at every
  start: they were created by the pre-1.15.1 updater and are exactly what
  kept the old versions from being replaced.

## Updating from a version up to 1.15.0 (important)

If updates never installed by themselves on your server, it is almost
certainly the nesting bug above, and the fix cannot reach you through the
broken updater itself. Once by hand:

1. Download this release zip on the server and extract it.
2. Stop the service: `Stop-Dashboard.bat` (twice, to be sure).
3. Copy the content of the extracted folder over your dashboard folder.
4. Run `scripts\Repair-Autostart.bat` as administrator (or `Install.bat`
   again: it only applies what is missing).

From there the updater works again and cleans the leftover folders by
itself at every start.

Everything else stays as before: temperature chain with 5 sources (Core
Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, 38 languages, self update from
GitHub at every start (`auto_update = no` to disable).

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), PowerShell 5.1,
administrator rights for the installation only.

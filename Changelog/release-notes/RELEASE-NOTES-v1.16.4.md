# PiBOH Windows Server Dashboard v1.16.4

Web dashboard for Windows Server 2016+, reachable from any PC on the LAN.
No agent, no IIS, no external module: copy the folder, run `Install.bat`,
done.

## Install

1. Copy the folder to the server, for example `C:\ServerDashboard\`
2. Right-click **`Install.bat`** -> *Run as administrator*
3. When asked, type the optional password (or just press Enter for none)
   and choose what it protects: the whole page or only the server options
4. Open `http://<server-ip>:8080` from any computer on the network

The dashboard starts **at boot as SYSTEM**, no interactive logon needed.
`Uninstall.bat` reverts exactly what the installer changed.

## What's new in 1.16.4

- **Manual update now really restarts the dashboard by itself**:
  `Update-Now.bat` restarts itself as administrator, like Diagnose.bat.
  Without those rights the old instance could not be stopped and the
  task could not be started again: the update looked successful while
  the OLD version kept serving, and the new one only appeared at the
  next boot.
- **Same version republished? Everybody updates anyway**: every release
  now records its build commit, so when the same number comes out again
  with different content every dashboard downloads it - which used to
  need a hand with the version file.
- The restart after an update got two more safeties: if the port never
  frees, the log says that the old version is still the one answering;
  and the direct launch of the last resort reserves the URL first, so
  it can really listen.

Everything else stays as before: temperature chain with 5 sources (Core
Temp plain program first), tiered sampling, no sampling while nobody
watches, per-browser refresh and theme, self update from GitHub
(`auto_update = no` to disable).


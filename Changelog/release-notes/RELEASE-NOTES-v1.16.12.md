# PiBOH Windows Server Dashboard v1.16.12

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

## What's new in 1.16.12

- **The interval you save is the interval you asked for.** The server default
  refresh interval that the panel writes had its limits written with whole
  numbers - `[math]::Min(3600, [math]::Max(0.5, $value))` - and PowerShell,
  given an integer literal, picks the integer version of `Min` and `Max` and
  drops the fraction. So the half-second refresh that the panel offers was
  saved as `refresh_seconds = 0`, 1.25 seconds as `1`, 2.5 seconds as `2`: the
  dashboard ran at a different pace from the one in the file, and the file
  held a value (`0`) that the reader then lifted back to `0.5`, which is why
  it never looked wrong.
- **The idle interval had the same defect, with a worse effect.** There `0` is
  not just a small number: it means *do not sample at all while nobody is
  watching*, so half a second on the idle row rounded down and switched idle
  sampling off. Both bounds are doubles now, and every fractional value
  survives the round trip from the panel (or from the API, or from a script)
  to `settings.txt` and back to `/api/settings`.
- **The same defect was in the network rates, where it could fail instead of
  just rounding.** The down and up rate of every network card was clamped with
  `[math]::Max(0, $rate)`, so the integer zero made PowerShell pick the
  integer version again: the rate was rounded to the nearest byte per second,
  and above 2 GB/s inside one cycle - a 25 GbE card, or a counter that jumps -
  the call threw and that cycle was published without its network section.
  The bound is a double there too.
- **Nothing else changed.** The accepted range is exactly what it was: under
  half a second still becomes `0.5` for the refresh interval, over an hour
  still becomes `3600`, a negative idle value is still ignored. Re-read your
  `settings.txt` if you ever chose a fractional value from the panel: a `0` on
  the `refresh_seconds` line, or on `idle_seconds`, is a leftover of this bug
  and the panel does not show it.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

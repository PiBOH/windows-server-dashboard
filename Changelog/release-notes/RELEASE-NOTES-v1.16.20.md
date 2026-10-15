# PiBOH Windows Server Dashboard v1.16.20

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

## What's new in 1.16.20

**The numbers that never moved.** Two columns of this dashboard were quietly
false, and both for the same reason. The CPU % of the processes came from the
"formatted" performance class, which on a real machine answered 0.0 for 207
processes out of 214: Task Manager showed those processes working while the
dashboard showed a wall of zeros. The busy percentage of the disks came from
the formatted class as well and stood still at the same value on every volume,
sample after sample - 4.0% on the machine where this was reported - even while
32 MB were being written to one.

The raw counters behind those classes grow exactly as they should, and 1.16.20
reads those instead: a rate is the difference between two samples divided by
the time between them, which is the arithmetic the formatted class was supposed
to do for us. A process that works now shows it, a disk being read or written
now shows it, and the first sample after a start is taken twice, 300 ms apart,
so the first page you open is not a row of zeros waiting for the next cycle.

**The process list keeps up.** The Processes table was read every five seconds
while everything else on the page moved at half a second or a second, so the
clock in the header advanced and the table did not. The section now has two
clocks: CPU %, memory, threads and handles - a difference of two counter
samples - are read every cycle, while the image name, its path and the
description of each executable are read every 30 seconds and remembered,
because they cost about three times as much (measured: ~250 ms against ~80 ms
with two hundred processes) and cannot change while a process runs. A process
started during that wait is not missing from the table: it is there, named the
way the counter names it ("chrome.exe", out of "chrome#1"), until the next pass
spells its path out.

**The Processes table opens on CPU %.** Two hundred rows sorted by name put a
screenful of idle system processes - all reading 0.0 - in front of the one
process that was doing the work, which is what made the wrong column look like
a dead table. The list now opens busiest first, like Task Manager, and the
arrow in the CPU % header says so. Every column still sorts on a click, and the
choice stays in the browser of each visitor.

**The About panel, without emoji.** The GitHub logo, the globe and the envelope
are inline SVG now, drawn in the colour of the text around them: an emoji is
drawn by whatever font the machine has, so the same panel looked different on
two servers and did not follow the light or dark theme. The "i" before the
title is gone (it said nothing), the "read live from github.com/..." line is
gone with it, and the unclear label before Releases is gone as well: the word
alone is clearer than a symbol the reader has to decode. The rules for this are
written down in `AGENTS.md`, which never travels with the release.

**The temperature panel stays where it is put.** The panel that explains a
missing CPU reading is opened to be read, and it used to close on its own while
a refresh repainted the page. It now closes only when you close it - its X, its
Close button, Escape - or when a click lands on the dark area around it.

**One line less to translate.** The line shown while no temperature source
answers is English in the 27 languages that use the Latin alphabet and
translated in the 11 that do not (Arabic, Bulgarian, Greek, Hebrew, Japanese,
Korean, Russian, Thai, Ukrainian, Chinese): a reader of a Latin script reads
the English line, and it is one sentence less to keep in step across 25 files.
Nothing else in the 38 language files changed.

`docs\README.md` documents the new sampling tiers and the order the process
table opens in. No new line is needed in `settings.txt`.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

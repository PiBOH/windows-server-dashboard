# PiBOH Windows Server Dashboard v1.16.21

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

## What's new in 1.16.21

**The phone.** The page was built for the width of a monitor and a pointer that
hovers. On a 360 pixel phone a card of the grid stayed wider than the screen and
the page scrolled sideways; a field smaller than 16 pixels made Safari on iOS
zoom the page the moment it took the focus, and stay zoomed; the header, wrapped
on four rows, ate a fifth of the screen and stayed there while the page was
read. None of that is true now: every track is `min(...,100%)` and nothing keeps
a fixed width, the form controls are 16 pixels, the buttons and the "?" of the
temperature are the size of a fingertip, the header scrolls away with the rest,
and turning the phone redraws the trend charts at the new width. A screen of any
size is read without scrolling sideways, and nothing is cut off.

**The four wide tables, as blocks.** Processes, services, events and adapters
were tables 882 pixels wide inside a pane of 312 - read by dragging them left
and right, one column at a time - and the message of an event, the one column
that cannot be narrow, made every row as tall as the whole text while its own
column sat off the screen: a phone showed two events and a screenful of empty
space. Up to 480 pixels wide, and on any touch screen up to 900, each row is now
a block of labelled values as wide as the card. Every column is read without
dragging, the message of an event wraps in full (a touch screen has no hover to
lean on), and the coloured bar of an engine or of a critical event marks the
whole block. A tablet held in the hand above 900 pixels keeps the table: there
it fits, and a table is a better answer than a list.

**The sort stays one tap away.** The header of those tables is kept above the
rows as a row of chips, pinned to the top of the pane. Tap the CPU % chip and
the list sorts by it, tap it again and the order reverses, and the arrow in the
chip says which way it went. Without it, two hundred rows below the header, the
header could not be reached at all. On a wide screen the real column header
keeps doing the same job, as before.

**The label of a value, read out loud.** The name of a column inside a block is
a real element and not a mark drawn by the stylesheet - which is exactly what
makes it readable: a screen reader announces every value together with the
column it belongs to ("PID 15688", "MESSAGGIO ..."), where before it read the
value alone, under a header a phone no longer shows. On a large screen, where
the header of a real table says the same thing above every column, that element
is drawn out of sight and the value is announced on its own, exactly as before.
For the same reason `aria-sort` is not used anywhere: the engine in the box does
not carry it into the accessibility tree, on either layout, so it would have
been a promise nothing keeps; the arrow inside the name of the sorted chip is
what is announced, and only that chip carries one.

**A touch screen has no right button.** Half a second with the finger still on a
row of the process or the service table opens the row menu where the finger is,
with the web search, the Properties panel and the two copy commands a right
click has always offered on a desktop. Ten pixels of travel cancel it, and so
does a second finger, so scrolling a list is never taken for a press. When the
menu has to be pulled back inside the screen because the press came close to an
edge, the click the browser sends as the finger is lifted is refused: an entry
is chosen by a tap, never by a finger being lifted onto a menu that just
appeared under it. A hold that is still running is dropped when the screen
changes, so turning the phone mid-press opens nothing. The desktop keeps its
right button, its menu, Escape and text selection.

**One line less in the About panel.** The hint under the Changelog caption said
that the changelog is read live from GitHub every time the panel opens. The
caption alone says what the link is, and the key is gone from all 38 language
files; nothing else in them changed.

If you are on 1.16.20, this is a phone and accessibility release: on a desktop
nothing moves, apart from that one line in the About panel. No new line is
needed in `settings.txt`, and `docs\README.md` documents the phone layout of the
four wide tables and the long press that opens the row menu.

## Requirements

Windows Server 2016 or newer (Windows 10/11 work too), 32-bit or 64-bit,
PowerShell 5.1 (the one already in the box), administrator rights for the
installation only.

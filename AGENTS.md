# Notes for whoever works on this repository (human or agent)

Raspberry-free, dependency-free: one PowerShell engine that publishes the page,
and one page written as three real files. Everything below is a rule this
project already follows - follow it too, or the checks fail.

## The page is generated: edit the sources, never the copies

The page exists as three files in `_build\web\` - `page.html`, `page.css`,
`page.js` - and as two generated copies:

- `scripts\ServerDashboard.ps1` carries it inside the here-string the engine
  serves from memory;
- `docs\Dashboard-Preview.html` is the same page standing on sample data.

After **any** change under `_build\`, run:

    powershell -File _build\Embed-Page.ps1

and commit the sources **and** both generated copies. `Embed-Page.ps1 -Check`
fails when they are out of step, and CI runs it on every push. Editing a
generated copy is pointless: the next build overwrites it.

## The interface uses inline SVG, not emoji

An emoji is drawn by the font and by the emoji set of the machine that opens
the page: the same panel looks different on every server, and on older Windows
Server builds some of them come out as a box or as a black-and-white glyph.
Several are also ambiguous - a label, a globe and a paperclip say nothing about
the link or the button they sit on - and they do not follow the theme colour.

So, in the page:

- draw a mark as inline `<svg>` with `viewBox`, `aria-hidden="true"`,
  `focusable="false"`, and `fill`/`stroke` set to `currentColor`, so it takes
  the colour of the text around it and of the light/dark theme (see `.ico` in
  `page.css` and the About panel in `page.html`);
- when no mark would be understood at a glance, leave it out: the word alone is
  better than a symbol the reader has to decode;
- emoji that are still in place (the header, the disk boxes, the password
  panel) are work left over, not a precedent: convert one when you touch it.

## Language files

`lang\*.xml`, 38 files, `en-US.xml` is the reference. Every file carries
exactly the keys of the reference, with a value and the same placeholders;
UTF-8 without BOM, CRLF line endings. `scripts\Test-Languages.ps1` is the rule
and CI runs it - a missing translation is a red build, not a warning. A new
key goes into the reference first, then into all 37 others.

New text in a language file is written **in that language**, following the
wording that file already uses; a value copied from English is a bug.

One exception, by decision of the owner: `temp_na`, the line shown while no
temperature source answers, is written in English - "not available (no
temperature source found)" - in every language that uses the Latin alphabet,
and translated only in the ones that do not (Arabic, Bulgarian, Greek, Hebrew,
Japanese, Korean, Russian, Thai, Ukrainian, Chinese). A reader of a Latin
script reads the English line, and it is one sentence less to keep in step in
25 files. Every other key follows the rule above: do not copy English into a
language file.

## Checks before committing

    powershell -File scripts\Test-Syntax.ps1                 # scripts\
    powershell -File scripts\Test-Syntax.ps1 -Folder _build  # _build\
    powershell -File scripts\Test-Languages.ps1
    powershell -File _build\Embed-Page.ps1 -Check

On every push CI runs these plus a run of the whole dashboard on the 32-bit
Windows PowerShell (`%WINDIR%\SysWOW64`), which is what makes the same script
usable on a 32-bit server.

## Never start the engine from the checkout

The engine, when it starts, removes the legacy leftovers it finds next to it -
`docs\CHANGELOG.md`, `docs\RELEASE-NOTES-*`, `docs\screenshots\*` are tracked
files here - so starting it from this repository deletes tracked files. Copy
`scripts\` and `lang\` into a folder outside the repository, with its own
`settings.txt`, and run it there.

## Releasing

1. `scripts\version.txt` (one line, the version), then every place that repeats
   it: the badge in `README.md`, `docs\README.md` (header and the versioning
   section), and the regenerated preview.
2. A short entry at the top of `Changelog\CHANGELOG.md` (one entry per version,
   in-line labels with emoji, two or three lines at most) and
   `Changelog\release-notes\RELEASE-NOTES-v<version>.md`, which the release
   workflow reads and refuses to build without. **Changelog must follow keepachangelog
   format with emoji, be in English, and be short and nice to read.**
3. Commit with a message whose **first word** is `v<version>`: that is what
   starts `auto-release.yml`. No `Co-authored-by` and no "Generated with" line.
4. One commit, no pull request: the workflow builds the zip, the `.sha512` and
   the release (not a draft, not a prerelease) from the tracked files, without
   the development folders. `AGENTS.md`, `_build\`, `screenshots\`, `.github\`
   and the local settings never travel with it.

## Changelog format

- Format based on [keepachangelog.com](https://keepachangelog.com/)
- Emoji used for visual categories
- All text in English
- Short and concise entries (2-3 lines max per item)
- Categories: Added, Changed, Fixed, Deprecated, Removed, Security
- Version sections: ## [x.y.z] - YYYY-MM-DD
- Unreleased section at top for ongoing work

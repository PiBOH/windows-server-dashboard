<#
    Embed-Page.ps1
    The dashboard page - markup, CSS and JavaScript - is edited as three real
    files in _build\web\:

        page.html   the markup, with one marker line where the stylesheet and
                    one where the script go: /*@CSS@*/ and /*@JS@*/
        page.css    the stylesheet: replaces /*@CSS@*/
        page.js     the script:      replaces /*@JS@*/

    From those three, plus the preview block in _build\preview\preview.js, this
    script writes the two copies of the page there are:

        scripts\ServerDashboard.ps1    the page spliced into the here-string the
                                       package ships and the dashboard serves
                                       from memory (nothing is read from disk at
                                       runtime, exactly as before)
        docs\Dashboard-Preview.html    the same page standing on sample data
                                       instead of a server: the preview block
                                       replaces what would ask the server, the
                                       placeholders get the values the engine
                                       would fill in, and the version comes from
                                       scripts\version.txt so it cannot go stale

    Run it after changing anything under _build\, then commit the sources and
    both generated files - they must always agree.

        powershell -File _build\Embed-Page.ps1

    -Check only verifies, without writing, and exits 1 when either copy is not
    what the sources produce; the syntax workflow runs it on every push, so no
    copy can drift from the sources.

    _build\ is a development folder: it is not part of the release archive and
    the updater never copies it onto an installation (see $UpdateSkip in
    ServerDashboard.ps1 and auto-release.yml).
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$root        = Split-Path -Parent $PSScriptRoot
$webDir      = Join-Path $PSScriptRoot 'web'
$targetFile  = Join-Path $root 'scripts\ServerDashboard.ps1'
$previewFile = Join-Path $root 'docs\Dashboard-Preview.html'
$versionFile = Join-Path $root 'scripts\version.txt'
$openHere    = '$Html = @' + "'" + "`r`n"
$closeHere   = "`r`n" + "'@"

# the line page.js boots from: the preview block is inserted just before it, so
# its overrides win over the page's own definitions and its data exists before
# anything calls into it
$bootAnchor  = '/* boot sequence: language list -> chosen language -> data */'

# what the engine replaces at serve time, and what the offline page shows
# instead. __HOST__ -> the sample server the preview data describes.
$previewSubs = @(
    @{ Token = '__HOST__';     Value = 'SRV-FILE01' },
    @{ Token = '__SYSLANG__';  Value = 'en-US' },
    @{ Token = '__VERSION__';  Value = '<version>' },
    @{ Token = '__INTERVAL__'; Value = '0.5' }
)

function Read-Source([string]$Path) {
    # whatever line endings the working copy has (git checks these files out
    # with CRLF on Windows): the build works in LF and writes CRLF back, like
    # the rest of the script
    if (-not (Test-Path $Path)) { throw "missing file: $Path" }
    $t = [System.IO.File]::ReadAllText($Path)
    if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }
    return $t.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-FirstDifference([string]$A, [string]$B) {
    $la = $A -split "`n"
    $lb = $B -split "`n"
    $n = [Math]::Min($la.Count, $lb.Count)
    for ($i = 0; $i -lt $n; $i++) {
        if ($la[$i] -ne $lb[$i]) {
            return "first difference at page line $($i + 1):`n    sources: $($lb[$i])`n    on disk: $($la[$i])"
        }
    }
    return "the two are equal for $n lines, one of them is longer (sources $($lb.Count) lines, on disk $($la.Count) lines)"
}

# ---- the page the sources produce ------------------------------------------
$page = (Read-Source (Join-Path $webDir 'page.html')).TrimEnd("`n")
$css  = Read-Source (Join-Path $webDir 'page.css')
$js   = Read-Source (Join-Path $webDir 'page.js')

foreach ($m in @(
    @{ Marker = '/*@CSS@*/'; Text = $css; File = 'page.css' },
    @{ Marker = '/*@JS@*/';  Text = $js;  File = 'page.js'  })) {
    $count = ([regex]::Matches($page, [regex]::Escape($m.Marker))).Count
    if ($count -ne 1) {
        throw "page.html must carry the marker $($m.Marker) exactly once, it has $count"
    }
    if (-not $page.Contains($m.Marker + "`n")) {
        throw "the marker $($m.Marker) must sit alone on its line (page.html, replaced by $($m.File))"
    }
    $page = $page.Replace($m.Marker + "`n", $m.Text)
}
$built = $page.Replace("`n", "`r`n")

# ---- the offline preview ----------------------------------------------------
$shim = Read-Source (Join-Path $PSScriptRoot 'preview\preview.js').TrimEnd("`n")
$version = (Read-Source $versionFile).Split("`n")[0].Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "scripts\version.txt does not start with a version number: '$version'"
}

$preview = $page

# the served page is titled after the host it runs on; the offline one is a
# page about the preview, and it carries the version that is being previewed
$titleCount = ([regex]::Matches($preview, '(?m)^<title>.*</title>$')).Count
if ($titleCount -ne 1) { throw "page.html must carry exactly one <title> line, it has $titleCount" }
$preview = [regex]::Replace($preview, '(?m)^<title>.*</title>$',
    '<title>PiBOH Windows Server Dashboard ' + $version + ' - preview</title>')

foreach ($s in $previewSubs) {
    $value = if ($s.Token -eq '__VERSION__') { $version } else { $s.Value }
    $count = ([regex]::Matches($preview, [regex]::Escape($s.Token))).Count
    if ($count -lt 1) { throw "the page no longer carries $($s.Token): the preview build must be told what to put there" }
    $preview = $preview.Replace($s.Token, $value)
    Write-Verbose "$($s.Token) -> $value ($count time(s))"
}

# the preview block sits right before the boot sequence
if (([regex]::Matches($preview, [regex]::Escape($bootAnchor))).Count -ne 1) {
    throw "page.js must carry the boot sequence marker exactly once: '$bootAnchor'"
}
$preview = $preview.Replace($bootAnchor, $shim + "`n" + $bootAnchor)

# a placeholder added to the page later must not reach the preview unfilled
$left = @([regex]::Matches($preview, '__[A-Z][A-Z0-9_]*__') | ForEach-Object { $_.Value } | Sort-Object -Unique)
if ($left.Count) {
    throw ("the preview still carries placeholder(s) the engine would fill in: " + ($left -join ', ') +
           " - teach the preview build what they mean")
}

# it is generated: say so where whoever opens it will look first
$banner = @(
    '<!--',
    '  Generated file - do not edit this one.',
    '  _build\Embed-Page.ps1 writes it from _build\web\ (page.html, page.css,',
    '  page.js) plus _build\preview\preview.js: edit those and run the build',
    '  again. The interface is the page ServerDashboard.ps1 serves, standing on',
    '  sample data instead of a server.'
    '-->'
) -join "`n"
if (-not $preview.StartsWith('<!DOCTYPE html>' + "`n")) { throw "page.html must start with <!DOCTYPE html>" }
$preview = $preview.Replace('<!DOCTYPE html>' + "`n", '<!DOCTYPE html>' + "`n" + $banner + "`n")
# compared and reported in LF, written as CRLF: the same text the sources are
# read in, so -Check never disagrees with itself over line endings
$previewLf = $preview.TrimEnd("`n")
$previewBuilt = $previewLf.Replace("`n", "`r`n") + "`r`n"

# ---- what is on disk now ----------------------------------------------------
$raw = [System.IO.File]::ReadAllText($targetFile)
$bom = ([System.IO.File]::ReadAllBytes($targetFile)[0..2] -join ',') -eq '239,187,191'
$start = $raw.IndexOf($openHere)
if ($start -lt 0) { throw "cannot find the page here-string ($openHere) in $targetFile" }
$start += $openHere.Length
$end = $raw.IndexOf($closeHere, $start)
if ($end -lt 0) { throw "cannot find the closing '@ of the page here-string in $targetFile" }
$current = $raw.Substring($start, $end - $start)

$currentPreview = ''
if (Test-Path $previewFile) { $currentPreview = (Read-Source $previewFile).TrimEnd("`n") }

$engineOk  = ($current -eq $built)
$previewOk = ($currentPreview -eq $previewLf)

$sizes = "page.css {0} bytes, page.js {1} bytes, page.html {2} bytes, page {3} bytes, preview block {4} bytes" -f `
         $css.Length, $js.Length, $page.Length, $built.Length, $shim.Length

if ($engineOk -and $previewOk) {
    Write-Host "OK     both copies match _build\ (engine page and offline preview)"
    Write-Host "       $sizes"
    exit 0
}

if ($Check) {
    if (-not $engineOk) {
        Write-Host "::error file=scripts/ServerDashboard.ps1::the embedded page is not what _build\web\ produces"
        Write-Host (Get-FirstDifference $current $built)
    }
    if (-not $previewOk) {
        Write-Host "::error file=docs/Dashboard-Preview.html::the offline preview is not what _build\web\ plus _build\preview\ produces"
        Write-Host (Get-FirstDifference $currentPreview $previewLf)
    }
    Write-Host '       run: powershell -File _build\Embed-Page.ps1  (then commit the result)'
    exit 1
}

if (-not $engineOk) {
    $new = $raw.Substring(0, $start) + $built + $raw.Substring($end)
    $enc = New-Object System.Text.UTF8Encoding($bom)
    [System.IO.File]::WriteAllText($targetFile, $new, $enc)
    Write-Host ("WROTE  scripts\ServerDashboard.ps1  (embedded page {0} -> {1} bytes)" -f $current.Length, $built.Length)
}
if (-not $previewOk) {
    $before = if ($currentPreview) { [System.Text.Encoding]::UTF8.GetByteCount($currentPreview) } else { 0 }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($previewFile, $previewBuilt, $enc)
    Write-Host ("WROTE  docs\Dashboard-Preview.html  (offline preview {0} -> {1} bytes)" -f $before, ([System.Text.Encoding]::UTF8.GetByteCount($previewBuilt)))
}
Write-Host "       $sizes"
exit 0

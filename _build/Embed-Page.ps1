<#
    Embed-Page.ps1
    The dashboard page - markup, CSS and JavaScript - is edited as three real
    files in _build\web\:

        page.html   the markup, with one marker line where the stylesheet and
                    one where the script go: /*@CSS@*/ and /*@JS@*/
        page.css    the stylesheet: replaces /*@CSS@*/
        page.js     the script:      replaces /*@JS@*/

    This script splices them back into the single here-string inside
    scripts\ServerDashboard.ps1, which is what the package ships and what the
    dashboard serves from memory. Nothing is read from disk at runtime: the
    page reaches the server embedded in the script, exactly as before.

    Run it after changing anything under _build\web\, then commit BOTH the
    sources and scripts\ServerDashboard.ps1 - the two must always agree.

        powershell -File _build\Embed-Page.ps1

    -Check only verifies, without writing, and exits 1 when the script is not
    what the sources produce; the syntax workflow runs it on every push, so the
    embedded copy can never drift from the sources.

    _build\ is a development folder: it is not part of the release archive and
    the updater never copies it onto an installation (see $UpdateSkip in
    ServerDashboard.ps1 and auto-release.yml).
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$root       = Split-Path -Parent $PSScriptRoot
$webDir     = Join-Path $PSScriptRoot 'web'
$targetFile = Join-Path $root 'scripts\ServerDashboard.ps1'
$openHere   = '$Html = @' + "'" + "`r`n"
$closeHere  = "`r`n" + "'@"

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
            return "first difference at page line $($i + 1):`n    sources: $($lb[$i])`n    embedded: $($la[$i])"
        }
    }
    return "the two are equal for $n lines, one of them is longer (sources $($lb.Count) lines, embedded $($la.Count) lines)"
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

# ---- what the script embeds now --------------------------------------------
$raw = [System.IO.File]::ReadAllText($targetFile)
$bom = ([System.IO.File]::ReadAllBytes($targetFile)[0..2] -join ',') -eq '239,187,191'
$start = $raw.IndexOf($openHere)
if ($start -lt 0) { throw "cannot find the page here-string ($openHere) in $targetFile" }
$start += $openHere.Length
$end = $raw.IndexOf($closeHere, $start)
if ($end -lt 0) { throw "cannot find the closing '@ of the page here-string in $targetFile" }
$current = $raw.Substring($start, $end - $start)

if ($current -eq $built) {
    Write-Host "OK     scripts\ServerDashboard.ps1 already carries the page built from _build\web\"
    Write-Host ("       page.css {0} bytes, page.js {1} bytes, page.html {2} bytes, page {3} bytes" -f `
                $css.Length, $js.Length, $page.Length, $built.Length)
    exit 0
}

if ($Check) {
    Write-Host "::error file=scripts/ServerDashboard.ps1::the embedded page is not what _build\web\ produces"
    Write-Host "       run: powershell -File _build\Embed-Page.ps1  (then commit the result)"
    Write-Host (Get-FirstDifference $current $built)
    exit 1
}

$new = $raw.Substring(0, $start) + $built + $raw.Substring($end)
$enc = New-Object System.Text.UTF8Encoding($bom)
[System.IO.File]::WriteAllText($targetFile, $new, $enc)
Write-Host ("WROTE  scripts\ServerDashboard.ps1  (embedded page {0} -> {1} bytes)" -f $current.Length, $built.Length)
Write-Host ("       sources: page.html {0} bytes, page.css {1} bytes, page.js {2} bytes" -f `
            $page.Length, $css.Length, $js.Length)
exit 0

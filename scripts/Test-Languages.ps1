<#
    Test-Languages.ps1
    The contract of the lang\ folder, one rule per line:

      - every file parses, and keeps the encoding and the line endings of the
        others (UTF-8, no BOM, CRLF);
      - every file carries exactly the keys en-US.xml carries: a missing key
        shows English text to somebody, an extra key is a string nothing asks
        for any more;
      - no value is empty;
      - the placeholders of a value ({0}, {1}, ...) are the ones en-US has, or
        the sentence would drop the number it is given.

    en-US.xml is the reference: it is the language the page falls back to, so a
    key that is not in it cannot be reached.

    A warning is not enough here - CI has to fail on a language file that
    drifts, or the same drift comes back - so this script exits 1 with the
    offending files named.
#>
[CmdletBinding()]
param([string]$Folder,
      [string]$Reference = 'en-US.xml')

# the lang\ folder of the package: this script lives in scripts\ next to it
if (-not $Folder) { $Folder = Join-Path (Split-Path -Parent $PSScriptRoot) 'lang' }
$folderPath = (Resolve-Path $Folder).Path
$refPath = Join-Path $folderPath $Reference
if (-not (Test-Path $refPath)) { Write-Output "RESULT=FAIL"; Write-Output "no $Reference in $folderPath"; exit 1 }

$refBytes = [System.IO.File]::ReadAllBytes($refPath)
$refText = [System.Text.Encoding]::UTF8.GetString($refBytes)
[xml]$ref = $refText
$refKeys = @($ref.language.string | ForEach-Object { $_.key })
$refValues = @{}
foreach ($s in $ref.language.string) { $refValues[$s.key] = $s.'#text' }
Write-Output ("reference {0}: {1} keys" -f $Reference, $refKeys.Count)

$bad = 0
foreach ($f in (Get-ChildItem -Path $folderPath -Filter *.xml -File | Sort-Object Name)) {
    $problems = New-Object System.Collections.Generic.List[string]
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $problems.Add('carries a UTF-8 BOM')
    }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text -match "(?<!`r)`n") { $problems.Add('has a line ending that is not CRLF') }
    try { [xml]$x = $text } catch { $problems.Add('is not valid XML: ' + $_.Exception.Message); }

    if ($x) {
        $keys = @($x.language.string | ForEach-Object { $_.key })
        $missing = @($refKeys | Where-Object { $_ -notin $keys })
        $extra = @($keys | Where-Object { $_ -notin $refKeys })
        if ($missing.Count) { $problems.Add('missing: ' + ($missing -join ', ')) }
        if ($extra.Count) { $problems.Add('not in ' + $Reference + ': ' + ($extra -join ', ')) }
        foreach ($s in $x.language.string) {
            $v = $s.'#text'
            if ([string]::IsNullOrWhiteSpace($v)) { $problems.Add('empty value for ' + $s.key); continue }
            if (-not $refValues.ContainsKey($s.key)) { continue }
            $want = @([regex]::Matches($refValues[$s.key], '\{\d+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
            $have = @([regex]::Matches($v, '\{\d+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
            if (($want -join ',') -ne ($have -join ',')) {
                $problems.Add(('placeholders of {0}: expected [{1}], found [{2}]' -f $s.key, ($want -join ','), ($have -join ',')))
            }
        }
    }

    if ($problems.Count) {
        $bad++
        Write-Output ("[X]  {0} ({1} keys)" -f $f.Name, @($x.language.string).Count)
        foreach ($p in $problems) { Write-Output ("     $p") }
        if ($env:GITHUB_ACTIONS) { Write-Output ("::error file=$($f.Name)::" + ($problems -join '; ')) }
    } else {
        Write-Output ("[OK] {0} ({1} keys)" -f $f.Name, $keys.Count)
    }
}
if ($bad) { Write-Output "RESULT=FAIL"; exit 1 }
Write-Output "RESULT=OK"
exit 0

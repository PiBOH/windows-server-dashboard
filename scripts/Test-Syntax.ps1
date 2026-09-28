<#
    Test-Syntax.ps1
    Parses every PowerShell file of the package with the official PowerShell
    parser and reports the errors, with file, line and column.

    Why it exists: a syntax error makes the script exit immediately with code 1,
    before it can write a single line of log - the dashboard simply never
    starts, and the scheduled task shows "Last result: 1" with no explanation.
    Install.bat runs this check before installing anything.
    By default it scans the folder it lives in (scripts\).
#>
[CmdletBinding()]
param([string]$Folder = $PSScriptRoot)

$bad = 0
foreach ($f in (Get-ChildItem -Path $Folder -Filter *.ps1 -File | Sort-Object Name)) {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count) {
        $bad++
        Write-Output ("[X]  {0}: {1} syntax error(s)" -f $f.Name, $errors.Count)
        foreach ($e in ($errors | Select-Object -First 5)) {
            Write-Output ("     line {0}, col {1}: {2}" -f `
                $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber, $e.Message)
        }
    } else {
        Write-Output ("[OK] {0}" -f $f.Name)
    }
}
if ($bad) { Write-Output "RESULT=FAIL"; exit 1 }
Write-Output "RESULT=OK"
exit 0

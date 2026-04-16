# Thin launcher: runs standardize_pricing_csv.py (Python 3 stdlib only) next to this script.
# Usage: .\standardize-pricing-csv.ps1 --input raw.csv --output out.csv --csp aws [-map extra.json] [-line-ending CRLF]
# All arguments are passed through to the Python script.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$PyScript = Join-Path $ScriptRoot 'standardize_pricing_csv.py'

if (-not (Test-Path -LiteralPath $PyScript)) {
    Write-Error "Not found: $PyScript"
    exit 1
}

$python = $null
foreach ($name in @('python3', 'python')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        $python = $cmd.Path
        break
    }
}

if (-not $python) {
    Write-Error 'Python 3 not found on PATH. Install from https://www.python.org/downloads/ and ensure python or python3 is on PATH.'
    exit 1
}

if (-not $Rest -or $Rest.Count -eq 0) {
    Write-Host @'
Usage: .\standardize-pricing-csv.ps1 --input <raw.csv> --output <out.csv> --csp aws|azure|gcp|oracle [--map map.json] [--line-ending LF|CRLF]

Example:
  .\standardize-pricing-csv.ps1 --input .\export.csv --output .\bulk.csv --csp aws --line-ending CRLF
'@
    exit 1
}

& $python $PyScript @Rest
exit $LASTEXITCODE

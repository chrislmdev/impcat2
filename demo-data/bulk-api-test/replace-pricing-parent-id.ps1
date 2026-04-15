# Replaces the Catalog_Import__c placeholder in the first column of a pricing CSV with the real
# parent Id (sf__Id from *-success-records.csv). UTF-8 no BOM; preserves CRLF vs LF.
#
# Usage:
#   .\replace-pricing-parent-id.ps1 -NewId a0XXXXXXXXXXXXXXX
#       If -CsvPath is omitted: auto-selects the sole pricing_items_*.csv next to this script,
#       or prompts you to pick if multiple match.
#   .\replace-pricing-parent-id.ps1 -NewId a0XXX -CsvPath "demo-data\bulk-api-test\pricing_items_gcp_2026-03.csv"
#       Explicit path when you already know which file to patch.
#   .\replace-pricing-parent-id.ps1 a0XXX -OldId "previousId"
#       Positional -NewId works: .\replace-pricing-parent-id.ps1 a0XXX
#
# Full wizard: .\write-demo-csv.ps1 -Interactive (passes -CsvPath for the file it just wrote)
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$NewId,

    [string]$CsvPath,

    [string]$OldId = 'PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PricingCsvPath {
    $cands = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'pricing_items_*.csv' -File |
            Sort-Object LastWriteTime -Descending)
    if ($cands.Count -eq 0) {
        Write-Error "No pricing_items_*.csv in $PSScriptRoot. Run write-demo-csv.ps1 / write-demo-csv.sh to generate one, or pass -CsvPath."
        exit 1
    }
    if ($cands.Count -eq 1) {
        Write-Host "Using pricing file: $($cands[0].Name)"
        return $cands[0].FullName
    }
    Write-Host 'Multiple pricing_items_*.csv files found — which one should be updated?'
    for ($i = 0; $i -lt $cands.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $cands[$i].Name)
    }
    while ($true) {
        $sel = Read-Host ("Enter number (1-{0}) or a full path to your CSV" -f $cands.Count)
        if (Test-Path -LiteralPath $sel) {
            return (Resolve-Path -LiteralPath $sel).Path
        }
        $n = 0
        if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $cands.Count) {
            return $cands[$n - 1].FullName
        }
        Write-Host 'Invalid choice. Enter a list number or a full file path.'
    }
}

if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $CsvPath = Resolve-PricingCsvPath
}

if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Error "Missing file: $CsvPath"
    exit 1
}

$raw = [System.IO.File]::ReadAllBytes($CsvPath)
$enc = [System.Text.UTF8Encoding]::new($false)
$text = $enc.GetString($raw)
$updated = $text.Replace($OldId, $NewId)
[System.IO.File]::WriteAllText($CsvPath, $updated, $enc)
Write-Host "Updated Catalog_Import__c column in: $CsvPath"

# Replaces the Catalog_Import__c placeholder in the first column of a pricing CSV with the real
# parent Id (sf__Id from *-success-records.csv). UTF-8 no BOM; preserves CRLF vs LF.
#
# Usage:
#   .\replace-pricing-parent-id.ps1 -NewId a0XXXXXXXXXXXXXXX
#   .\replace-pricing-parent-id.ps1 -NewId a0XXX -CsvPath .\pricing_items_gcp_2025-06.csv
#
# For the full guided flow: .\write-demo-csv.ps1 -Interactive
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$NewId,

    [string]$CsvPath = (Join-Path $PSScriptRoot 'pricing_items_aws_2025-12.csv'),

    [string]$OldId = 'PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Error "Missing file: $CsvPath"
    exit 1
}

$raw = [System.IO.File]::ReadAllBytes($CsvPath)
$enc = [System.Text.UTF8Encoding]::new($false)
$text = $enc.GetString($raw)
$nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
$updated = $text.Replace($OldId, $NewId)
[System.IO.File]::WriteAllText($CsvPath, $updated, $enc)
Write-Host "Updated Catalog_Import__c column in: $CsvPath"

# Bulk API 2.0 helpers: Catalog_Import__c parent row + Pricing_Item__c conversion for sf data import bulk.
#
# Non-interactive (parent snapshot only):
#   .\write-bulk-import-csv.ps1
#   .\write-bulk-import-csv.ps1 -LineEnding LF -ImportMonth 2026-03 -Csp gcp
#   Writes: catalog_import_<csp>_<ImportMonth>.csv (UTF-8 no BOM)
#
# Non-interactive: convert source pricing to Salesforce API columns (writes next to this script):
#   .\write-bulk-import-csv.ps1 -PricingCsv C:\exports\source.csv -ColumnMapPath .\pricing_column_map.json
#   Output: pricing_for_bulk_<Csp>_<ImportMonth>.csv  (defaults: aws, 2025-12)
#
# Interactive wizard (sf on PATH):
#   .\write-bulk-import-csv.ps1 -Interactive
#   Prompts for source pricing CSV (required), optional column map JSON, year/month/CSP, org, line ending.
#   Writes catalog_import_<csp>_<YYYY-MM>.csv and pricing_for_bulk_<csp>_<YYYY-MM>.csv (converted).
#
# Column maps: see pricing_column_map.example.json (source header string -> API name).
# Without a map, every source header must already be a valid field API name (ends with __c).
#
# IMPORTANT: Pricing rows use Catalog_Import__c = placeholder until replace-pricing-parent-id.ps1 after parent import.
param(
    [switch]$Interactive,
    [string]$PricingCsv,
    [string]$ColumnMapPath,
    [ValidateSet('CRLF', 'LF')]
    [string]$LineEnding = 'CRLF',
    [string]$ImportMonth = '2025-12',
    [ValidateSet('aws', 'azure', 'gcp', 'oracle')]
    [string]$Csp = 'aws'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$Placeholder = 'PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV'
$Enc = [System.Text.UTF8Encoding]::new($false)

$script:PreferredPricingApiOrder = @(
    'Catalog_Import__c', 'CSP__c', 'Catalog_Item_Number__c', 'Title__c', 'CSO_Short_Name__c',
    'Description__c', 'List_Unit_Price__c', 'Pricing_Unit__c', 'JWCC_Unit_Price__c', 'JWCC_Unit_Of_Issue__c',
    'Discount_Premium_Fee__c', 'Focus_Category__c', 'Service_Category__c'
)

function Get-Newline {
    param([string]$Ending)
    if ($Ending -eq 'CRLF') { return "`r`n" }
    return [char]10
}

function Test-ApiFieldName {
    param([string]$Name)
    return $Name -match '^[A-Za-z][A-Za-z0-9_]*__c$'
}

function Read-ColumnMapJson {
    param([string]$Path)
    $m = @{}
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $m }
    $j = Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json
    if ($j.column_mappings) {
        foreach ($p in $j.column_mappings.PSObject.Properties) {
            if ($p.Name.StartsWith('_')) { continue }
            $m[$p.Name] = [string]$p.Value
        }
    } elseif ($j.mappings) {
        foreach ($p in $j.mappings.PSObject.Properties) {
            if ($p.Name.StartsWith('_')) { continue }
            $m[$p.Name] = [string]$p.Value
        }
    }
    return $m
}

function Resolve-SourceHeaderToApi {
    param([string]$Stripped, [hashtable]$Map)
    if ($Map.ContainsKey($Stripped)) { return $Map[$Stripped] }
    if (Test-ApiFieldName -Name $Stripped) { return $Stripped }
    return $null
}

function Convert-PricingCsvToSalesforceApi {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [string]$MapPath,
        [Parameter(Mandatory = $true)][string]$LineEnding
    )

    $map = Read-ColumnMapJson -Path $MapPath
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Source file not found: $SourcePath"
    }

    $rows = Import-Csv -LiteralPath $SourcePath -Encoding UTF8
    if ($null -eq $rows) {
        throw "Could not read CSV (empty or invalid): $SourcePath"
    }
    if ($rows -isnot [System.Array]) { $rows = @($rows) }

    $sample = $rows | Select-Object -First 1
    if (-not $sample) {
        throw "CSV has no data rows (header-only). Add rows or use convert_pricing_csv_to_api.py for header-only files."
    }

    $rawNames = @($sample.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } | ForEach-Object { $_.Name })
    $apiByRaw = @{}
    $errors = [System.Collections.Generic.List[string]]::new()

    foreach ($raw in $rawNames) {
        $stripped = $raw.Trim()
        $api = Resolve-SourceHeaderToApi -Stripped $stripped -Map $map
        if ($null -eq $api) {
            $errors.Add($stripped) | Out-Null
        } else {
            $apiByRaw[$raw] = $api
        }
    }

    if ($errors.Count -gt 0) {
        $msg = "Unknown source column(s) (add to column map JSON or rename headers):`n  " + ($errors -join "`n  ")
        throw $msg
    }

    $seen = @{}
    foreach ($pair in $apiByRaw.GetEnumerator()) {
        $api = $pair.Value
        $raw = $pair.Key
        if ($seen.ContainsKey($api) -and $seen[$api] -ne $raw) {
            throw "Two source columns map to the same API name '$api'."
        }
        $seen[$api] = $raw
    }

    $uniqApis = @($apiByRaw.Values | Sort-Object -Unique)
    $ordered = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $script:PreferredPricingApiOrder) {
        if ($uniqApis -contains $p) { $ordered.Add($p) | Out-Null }
    }
    $rest = $uniqApis | Where-Object { $ordered -notcontains $_ }
    foreach ($r in $rest) { $ordered.Add($r) | Out-Null }

    $nl = Get-Newline -Ending $LineEnding
    $lines = New-Object System.Collections.Generic.List[string]
    $headerLine = ($ordered -join ',')
    $lines.Add($headerLine) | Out-Null

    foreach ($row in $rows) {
        $cells = foreach ($col in $ordered) {
            $srcKey = $null
            foreach ($k in $apiByRaw.Keys) {
                if ($apiByRaw[$k] -eq $col) { $srcKey = $k; break }
            }
            $val = if ($srcKey) { $row.$srcKey } else { '' }
            if ($null -eq $val) { $val = '' }
            $s = [string]$val
            if ($s.Contains('"') -or $s.Contains(',') -or $s.Contains("`n") -or $s.Contains("`r")) {
                '"' + ($s -replace '"', '""') + '"'
            } else {
                $s
            }
        }
        $lines.Add(($cells -join ',')) | Out-Null
    }

    $text = ($lines -join $nl) + $nl
    [System.IO.File]::WriteAllText($OutputPath, $text, $Enc)
}

function Export-CatalogImportCsv {
    param(
        [string]$ImportMonth,
        [string]$Csp,
        [string]$LineEnding,
        [string]$CatalogPath,
        [string]$SourceFile,
        [string]$ImportedAt,
        [string]$ImportedBy,
        [int]$RowCount = 0
    )

    $nl = Get-Newline -Ending $LineEnding
    $catalogLines = @(
        'Import_Month__c,CSP__c,Schema__c,Status__c,Source_File__c,Imported_At__c,Imported_By__c,Row_Count__c'
        "$ImportMonth,$Csp,pricing,processing,$SourceFile,$ImportedAt,$ImportedBy,$RowCount"
    )
    [System.IO.File]::WriteAllText($CatalogPath, (($catalogLines -join $nl) + $nl), $Enc)
}

function Test-SfAvailable {
    return $null -ne (Get-Command sf -ErrorAction SilentlyContinue)
}

function Read-SfIdFromSuccessCsv {
    param([string]$ResultsDir)
    $files = Get-ChildItem -Path $ResultsDir -Filter '*-success-records.csv' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $files -or $files.Count -eq 0) { return $null }
    $path = $files[0].FullName
    $rows = Import-Csv -LiteralPath $path
    if (-not $rows) { return $null }
    $row = $rows[0]
    foreach ($p in $row.PSObject.Properties) {
        if ($p.Name -eq 'sf__Id' -or $p.Name -eq 'sf__id') {
            return [string]$p.Value
        }
    }
    return $null
}

function Get-OutputPricingPath {
    param([string]$Csp, [string]$ImportMonth)
    return Join-Path $ScriptRoot ("pricing_for_bulk_{0}_{1}.csv" -f $Csp, $ImportMonth)
}

function Invoke-InteractiveWizard {
    param(
        [AllowEmptyString()][string]$PricingCsvIn,
        [AllowEmptyString()][string]$ColumnMapIn
    )

    if ([string]::IsNullOrWhiteSpace($PricingCsvIn) -and $env:PRICING_CSV) {
        $PricingCsvIn = $env:PRICING_CSV
    }
    if ([string]::IsNullOrWhiteSpace($ColumnMapIn) -and $env:PRICING_COLUMN_MAP) {
        $ColumnMapIn = $env:PRICING_COLUMN_MAP
    }

    if (-not (Test-SfAvailable)) {
        Write-Host 'Salesforce CLI (sf) not found on PATH. Install: https://developer.salesforce.com/tools/salesforcecli' -ForegroundColor Red
        exit 1
    }

    Write-Host ''
    Write-Host '=== Bulk import wizard (pricing only) ===' -ForegroundColor Cyan
    Write-Host 'You need: source pricing CSV, import month, CSP, org alias, Bulk Job Id from sf output.'
    Write-Host ''

    do {
        $y = Read-Host 'Calendar year (e.g. 2025)'
        if ($y -match '^\d{4}$' -and [int]$y -ge 2020 -and [int]$y -le 2035) { break }
        Write-Host 'Enter a 4-digit year between 2020 and 2035.'
    } while ($true)

    do {
        $mo = Read-Host 'Month (1-12 or name like March)'
        $mm = $null
        if ($mo -match '^\d{1,2}$') {
            $n = [int]$mo
            if ($n -ge 1 -and $n -le 12) { $mm = '{0:D2}' -f $n }
        } else {
            $dt = [datetime]::MinValue
            if ([datetime]::TryParse("$mo 1, $y", [ref]$dt)) { $mm = $dt.ToString('MM') }
        }
        if ($null -ne $mm) { break }
        Write-Host 'Invalid month.'
    } while ($true)

    $importMonth = "$y-$mm"

    Write-Host ''
    Write-Host 'CSP (cloud vendor):'
    Write-Host '  1) aws   2) azure   3) gcp   4) oracle'
    $csp = $null
    do {
        $c = Read-Host 'Choose 1-4'
        switch ($c) {
            '1' { $csp = 'aws' }
            '2' { $csp = 'azure' }
            '3' { $csp = 'gcp' }
            '4' { $csp = 'oracle' }
            default {
                if ($c -in @('aws', 'azure', 'gcp', 'oracle')) { $csp = $c }
            }
        }
        if ($csp) { break }
        Write-Host 'Enter 1-4 or type aws, azure, gcp, or oracle.'
    } while ($true)

    $defaultSource = "${importMonth}_${csp}_pricing.csv"
    $srcIn = Read-Host "Source_File__c (Enter for default: $defaultSource)"
    if ([string]::IsNullOrWhiteSpace($srcIn)) { $srcIn = $defaultSource }

    $utcNow = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $atIn = Read-Host "Imported_At__c UTC (Enter for now: $utcNow)"
    if ([string]::IsNullOrWhiteSpace($atIn)) { $atIn = $utcNow }

    $defaultBy = if ($env:USERNAME) { $env:USERNAME } else { 'bulk_import' }
    $byIn = Read-Host "Imported_By__c (Enter for: $defaultBy)"
    if ([string]::IsNullOrWhiteSpace($byIn)) { $byIn = $defaultBy }

    if ([string]::IsNullOrWhiteSpace($PricingCsvIn)) {
        $PricingCsvIn = Read-Host 'Path to source pricing CSV (your export; not yet Salesforce API headers)'
    }
    if ([string]::IsNullOrWhiteSpace($PricingCsvIn)) {
        Write-Host 'Source pricing CSV is required.'
        exit 1
    }
    try {
        $srcPricingPath = (Resolve-Path -LiteralPath $PricingCsvIn.Trim()).Path
    } catch {
        Write-Error "Pricing CSV not found: $PricingCsvIn"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($ColumnMapIn)) {
        $ColumnMapIn = Read-Host 'Path to column map JSON (optional; Enter if headers are already *__c API names)'
    }
    $mapPathResolved = $null
    if (-not [string]::IsNullOrWhiteSpace($ColumnMapIn)) {
        try {
            $mapPathResolved = (Resolve-Path -LiteralPath $ColumnMapIn.Trim()).Path
        } catch {
            Write-Error "Column map not found: $ColumnMapIn"
            exit 1
        }
    }

    $catalogName = "catalog_import_${csp}_${importMonth}.csv"
    $catalogPath = Join-Path $ScriptRoot $catalogName
    $bulkPricingPath = Get-OutputPricingPath -Csp $csp -ImportMonth $importMonth

    Write-Host ''
    Write-Host '--- Summary ---'
    Write-Host "  Import_Month__c: $importMonth"
    Write-Host "  CSP:             $csp"
    Write-Host "  Source_File__c:  $srcIn"
    Write-Host "  Catalog file:    $catalogName"
    Write-Host "  Source pricing:  $srcPricingPath"
    Write-Host "  Converted file:  $bulkPricingPath"
    if ($mapPathResolved) {
        Write-Host "  Column map:      $mapPathResolved"
    }
    Write-Host "  Placeholder:     $Placeholder in Catalog_Import__c until parent succeeds."
    Write-Host ''
    $ok = Read-Host 'Continue? (y/n)'
    if ($ok -notmatch '^[yY]') {
        Write-Host 'Cancelled.'
        exit 0
    }

    $org = Read-Host 'Salesforce org alias or username (sf --target-org)'
    if ([string]::IsNullOrWhiteSpace($org)) {
        Write-Host 'Org is required.'
        exit 1
    }

    $isWin = ($env:OS -eq 'Windows_NT')
    $defaultLe = if ($isWin) { 'CRLF' } else { 'LF' }
    $leIn = Read-Host "Line ending for CSV + sf (Enter for $defaultLe, or type CRLF / LF)"
    if ([string]::IsNullOrWhiteSpace($leIn)) {
        $LineEnding = $defaultLe
    } else {
        $LineEnding = $leIn.Trim().ToUpperInvariant()
        if ($LineEnding -notin @('CRLF', 'LF')) {
            Write-Host 'Use CRLF or LF. Exiting.'
            exit 1
        }
    }

    try {
        Convert-PricingCsvToSalesforceApi -SourcePath $srcPricingPath -OutputPath $bulkPricingPath `
            -MapPath $mapPathResolved -LineEnding $LineEnding
    } catch {
        Write-Error $_
        exit 1
    }

    Export-CatalogImportCsv -ImportMonth $importMonth -Csp $csp -LineEnding $LineEnding `
        -CatalogPath $catalogPath -SourceFile $srcIn -ImportedAt $atIn -ImportedBy $byIn -RowCount 0

    Write-Host ''
    Write-Host "Wrote:`n  $catalogPath`n  $bulkPricingPath (Salesforce API columns)"
    Write-Host ''
    Write-Host 'NOTE: Bulk JOB Id (750...) is only for downloading results.' -ForegroundColor Yellow
    Write-Host '      RECORD Id (sf__Id, often a0...) goes in Catalog_Import__c on pricing rows.' -ForegroundColor Yellow
    Write-Host ''

    $sfArgs = @(
        'data', 'import', 'bulk',
        '--sobject', 'Catalog_Import__c',
        '--file', $catalogPath,
        '--target-org', $org,
        '--wait', '10m',
        '--line-ending', $LineEnding
    )
    Write-Host "Running: sf $($sfArgs -join ' ')" -ForegroundColor DarkGray
    & sf @sfArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Parent import failed. Fix errors and re-run, or import manually.' -ForegroundColor Red
        exit $LASTEXITCODE
    }

    do {
        $jobId = Read-Host 'Paste the Bulk ingest Job Id from the output above (750...)'
        $jobId = $jobId.Trim()
        if ($jobId -match '^[a-zA-Z0-9]{15,18}$') { break }
        Write-Host 'Expected 15-18 alphanumeric characters.'
    } while ($true)

    $resultsDir = Join-Path $ScriptRoot '.bulk-results'
    if (-not (Test-Path $resultsDir)) {
        New-Item -ItemType Directory -Path $resultsDir | Out-Null
    }
    Push-Location $resultsDir
    try {
        & sf data bulk results -o $org --job-id $jobId
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'sf data bulk results failed.' -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }

    Write-Host "Results files are under: $resultsDir" -ForegroundColor Green

    $sfId = Read-SfIdFromSuccessCsv -ResultsDir $resultsDir
    if ([string]::IsNullOrWhiteSpace($sfId)) {
        $sfId = Read-Host 'Could not read sf__Id automatically. Paste the Catalog_Import__c Id (NOT the 750 Job Id)'
    }

    $sfId = $sfId.Trim()
    if ($sfId.StartsWith('750')) {
        Write-Host 'That looks like a Bulk Job Id. Use sf__Id from the success CSV (usually starts with a0).' -ForegroundColor Red
        exit 1
    }

    $replaceScript = Join-Path $ScriptRoot 'replace-pricing-parent-id.ps1'
    & $replaceScript -NewId $sfId -CsvPath $bulkPricingPath

    Write-Host ''
    $sfArgs2 = @(
        'data', 'import', 'bulk',
        '--sobject', 'Pricing_Item__c',
        '--file', $bulkPricingPath,
        '--target-org', $org,
        '--wait', '10m',
        '--line-ending', $LineEnding
    )
    Write-Host "Running: sf $($sfArgs2 -join ' ')" -ForegroundColor DarkGray
    & sf @sfArgs2
    $childExit = $LASTEXITCODE
    if ($childExit -ne 0) {
        Write-Host 'Pricing import reported failure. Check sf output above.' -ForegroundColor Red
        Write-Host "To fetch failed rows: sf data bulk results -o $org --job-id <job_id_from_output>"
        exit $childExit
    }

    Write-Host ''
    Write-Host 'Done. If any pricing rows failed, run sf data bulk results with the job id from that step.' -ForegroundColor Green
}

if ($Interactive) {
    Invoke-InteractiveWizard -PricingCsvIn $PricingCsv -ColumnMapIn $ColumnMapPath
    exit 0
}

if ($ColumnMapPath -and -not $PricingCsv) {
    Write-Error 'ColumnMapPath requires -PricingCsv (or use -Interactive).'
    exit 1
}

if ($PricingCsv) {
    try {
        $src = (Resolve-Path -LiteralPath $PricingCsv.Trim()).Path
    } catch {
        Write-Error "PricingCsv not found: $PricingCsv"
        exit 1
    }
    $mapR = $null
    if ($ColumnMapPath) {
        try {
            $mapR = (Resolve-Path -LiteralPath $ColumnMapPath.Trim()).Path
        } catch {
            Write-Error "ColumnMapPath not found: $ColumnMapPath"
            exit 1
        }
    }
    $outP = Get-OutputPricingPath -Csp $Csp -ImportMonth $ImportMonth
    Convert-PricingCsvToSalesforceApi -SourcePath $src -OutputPath $outP -MapPath $mapR -LineEnding $LineEnding
    Write-Host "Converted pricing written: $outP ($LineEnding)"
    exit 0
}

$catalogPath = Join-Path $ScriptRoot "catalog_import_${Csp}_${ImportMonth}.csv"
Export-CatalogImportCsv -ImportMonth $ImportMonth -Csp $Csp -LineEnding $LineEnding `
    -CatalogPath $catalogPath `
    -SourceFile "${ImportMonth}_${Csp}_pricing.csv" `
    -ImportedAt ([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')) `
    -ImportedBy 'bulk_import' -RowCount 0

Write-Host ("Wrote UTF-8 {0}: {1}" -f $LineEnding, (Split-Path $catalogPath -Leaf))
Write-Host 'Optional: .\write-bulk-import-csv.ps1 -PricingCsv <source.csv> [-ColumnMapPath map.json]'
Write-Host ('Use: sf data import bulk ... --line-ending ' + $LineEnding)

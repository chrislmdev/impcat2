# Demo Bulk API 2.0 CSVs for Catalog_Import__c + Pricing_Item__c (pricing schema only; no exceptions).
#
# Non-interactive (default):
#   .\write-demo-csv.ps1
#   .\write-demo-csv.ps1 -LineEnding LF
#   Writes fixed demo files next to this script:
#     catalog_import_aws_2025-12.csv
#     pricing_items_aws_2025-12.csv
#   Use the same -LineEnding value with: sf data import bulk ... --line-ending <CRLF|LF>
#
# Interactive wizard (requires sf on PATH):
#   .\write-demo-csv.ps1 -Interactive
#   .\write-demo-csv.ps1 -Interactive -ProductionPricingCsv "C:\exports\my_pricing.csv"
#   Optional env: $env:PRODUCTION_PRICING_CSV (same as -ProductionPricingCsv if param omitted)
#   Prompts for year, month, CSP, org, line ending; always writes ONE catalog_import_<csp>_<YYYY-MM>.csv.
#   Pricing file: either four DEMO sample rows (default) OR your production CSV (-ProductionPricingCsv or prompt).
#   Production CSV must use Pricing_Item__c API column headers; Catalog_Import__c column = placeholder until replace.
#   Then: parent bulk import, sf data bulk results (under .bulk-results\), replace-pricing-parent-id.ps1, child import.
#
# IMPORTANT: On pricing rows, Catalog_Import__c must be the record Id (sf__Id from *-success-records.csv),
#            not the Bulk ingest Job Id (750...).
param(
    [switch]$Interactive,
    [string]$ProductionPricingCsv,
    [ValidateSet('CRLF', 'LF')]
    [string]$LineEnding = 'CRLF'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$Placeholder = 'PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV'
$Enc = [System.Text.UTF8Encoding]::new($false)

function Get-Newline {
    param([string]$Ending)
    if ($Ending -eq 'CRLF') { return "`r`n" }
    return [char]10
}

function Get-CspTag {
    param([string]$Csp)
    switch ($Csp.ToLower()) {
        'aws' { 'AWS' }
        'azure' { 'AZURE' }
        'gcp' { 'GCP' }
        'oracle' { 'ORA' }
        default { throw "Invalid CSP: $Csp" }
    }
}

function Export-DemoCsvFiles {
    param(
        [string]$ImportMonth,
        [string]$Csp,
        [string]$LineEnding,
        [string]$CatalogPath,
        [string]$PricingPath,
        [string]$ParentIdPlaceholder,
        [string]$SourceFile,
        [string]$ImportedAt,
        [string]$ImportedBy,
        [int]$RowCount = 0,
        [switch]$CatalogOnly
    )

    $nl = Get-Newline -Ending $LineEnding
    $tag = Get-CspTag -Csp $Csp

    $catalogLines = @(
        'Import_Month__c,CSP__c,Schema__c,Status__c,Source_File__c,Imported_At__c,Imported_By__c,Row_Count__c'
        "$ImportMonth,$Csp,pricing,processing,$SourceFile,$ImportedAt,$ImportedBy,$RowCount"
    )
    [System.IO.File]::WriteAllText($CatalogPath, (($catalogLines -join $nl) + $nl), $Enc)

    if ($CatalogOnly) {
        return
    }

    $pricingLines = @(
        'Catalog_Import__c,CSP__c,Catalog_Item_Number__c,Title__c,CSO_Short_Name__c,Description__c,List_Unit_Price__c,Pricing_Unit__c,JWCC_Unit_Price__c,JWCC_Unit_Of_Issue__c,Discount_Premium_Fee__c,Focus_Category__c,Service_Category__c'
        ($ParentIdPlaceholder + ",$Csp,DEMO-${tag}-EC2-T3MICRO,t3.micro mock,$tag compute,General purpose burstable; demo row,0.0104,Hour,0.0092,Hour,-12%,Compute,Compute")
        ($ParentIdPlaceholder + ",$Csp,DEMO-${tag}-S3-STD,S3 Standard storage mock,$tag storage,Object storage per GB-month; demo,0.023,GB-Mo,0.0202,GB-Mo,,Storage,Storage")
        ($ParentIdPlaceholder + ",$Csp,DEMO-${tag}-RDS-MYSQL,db.t3.micro MySQL mock,$tag database,Managed relational DB; demo,0.017,Hour,0.015,Hour,-10%,Database,Database")
        ($ParentIdPlaceholder + ",$Csp,DEMO-${tag}-VPC-ENDPOINT,Interface VPC endpoint mock,$tag network,Private connectivity; demo,0.01,Hour,0.0088,Hour,,Networking,Networking")
    )
    [System.IO.File]::WriteAllText($PricingPath, (($pricingLines -join $nl) + $nl), $Enc)
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

function Invoke-InteractiveWizard {
    param(
        [AllowEmptyString()]
        [string]$ProductionPricingCsv
    )

    if ([string]::IsNullOrWhiteSpace($ProductionPricingCsv) -and $env:PRODUCTION_PRICING_CSV) {
        $ProductionPricingCsv = $env:PRODUCTION_PRICING_CSV
    }

    if (-not (Test-SfAvailable)) {
        Write-Host 'Salesforce CLI (sf) not found on PATH. Install: https://developer.salesforce.com/tools/salesforcecli' -ForegroundColor Red
        exit 1
    }

    Write-Host ''
    Write-Host '=== Bulk import wizard (pricing only) ===' -ForegroundColor Cyan
    Write-Host 'You will need: import month, CSP, org alias, and later the Bulk Job Id from sf output.'
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

    $defaultBy = if ($env:USERNAME) { $env:USERNAME } else { 'bulk_import_wizard' }
    $byIn = Read-Host "Imported_By__c (Enter for: $defaultBy)"
    if ([string]::IsNullOrWhiteSpace($byIn)) { $byIn = $defaultBy }

    $catalogName = "catalog_import_${csp}_${importMonth}.csv"
    $catalogPath = Join-Path $ScriptRoot $catalogName

    $prodPathResolved = $null
    if (-not [string]::IsNullOrWhiteSpace($ProductionPricingCsv)) {
        try {
            $prodPathResolved = (Resolve-Path -LiteralPath $ProductionPricingCsv.Trim()).Path
        } catch {
            Write-Error "ProductionPricingCsv not found: $ProductionPricingCsv"
            exit 1
        }
    } else {
        $askProd = Read-Host 'Path to production pricing CSV (optional; Enter for 4 demo sample rows)'
        if (-not [string]::IsNullOrWhiteSpace($askProd)) {
            try {
                $prodPathResolved = (Resolve-Path -LiteralPath $askProd.Trim()).Path
            } catch {
                Write-Error "File not found: $askProd"
                exit 1
            }
        }
    }

    $pricingPath = if ($prodPathResolved) { $prodPathResolved } else { Join-Path $ScriptRoot "pricing_items_${csp}_${importMonth}.csv" }
    $pricingLabel = if ($prodPathResolved) { $prodPathResolved } else { "pricing_items_${csp}_${importMonth}.csv" }

    Write-Host ''
    Write-Host '--- Summary ---'
    Write-Host "  Import_Month__c: $importMonth"
    Write-Host "  CSP:             $csp"
    Write-Host "  Schema:          pricing (fixed)"
    Write-Host "  Source_File__c:  $srcIn"
    Write-Host "  Catalog file:    $catalogName"
    if ($prodPathResolved) {
        Write-Host "  Pricing file:    $pricingLabel (your data — not overwritten by this script)"
        Write-Host "                   Ensure Catalog_Import__c column = $Placeholder before import."
    } else {
        Write-Host "  Pricing file:    $pricingLabel (demo sample rows)"
    }
    Write-Host ''
    $ok = Read-Host 'Continue? (y/n)'
    if ($ok -notmatch '^[yY]') {
        Write-Host 'Cancelled.'
        exit 0
    }

    $org = Read-Host 'Salesforce org alias or username (sf --target-org). Run sf org list if unsure'
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

    if ($prodPathResolved) {
        Export-DemoCsvFiles -ImportMonth $importMonth -Csp $csp -LineEnding $LineEnding `
            -CatalogPath $catalogPath -PricingPath $pricingPath -ParentIdPlaceholder $Placeholder `
            -SourceFile $srcIn -ImportedAt $atIn -ImportedBy $byIn -RowCount 0 -CatalogOnly
        Write-Host ''
        Write-Host "Wrote catalog: $catalogPath"
        Write-Host "Using your pricing file (unchanged): $pricingPath"
    } else {
        Export-DemoCsvFiles -ImportMonth $importMonth -Csp $csp -LineEnding $LineEnding `
            -CatalogPath $catalogPath -PricingPath $pricingPath -ParentIdPlaceholder $Placeholder `
            -SourceFile $srcIn -ImportedAt $atIn -ImportedBy $byIn -RowCount 0
        Write-Host ''
        Write-Host "Wrote:`n  $catalogPath`n  $pricingPath"
    }
    Write-Host ''
    Write-Host 'NOTE: The Bulk JOB Id (often starts with 750) is only for downloading results.' -ForegroundColor Yellow
    Write-Host '      The RECORD Id for Catalog_Import__c (sf__Id, often starts with a0) goes in the pricing file.' -ForegroundColor Yellow
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
        if ($jobId -match '^[a-zA-Z0-9]{15,18}$') {
            if (-not $jobId.StartsWith('750')) {
                Write-Host '(Unusual: Job Ids often start with 750; continuing anyway.)' -ForegroundColor DarkYellow
            }
            break
        }
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
    & $replaceScript -NewId $sfId -CsvPath $pricingPath

    Write-Host ''
    $sfArgs2 = @(
        'data', 'import', 'bulk',
        '--sobject', 'Pricing_Item__c',
        '--file', $pricingPath,
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
    Invoke-InteractiveWizard -ProductionPricingCsv $ProductionPricingCsv
    exit 0
}

# --- non-interactive (original behavior) ---
$nl = Get-Newline -Ending $LineEnding
$catalogPath = Join-Path $ScriptRoot 'catalog_import_aws_2025-12.csv'
$pricingPath = Join-Path $ScriptRoot 'pricing_items_aws_2025-12.csv'
Export-DemoCsvFiles -ImportMonth '2025-12' -Csp 'aws' -LineEnding $LineEnding `
    -CatalogPath $catalogPath -PricingPath $pricingPath -ParentIdPlaceholder $Placeholder `
    -SourceFile '2025-12_aws_pricing.csv' -ImportedAt '2025-12-15T10:00:00.000Z' -ImportedBy 'bulk_test_import' -RowCount 0

Write-Host ("Wrote UTF-8 {0}: catalog_import_aws_2025-12.csv, pricing_items_aws_2025-12.csv" -f $LineEnding)
Write-Host ('Use: sf data import bulk ... --line-ending ' + $LineEnding)

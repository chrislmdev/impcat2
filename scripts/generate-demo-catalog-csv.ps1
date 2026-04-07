# Writes demo bulk-upload CSVs under demo-data/catalog-mock/
# Run from repo root:  powershell -File scripts/generate-demo-catalog-csv.ps1

$ErrorActionPreference = "Stop"
$RowCount = 520
$RepoRoot = Split-Path $PSScriptRoot -Parent
$OutDir = Join-Path $RepoRoot "demo-data\catalog-mock"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Join-CsvRow {
    param([string[]]$Fields)
    ($Fields | ForEach-Object {
        $s = "$_"
        if ($s -match '[",\r\n]') {
            '"' + ($s -replace '"', '""') + '"'
        } else {
            $s
        }
    }) -join ","
}

# --- January pricing ---
$janPricing = Join-Path $OutDir "2026-01_aws_pricing.csv"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add((Join-CsvRow @(
    "Catalog_Item_Number__c", "Title__c", "CSO_Short_Name__c", "Description__c",
    "List_Unit_Price__c", "Pricing_Unit__c", "JWCC_Unit_Price__c", "JWCC_Unit_Of_Issue__c", "Discount_Premium_Fee__c"
)))
for ($i = 1; $i -le $RowCount; $i++) {
    $sku = "DEMO-P-202601-{0:D5}" -f $i
    $listPrice = [math]::Round(9.99 + ($i * 0.07), 4)
    $jwcc = [math]::Round($listPrice * 0.88, 4)
    $unit = if ($i % 2 -eq 0) { "Each" } else { "GB-Mo" }
    $disc = if ($i % 5 -ne 0) { "Standard" } else { "" }
    $lines.Add((Join-CsvRow @(
        $sku,
        "Mock AWS catalog line $i - compute and storage blend",
        ("CSO-SVC-{0:D2}" -f (($i % 40) + 1)),
        "Demo description for pricing row $i; safe for POC uploads.",
        "$listPrice",
        $unit,
        "$jwcc",
        $unit,
        $disc
    )))
}
$lines | Set-Content -Path $janPricing -Encoding utf8
Write-Host "Wrote $janPricing ($($lines.Count) lines)"

# --- February pricing (unchanged + updated + new; many Jan rows removed) ---
$febPricing = Join-Path $OutDir "2026-02_aws_pricing.csv"
$unchangedEnd = 220
$updatedStart = 221
$updatedEnd = 320
$newCount = $RowCount - $unchangedEnd - ($updatedEnd - $updatedStart + 1)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add((Join-CsvRow @(
    "Catalog_Item_Number__c", "Title__c", "CSO_Short_Name__c", "Description__c",
    "List_Unit_Price__c", "Pricing_Unit__c", "JWCC_Unit_Price__c", "JWCC_Unit_Of_Issue__c", "Discount_Premium_Fee__c"
)))
for ($i = 1; $i -le $unchangedEnd; $i++) {
    $sku = "DEMO-P-202601-{0:D5}" -f $i
    $listPrice = [math]::Round(9.99 + ($i * 0.07), 4)
    $jwcc = [math]::Round($listPrice * 0.88, 4)
    $unit = if ($i % 2 -eq 0) { "Each" } else { "GB-Mo" }
    $disc = if ($i % 5 -ne 0) { "Standard" } else { "" }
    $lines.Add((Join-CsvRow @(
        $sku,
        "Mock AWS catalog line $i - compute and storage blend",
        ("CSO-SVC-{0:D2}" -f (($i % 40) + 1)),
        "Demo description for pricing row $i; safe for POC uploads.",
        "$listPrice",
        $unit,
        "$jwcc",
        $unit,
        $disc
    )))
}
for ($i = $updatedStart; $i -le $updatedEnd; $i++) {
    $sku = "DEMO-P-202601-{0:D5}" -f $i
    $listPrice = [math]::Round(9.99 + ($i * 0.07) + 2.5, 4)
    $jwcc = [math]::Round($listPrice * 0.88, 4)
    $unit = if ($i % 2 -eq 0) { "Each" } else { "GB-Mo" }
    $disc = if ($i % 5 -ne 0) { "Standard" } else { "" }
    $lines.Add((Join-CsvRow @(
        $sku,
        "Mock AWS catalog line $i - compute and storage blend",
        ("CSO-SVC-{0:D2}" -f (($i % 40) + 1)),
        "Demo description for pricing row $i; safe for POC uploads.",
        "$listPrice",
        $unit,
        "$jwcc",
        $unit,
        $disc
    )))
}
for ($j = 1; $j -le $newCount; $j++) {
    $sku = "DEMO-P-202602-NEW-{0:D5}" -f $j
    $listPrice = [math]::Round(19.5 + ($j * 0.05), 4)
    $jwcc = [math]::Round($listPrice * 0.9, 4)
    $lines.Add((Join-CsvRow @(
        $sku,
        "New February 2026 SKU $j",
        ("CSO-NEW-{0:D2}" -f (($j % 12) + 1)),
        "Net-new item for added-row demo.",
        "$listPrice",
        "Each",
        "$jwcc",
        "Each",
        ""
    )))
}
$lines | Set-Content -Path $febPricing -Encoding utf8
Write-Host "Wrote $febPricing ($($lines.Count) lines)"

# --- January exceptions ---
$janEx = Join-Path $OutDir "2026-01_aws_exceptions.csv"
$impacts = @("Low", "Medium", "High")
$statuses = @("Draft", "Open", "In Review", "Approved")
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add((Join-CsvRow @(
    "Exception_Unique_Id__c", "CSO_Short_Name__c", "Impact_Level__c", "Exception_Status__c",
    "Exception_PWS_Requirement__c", "Exception_Basis_For_Request__c", "Exception_Security__c"
)))
for ($i = 1; $i -le $RowCount; $i++) {
    $uid = "DEMO-X-202601-{0:D5}" -f $i
    $pws = if ($i % 3 -eq 0) { "PWS required" } else { "Not required" }
    $basis = if ($i % 2 -eq 0) { "Cost optimization" } else { "Architecture alignment" }
    $sec = if ($i % 4 -eq 0) { "FedRAMP Moderate" } else { "IL5" }
    $lines.Add((Join-CsvRow @(
        $uid,
        ("Workload-{0:D2}" -f (($i % 35) + 1)),
        $impacts[$i % 3],
        $statuses[$i % 4],
        $pws,
        $basis,
        $sec
    )))
}
$lines | Set-Content -Path $janEx -Encoding utf8
Write-Host "Wrote $janEx ($($lines.Count) lines)"

# --- February exceptions ---
$febEx = Join-Path $OutDir "2026-02_aws_exceptions.csv"
$unchangedEnd = 200
$updatedStart = 201
$updatedEnd = 290
$newCount = $RowCount - $unchangedEnd - ($updatedEnd - $updatedStart + 1)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add((Join-CsvRow @(
    "Exception_Unique_Id__c", "CSO_Short_Name__c", "Impact_Level__c", "Exception_Status__c",
    "Exception_PWS_Requirement__c", "Exception_Basis_For_Request__c", "Exception_Security__c"
)))
for ($i = 1; $i -le $unchangedEnd; $i++) {
    $uid = "DEMO-X-202601-{0:D5}" -f $i
    $pws = if ($i % 3 -eq 0) { "PWS required" } else { "Not required" }
    $basis = if ($i % 2 -eq 0) { "Cost optimization" } else { "Architecture alignment" }
    $sec = if ($i % 4 -eq 0) { "FedRAMP Moderate" } else { "IL5" }
    $lines.Add((Join-CsvRow @(
        $uid,
        ("Workload-{0:D2}" -f (($i % 35) + 1)),
        $impacts[$i % 3],
        $statuses[$i % 4],
        $pws,
        $basis,
        $sec
    )))
}
for ($i = $updatedStart; $i -le $updatedEnd; $i++) {
    $uid = "DEMO-X-202601-{0:D5}" -f $i
    $pws = if ($i % 3 -eq 0) { "PWS required" } else { "Not required" }
    $basis = if ($i % 2 -eq 0) { "Cost optimization" } else { "Architecture alignment" }
    $sec = if ($i % 4 -eq 0) { "FedRAMP Moderate" } else { "IL5" }
    $st = $statuses[($i % 4 + 1) % 4]
    $lines.Add((Join-CsvRow @(
        $uid,
        ("Workload-{0:D2}" -f (($i % 35) + 1)),
        $impacts[$i % 3],
        $st,
        $pws,
        $basis,
        $sec
    )))
}
for ($j = 1; $j -le $newCount; $j++) {
    $uid = "DEMO-X-202602-NEW-{0:D5}" -f $j
    $lines.Add((Join-CsvRow @(
        $uid,
        ("NewEx-{0:D2}" -f (($j % 20) + 1)),
        "High",
        "Open",
        "PWS required",
        "New capability onboarding",
        "IL5"
    )))
}
$lines | Set-Content -Path $febEx -Encoding utf8
Write-Host "Wrote $febEx ($($lines.Count) lines)"

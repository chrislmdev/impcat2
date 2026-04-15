# Re-writes demo Bulk API CSVs as UTF-8 (no BOM). Default: CRLF line endings (matches Windows
# editors and `sf data import bulk --line-ending CRLF`). Avoids ClientInputError when the file
# is CRLF but the CLI was given `--line-ending LF`.
#
# IMPORTANT: Catalog_Import__c on pricing rows must be the record Id from the *parent* import
# success file (column sf__Id in *-success-records.csv), NOT the Bulk API Job Id (750...).
param(
    [ValidateSet('CRLF', 'LF')]
    [string]$LineEnding = 'CRLF'
)

$enc = New-Object System.Text.UTF8Encoding $false
$nl = if ($LineEnding -eq 'CRLF') { "`r`n" } else { [char]10 }

$catalogPath = Join-Path $PSScriptRoot 'catalog_import_aws_2025-12.csv'
$catalogLines = @(
    'Import_Month__c,CSP__c,Schema__c,Status__c,Source_File__c,Imported_At__c,Imported_By__c,Row_Count__c'
    '2025-12,aws,pricing,processing,2025-12_aws_pricing.csv,2025-12-15T10:00:00.000Z,bulk_test_import,0'
)
[System.IO.File]::WriteAllText($catalogPath, (($catalogLines -join $nl) + $nl), $enc)

# Set after parent bulk import: sf data bulk results --job-id <parent-job-id>
$catalogImportRecordId = 'PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV'  # sf__Id from success CSV (a0...), not Job Id (750...)

$pricingPath = Join-Path $PSScriptRoot 'pricing_items_aws_2025-12.csv'
$pricingLines = @(
    'Catalog_Import__c,CSP__c,Catalog_Item_Number__c,Title__c,CSO_Short_Name__c,Description__c,List_Unit_Price__c,Pricing_Unit__c,JWCC_Unit_Price__c,JWCC_Unit_Of_Issue__c,Discount_Premium_Fee__c,Focus_Category__c,Service_Category__c'
    ($catalogImportRecordId + ',aws,AWS-DEMO-EC2-T3MICRO,t3.micro Linux us-east-1 mock,CSO-COMPUTE-EC2,General purpose burstable; test row only,0.0104,Hour,0.0092,Hour,-12%,Compute,Compute')
    ($catalogImportRecordId + ',aws,AWS-DEMO-S3-STD,S3 Standard storage mock,CSO-STORAGE-S3,Object storage per GB-month; test row,0.023,GB-Mo,0.0202,GB-Mo,,Storage,Storage')
    ($catalogImportRecordId + ',aws,AWS-DEMO-RDS-MYSQL,db.t3.micro MySQL mock,CSO-DATABASE-RDS,Managed relational DB; test row,0.017,Hour,0.015,Hour,-10%,Database,Database')
    ($catalogImportRecordId + ',aws,AWS-DEMO-VPC-ENDPOINT,Interface VPC endpoint mock,CSO-NETWORK-VPC,Private connectivity; test row,0.01,Hour,0.0088,Hour,,Networking,Networking')
)
[System.IO.File]::WriteAllText($pricingPath, (($pricingLines -join $nl) + $nl), $enc)

Write-Host ("Wrote UTF-8 {0}: catalog_import_aws_2025-12.csv, pricing_items_aws_2025-12.csv" -f $LineEnding)
Write-Host ('Use: sf data import bulk ... --line-ending ' + $LineEnding)

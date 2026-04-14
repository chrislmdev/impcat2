// Multi-CSP demo seed for CloudPrism POC (all four CSPs, 2026-01 vs 2026-02).
//
// Run: sf apex run --file scripts/sample-data.apex
// Requires CloudPrism_POC (or equivalent FLS) on the running user.
//
// Re-running inserts DUPLICATE imports for the same month/CSP/schema unless you delete
// existing demo Catalog_Import__c rows (and children) first—use a clean org or remove
// prior demo trees before a second load.

List<String> csps = new List<String>{ 'aws', 'azure', 'gcp', 'oracle' };
Map<String, String> monthToFilePart = new Map<String, String>{
    '2026-01' => 'jan2026',
    '2026-02' => 'feb2026'
};
List<String> months = new List<String>{ '2026-01', '2026-02' };
Map<String, String> cspToSkuTag = new Map<String, String>{
    'aws' => 'AWS',
    'azure' => 'AZURE',
    'gcp' => 'GCP',
    'oracle' => 'ORA'
};

List<Catalog_Import__c> imports = new List<Catalog_Import__c>();
for (String csp : csps) {
    for (String schema : new List<String>{ 'pricing', 'exceptions' }) {
        for (String mo : months) {
            Integer moNum = mo == '2026-01' ? 1 : 2;
            Integer day = schema == 'pricing' ? 15 : 10;
            imports.add(
                new Catalog_Import__c(
                    Import_Month__c = mo,
                    CSP__c = csp,
                    Schema__c = schema,
                    Status__c = 'done',
                    Source_File__c = csp + '_' + schema + '_' + monthToFilePart.get(mo) + '.csv',
                    Imported_At__c = Datetime.newInstanceGmt(2026, moNum, day, 12, 0, 0),
                    Imported_By__c = 'sample-data.apex',
                    Row_Count__c = 2
                )
            );
        }
    }
}
insert imports;

Map<String, Id> importIdByKey = new Map<String, Id>();
for (Catalog_Import__c ci : imports) {
    importIdByKey.put(ci.CSP__c + '|' + ci.Schema__c + '|' + ci.Import_Month__c, ci.Id);
}

List<Pricing_Item__c> pricingRows = new List<Pricing_Item__c>();
for (String csp : csps) {
    String tag = cspToSkuTag.get(csp);
    Id janP = importIdByKey.get(csp + '|pricing|2026-01');
    Id febP = importIdByKey.get(csp + '|pricing|2026-02');

    pricingRows.add(
        new Pricing_Item__c(
            Catalog_Import__c = janP,
            CSP__c = csp,
            Catalog_Item_Number__c = 'DEMO-' + tag + '-REMOVED',
            Title__c = tag + ' — removed after January',
            CSO_Short_Name__c = 'Demo',
            List_Unit_Price__c = 1.0000,
            JWCC_Unit_Price__c = 0.9000,
            Pricing_Unit__c = 'Hour',
            JWCC_Unit_Of_Issue__c = 'Hour',
            Focus_Category__c = 'Compute',
            Discount_Premium_Fee__c = '-10%'
        )
    );
    pricingRows.add(
        new Pricing_Item__c(
            Catalog_Import__c = janP,
            CSP__c = csp,
            Catalog_Item_Number__c = 'DEMO-' + tag + '-UPDATED',
            Title__c = tag + ' — price bump in February',
            CSO_Short_Name__c = 'Demo',
            List_Unit_Price__c = 10.0000,
            JWCC_Unit_Price__c = 9.0000,
            Pricing_Unit__c = 'Hour',
            JWCC_Unit_Of_Issue__c = 'Hour',
            Focus_Category__c = 'Compute',
            Discount_Premium_Fee__c = '-10%'
        )
    );
    pricingRows.add(
        new Pricing_Item__c(
            Catalog_Import__c = febP,
            CSP__c = csp,
            Catalog_Item_Number__c = 'DEMO-' + tag + '-UPDATED',
            Title__c = tag + ' — price bump in February',
            CSO_Short_Name__c = 'Demo',
            List_Unit_Price__c = 11.0000,
            JWCC_Unit_Price__c = 9.5000,
            Pricing_Unit__c = 'Hour',
            JWCC_Unit_Of_Issue__c = 'Hour',
            Focus_Category__c = 'Compute',
            Discount_Premium_Fee__c = '-10%'
        )
    );
    pricingRows.add(
        new Pricing_Item__c(
            Catalog_Import__c = febP,
            CSP__c = csp,
            Catalog_Item_Number__c = 'DEMO-' + tag + '-NEW',
            Title__c = tag + ' — new SKU in February',
            CSO_Short_Name__c = 'Demo',
            List_Unit_Price__c = 5.0000,
            JWCC_Unit_Price__c = 4.5000,
            Pricing_Unit__c = 'GB',
            JWCC_Unit_Of_Issue__c = 'GB',
            Focus_Category__c = 'Storage',
            Discount_Premium_Fee__c = '0%'
        )
    );
}
insert pricingRows;

List<Exception_Item__c> exceptionRows = new List<Exception_Item__c>();
for (String csp : csps) {
    String tag = cspToSkuTag.get(csp);
    Id janE = importIdByKey.get(csp + '|exceptions|2026-01');
    Id febE = importIdByKey.get(csp + '|exceptions|2026-02');

    exceptionRows.add(
        new Exception_Item__c(
            Catalog_Import__c = janE,
            CSP__c = csp,
            Exception_Unique_Id__c = 'DEMO-' + tag + '-EX-001',
            CSO_Short_Name__c = 'Svc-' + tag,
            Impact_Level__c = 'IL4',
            Exception_Status__c = 'Pending',
            Exception_PWS_Requirement__c = tag + ' sample PWS',
            Exception_Basis_For_Request__c = 'Sample basis',
            Exception_Requested_Duration__c = '30 days',
            Exception_Suggested_Plan__c = 'Initial mitigation'
        )
    );
    exceptionRows.add(
        new Exception_Item__c(
            Catalog_Import__c = janE,
            CSP__c = csp,
            Exception_Unique_Id__c = 'DEMO-' + tag + '-EX-002',
            CSO_Short_Name__c = 'Legacy-' + tag,
            Impact_Level__c = 'IL2',
            Exception_Status__c = 'Pending',
            Exception_PWS_Requirement__c = 'Removed in Feb snapshot',
            Exception_Basis_For_Request__c = 'N/A',
            Exception_Requested_Duration__c = '60 days',
            Exception_Suggested_Plan__c = 'Retire workload'
        )
    );
    exceptionRows.add(
        new Exception_Item__c(
            Catalog_Import__c = febE,
            CSP__c = csp,
            Exception_Unique_Id__c = 'DEMO-' + tag + '-EX-001',
            CSO_Short_Name__c = 'Svc-' + tag,
            Impact_Level__c = 'IL4',
            Exception_Status__c = 'Approved',
            Exception_PWS_Requirement__c = tag + ' sample PWS',
            Exception_Basis_For_Request__c = 'Sample basis',
            Exception_Requested_Duration__c = '90 days',
            Exception_Suggested_Plan__c = 'Extended monitoring'
        )
    );
    exceptionRows.add(
        new Exception_Item__c(
            Catalog_Import__c = febE,
            CSP__c = csp,
            Exception_Unique_Id__c = 'DEMO-' + tag + '-EX-003',
            CSO_Short_Name__c = 'New-' + tag,
            Impact_Level__c = 'IL5',
            Exception_Status__c = 'Pending',
            Exception_PWS_Requirement__c = 'New in Feb',
            Exception_Basis_For_Request__c = 'N/A',
            Exception_Requested_Duration__c = '180 days',
            Exception_Suggested_Plan__c = 'Pilot then scale'
        )
    );
}
insert exceptionRows;

System.debug(
    'CloudPrism sample data: 16 Catalog_Import__c, ' +
        pricingRows.size() +
        ' Pricing_Item__c, ' +
        exceptionRows.size() +
        ' Exception_Item__c (4 CSPs x Jan/Feb pricing+exceptions)'
);

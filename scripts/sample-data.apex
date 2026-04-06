// Run after deploying metadata (assign CloudPrism_POC permission set first):
//   sf apex run --file scripts/sample-data.apex --target-org <yourOrgAlias>
//
// Creates two pricing import months (2026-01 / 2026-02) and two exception months with
// intentional adds/removes/updates for Catalog Changes smoke testing.

List<Catalog_Import__c> imports = new List<Catalog_Import__c>{
    new Catalog_Import__c(
        Import_Month__c = '2026-01',
        CSP__c = 'aws',
        Schema__c = 'pricing',
        Status__c = 'done',
        Source_File__c = 'aws_pricing_jan2026.csv',
        Imported_At__c = Datetime.newInstanceGmt(2026, 1, 15, 12, 0, 0),
        Imported_By__c = 'sample-data.apex',
        Row_Count__c = 3
    ),
    new Catalog_Import__c(
        Import_Month__c = '2026-02',
        CSP__c = 'aws',
        Schema__c = 'pricing',
        Status__c = 'done',
        Source_File__c = 'aws_pricing_feb2026.csv',
        Imported_At__c = Datetime.newInstanceGmt(2026, 2, 15, 12, 0, 0),
        Imported_By__c = 'sample-data.apex',
        Row_Count__c = 3
    ),
    new Catalog_Import__c(
        Import_Month__c = '2026-01',
        CSP__c = 'aws',
        Schema__c = 'exceptions',
        Status__c = 'done',
        Source_File__c = 'aws_exceptions_jan2026.csv',
        Imported_At__c = Datetime.newInstanceGmt(2026, 1, 10, 12, 0, 0),
        Imported_By__c = 'sample-data.apex',
        Row_Count__c = 2
    ),
    new Catalog_Import__c(
        Import_Month__c = '2026-02',
        CSP__c = 'aws',
        Schema__c = 'exceptions',
        Status__c = 'done',
        Source_File__c = 'aws_exceptions_feb2026.csv',
        Imported_At__c = Datetime.newInstanceGmt(2026, 2, 10, 12, 0, 0),
        Imported_By__c = 'sample-data.apex',
        Row_Count__c = 2
    )
};
insert imports;

Id janP = imports[0].Id;
Id febP = imports[1].Id;
Id janE = imports[2].Id;
Id febE = imports[3].Id;

insert new List<Pricing_Item__c>{
    new Pricing_Item__c(
        Catalog_Import__c = janP,
        CSP__c = 'aws',
        Catalog_Item_Number__c = 'DEMO-SKU-REMOVED',
        Title__c = 'Removed after January',
        CSO_Short_Name__c = 'Demo',
        List_Unit_Price__c = 1.0000,
        JWCC_Unit_Price__c = 0.9000,
        Pricing_Unit__c = 'Hour',
        JWCC_Unit_Of_Issue__c = 'Hour',
        Focus_Category__c = 'Compute',
        Discount_Premium_Fee__c = '-10%'
    ),
    new Pricing_Item__c(
        Catalog_Import__c = janP,
        CSP__c = 'aws',
        Catalog_Item_Number__c = 'DEMO-SKU-UPDATED',
        Title__c = 'Price changes in February',
        CSO_Short_Name__c = 'Demo',
        List_Unit_Price__c = 10.0000,
        JWCC_Unit_Price__c = 9.0000,
        Pricing_Unit__c = 'Hour',
        JWCC_Unit_Of_Issue__c = 'Hour',
        Focus_Category__c = 'Compute',
        Discount_Premium_Fee__c = '-10%'
    ),
    new Pricing_Item__c(
        Catalog_Import__c = febP,
        CSP__c = 'aws',
        Catalog_Item_Number__c = 'DEMO-SKU-UPDATED',
        Title__c = 'Price changes in February',
        CSO_Short_Name__c = 'Demo',
        List_Unit_Price__c = 11.0000,
        JWCC_Unit_Price__c = 9.5000,
        Pricing_Unit__c = 'Hour',
        JWCC_Unit_Of_Issue__c = 'Hour',
        Focus_Category__c = 'Compute',
        Discount_Premium_Fee__c = '-10%'
    ),
    new Pricing_Item__c(
        Catalog_Import__c = febP,
        CSP__c = 'aws',
        Catalog_Item_Number__c = 'DEMO-SKU-NEW',
        Title__c = 'New SKU in February',
        CSO_Short_Name__c = 'Demo',
        List_Unit_Price__c = 5.0000,
        JWCC_Unit_Price__c = 4.5000,
        Pricing_Unit__c = 'GB',
        JWCC_Unit_Of_Issue__c = 'GB',
        Focus_Category__c = 'Storage',
        Discount_Premium_Fee__c = '0%'
    )
};

insert new List<Exception_Item__c>{
    new Exception_Item__c(
        Catalog_Import__c = janE,
        CSP__c = 'aws',
        Exception_Unique_Id__c = 'DEMO-EX-001',
        CSO_Short_Name__c = 'Lambda',
        Impact_Level__c = 'IL4',
        Exception_Status__c = 'Pending',
        Exception_PWS_Requirement__c = 'Sample PWS text',
        Exception_Basis_For_Request__c = 'Sample basis'
    ),
    new Exception_Item__c(
        Catalog_Import__c = janE,
        CSP__c = 'aws',
        Exception_Unique_Id__c = 'DEMO-EX-002',
        CSO_Short_Name__c = 'S3',
        Impact_Level__c = 'IL2',
        Exception_Status__c = 'Pending',
        Exception_PWS_Requirement__c = 'Removed in Feb snapshot',
        Exception_Basis_For_Request__c = 'N/A'
    ),
    new Exception_Item__c(
        Catalog_Import__c = febE,
        CSP__c = 'aws',
        Exception_Unique_Id__c = 'DEMO-EX-001',
        CSO_Short_Name__c = 'Lambda',
        Impact_Level__c = 'IL4',
        Exception_Status__c = 'Approved',
        Exception_PWS_Requirement__c = 'Sample PWS text',
        Exception_Basis_For_Request__c = 'Sample basis'
    ),
    new Exception_Item__c(
        Catalog_Import__c = febE,
        CSP__c = 'aws',
        Exception_Unique_Id__c = 'DEMO-EX-003',
        CSO_Short_Name__c = 'RDS',
        Impact_Level__c = 'IL5',
        Exception_Status__c = 'Pending',
        Exception_PWS_Requirement__c = 'New in Feb',
        Exception_Basis_For_Request__c = 'N/A'
    )
};

System.debug('CloudPrism sample data inserted: pricing + exceptions for 2026-01 and 2026-02');

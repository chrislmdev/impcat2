@IsTest
private class CloudPrismCatalogTest {
    @TestSetup
    static void setup() {
        Catalog_Import__c janP = new Catalog_Import__c(
            Import_Month__c = '2026-01',
            CSP__c = 'aws',
            Schema__c = 'pricing',
            Status__c = 'done',
            Imported_At__c = Datetime.newInstance(2026, 1, 15, 12, 0, 0)
        );
        Catalog_Import__c febP = new Catalog_Import__c(
            Import_Month__c = '2026-02',
            CSP__c = 'aws',
            Schema__c = 'pricing',
            Status__c = 'done',
            Imported_At__c = Datetime.newInstance(2026, 2, 15, 12, 0, 0)
        );
        Catalog_Import__c janE = new Catalog_Import__c(
            Import_Month__c = '2026-01',
            CSP__c = 'aws',
            Schema__c = 'exceptions',
            Status__c = 'done',
            Imported_At__c = Datetime.newInstance(2026, 1, 10, 12, 0, 0)
        );
        Catalog_Import__c febE = new Catalog_Import__c(
            Import_Month__c = '2026-02',
            CSP__c = 'aws',
            Schema__c = 'exceptions',
            Status__c = 'done',
            Imported_At__c = Datetime.newInstance(2026, 2, 10, 12, 0, 0)
        );
        Catalog_Import__c janPar = new Catalog_Import__c(
            Import_Month__c = '2026-01',
            CSP__c = 'aws',
            Schema__c = 'parent',
            Status__c = 'done',
            Imported_At__c = Datetime.newInstance(2026, 1, 12, 12, 0, 0)
        );
        insert new List<Catalog_Import__c>{ janP, febP, janE, febE, janPar };

        insert new List<Pricing_Item__c>{
            new Pricing_Item__c(
                Catalog_Import__c = janP.Id,
                CSP__c = 'aws',
                Catalog_Item_Number__c = 'SKU-OLD',
                Title__c = 'Old only',
                List_Unit_Price__c = 1,
                JWCC_Unit_Price__c = 0.9,
                Pricing_Unit__c = 'Hour',
                JWCC_Unit_Of_Issue__c = 'Hour'
            ),
            new Pricing_Item__c(
                Catalog_Import__c = janP.Id,
                CSP__c = 'aws',
                Catalog_Item_Number__c = 'SKU-BOTH',
                Title__c = 'Both months',
                List_Unit_Price__c = 10,
                JWCC_Unit_Price__c = 9,
                Pricing_Unit__c = 'Hour',
                JWCC_Unit_Of_Issue__c = 'Hour',
                Focus_Category__c = 'Compute'
            ),
            new Pricing_Item__c(
                Catalog_Import__c = febP.Id,
                CSP__c = 'aws',
                Catalog_Item_Number__c = 'SKU-BOTH',
                Title__c = 'Both months',
                List_Unit_Price__c = 11,
                JWCC_Unit_Price__c = 9.5,
                Pricing_Unit__c = 'Hour',
                JWCC_Unit_Of_Issue__c = 'Hour'
            ),
            new Pricing_Item__c(
                Catalog_Import__c = febP.Id,
                CSP__c = 'aws',
                Catalog_Item_Number__c = 'SKU-NEW',
                Title__c = 'New in Feb',
                List_Unit_Price__c = 5,
                JWCC_Unit_Price__c = 4.5,
                Pricing_Unit__c = 'GB',
                JWCC_Unit_Of_Issue__c = 'GB'
            )
        };

        insert new List<Exception_Item__c>{
            new Exception_Item__c(
                Catalog_Import__c = janE.Id,
                CSP__c = 'aws',
                Exception_Unique_Id__c = 'EX-1',
                CSO_Short_Name__c = 'Lambda',
                Impact_Level__c = 'IL4',
                Exception_Status__c = 'Pending',
                Exception_Requested_Duration__c = '30 days',
                Exception_Suggested_Plan__c = 'Plan A'
            ),
            new Exception_Item__c(
                Catalog_Import__c = febE.Id,
                CSP__c = 'aws',
                Exception_Unique_Id__c = 'EX-1',
                CSO_Short_Name__c = 'Lambda',
                Impact_Level__c = 'IL4',
                Exception_Status__c = 'Approved',
                Exception_Requested_Duration__c = '90 days',
                Exception_Suggested_Plan__c = 'Plan B'
            ),
            new Exception_Item__c(
                Catalog_Import__c = febE.Id,
                CSP__c = 'aws',
                Exception_Unique_Id__c = 'EX-2',
                CSO_Short_Name__c = 'S3',
                Impact_Level__c = 'IL2',
                Exception_Status__c = 'Pending'
            )
        };

        insert new List<Parent_Item__c>{
            new Parent_Item__c(
                Catalog_Import__c = janPar.Id,
                CSP__c = 'aws',
                Title__c = 'Parent offering Alpha',
                CSO_Short_Name__c = 'SvcAlpha',
                Category__c = 'Compute',
                Impact_Level__c = 'IL4'
            )
        };
    }

    @IsTest
    static void pricingChanges_detectsAddedRemovedUpdated() {
        Test.startTest();
        List<PricingChangeService.PricingChangeRow> rows = PricingChangeService.compare(
            '2026-01',
            '2026-02',
            null,
            null
        );
        Test.stopTest();

        Map<String, String> typesBySku = new Map<String, String>();
        for (PricingChangeService.PricingChangeRow r : rows) {
            typesBySku.put(r.catalogitemnumber, r.change_type);
        }
        System.assertEquals('removed', typesBySku.get('SKU-OLD'));
        System.assertEquals('added', typesBySku.get('SKU-NEW'));
        System.assertEquals('updated', typesBySku.get('SKU-BOTH'));
    }

    @IsTest
    static void exceptionChanges_detectsAddedUpdated() {
        Test.startTest();
        List<ExceptionChangeService.ExceptionChangeRow> rows = ExceptionChangeService.compare(
            '2026-01',
            '2026-02',
            null,
            null
        );
        Test.stopTest();

        Map<String, String> typesByEx = new Map<String, String>();
        ExceptionChangeService.ExceptionChangeRow ex1Row;
        for (ExceptionChangeService.ExceptionChangeRow r : rows) {
            typesByEx.put(r.exceptionuniqueid, r.change_type);
            if (r.exceptionuniqueid == 'EX-1') {
                ex1Row = r;
            }
        }
        System.assertEquals('updated', typesByEx.get('EX-1'));
        System.assertEquals('added', typesByEx.get('EX-2'));
        System.assertNotEquals(null, ex1Row);
        System.assertEquals('30 days', ex1Row.requestedduration_prev);
        System.assertEquals('90 days', ex1Row.requestedduration_curr);
        System.assertEquals('Plan A', ex1Row.suggestedplan_prev);
        System.assertEquals('Plan B', ex1Row.suggestedplan_curr);
    }

    @IsTest
    static void controllerReturnsPricingRows() {
        List<Pricing_Item__c> pr = CloudPrismCatalogController.getPricingItems('aws', 'SKU-BOTH', 50);
        System.assert(!pr.isEmpty(), 'Expected pricing rows');
    }

    @IsTest
    static void controllerSearchIncludesFocusCategory() {
        List<Pricing_Item__c> pr = CloudPrismCatalogController.getPricingItems('aws', 'Compute', 50);
        System.assert(!pr.isEmpty(), 'Search should match Focus_Category__c');
    }

    @IsTest
    static void controllerReturnsMonths() {
        List<String> m = CloudPrismCatalogController.getDistinctImportMonths('pricing');
        System.assert(m.contains('2026-01'));
        System.assert(m.contains('2026-02'));
    }

    @IsTest
    static void controllerReturnsParentRows() {
        List<Parent_Item__c> pr = CloudPrismCatalogController.getParentItems('aws', 'Alpha', 50);
        System.assertEquals(1, pr.size());
        System.assertEquals('Parent offering Alpha', pr[0].Title__c);
    }

    @IsTest
    static void controllerReturnsParentImportMonths() {
        List<String> m = CloudPrismCatalogController.getDistinctImportMonths('parent');
        System.assert(m.contains('2026-01'));
    }
}

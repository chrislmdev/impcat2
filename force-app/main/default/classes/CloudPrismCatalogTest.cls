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
        insert new List<Catalog_Import__c>{ janP, febP, janE, febE };

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
                Exception_Status__c = 'Pending'
            ),
            new Exception_Item__c(
                Catalog_Import__c = febE.Id,
                CSP__c = 'aws',
                Exception_Unique_Id__c = 'EX-1',
                CSO_Short_Name__c = 'Lambda',
                Impact_Level__c = 'IL4',
                Exception_Status__c = 'Approved'
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
        for (ExceptionChangeService.ExceptionChangeRow r : rows) {
            typesByEx.put(r.exceptionuniqueid, r.change_type);
        }
        System.assertEquals('updated', typesByEx.get('EX-1'));
        System.assertEquals('added', typesByEx.get('EX-2'));
    }

    @IsTest
    static void controllerReturnsPricingRows() {
        List<Pricing_Item__c> pr = CloudPrismCatalogController.getPricingItems('aws', 'SKU-BOTH', null, null, 50);
        System.assert(!pr.isEmpty(), 'Expected pricing rows');
    }

    @IsTest
    static void controllerSearchIncludesFocusCategory() {
        List<Pricing_Item__c> pr = CloudPrismCatalogController.getPricingItems('aws', 'Compute', null, null, 50);
        System.assert(!pr.isEmpty(), 'Search should match Focus_Category__c');
    }

    @IsTest
    static void controllerPricingFilterByImportMonth() {
        List<Pricing_Item__c> pr = CloudPrismCatalogController.getPricingItems('aws', null, '2026-01', null, 100);
        System.assertEquals(2, pr.size());
        for (Pricing_Item__c p : pr) {
            System.assertEquals('2026-01', p.Catalog_Import__r.Import_Month__c);
        }
    }

    @IsTest
    static void controllerPricingFilterByFocusCategory() {
        List<Pricing_Item__c> pr = CloudPrismCatalogController.getPricingItems('aws', null, null, 'Compute', 100);
        System.assertEquals(1, pr.size());
        System.assertEquals('Compute', pr[0].Focus_Category__c);
    }

    @IsTest
    static void controllerExceptionFilterByMonthAndStatus() {
        List<Exception_Item__c> ex = CloudPrismCatalogController.getExceptionItems(
            'aws',
            null,
            '2026-01',
            'Pending',
            100
        );
        System.assertEquals(1, ex.size());
        System.assertEquals('EX-1', ex[0].Exception_Unique_Id__c);
    }

    @IsTest
    static void controllerReturnsDistinctFocusCategories() {
        List<String> cats = CloudPrismCatalogController.getDistinctFocusCategories();
        System.assert(cats.contains('Compute'));
    }

    @IsTest
    static void controllerReturnsDistinctExceptionStatuses() {
        List<String> sts = CloudPrismCatalogController.getDistinctExceptionStatuses();
        System.assert(sts.contains('Pending'));
        System.assert(sts.contains('Approved'));
    }

    @IsTest
    static void controllerReturnsMonths() {
        List<String> m = CloudPrismCatalogController.getDistinctImportMonths('pricing');
        System.assert(m.contains('2026-01'));
        System.assert(m.contains('2026-02'));
    }

    @IsTest
    static void controllerReturnsStaticAssetUrlMap() {
        Map<String, String> u = CloudPrismCatalogController.getCloudPrismStaticAssetUrls();
        System.assertNotEquals(null, u);
        System.assert(u.containsKey('theme'));
        System.assert(u.containsKey('jspdfUmd'));
        System.assert(u.containsKey('jspdfAutotable'));
        System.assert(u.containsKey('exportLib'));
        System.assert(String.isNotBlank(u.get('theme')));
    }
}

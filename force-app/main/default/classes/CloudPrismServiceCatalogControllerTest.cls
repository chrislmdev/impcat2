@IsTest
private class CloudPrismServiceCatalogControllerTest {
    @IsTest
    static void getServiceCatalogRows_usesMockWhenEmpty() {
        List<CloudPrismServiceCatalogController.ServiceCatalogRow> rows = CloudPrismServiceCatalogController.getServiceCatalogRows();
        System.assert(!rows.isEmpty(), 'Mock rows when object empty');
        System.assertEquals('aws', rows[0].csp);
    }

    @IsTest
    static void getServiceCatalogRows_usesDatabaseWhenPresent() {
        insert new Service_Catalog_Entry__c(
            CSP__c = 'aws',
            Service_Name__c = 'Test Service',
            Focus_Category__c = 'Compute',
            Comparison_Subcategory__c = 'VMs',
            Description__c = 'Desc',
            Impact_Level__c = 'IL2',
            Popularity_Score__c = 100
        );
        List<CloudPrismServiceCatalogController.ServiceCatalogRow> rows = CloudPrismServiceCatalogController.getServiceCatalogRows();
        System.assertEquals(1, rows.size());
        System.assertEquals('Test Service', rows[0].serviceName);
        System.assertEquals(100, rows[0].popularityScore);
    }

    @IsTest
    static void buildMockRows_isStable() {
        List<CloudPrismServiceCatalogController.ServiceCatalogRow> m = CloudPrismServiceCatalogController.buildMockRows();
        System.assert(m.size() > 5);
    }
}

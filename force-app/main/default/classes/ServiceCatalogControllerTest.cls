@IsTest
private class ServiceCatalogControllerTest {
    /**
     * Mock catalog rows for tests (FinOps-style categories, four CSPs, pipe-delimited impact levels).
     */
    @TestVisible
    private static final String MOCK_SERVICE_CATALOG_JSON =
        '[' +
        '{"csp":"AWS","service":"Amazon EC2 c6i.large","category":"Compute","subcategory":"Virtual Machines","description":"On-demand Linux compute","impactLevel":"COMM|IL2|IL4"},' +
        '{"csp":"Azure","service":"Virtual Machines D4s v5","category":"Compute","subcategory":"Virtual Machines","description":"General purpose VM","impactLevel":"COMM|IL4|IL5"},' +
        '{"csp":"GCP","service":"Compute Engine n2-standard-4","category":"Compute","subcategory":"Virtual Machines","description":"N2 family VM","impactLevel":"IL4|IL5|IL6"},' +
        '{"csp":"Oracle","service":"OCI VM.Standard.E4.Flex","category":"Compute","subcategory":"Virtual Machines","description":"Flexible OCPU VM","impactLevel":"COMM|TS"},' +
        '{"csp":"AWS","service":"Amazon S3 Standard","category":"Storage","subcategory":"Object Storage","description":"Regional object storage","impactLevel":"IL2|IL4"},' +
        '{"csp":"Azure","service":"Blob Storage Hot","category":"Storage","subcategory":"Object Storage","description":"LRS blob tier","impactLevel":"COMM|IL4"},' +
        '{"csp":"GCP","service":"Cloud Storage Standard","category":"Storage","subcategory":"Object Storage","description":"Multi-region capable","impactLevel":"IL4|IL5"},' +
        '{"csp":"Oracle","service":"Object Storage Standard","category":"Storage","subcategory":"Object Storage","description":"OCI object store","impactLevel":"IL5|IL6"},' +
        '{"csp":"AWS","service":"AWS Lambda","category":"Cloud Optimization","subcategory":"Serverless","description":"Per-invocation pricing","impactLevel":"COMM|IL2|IL4"},' +
        '{"csp":"Azure","service":"Azure Functions Consumption","category":"Cloud Optimization","subcategory":"Serverless","description":"Consumption plan","impactLevel":"IL4|TS"},' +
        '{"csp":"GCP","service":"Cloud Functions Gen2","category":"Cloud Optimization","subcategory":"Serverless","description":"Event-driven compute","impactLevel":"IL4|IL5"},' +
        '{"csp":"Oracle","service":"Functions","category":"Cloud Optimization","subcategory":"Serverless","description":"OCI functions","impactLevel":"COMM|IL6"}' +
        ']';

    @IsTest
    static void getCatalogRows_returnsInsertedData() {
        insertRowsFromMockJson();

        Test.startTest();
        List<Service_Catalog__c> rows = ServiceCatalogController.getCatalogRows();
        Test.stopTest();

        System.assertEquals(12, rows.size(), 'Expected one row per mock record');
        Boolean sawAws = false;
        for (Service_Catalog__c r : rows) {
            System.assertNotEquals(null, r.Id);
            if (r.CSP__c == 'AWS' && r.Service__c != null && r.Service__c.contains('EC2')) {
                sawAws = true;
                System.assert(r.Impact_Level__c != null && r.Impact_Level__c.contains('IL4'));
            }
        }
        System.assert(sawAws, 'Expected at least one AWS compute row');
    }

    private static void insertRowsFromMockJson() {
        List<Object> raw = (List<Object>) JSON.deserializeUntyped(MOCK_SERVICE_CATALOG_JSON);
        List<Service_Catalog__c> toInsert = new List<Service_Catalog__c>();
        for (Object o : raw) {
            Map<String, Object> m = (Map<String, Object>) o;
            Service_Catalog__c r = new Service_Catalog__c();
            r.CSP__c = (String) m.get('csp');
            r.Service__c = (String) m.get('service');
            r.Category__c = (String) m.get('category');
            r.Subcategory__c = (String) m.get('subcategory');
            r.Description__c = (String) m.get('description');
            r.Impact_Level__c = (String) m.get('impactLevel');
            toInsert.add(r);
        }
        insert toInsert;
    }
}

@IsTest
private class CloudPrismServiceCatalogPageCtrlTest {
    @IsTest
    static void getCatalogJsonRemote_returns_json_array() {
        Test.startTest();
        String json = CloudPrismServiceCatalogPageCtrl.getCatalogJsonRemote();
        Test.stopTest();
        System.assertNotEquals(null, json);
        System.assert(json.startsWith('['));
    }
}

@IsTest
private class CloudPrismServiceCatalogPageCtrlTest {
    @IsTest
    static void pageController_serializesCatalog() {
        Test.startTest();
        CloudPrismServiceCatalogPageCtrl c = new CloudPrismServiceCatalogPageCtrl();
        Test.stopTest();
        System.assertNotEquals(null, c.catalogJsonB64);
        String raw = EncodingUtil.base64Decode(c.catalogJsonB64).toString();
        System.assert(raw.startsWith('['));
    }
}

/**
 * Visualforce host for the RosettaStone-style HTML service catalog; bootstraps JSON via base64 to avoid script injection issues.
 */
public with sharing class CloudPrismServiceCatalogPageCtrl {
    public String catalogJsonB64 { get; private set; }

    public CloudPrismServiceCatalogPageCtrl() {
        List<Map<String, Object>> rows = CloudPrismServiceCatalogController.getRosettaParentRows();
        catalogJsonB64 = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(rows)));
    }
}

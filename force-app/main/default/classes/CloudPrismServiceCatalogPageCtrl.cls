/**
 * Visualforce host for the RosettaStone-style HTML service catalog.
 * Catalog JSON is loaded via @RemoteAction so it works reliably inside Lightning iframes (no inline merge payload).
 */
public with sharing class CloudPrismServiceCatalogPageCtrl {
    @RemoteAction
    public static String getCatalogJsonRemote() {
        return JSON.serialize(CloudPrismServiceCatalogController.getRosettaParentRows());
    }
}

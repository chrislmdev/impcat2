/**
 * Service catalog rows for the serviceCatalog LWC.
 * Description merge per (Category, Subcategory) group: first non-empty Description__c wins in Apex query order
 * (ORDER BY ... preserves deterministic pick — first row in group with description sets the label).
 */
public with sharing class ServiceCatalogController {
    public class CatalogRow {
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String csp { get; set; }
        @AuraEnabled
        public String service { get; set; }
        @AuraEnabled
        public String category { get; set; }
        @AuraEnabled
        public String subcategory { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String impactLevel { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<CatalogRow> getCatalogRows() {
        List<Service_Catalog__c> rows = [
            SELECT Id, CSP__c, Service__c, Category__c, Subcategory__c, Description__c, Impact_Level__c
            FROM Service_Catalog__c
            ORDER BY Category__c, Subcategory__c, CSP__c, Service__c
            LIMIT 5000
        ];
        List<CatalogRow> out = new List<CatalogRow>();
        for (Service_Catalog__c r : rows) {
            CatalogRow o = new CatalogRow();
            o.id = r.Id;
            o.csp = r.CSP__c;
            o.service = r.Service__c;
            o.category = r.Category__c;
            o.subcategory = r.Subcategory__c;
            o.description = r.Description__c;
            o.impactLevel = r.Impact_Level__c;
            out.add(o);
        }
        return out;
    }
}

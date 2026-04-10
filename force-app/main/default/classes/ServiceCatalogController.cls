/**
 * Service catalog rows for the serviceCatalog LWC.
 * Returns SObjects so the class compiles cleanly with @wire; description merge for display is done in LWC (first non-empty per group).
 */
public with sharing class ServiceCatalogController {
    @AuraEnabled(cacheable=true)
    public static List<Service_Catalog__c> getCatalogRows() {
        return [
            SELECT Id, CSP__c, Service__c, Category__c, Subcategory__c, Description__c, Impact_Level__c
            FROM Service_Catalog__c
            ORDER BY Category__c, Subcategory__c, CSP__c, Service__c
            LIMIT 5000
        ];
    }
}

/**
 * LWC-facing read APIs for CloudPrism POC catalog UIs.
 */
public with sharing class CloudPrismCatalogController {
    @AuraEnabled(cacheable=true)
    public static List<Pricing_Item__c> getPricingItems(String csp, String searchKey, Integer rowLimit) {
        Integer lim = rowLimit != null && rowLimit > 0 ? Math.min(rowLimit, 2000) : 500;
        String q = String.isNotBlank(searchKey) ? '%' + String.escapeSingleQuotes(searchKey.trim()) + '%' : null;
        String c = String.isNotBlank(csp) ? csp.toLowerCase().trim() : null;

        String soql =
            'SELECT Id, Name, CSP__c, Catalog_Item_Number__c, Title__c, CSO_Short_Name__c, Description__c, ' +
            'List_Unit_Price__c, Pricing_Unit__c, JWCC_Unit_Price__c, JWCC_Unit_Of_Issue__c, ' +
            'Discount_Premium_Fee__c, Focus_Category__c, Service_Category__c, ' +
            'Catalog_Import__r.Import_Month__c, Catalog_Import__r.Imported_At__c ' +
            'FROM Pricing_Item__c WHERE Catalog_Import__r.Schema__c = \'pricing\'';

        if (c != null) {
            soql += ' AND CSP__c = :c';
        }
        if (q != null) {
            soql +=
                ' AND (Title__c LIKE :q OR Catalog_Item_Number__c LIKE :q OR CSO_Short_Name__c LIKE :q OR Description__c LIKE :q)';
        }
        soql += ' ORDER BY CSP__c, Catalog_Item_Number__c LIMIT :lim';
        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<Exception_Item__c> getExceptionItems(String csp, String searchKey, Integer rowLimit) {
        Integer lim = rowLimit != null && rowLimit > 0 ? Math.min(rowLimit, 2000) : 500;
        String q = String.isNotBlank(searchKey) ? '%' + String.escapeSingleQuotes(searchKey.trim()) + '%' : null;
        String c = String.isNotBlank(csp) ? csp.toLowerCase().trim() : null;

        String soql =
            'SELECT Id, Name, CSP__c, Exception_Unique_Id__c, CSO_Short_Name__c, Impact_Level__c, Exception_Status__c, ' +
            'Exception_PWS_Requirement__c, Exception_Basis_For_Request__c, Exception_Security__c, ' +
            'Catalog_Import__r.Import_Month__c, Catalog_Import__r.Imported_At__c ' +
            'FROM Exception_Item__c WHERE Catalog_Import__r.Schema__c = \'exceptions\'';

        if (c != null) {
            soql += ' AND CSP__c = :c';
        }
        if (q != null) {
            soql +=
                ' AND (Exception_Unique_Id__c LIKE :q OR CSO_Short_Name__c LIKE :q OR Impact_Level__c LIKE :q OR Exception_Status__c LIKE :q OR Exception_PWS_Requirement__c LIKE :q OR Exception_Basis_For_Request__c LIKE :q)';
        }
        soql += ' ORDER BY CSP__c, Exception_Unique_Id__c LIMIT :lim';
        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctImportMonths(String schemaName) {
        String sch = String.isNotBlank(schemaName) ? schemaName.toLowerCase().trim() : 'pricing';
        if (sch != 'pricing' && sch != 'exceptions') {
            sch = 'pricing';
        }
        Set<String> months = new Set<String>();
        for (AggregateResult ar : [
            SELECT Import_Month__c
            FROM Catalog_Import__c
            WHERE Schema__c = :sch AND Import_Month__c != NULL
            GROUP BY Import_Month__c
        ]) {
            months.add((String) ar.get('Import_Month__c'));
        }
        List<String> sorted = new List<String>(months);
        sorted.sort();
        return sorted;
    }

    @AuraEnabled(cacheable=true)
    public static List<PricingChangeService.PricingChangeRow> getPricingChanges(
        String monthFrom,
        String monthTo,
        String csp,
        String changeType
    ) {
        return PricingChangeService.compare(monthFrom, monthTo, csp, changeType);
    }

    @AuraEnabled(cacheable=true)
    public static List<ExceptionChangeService.ExceptionChangeRow> getExceptionChanges(
        String monthFrom,
        String monthTo,
        String csp,
        String changeType
    ) {
        return ExceptionChangeService.compare(monthFrom, monthTo, csp, changeType);
    }

    /**
     * Single entry for LWC wire so `entity` toggles refresh when switching pricing vs exceptions.
     */
    @AuraEnabled(cacheable=true)
    public static Object getCatalogChangeRows(
        String entity,
        String monthFrom,
        String monthTo,
        String csp,
        String changeType
    ) {
        String e = entity != null ? entity.toLowerCase() : 'pricing';
        if (e == 'exceptions') {
            return ExceptionChangeService.compare(monthFrom, monthTo, csp, changeType);
        }
        return PricingChangeService.compare(monthFrom, monthTo, csp, changeType);
    }
}

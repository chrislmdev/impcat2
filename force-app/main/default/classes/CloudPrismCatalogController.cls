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
            // Long Text Area fields (e.g. Description__c) cannot appear in SOQL WHERE.
            soql +=
                ' AND (Title__c LIKE :q OR Catalog_Item_Number__c LIKE :q OR CSO_Short_Name__c LIKE :q OR Focus_Category__c LIKE :q)';
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
            'Exception_Requested_Duration__c, Exception_Suggested_Plan__c, ' +
            'Catalog_Import__r.Import_Month__c, Catalog_Import__r.Imported_At__c ' +
            'FROM Exception_Item__c WHERE Catalog_Import__r.Schema__c = \'exceptions\'';

        if (c != null) {
            soql += ' AND CSP__c = :c';
        }
        if (q != null) {
            // Long Text Area fields cannot appear in SOQL WHERE.
            soql +=
                ' AND (Exception_Unique_Id__c LIKE :q OR CSO_Short_Name__c LIKE :q OR Impact_Level__c LIKE :q OR Exception_Status__c LIKE :q OR Exception_Requested_Duration__c LIKE :q)';
        }
        soql += ' ORDER BY CSP__c, Exception_Unique_Id__c LIMIT :lim';
        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<Parent_Item__c> getParentItems(String csp, String searchKey, Integer rowLimit) {
        Integer lim = rowLimit != null && rowLimit > 0 ? Math.min(rowLimit, 2000) : 500;
        String q = String.isNotBlank(searchKey) ? '%' + String.escapeSingleQuotes(searchKey.trim()) + '%' : null;
        String c = String.isNotBlank(csp) ? csp.toLowerCase().trim() : null;

        String soql =
            'SELECT Id, Name, CSP__c, CSP_Name__c, Offering_Indicator__c, Title__c, CSO_Short_Name__c, Description__c, ' +
            'Category__c, Impact_Level__c, Contract_CLIN__c, Section_508_Compliance__c, Method_Of_Add__c, CSO_Change_Type__c, ' +
            'IL2_Pa_Doc_Title__c, IL2_Cso_Name_On_Pa__c, IL2_Authorizing_Agency__c, IL2_Authorization_Timeline__c, ' +
            'IL4_Pa_Doc_Title__c, IL4_Cso_Name_On_Pa__c, IL4_Authorizing_Agency__c, IL4_Authorization_Timeline__c, ' +
            'IL5_Pa_Doc_Title__c, IL5_Cso_Name_On_Pa__c, IL5_Authorizing_Agency__c, IL5_Authorization_Timeline__c, ' +
            'IL6_Pa_Doc_Title__c, IL6_Cso_Name_On_Pa__c, IL6_Authorizing_Agency__c, IL6_Authorization_Timeline__c, ' +
            'TS_Pa_Doc_Title__c, TS_Cso_Name_On_Pa__c, TS_Authorizing_Agency__c, TS_Authorization_Timeline__c, ' +
            'Product_URL__c, Notes__c, Available_For_Usage__c, ' +
            'Catalog_Import__r.Import_Month__c, Catalog_Import__r.Imported_At__c ' +
            'FROM Parent_Item__c WHERE Catalog_Import__r.Schema__c = \'parent\'';

        if (c != null) {
            soql += ' AND CSP__c = :c';
        }
        if (q != null) {
            // Long Text Area fields cannot appear in SOQL WHERE.
            soql +=
                ' AND (CSP_Name__c LIKE :q OR Offering_Indicator__c LIKE :q OR Title__c LIKE :q OR CSO_Short_Name__c LIKE :q OR ' +
                'Category__c LIKE :q OR Impact_Level__c LIKE :q OR Contract_CLIN__c LIKE :q OR Section_508_Compliance__c LIKE :q OR ' +
                'Method_Of_Add__c LIKE :q OR CSO_Change_Type__c LIKE :q OR ' +
                'IL2_Pa_Doc_Title__c LIKE :q OR IL2_Cso_Name_On_Pa__c LIKE :q OR IL2_Authorizing_Agency__c LIKE :q OR IL2_Authorization_Timeline__c LIKE :q OR ' +
                'IL4_Pa_Doc_Title__c LIKE :q OR IL4_Cso_Name_On_Pa__c LIKE :q OR IL4_Authorizing_Agency__c LIKE :q OR IL4_Authorization_Timeline__c LIKE :q OR ' +
                'IL5_Pa_Doc_Title__c LIKE :q OR IL5_Cso_Name_On_Pa__c LIKE :q OR IL5_Authorizing_Agency__c LIKE :q OR IL5_Authorization_Timeline__c LIKE :q OR ' +
                'IL6_Pa_Doc_Title__c LIKE :q OR IL6_Cso_Name_On_Pa__c LIKE :q OR IL6_Authorizing_Agency__c LIKE :q OR IL6_Authorization_Timeline__c LIKE :q OR ' +
                'TS_Pa_Doc_Title__c LIKE :q OR TS_Cso_Name_On_Pa__c LIKE :q OR TS_Authorizing_Agency__c LIKE :q OR TS_Authorization_Timeline__c LIKE :q OR ' +
                'Product_URL__c LIKE :q OR Available_For_Usage__c LIKE :q)';
        }
        soql += ' ORDER BY CSP__c, Title__c LIMIT :lim';
        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctImportMonths(String schemaName) {
        String sch = String.isNotBlank(schemaName) ? schemaName.toLowerCase().trim() : 'pricing';
        if (sch != 'pricing' && sch != 'exceptions' && sch != 'parent') {
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

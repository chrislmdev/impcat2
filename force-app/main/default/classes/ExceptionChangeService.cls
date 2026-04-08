/**
 * Month-over-month exception library diff (mirrors CloudPrism GET /exceptions/changes).
 */
public with sharing class ExceptionChangeService {
    public class ExceptionRowSnap {
        public String uniqueId;
        public String impactlevel;
        public String exceptionstatus;
        public String pws;
        public String basis;
        public String security;
        public String csoshortname;
    }

    public class ExceptionChangeRow {
        @AuraEnabled public String month_from;
        @AuraEnabled public String month_to;
        @AuraEnabled public String change_type;
        @AuraEnabled public String csp;
        @AuraEnabled public String exceptionuniqueid;
        @AuraEnabled public String csoshortname;
        @AuraEnabled public String impactlevel_prev;
        @AuraEnabled public String impactlevel_curr;
        @AuraEnabled public String exceptionstatus_prev;
        @AuraEnabled public String exceptionstatus_curr;
    }

    public static Map<String, ExceptionRowSnap> latestExceptionsForMonth(String importMonth) {
        Map<String, ExceptionRowSnap> outMap = new Map<String, ExceptionRowSnap>();
        if (String.isBlank(importMonth)) {
            return outMap;
        }

        List<Exception_Item__c> rows = [
            SELECT
                CSP__c,
                Exception_Unique_Id__c,
                CSO_Short_Name__c,
                Impact_Level__c,
                Exception_Status__c,
                Exception_PWS_Requirement__c,
                Exception_Basis_For_Request__c,
                Exception_Security__c
            FROM Exception_Item__c
            WHERE
                Catalog_Import__r.Import_Month__c = :importMonth
                AND Catalog_Import__r.Schema__c = 'exceptions'
            ORDER BY Catalog_Import__r.Imported_At__c DESC NULLS LAST, Catalog_Import__r.CreatedDate DESC, Id DESC
        ];

        for (Exception_Item__c e : rows) {
            String csp = e.CSP__c != null ? e.CSP__c.toLowerCase() : '';
            String uid = e.Exception_Unique_Id__c != null ? e.Exception_Unique_Id__c.trim() : '';
            if (String.isBlank(uid)) {
                continue;
            }
            String key = csp + '|' + uid.toLowerCase();
            if (outMap.containsKey(key)) {
                continue;
            }

            outMap.put(key, snapFromExceptionItem(e, uid));
        }
        return outMap;
    }

    public static ExceptionRowSnap snapFromExceptionItem(Exception_Item__c e, String trimmedUniqueId) {
        ExceptionRowSnap s = new ExceptionRowSnap();
        s.uniqueId = trimmedUniqueId;
        s.impactlevel = e.Impact_Level__c != null ? e.Impact_Level__c : '';
        s.exceptionstatus = e.Exception_Status__c != null ? e.Exception_Status__c : '';
        s.pws = e.Exception_PWS_Requirement__c != null ? e.Exception_PWS_Requirement__c : '';
        s.basis = e.Exception_Basis_For_Request__c != null ? e.Exception_Basis_For_Request__c : '';
        s.security = e.Exception_Security__c != null ? e.Exception_Security__c : '';
        s.csoshortname = e.CSO_Short_Name__c;
        return s;
    }

    public static List<ExceptionChangeRow> compare(
        String monthFrom,
        String monthTo,
        String cspFilter,
        String changeTypeFilter
    ) {
        List<ExceptionChangeRow> results = new List<ExceptionChangeRow>();
        if (String.isBlank(monthFrom) || String.isBlank(monthTo) || monthFrom.equals(monthTo)) {
            return results;
        }

        Map<String, ExceptionRowSnap> prevMap = latestExceptionsForMonth(monthFrom);
        Map<String, ExceptionRowSnap> currMap = latestExceptionsForMonth(monthTo);

        Set<String> keys = new Set<String>();
        keys.addAll(prevMap.keySet());
        keys.addAll(currMap.keySet());

        String cspLower = String.isNotBlank(cspFilter) ? cspFilter.toLowerCase().trim() : null;

        for (String key : keys) {
            ExceptionRowSnap pr = prevMap.get(key);
            ExceptionRowSnap cr = currMap.get(key);

            String csp = key.substringBefore('|');
            if (cspLower != null && !csp.equals(cspLower)) {
                continue;
            }

            String changeType;
            if (pr == null) {
                changeType = 'added';
            } else if (cr == null) {
                changeType = 'removed';
            } else {
                Boolean changed =
                    pr.impactlevel != cr.impactlevel ||
                    pr.exceptionstatus != cr.exceptionstatus ||
                    pr.pws != cr.pws ||
                    pr.basis != cr.basis ||
                    pr.security != cr.security ||
                    (pr.csoshortname != cr.csoshortname);
                if (!changed) {
                    continue;
                }
                changeType = 'updated';
            }

            if (String.isNotBlank(changeTypeFilter) && !changeTypeFilter.equalsIgnoreCase(changeType)) {
                continue;
            }

            ExceptionChangeRow row = new ExceptionChangeRow();
            row.month_from = monthFrom;
            row.month_to = monthTo;
            row.change_type = changeType;
            row.csp = csp;
            row.exceptionuniqueid = cr != null && cr.uniqueId != null
                ? cr.uniqueId
                : (pr != null ? pr.uniqueId : key.substringAfter('|'));
            row.csoshortname = cr != null ? cr.csoshortname : (pr != null ? pr.csoshortname : null);
            row.impactlevel_prev = pr != null && String.isNotBlank(pr.impactlevel) ? pr.impactlevel : null;
            row.impactlevel_curr = cr != null && String.isNotBlank(cr.impactlevel) ? cr.impactlevel : null;
            row.exceptionstatus_prev = pr != null && String.isNotBlank(pr.exceptionstatus)
                ? pr.exceptionstatus
                : null;
            row.exceptionstatus_curr = cr != null && String.isNotBlank(cr.exceptionstatus)
                ? cr.exceptionstatus
                : null;

            results.add(row);
        }

        results.sort(new ExceptionChangeComparator());
        return results;
    }

    private class ExceptionChangeComparator implements Comparator<ExceptionChangeRow> {
        public Integer compare(ExceptionChangeRow a, ExceptionChangeRow b) {
            Integer c = a.csp.compareTo(b.csp);
            if (c != 0) {
                return c;
            }
            String ua = a.exceptionuniqueid != null ? a.exceptionuniqueid : '';
            String ub = b.exceptionuniqueid != null ? b.exceptionuniqueid : '';
            c = ua.compareTo(ub);
            if (c != 0) {
                return c;
            }
            String sa = a.csoshortname != null ? a.csoshortname : '';
            String sb = b.csoshortname != null ? b.csoshortname : '';
            return sa.compareTo(sb);
        }
    }
}

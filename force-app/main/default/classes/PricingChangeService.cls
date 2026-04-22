/**
 * Month-over-month pricing catalog diff (mirrors CloudPrism GET /pricing/changes semantics).
 */
public with sharing class PricingChangeService {
    public class PricingRowSnap {
        public String catalogNum;
        public Decimal jwccPric;
        public Decimal commPric;
        public String disc;
        public String jwccU;
        public String commU;
        public String title;
        /** True when import stored a multi-value price cell (manual review). */
        public Boolean containsMulti;
    }

    public class PricingChangeRow {
        @AuraEnabled public String month_from;
        @AuraEnabled public String month_to;
        @AuraEnabled public String change_type;
        @AuraEnabled public String csp;
        @AuraEnabled public String catalogitemnumber;
        @AuraEnabled public String title;
        @AuraEnabled public Decimal prev_jwcc;
        @AuraEnabled public Decimal curr_jwcc;
        @AuraEnabled public Decimal prev_comm;
        @AuraEnabled public Decimal curr_comm;
        @AuraEnabled public Decimal cust_delta;
        @AuraEnabled public Decimal cust_delta_pct;
        @AuraEnabled public Decimal comm_delta;
        @AuraEnabled public Decimal comm_delta_pct;
        /** True if either snapshot month had Contains_Multi_Price__c on the pricing row. */
        @AuraEnabled public Boolean contains_multi_price;
    }

    /**
     * Latest row per (csp, catalog #) for a given import month (pricing schema only).
     */
    public static Map<String, PricingRowSnap> latestPricingForMonth(String importMonth) {
        Map<String, PricingRowSnap> outMap = new Map<String, PricingRowSnap>();
        if (String.isBlank(importMonth)) {
            return outMap;
        }

        List<Pricing_Item__c> rows = [
            SELECT
                CSP__c,
                Catalog_Item_Number__c,
                Title__c,
                List_Unit_Price__c,
                JWCC_Unit_Price__c,
                Discount_Premium_Fee__c,
                Pricing_Unit__c,
                JWCC_Unit_Of_Issue__c,
                Contains_Multi_Price__c,
                Catalog_Import__r.Import_Month__c,
                Catalog_Import__r.Imported_At__c,
                Catalog_Import__r.CreatedDate
            FROM Pricing_Item__c
            WHERE
                Catalog_Import__r.Import_Month__c = :importMonth
                AND Catalog_Import__r.Schema__c = 'pricing'
            ORDER BY Catalog_Import__r.Imported_At__c DESC NULLS LAST, Catalog_Import__r.CreatedDate DESC, Id DESC
        ];

        for (Pricing_Item__c p : rows) {
            String csp = p.CSP__c != null ? p.CSP__c.toLowerCase() : '';
            String cat = p.Catalog_Item_Number__c != null ? p.Catalog_Item_Number__c.trim() : '';
            if (String.isBlank(cat)) {
                continue;
            }
            String key = csp + '|' + cat.toLowerCase();
            if (outMap.containsKey(key)) {
                continue;
            }

            outMap.put(key, snapFromPricingItem(p));
        }
        return outMap;
    }

    public static PricingRowSnap snapFromPricingItem(Pricing_Item__c p) {
        PricingRowSnap s = new PricingRowSnap();
        s.catalogNum = p.Catalog_Item_Number__c != null ? p.Catalog_Item_Number__c.trim() : '';
        s.jwccPric = p.JWCC_Unit_Price__c;
        s.commPric = p.List_Unit_Price__c;
        s.disc = p.Discount_Premium_Fee__c != null ? p.Discount_Premium_Fee__c : '';
        s.jwccU = p.JWCC_Unit_Of_Issue__c != null ? p.JWCC_Unit_Of_Issue__c.trim() : '';
        s.commU = p.Pricing_Unit__c != null ? p.Pricing_Unit__c.trim() : '';
        s.title = p.Title__c;
        s.containsMulti = p.Contains_Multi_Price__c == true;
        return s;
    }

    public static List<PricingChangeRow> compare(
        String monthFrom,
        String monthTo,
        String cspFilter,
        String changeTypeFilter
    ) {
        List<PricingChangeRow> results = new List<PricingChangeRow>();
        if (String.isBlank(monthFrom) || String.isBlank(monthTo) || monthFrom.equals(monthTo)) {
            return results;
        }

        Map<String, PricingRowSnap> prevMap = latestPricingForMonth(monthFrom);
        Map<String, PricingRowSnap> currMap = latestPricingForMonth(monthTo);

        Set<String> keys = new Set<String>();
        keys.addAll(prevMap.keySet());
        keys.addAll(currMap.keySet());

        String cspLower = String.isNotBlank(cspFilter) ? cspFilter.toLowerCase().trim() : null;

        for (String key : keys) {
            PricingRowSnap pr = prevMap.get(key);
            PricingRowSnap cr = currMap.get(key);

            String csp = '';
            if (cr != null) {
                csp = key.substringBefore('|');
            } else if (pr != null) {
                csp = key.substringBefore('|');
            }

            if (cspLower != null && !csp.equals(cspLower)) {
                continue;
            }

            String changeType;
            if (pr == null) {
                changeType = 'added';
            } else if (cr == null) {
                changeType = 'removed';
            } else {
                Boolean sameJwcc = decimalsEqual(pr.jwccPric, cr.jwccPric);
                Boolean sameComm = decimalsEqual(pr.commPric, cr.commPric);
                Boolean sameDisc = pr.disc == cr.disc;
                Boolean sameJwccU = pr.jwccU == cr.jwccU;
                Boolean sameCommU = pr.commU == cr.commU;
                if (sameJwcc && sameComm && sameDisc && sameJwccU && sameCommU) {
                    continue;
                }
                changeType = 'updated';
            }

            if (String.isNotBlank(changeTypeFilter) && !changeTypeFilter.equalsIgnoreCase(changeType)) {
                continue;
            }

            PricingChangeRow row = new PricingChangeRow();
            row.month_from = monthFrom;
            row.month_to = monthTo;
            row.change_type = changeType;
            row.csp = csp;
            row.catalogitemnumber = cr != null && cr.catalogNum != null
                ? cr.catalogNum
                : (pr != null ? pr.catalogNum : key.substringAfter('|'));
            row.title = cr != null ? cr.title : (pr != null ? pr.title : null);

            row.prev_jwcc = pr != null ? pr.jwccPric : null;
            row.curr_jwcc = cr != null ? cr.jwccPric : null;
            row.prev_comm = pr != null ? pr.commPric : null;
            row.curr_comm = cr != null ? cr.commPric : null;
            row.contains_multi_price =
                (pr != null && pr.containsMulti == true) || (cr != null && cr.containsMulti == true);

            Decimal pj = row.prev_jwcc != null ? row.prev_jwcc : 0;
            Decimal cj = row.curr_jwcc != null ? row.curr_jwcc : 0;
            Decimal pc = row.prev_comm != null ? row.prev_comm : 0;
            Decimal cc = row.curr_comm != null ? row.curr_comm : 0;

            if (changeType == 'added') {
                row.cust_delta = cj;
                row.comm_delta = cc;
            } else if (changeType == 'removed') {
                row.cust_delta = -pj;
                row.comm_delta = -pc;
            } else {
                row.cust_delta = cj - pj;
                row.comm_delta = cc - pc;
                row.cust_delta_pct = (pj != null && pj != 0) ? (100.0 * (cj - pj) / pj) : null;
                row.comm_delta_pct = (pc != null && pc != 0) ? (100.0 * (cc - pc) / pc) : null;
            }

            results.add(row);
        }

        results.sort(new PricingChangeComparator());
        return results;
    }

    private static Boolean decimalsEqual(Decimal a, Decimal b) {
        if (a == null && b == null) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        return a == b;
    }

    private class PricingChangeComparator implements Comparator<PricingChangeRow> {
        public Integer compare(PricingChangeRow a, PricingChangeRow b) {
            Integer c = a.csp.compareTo(b.csp);
            if (c != 0) {
                return c;
            }
            String na = a.catalogitemnumber != null ? a.catalogitemnumber : '';
            String nb = b.catalogitemnumber != null ? b.catalogitemnumber : '';
            return na.compareTo(nb);
        }
    }
}

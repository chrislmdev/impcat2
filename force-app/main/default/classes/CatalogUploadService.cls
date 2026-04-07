/**
 * In-app CSV upload for CloudPrism POC (small files only).
 * Filename: {YYYY-MM}_{csp}_{pricing|exceptions|parent}.csv
 */
public with sharing class CatalogUploadService {
    @TestVisible
    static final Integer MAX_BODY_CHARS = 1048576;
    @TestVisible
    static final Integer MAX_DATA_ROWS = 8000;

    private static final Set<String> RESERVED_HEADERS = new Set<String>{
        'Id',
        'Name',
        'Catalog_Import__c',
        'CSP__c'
    };

    private static final Set<String> PRICING_HEADERS = new Set<String>{
        'Catalog_Item_Number__c',
        'Title__c',
        'CSO_Short_Name__c',
        'Description__c',
        'List_Unit_Price__c',
        'Pricing_Unit__c',
        'JWCC_Unit_Price__c',
        'JWCC_Unit_Of_Issue__c',
        'Discount_Premium_Fee__c',
        'Focus_Category__c',
        'Service_Category__c'
    };

    private static final Set<String> EXCEPTION_HEADERS = new Set<String>{
        'Exception_Unique_Id__c',
        'CSO_Short_Name__c',
        'Impact_Level__c',
        'Exception_Status__c',
        'Exception_PWS_Requirement__c',
        'Exception_Basis_For_Request__c',
        'Exception_Security__c'
    };

    private static final Set<String> DECIMAL_FIELDS = new Set<String>{
        'List_Unit_Price__c',
        'JWCC_Unit_Price__c'
    };

    private static final Pattern HEADER_ALNUM = Pattern.compile('[a-z0-9]');

    /**
     * Extra CSV header fingerprints (alphanumeric-only) -> canonical API for pricing only.
     * Used when the export uses business/camelCase names that do not match API fingerprints.
     */
    private static final Map<String, String> PRICING_HEADER_ALIASES = new Map<String, String>{
        'commercialunitprice' => 'List_Unit_Price__c',
        'commerciallistprice' => 'List_Unit_Price__c',
        'commercialprice' => 'List_Unit_Price__c',
        'listprice' => 'List_Unit_Price__c',
        'unitlistprice' => 'List_Unit_Price__c',
        'jwccprice' => 'JWCC_Unit_Price__c',
        'sku' => 'Catalog_Item_Number__c',
        'catalognumber' => 'Catalog_Item_Number__c',
        'itemnumber' => 'Catalog_Item_Number__c',
        'shortname' => 'CSO_Short_Name__c',
        'csoshortname' => 'CSO_Short_Name__c',
        'commercialunit' => 'Pricing_Unit__c',
        'commercialunitofmeasure' => 'Pricing_Unit__c',
        'jwccunit' => 'JWCC_Unit_Of_Issue__c',
        'jwccunitofissue' => 'JWCC_Unit_Of_Issue__c',
        'discountpremium' => 'Discount_Premium_Fee__c',
        'focuscategory' => 'Focus_Category__c',
        'servicecategory' => 'Service_Category__c'
    };

    /**
     * Lowercase, strip optional trailing __c, keep only alphanumerics (underscores/spaces removed).
     * Used to match human-friendly CSV headers to canonical API names.
     */
    @TestVisible
    static String headerFingerprint(String raw) {
        if (raw == null) {
            return '';
        }
        String s = raw.trim().toLowerCase();
        if (s.endsWith('__c')) {
            s = s.substring(0, s.length() - 3);
        }
        String out = '';
        for (Integer i = 0; i < s.length(); i++) {
            String ch = s.substring(i, i + 1);
            if (HEADER_ALNUM.matcher(ch).matches()) {
                out += ch;
            }
        }
        return out;
    }

    /**
     * fingerprint -> canonical API name. If two allowed fields share a fingerprint, throws (POC guard).
     */
    @TestVisible
    static Map<String, String> buildHeaderResolveMap(Set<String> allowedApis) {
        Map<String, String> fpToApi = new Map<String, String>();
        for (String api : allowedApis) {
            String fp = headerFingerprint(api);
            if (String.isBlank(fp)) {
                continue;
            }
            if (fpToApi.containsKey(fp)) {
                throw new IllegalArgumentException(
                    'Header fingerprint collision for "' +
                    fp +
                    '": ' +
                    fpToApi.get(fp) +
                    ' vs ' +
                    api
                );
            }
            fpToApi.put(fp, api);
        }
        return fpToApi;
    }

    public class FileProcessResult {
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String catalogImportId;
        @AuraEnabled
        public Integer rowsInserted;
        @AuraEnabled
        public List<String> errors;
    }

    public class ParsedFileName {
        public String importMonth;
        public String csp;
        public String schema;
    }

    @AuraEnabled
    public static FileProcessResult processFile(String fileName, String csvBody) {
        FileProcessResult out = new FileProcessResult();
        out.success = false;
        out.rowsInserted = 0;
        out.errors = new List<String>();

        if (csvBody == null) {
            csvBody = '';
        }
        if (csvBody.length() > MAX_BODY_CHARS) {
            out.message =
                'File too large for in-app upload (max ' +
                MAX_BODY_CHARS +
                ' characters). Use MuleSoft / SharePoint → Bulk API 2.0 for large catalogs.';
            return out;
        }

        if (csvBody.length() > 0 && csvBody.startsWith('\uFEFF')) {
            csvBody = csvBody.substring(1);
        }

        Integer lineCount = countLines(csvBody);
        if (lineCount > MAX_DATA_ROWS + 1) {
            out.message =
                'Too many rows for in-app upload (max ' +
                MAX_DATA_ROWS +
                ' data rows plus header). Use MuleSoft and Bulk API 2.0 for large files.';
            return out;
        }

        String base = basename(fileName);
        ParsedFileName pfn;
        try {
            pfn = parseFileName(base);
        } catch (Exception e) {
            out.message = e.getMessage();
            return out;
        }

        Catalog_Import__c header = new Catalog_Import__c(
            Import_Month__c = pfn.importMonth,
            CSP__c = pfn.csp,
            Schema__c = pfn.schema,
            Source_File__c = base,
            Status__c = 'processing',
            Imported_At__c = System.now(),
            Imported_By__c = UserInfo.getUserId(),
            Row_Count__c = 0
        );
        insert header;

        try {
            if (pfn.schema == 'parent') {
                header.Status__c = 'done';
                header.Row_Count__c = 0;
                update header;
                out.success = true;
                out.catalogImportId = header.Id;
                out.rowsInserted = 0;
                out.message = 'Catalog import header created (parent schema — no line items in POC).';
                return out;
            }

            if (String.isBlank(csvBody) || csvBody.trim().length() == 0) {
                header.Status__c = 'error';
                update header;
                out.message = 'CSV body is empty.';
                out.catalogImportId = header.Id;
                return out;
            }

            List<String> lines = splitLines(csvBody);
            if (lines.isEmpty()) {
                header.Status__c = 'error';
                update header;
                out.message = 'No CSV lines found.';
                out.catalogImportId = header.Id;
                return out;
            }

            List<String> headerCells = splitCsvLine(lines[0]);
            List<String> headers = new List<String>();
            for (String h : headerCells) {
                headers.add(h != null ? h.trim() : '');
            }

            Set<String> allowed = pfn.schema == 'pricing' ? PRICING_HEADERS : EXCEPTION_HEADERS;
            String requiredKey = pfn.schema == 'pricing' ? 'Catalog_Item_Number__c' : 'Exception_Unique_Id__c';

            Map<String, String> fpToCanonical;
            try {
                fpToCanonical = buildHeaderResolveMap(allowed);
            } catch (IllegalArgumentException e) {
                header.Status__c = 'error';
                update header;
                out.message = 'Import configuration error: ' + e.getMessage();
                out.catalogImportId = header.Id;
                return out;
            }

            Map<String, Integer> colIndex = new Map<String, Integer>();
            for (Integer i = 0; i < headers.size(); i++) {
                String hn = headers[i];
                if (String.isBlank(hn)) {
                    continue;
                }
                if (RESERVED_HEADERS.contains(hn)) {
                    continue;
                }
                String canonical;
                if (allowed.contains(hn)) {
                    canonical = hn;
                } else {
                    String fp = headerFingerprint(hn);
                    canonical = fpToCanonical.get(fp);
                    if (canonical == null && pfn.schema == 'pricing') {
                        String aliasTarget = PRICING_HEADER_ALIASES.get(fp);
                        if (aliasTarget != null && allowed.contains(aliasTarget)) {
                            canonical = aliasTarget;
                        }
                    }
                }
                if (canonical == null) {
                    header.Status__c = 'error';
                    update header;
                    out.message = 'Unknown column: ' + hn + '. Allowed: ' + String.join(new List<String>(allowed), ', ');
                    out.catalogImportId = header.Id;
                    return out;
                }
                if (colIndex.containsKey(canonical)) {
                    header.Status__c = 'error';
                    update header;
                    out.message = 'Duplicate column maps to ' + canonical + '.';
                    out.catalogImportId = header.Id;
                    return out;
                }
                colIndex.put(canonical, i);
            }

            if (!colIndex.containsKey(requiredKey)) {
                header.Status__c = 'error';
                update header;
                out.message = 'CSV must include column ' + requiredKey + '.';
                out.catalogImportId = header.Id;
                return out;
            }

            Integer inserted = 0;
            List<SObject> batch = new List<SObject>();

            for (Integer r = 1; r < lines.size(); r++) {
                String line = lines[r];
                if (String.isBlank(line)) {
                    continue;
                }
                List<String> cells = splitCsvLine(line);
                SObject row;
                if (pfn.schema == 'pricing') {
                    row = new Pricing_Item__c();
                } else {
                    row = new Exception_Item__c();
                }
                row.put('Catalog_Import__c', header.Id);
                row.put('CSP__c', pfn.csp);

                List<String> rowErrs = new List<String>();
                for (String api : colIndex.keySet()) {
                    Integer idx = colIndex.get(api);
                    String raw = idx < cells.size() && cells[idx] != null ? cells[idx].trim() : '';
                    if (String.isBlank(raw)) {
                        continue;
                    }
                    if (DECIMAL_FIELDS.contains(api)) {
                        try {
                            row.put(api, Decimal.valueOf(raw));
                        } catch (Exception ex) {
                            rowErrs.add('Row ' + r + ': invalid number for ' + api + ': ' + raw);
                        }
                    } else {
                        row.put(api, raw);
                    }
                }

                Object reqVal = row.get(requiredKey);
                if (reqVal == null || (reqVal instanceof String && String.isBlank((String) reqVal))) {
                    rowErrs.add('Row ' + r + ': missing ' + requiredKey);
                }

                if (!rowErrs.isEmpty()) {
                    out.errors.addAll(rowErrs);
                    continue;
                }

                batch.add(row);
                if (batch.size() >= 200) {
                    inserted += insertBatch(batch, out.errors);
                    batch.clear();
                }
            }
            if (!batch.isEmpty()) {
                inserted += insertBatch(batch, out.errors);
            }

            header.Row_Count__c = inserted;
            header.Status__c = out.errors.isEmpty() ? 'done' : 'error';
            update header;

            out.success = out.errors.isEmpty();
            out.catalogImportId = header.Id;
            out.rowsInserted = inserted;
            out.message = out.success
                ? 'Imported ' + inserted + ' row(s).'
                : 'Completed with errors; see errors list. Rows inserted: ' + inserted + '.';
            return out;
        } catch (Exception e) {
            header.Status__c = 'error';
            try {
                update header;
            } catch (Exception ignore) {
            }
            out.message = 'Import failed: ' + e.getMessage();
            out.catalogImportId = header.Id;
            out.errors.add(e.getMessage());
            return out;
        }
    }

    private static Integer insertBatch(List<SObject> rows, List<String> errCollector) {
        Integer ok = 0;
        Database.SaveResult[] srs = Database.insert(rows, false);
        for (Integer i = 0; i < srs.size(); i++) {
            if (srs[i].isSuccess()) {
                ok++;
            } else {
                for (Database.Error err : srs[i].getErrors()) {
                    errCollector.add('DML: ' + err.getMessage());
                }
            }
        }
        return ok;
    }

    @TestVisible
    static ParsedFileName parseFileName(String base) {
        if (String.isBlank(base)) {
            throw new IllegalArgumentException('File name is required.');
        }
        String lower = base.toLowerCase();
        if (!lower.endsWith('.csv')) {
            throw new IllegalArgumentException('File must end with .csv (got: ' + base + ').');
        }
        String stem = base.substring(0, base.length() - 4);
        List<String> parts = stem.split('_', -1);
        if (parts.size() != 3) {
            throw new IllegalArgumentException(
                'Expected name {YYYY-MM}_{csp}_{schema}.csv (e.g. 2026-02_aws_pricing.csv). Got: ' + base
            );
        }
        String month = parts[0];
        String csp = parts[1].toLowerCase();
        String schema = parts[2].toLowerCase();

        if (!Pattern.compile('^\\d{4}-\\d{2}$').matcher(month).matches()) {
            throw new IllegalArgumentException('Invalid month in file name: ' + month + ' (use YYYY-MM).');
        }
        Set<String> csps = new Set<String>{ 'aws', 'azure', 'gcp', 'oracle' };
        if (!csps.contains(csp)) {
            throw new IllegalArgumentException('Invalid CSP in file name: ' + csp + ' (use aws, azure, gcp, oracle).');
        }
        Set<String> schemas = new Set<String>{ 'pricing', 'exceptions', 'parent' };
        if (!schemas.contains(schema)) {
            throw new IllegalArgumentException(
                'Invalid schema in file name: ' + schema + ' (use pricing, exceptions, parent).'
            );
        }

        ParsedFileName p = new ParsedFileName();
        p.importMonth = month;
        p.csp = csp;
        p.schema = schema;
        return p;
    }

    @TestVisible
    static String basename(String path) {
        if (String.isBlank(path)) {
            return '';
        }
        String p = path.replace('\\', '/');
        Integer slash = p.lastIndexOf('/');
        return slash >= 0 ? p.substring(slash + 1) : p;
    }

    @TestVisible
    static Integer countLines(String body) {
        if (String.isBlank(body)) {
            return 0;
        }
        return body.countMatches('\n') + 1;
    }

    @TestVisible
    static List<String> splitLines(String body) {
        List<String> out = new List<String>();
        if (body == null) {
            return out;
        }
        for (String line : body.split('\n')) {
            if (line.endsWith('\r')) {
                line = line.substring(0, line.length() - 1);
            }
            out.add(line);
        }
        return out;
    }

    /**
     * RFC4180-style: commas split fields; doubled quotes inside quoted field.
     */
    @TestVisible
    static List<String> splitCsvLine(String line) {
        List<String> fields = new List<String>();
        if (line == null) {
            return fields;
        }
        String cur = '';
        Boolean inQuotes = false;
        Integer len = line.length();
        Integer i = 0;
        while (i < len) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                if (inQuotes && i + 1 < len && line.substring(i + 1, i + 2) == '"') {
                    cur += '"';
                    i += 2;
                    continue;
                }
                inQuotes = !inQuotes;
                i++;
                continue;
            }
            if (ch == ',' && !inQuotes) {
                fields.add(cur);
                cur = '';
                i++;
                continue;
            }
            cur += ch;
            i++;
        }
        fields.add(cur);
        return fields;
    }
}

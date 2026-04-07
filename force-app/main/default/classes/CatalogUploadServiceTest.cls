@IsTest
private class CatalogUploadServiceTest {
    @IsTest
    static void parseFileName_acceptsValid() {
        CatalogUploadService.ParsedFileName p = CatalogUploadService.parseFileName('2026-02_aws_pricing.csv');
        System.assertEquals('2026-02', p.importMonth);
        System.assertEquals('aws', p.csp);
        System.assertEquals('pricing', p.schema);
    }

    @IsTest
    static void parseFileName_normalizesCspCase() {
        CatalogUploadService.ParsedFileName p = CatalogUploadService.parseFileName('2026-01_Azure_exceptions.csv');
        System.assertEquals('azure', p.csp);
        System.assertEquals('exceptions', p.schema);
    }

    @IsTest
    static void parseFileName_rejectsBadPattern() {
        try {
            CatalogUploadService.parseFileName('bad.csv');
            System.assert(false, 'expected exception');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Expected name'));
        }
    }

    @IsTest
    static void basename_trimsPath() {
        System.assertEquals('x.csv', CatalogUploadService.basename('a/b/x.csv'));
        System.assertEquals('x.csv', CatalogUploadService.basename('a\\b\\x.csv'));
    }

    @IsTest
    static void splitCsvLine_handlesQuotes() {
        List<String> f = CatalogUploadService.splitCsvLine('"a,b",c');
        System.assertEquals(2, f.size());
        System.assertEquals('a,b', f[0]);
        System.assertEquals('c', f[1]);
    }

    @IsTest
    static void headerFingerprint_matchesFriendlyHeaders() {
        System.assertEquals('title', CatalogUploadService.headerFingerprint('title'));
        System.assertEquals('title', CatalogUploadService.headerFingerprint('Title__c'));
        System.assertEquals('exceptionuniqueid', CatalogUploadService.headerFingerprint('ExceptionuniqueID'));
        System.assertEquals(
            'exceptionuniqueid',
            CatalogUploadService.headerFingerprint('Exception_Unique_Id__c')
        );
    }

    @IsTest
    static void processFile_pricing_acceptsFriendlyTitleColumn() {
        String csv =
            'Catalog_Item_Number__c,title,List_Unit_Price__c\n' +
            'SKU-A,Alpha,1.25\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-03_aws_pricing.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(1, r.rowsInserted);
    }

    @IsTest
    static void processFile_pricing_acceptsCommercialUnitPriceAlias() {
        String csv = 'Catalog_Item_Number__c,commercialUnitPrice\n' + 'SKU-X,99.5\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-03_aws_pricing.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(1, r.rowsInserted);
        Pricing_Item__c row = [
            SELECT List_Unit_Price__c
            FROM Pricing_Item__c
            WHERE Catalog_Import__c = :r.catalogImportId
            LIMIT 1
        ];
        System.assertEquals(99.5, row.List_Unit_Price__c);
    }

    @IsTest
    static void processFile_exceptions_acceptsFriendlyExceptionIdColumn() {
        String csv = 'ExceptionuniqueID,CSO_Short_Name__c\n' + 'EX-1,svc1\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-03_aws_exceptions.csv',
            csv
        );
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(1, r.rowsInserted);
    }

    @IsTest
    static void processFile_rejectsDuplicateColumnsSameField() {
        String csv = 'Catalog_Item_Number__c,Title__c,title\n' + 'SKU-A,Old,New\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-02_aws_pricing.csv', csv);
        System.assertEquals(false, r.success);
        System.assert(r.message != null && r.message.contains('Duplicate column'));
    }

    @IsTest
    static void processFile_parentSchema_noRows() {
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-02_aws_parent.csv',
            ''
        );
        System.assertEquals(true, r.success);
        System.assertEquals(0, r.rowsInserted);
        Catalog_Import__c h = [
            SELECT Status__c, Schema__c, Row_Count__c
            FROM Catalog_Import__c
            WHERE Id = :r.catalogImportId
        ];
        System.assertEquals('done', h.Status__c);
        System.assertEquals('parent', h.Schema__c);
        System.assertEquals(0, h.Row_Count__c);
    }

    @IsTest
    static void processFile_pricing_insertsRows() {
        String csv =
            'Catalog_Item_Number__c,Title__c,List_Unit_Price__c\n' +
            'SKU-A,Alpha,1.25\n' +
            'SKU-B,Beta,2\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-02_gcp_pricing.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(2, r.rowsInserted);
        Integer n = [SELECT COUNT() FROM Pricing_Item__c WHERE Catalog_Import__c = :r.catalogImportId];
        System.assertEquals(2, n);
    }

    @IsTest
    static void processFile_exceptions_insertsRows() {
        String csv = 'Exception_Unique_Id__c,CSO_Short_Name__c\n' + 'EX-1,svc1\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-02_oracle_exceptions.csv',
            csv
        );
        System.assertEquals(true, r.success, r.message);
        System.assertEquals(1, r.rowsInserted);
    }

    @IsTest
    static void processFile_rejectsTooManyLines() {
        String body = 'Catalog_Item_Number__c\n';
        for (Integer i = 0; i < CatalogUploadService.MAX_DATA_ROWS + 1; i++) {
            body += 'X' + i + '\n';
        }
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-02_aws_pricing.csv',
            body
        );
        System.assertEquals(false, r.success);
        System.assert(r.message != null && r.message.contains('Too many rows'));
    }

    @IsTest
    static void processFile_rowValidation_badDecimal() {
        String csv = 'Catalog_Item_Number__c,List_Unit_Price__c\n' + 'SKU1,not-a-number\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-02_aws_pricing.csv',
            csv
        );
        System.assertEquals(false, r.success);
        System.assert(!r.errors.isEmpty());
    }

    @IsTest
    static void processFile_unknownColumn() {
        String csv = 'Catalog_Item_Number__c,Unknown__c\n' + 'SKU1,x\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-02_aws_pricing.csv',
            csv
        );
        System.assertEquals(false, r.success);
        System.assert(r.message.contains('Unknown column'));
    }
}

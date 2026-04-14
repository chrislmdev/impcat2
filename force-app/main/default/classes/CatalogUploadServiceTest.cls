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
    static void processFile_pricing_acceptsCommercialUnitOfIssueAlias() {
        String csv = 'Catalog_Item_Number__c,commercialUnitOfIssue\n' + 'SKU-Y,Each\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-03_aws_pricing.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(1, r.rowsInserted);
        Pricing_Item__c row = [
            SELECT Pricing_Unit__c
            FROM Pricing_Item__c
            WHERE Catalog_Import__c = :r.catalogImportId
            LIMIT 1
        ];
        System.assertEquals('Each', row.Pricing_Unit__c);
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
    static void processFile_exceptions_acceptsDurationAndSuggestedPlanHeaders() {
        String csv =
            'ExceptionuniqueID,ExceptionRequestedDuration,ExceptionSuggestedPlan\n' +
            'EX-2,90 days,Phase rollout then review\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-03_aws_exceptions.csv',
            csv
        );
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(1, r.rowsInserted);
        Exception_Item__c row = [
            SELECT Exception_Requested_Duration__c, Exception_Suggested_Plan__c
            FROM Exception_Item__c
            WHERE Catalog_Import__c = :r.catalogImportId
            LIMIT 1
        ];
        System.assertEquals('90 days', row.Exception_Requested_Duration__c);
        System.assertEquals('Phase rollout then review', row.Exception_Suggested_Plan__c);
    }

    @IsTest
    static void processFile_rejectsDuplicateColumnsSameField() {
        String csv = 'Catalog_Item_Number__c,Title__c,title\n' + 'SKU-A,Old,New\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-02_aws_pricing.csv', csv);
        System.assertEquals(false, r.success);
        System.assert(r.message != null && r.message.contains('Duplicate column'));
    }

    @IsTest
    static void processFile_parentSchema_emptyBody_errors() {
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile(
            '2026-02_aws_parent.csv',
            ''
        );
        System.assertEquals(false, r.success);
        System.assert(r.message != null && r.message.contains('empty'), r.message);
    }

    @IsTest
    static void processFile_parentSchema_importsRows() {
        String csv = 'title,cspName\n' + 'My parent row,aws-org\n' + 'Second title,gcp-org\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-03_aws_parent.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        System.assertEquals(2, r.rowsInserted);
        Parent_Item__c one = [
            SELECT Title__c, CSP_Name__c
            FROM Parent_Item__c
            WHERE Catalog_Import__c = :r.catalogImportId
            ORDER BY Title__c
            LIMIT 1
        ];
        System.assertEquals('My parent row', one.Title__c);
        System.assertEquals('aws-org', one.CSP_Name__c);
    }

    @IsTest
    static void countAssumedParentDataRowsAfterHeader_countsNonBlankLines() {
        System.assertEquals(0, CatalogUploadService.countAssumedParentDataRowsAfterHeader(''));
        System.assertEquals(0, CatalogUploadService.countAssumedParentDataRowsAfterHeader('header only'));
        System.assertEquals(1, CatalogUploadService.countAssumedParentDataRowsAfterHeader('h\nr1\n'));
        System.assertEquals(2, CatalogUploadService.countAssumedParentDataRowsAfterHeader('h' + '\n' + 'r1' + '\n' + 'r2' + '\n'));
    }

    @IsTest
    static void processFile_pricing_infersFocusWhenNoFocusColumn() {
        String csv =
            'Catalog_Item_Number__c,title\n' +
            'SKU-Z,Amazon S3 Standard storage\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-04_aws_pricing.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        Pricing_Item__c row = [
            SELECT Focus_Category__c
            FROM Pricing_Item__c
            WHERE Catalog_Import__c = :r.catalogImportId
            LIMIT 1
        ];
        System.assertEquals('Storage', row.Focus_Category__c);
    }

    @IsTest
    static void processFile_pricing_categoryAliasFeedsServiceCategoryAndFocus() {
        String csv = 'Catalog_Item_Number__c,category\n' + 'SKU-1,compute\n';
        CatalogUploadService.FileProcessResult r = CatalogUploadService.processFile('2026-04_gcp_pricing.csv', csv);
        System.assertEquals(true, r.success, r.message + ' ' + r.errors);
        Pricing_Item__c row = [
            SELECT Focus_Category__c, Service_Category__c
            FROM Pricing_Item__c
            WHERE Catalog_Import__c = :r.catalogImportId
            LIMIT 1
        ];
        System.assertEquals('compute', row.Service_Category__c);
        System.assertEquals('Compute', row.Focus_Category__c);
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

    @IsTest
    static void processFile_pricing_insertsAllRowsWhenPriorMonthExists() {
        String csv =
            'Catalog_Item_Number__c,Title__c,List_Unit_Price__c,JWCC_Unit_Price__c\n' +
            'SKU-A,Alpha,1.25,1\n';
        CatalogUploadService.FileProcessResult first = CatalogUploadService.processFile(
            '2030-01_aws_pricing.csv',
            csv
        );
        System.assertEquals(true, first.success, first.message + ' ' + first.errors);
        System.assertEquals(1, first.rowsInserted);

        CatalogUploadService.FileProcessResult second = CatalogUploadService.processFile(
            '2030-02_aws_pricing.csv',
            csv
        );
        System.assertEquals(true, second.success, second.message + ' ' + second.errors);
        System.assertEquals(1, second.rowsInserted);
        Catalog_Import__c h = [SELECT Row_Count__c FROM Catalog_Import__c WHERE Id = :second.catalogImportId];
        System.assertEquals(1, h.Row_Count__c);
    }
}

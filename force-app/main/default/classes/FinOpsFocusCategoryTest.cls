@IsTest
private class FinOpsFocusCategoryTest {
    @IsTest
    static void normalize_mapsStorageAndNetwork() {
        System.assertEquals('Storage', FinOpsFocusCategory.normalizeFocusCategory('storage'));
        System.assertEquals('Networking', FinOpsFocusCategory.normalizeFocusCategory('network'));
    }

    @IsTest
    static void normalize_iaasPaasSaas() {
        System.assertEquals('Compute', FinOpsFocusCategory.normalizeFocusCategory('IaaS offering'));
        System.assertEquals('Compute', FinOpsFocusCategory.normalizeFocusCategory('PaaS'));
        System.assertEquals('Web and Mobile', FinOpsFocusCategory.normalizeFocusCategory('SaaS app'));
    }

    @IsTest
    static void normalize_blankIsOther() {
        System.assertEquals('Other', FinOpsFocusCategory.normalizeFocusCategory(null));
        System.assertEquals('Other', FinOpsFocusCategory.normalizeFocusCategory(''));
        System.assertEquals('Other', FinOpsFocusCategory.normalizeFocusCategory('n/a'));
    }

    @IsTest
    static void infer_lambdaIsCompute() {
        System.assertEquals(
            'Compute',
            FinOpsFocusCategory.inferFocusCategoryFromText('AWS Lambda function pricing')
        );
    }

    @IsTest
    static void infer_bucketIsStorage() {
        System.assertEquals(
            'Storage',
            FinOpsFocusCategory.inferFocusCategoryFromText('object bucket archive tier')
        );
    }

    @IsTest
    static void resolve_serviceCategoryNormalizesStorage() {
        System.assertEquals(
            'Storage',
            FinOpsFocusCategory.resolveForPricingImport(null, 'storage', '', '', '')
        );
    }

    @IsTest
    static void resolve_inferFromTitleRds() {
        System.assertEquals(
            'Database',
            FinOpsFocusCategory.resolveForPricingImport('', '', 'Amazon RDS PostgreSQL', '', '')
        );
    }

    @IsTest
    static void coalesce_prefersFocus() {
        System.assertEquals('x', FinOpsFocusCategory.coalesceTrim('x', 'y'));
        System.assertEquals('y', FinOpsFocusCategory.coalesceTrim('', 'y'));
    }
}

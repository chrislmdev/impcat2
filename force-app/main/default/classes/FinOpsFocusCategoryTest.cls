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

    @IsTest
    static void normalize_mapSynonyms_cspAndVendors() {
        System.assertEquals('Compute', FinOpsFocusCategory.normalizeFocusCategory('EKS workloads'));
        System.assertEquals('Storage', FinOpsFocusCategory.normalizeFocusCategory('AWS EFS tier'));
        System.assertEquals('Database', FinOpsFocusCategory.normalizeFocusCategory('DynamoDB'));
        System.assertEquals('Analytics', FinOpsFocusCategory.normalizeFocusCategory('Snowflake warehouse'));
        System.assertEquals('Networking', FinOpsFocusCategory.normalizeFocusCategory('Direct Connect port'));
        System.assertEquals('Security', FinOpsFocusCategory.normalizeFocusCategory('zero trust access'));
        System.assertEquals('Management and Governance', FinOpsFocusCategory.normalizeFocusCategory('FinOps dashboard'));
        System.assertEquals('Integration', FinOpsFocusCategory.normalizeFocusCategory('Confluent Cloud'));
    }

    @IsTest
    static void infer_backupAndSnapshot_storage() {
        System.assertEquals(
            'Storage',
            FinOpsFocusCategory.inferFocusCategoryFromText('Automated backup vault retention')
        );
        System.assertEquals(
            'Storage',
            FinOpsFocusCategory.inferFocusCategoryFromText('EBS snapshot copy pricing')
        );
    }

    @IsTest
    static void infer_disasterRecovery_migration() {
        System.assertEquals(
            'Migration and Transfer',
            FinOpsFocusCategory.inferFocusCategoryFromText('Disaster recovery replication to secondary region')
        );
    }

    @IsTest
    static void infer_serviceMesh_networking() {
        System.assertEquals(
            'Networking',
            FinOpsFocusCategory.inferFocusCategoryFromText('Istio service mesh control plane')
        );
    }

    @IsTest
    static void infer_sapImplementation_professionalServices() {
        System.assertEquals(
            'Professional Services',
            FinOpsFocusCategory.inferFocusCategoryFromText('SAP S/4HANA implementation partner')
        );
    }

    @IsTest
    static void infer_sapHanaVm_compute() {
        System.assertEquals(
            'Compute',
            FinOpsFocusCategory.inferFocusCategoryFromText('SAP HANA on Azure VM SKUs')
        );
    }

    @IsTest
    static void infer_observabilityAndCost_governance() {
        System.assertEquals(
            'Management and Governance',
            FinOpsFocusCategory.inferFocusCategoryFromText('Datadog APM host pricing')
        );
        System.assertEquals(
            'Management and Governance',
            FinOpsFocusCategory.inferFocusCategoryFromText('Azure Cost Management exports')
        );
    }

    @IsTest
    static void infer_helm_developerTools() {
        System.assertEquals(
            'Developer Tools',
            FinOpsFocusCategory.inferFocusCategoryFromText('Helm chart registry private')
        );
    }

    @IsTest
    static void resolve_inferFromTextWhenCsvOther() {
        System.assertEquals(
            'Analytics',
            FinOpsFocusCategory.resolveForPricingImport(null, null, 'Databricks SQL warehouse', '', '')
        );
        System.assertEquals(
            'Database',
            FinOpsFocusCategory.resolveForPricingImport('', '', '', 'Amazon OpenSearch', '')
        );
    }

    @IsTest
    static void infer_trulyGeneric_staysOther() {
        System.assertEquals(
            'Other',
            FinOpsFocusCategory.inferFocusCategoryFromText('Miscellaneous catalog line item fee')
        );
        System.assertEquals(
            'Other',
            FinOpsFocusCategory.resolveForPricingImport(null, null, 'Standard adjustment', '', '')
        );
    }
}

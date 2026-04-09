/**
 * Service catalog rows for Cloud Prism (FOCUS category × subcategory × CSP), with popularity for top-N display.
 * Empty org data falls back to in-code mock rows for demos.
 */
public with sharing class CloudPrismServiceCatalogController {
    public class ServiceCatalogRow {
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String csp { get; set; }
        @AuraEnabled
        public String serviceName { get; set; }
        @AuraEnabled
        public String focusCategory { get; set; }
        @AuraEnabled
        public String comparisonSubcategory { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String impactLevel { get; set; }
        @AuraEnabled
        public Decimal popularityScore { get; set; }
        @AuraEnabled
        public String catalogItemNumber { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceCatalogRow> getServiceCatalogRows() {
        List<Service_Catalog_Entry__c> recs = [
            SELECT
                Id,
                CSP__c,
                Service_Name__c,
                Focus_Category__c,
                Comparison_Subcategory__c,
                Description__c,
                Impact_Level__c,
                Popularity_Score__c,
                Catalog_Item_Number__c
            FROM Service_Catalog_Entry__c
            ORDER BY Focus_Category__c, Comparison_Subcategory__c, CSP__c, Popularity_Score__c DESC NULLS LAST, Service_Name__c
        ];
        if (recs.isEmpty()) {
            return buildMockRows();
        }
        List<ServiceCatalogRow> out = new List<ServiceCatalogRow>();
        for (Service_Catalog_Entry__c r : recs) {
            out.add(mapFromSObject(r));
        }
        return out;
    }

    private static ServiceCatalogRow mapFromSObject(Service_Catalog_Entry__c r) {
        ServiceCatalogRow o = new ServiceCatalogRow();
        o.id = r.Id;
        o.csp = r.CSP__c;
        o.serviceName = r.Service_Name__c;
        o.focusCategory = r.Focus_Category__c;
        o.comparisonSubcategory = r.Comparison_Subcategory__c;
        o.description = r.Description__c;
        o.impactLevel = r.Impact_Level__c;
        o.popularityScore = r.Popularity_Score__c != null ? r.Popularity_Score__c : 0;
        o.catalogItemNumber = r.Catalog_Item_Number__c;
        return o;
    }

    /**
     * Demo data when no Service_Catalog_Entry__c rows exist. Matches six-column editorial shape + popularity scores.
     */
    @TestVisible
    static List<ServiceCatalogRow> buildMockRows() {
        List<ServiceCatalogRow> m = new List<ServiceCatalogRow>();
        // Compute / Containers — several AWS services to exercise top-3 + expand
        m.add(mockRow('aws', 'Amazon Elastic Kubernetes Service', 'Compute', 'Containers', 'Managed Kubernetes — control plane and data plane', 'IL2|IL4|IL5', 980));
        m.add(mockRow('aws', 'Amazon ECS', 'Compute', 'Containers', 'Elastic Container Service', 'IL2|IL4', 920));
        m.add(mockRow('aws', 'AWS Fargate', 'Compute', 'Containers', 'Serverless containers', 'IL2|IL4|IL5', 910));
        m.add(mockRow('aws', 'Amazon ECR', 'Compute', 'Containers', 'Container registry', 'IL2|IL4', 860));
        m.add(mockRow('aws', 'AWS App Runner', 'Compute', 'Containers', 'Fully managed app service', 'IL2|IL4', 840));
        m.add(mockRow('azure', 'Azure Kubernetes Service', 'Compute', 'Containers', 'Managed Kubernetes on Azure', 'IL2|IL3|IL4', 970));
        m.add(mockRow('azure', 'Azure Container Instances', 'Compute', 'Containers', 'Burst containers without managing servers', 'IL2|IL4', 880));
        m.add(mockRow('gcp', 'Google Kubernetes Engine', 'Compute', 'Containers', 'Managed Kubernetes on GCP', 'IL2|IL4', 960));
        m.add(mockRow('gcp', 'Cloud Run', 'Compute', 'Containers', 'Serverless for containers', 'IL2|IL4', 900));
        m.add(mockRow('oracle', 'Oracle Kubernetes Engine', 'Compute', 'Containers', 'OCI-managed Kubernetes', 'IL2|IL4', 850));
        // Storage
        m.add(mockRow('aws', 'Amazon S3', 'Storage', 'Object storage', 'Regional durable object storage', 'IL2|IL4', 995));
        m.add(mockRow('azure', 'Azure Blob Storage', 'Storage', 'Object storage', 'Hot/cool/archive tiers', 'IL2|IL4', 990));
        m.add(mockRow('gcp', 'Cloud Storage', 'Storage', 'Object storage', 'Multi-region and dual-region', 'IL2|IL4', 985));
        m.add(mockRow('oracle', 'OCI Object Storage', 'Storage', 'Object storage', 'OCI object store', 'IL2|IL4', 870));
        return m;
    }

    private static ServiceCatalogRow mockRow(
        String csp,
        String serviceName,
        String focusCategory,
        String subcategory,
        String description,
        String impactLevel,
        Integer popularity
    ) {
        ServiceCatalogRow o = new ServiceCatalogRow();
        o.id = null;
        o.csp = csp;
        o.serviceName = serviceName;
        o.focusCategory = focusCategory;
        o.comparisonSubcategory = subcategory;
        o.description = description;
        o.impactLevel = impactLevel;
        o.popularityScore = popularity;
        o.catalogItemNumber = null;
        return o;
    }
}

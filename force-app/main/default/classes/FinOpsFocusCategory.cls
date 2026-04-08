/**
 * FinOps FOCUS-style category labels for pricing rows.
 * Ported from RosettaStone focusInference.js (normalize + infer + resolve order).
 */
public class FinOpsFocusCategory {
    private static final Integer MAX_FOCUS_LEN = 255;

    private static final Map<String, String> FOCUS_CATEGORY_MAP = new Map<String, String>{
        'compute' => 'Compute',
        'amazon ec2' => 'Compute',
        'google compute' => 'Compute',
        'azure vm' => 'Compute',
        'ec2' => 'Compute',
        'eks' => 'Compute',
        'gke' => 'Compute',
        'aks' => 'Compute',
        'vmware' => 'Compute',
        'bare metal' => 'Compute',
        'baremetal' => 'Compute',
        'autoscaling' => 'Compute',
        'storage' => 'Storage',
        'amazon s3' => 'Storage',
        'azure blob' => 'Storage',
        'efs' => 'Storage',
        'ebs' => 'Storage',
        'glacier' => 'Storage',
        'cold storage' => 'Storage',
        'file share' => 'Storage',
        'fileshare' => 'Storage',
        'nas' => 'Storage',
        'netapp' => 'Storage',
        'database' => 'Database',
        'dynamodb' => 'Database',
        'snowflake' => 'Analytics',
        'databricks' => 'Analytics',
        'elasticsearch' => 'Database',
        'opensearch' => 'Database',
        'mongodb' => 'Database',
        'mongo' => 'Database',
        'cassandra' => 'Database',
        'cosmos db' => 'Database',
        'networking' => 'Networking',
        'network' => 'Networking',
        'direct connect' => 'Networking',
        'transit gateway' => 'Networking',
        'peering' => 'Networking',
        'front door' => 'Networking',
        'application gateway' => 'Networking',
        'security' => 'Security',
        'identity' => 'Security',
        'secrets manager' => 'Security',
        'certificate' => 'Security',
        'sso' => 'Security',
        'mfa' => 'Security',
        'zero trust' => 'Security',
        'ai' => 'AI and Machine Learning',
        'machine learning' => 'AI and Machine Learning',
        'ml' => 'AI and Machine Learning',
        'analytics' => 'Analytics',
        'big data' => 'Analytics',
        'power bi' => 'Analytics',
        'looker' => 'Analytics',
        'quicksight' => 'Analytics',
        'etl' => 'Analytics',
        'dataflow' => 'Analytics',
        'developer tools' => 'Developer Tools',
        'devops' => 'Developer Tools',
        'management' => 'Management and Governance',
        'governance' => 'Management and Governance',
        'monitoring' => 'Management and Governance',
        'cost explorer' => 'Management and Governance',
        'cloudhealth' => 'Management and Governance',
        'finops' => 'Management and Governance',
        'chargeback' => 'Management and Governance',
        'billing' => 'Management and Governance',
        'budget' => 'Management and Governance',
        'serverless' => 'Compute',
        'containers' => 'Compute',
        'web' => 'Web and Mobile',
        'mobile' => 'Web and Mobile',
        'iot' => 'Internet of Things',
        'integration' => 'Integration',
        'messaging' => 'Integration',
        'api gateway' => 'Integration',
        'kafka' => 'Integration',
        'mulesoft' => 'Integration',
        'confluent' => 'Integration',
        'media' => 'Media Services',
        'migration' => 'Migration and Transfer',
        'transfer' => 'Migration and Transfer',
        'end user computing' => 'End User Computing',
        'desktop' => 'End User Computing',
        'professional services' => 'Professional Services',
        'pro services' => 'Professional Services'
    };

    private static List<String> sortedMapKeys;

    private static final Pattern PAT_IAAS = Pattern.compile('(?i)\\biaas\\b');
    private static final Pattern PAT_PAAS = Pattern.compile('(?i)\\bpaas\\b');
    private static final Pattern PAT_SAAS = Pattern.compile('(?i)\\bsaas\\b');

    private static final Pattern INF_1_PRO_SERVICES = Pattern.compile(
        '(?i)(professional services|managed service|technical account|tam|consulting|implementation service|support plan|premier support|training workshop|advisory|pro services)'
    );
    /** SAP / ERP + implementation or consulting → Professional Services (before generic ERP/compute). */
    private static final Pattern INF_1B_SAP_IMPLEMENTATION = Pattern.compile(
        '(?i)(sap|s4hana|s 4hana|hana enterprise|erp).*(implementation|consulting|advisory|professional service|migration project)|(implementation|consulting|advisory).*(sap|s4hana|s 4hana|hana enterprise|erp)'
    );
    private static final Pattern INF_2_AI = Pattern.compile(
        '(?i)(bedrock|openai|vertex|genai|machine learning|\\bai\\b|inference|embedding|neural|model|token|ml )'
    );
    private static final Pattern INF_3_ANALYTICS = Pattern.compile(
        '(?i)(analytics|bigquery|synapse|athena|data lake|warehouse|spark|big data|databricks|snowflake|power bi|looker|quicksight|etl|dataflow)'
    );
    /** SAP HANA / S/4 on VM-style hosting → Compute (before Database catches “hana”). */
    private static final Pattern INF_3B_SAP_COMPUTE = Pattern.compile(
        '(?i)((sap hana|s4hana|s4 hana|sap netweaver).*(vm|virtual|instance|compute|hosting|infrastructure|hyperscaler)|\\b(sap|erp)\\b.*\\b(vm|virtual machine|instance|compute|hosting)\\b)'
    );
    private static final Pattern INF_4_DATABASE = Pattern.compile(
        '(?i)(database|sql|nosql|rds|postgres|mysql|cosmos|spanner|redis|caching|dynamodb|mongo|cassandra|elasticsearch|opensearch|\\bhana\\b)'
    );
    private static final Pattern INF_5_SECURITY = Pattern.compile(
        '(?i)(security|iam|kms|waf|guardduty|sentinel|defender|siem|threat|key management|secrets|certificate|sso|mfa|zero trust)'
    );
    private static final Pattern INF_6_INTEGRATION = Pattern.compile(
        '(?i)(api gateway|service bus|event hub|event grid|pub\\.?sub|pubsub|messaging|queue|integration|workflow|orchestration|apim|kafka|confluent|mulesoft)'
    );
    private static final Pattern INF_7_NETWORK = Pattern.compile(
        '(?i)(network|vpc|vpn|dns|load balancer|cdn|egress|firewall|expressroute|interconnect|nat gateway|service mesh|istio|linkerd|app mesh|peering|transit gateway|direct connect)'
    );
    private static final Pattern INF_8_STORAGE = Pattern.compile(
        '(?i)(storage|object|bucket|archive|block|blob|volume|disk|s3 |backup|snapshot|point in time)'
    );
    private static final Pattern INF_9_COMPUTE = Pattern.compile(
        '(?i)(compute|vm|virtual machine|instance|kubernetes|container|serverless|lambda|function|engine|ocpu)'
    );
    private static final Pattern INF_10_DEVOPS = Pattern.compile(
        '(?i)(devops|developer|pipeline|artifact|repo|build|deploy|helm)'
    );
    private static final Pattern INF_11_GOV = Pattern.compile(
        '(?i)(monitor|governance|policy|logging|observability|control tower|apm|tracing|grafana|datadog|new relic|prometheus|cost management|cloudhealth|finops|chargeback|cost explorer|cloudability|budget)'
    );
    private static final Pattern INF_12_MIGRATE = Pattern.compile(
        '(?i)(migrate|migration|transfer|data movement|disaster recovery|\\bdr\\b|geo replication|geo.?replication|cross.region replication)'
    );
    private static final Pattern INF_13_EUC = Pattern.compile(
        '(?i)(desktop|avd|virtual desktop|end user)'
    );
    private static final Pattern INF_14_MEDIA = Pattern.compile(
        '(?i)(media|streaming|video|transcode)'
    );
    private static final Pattern INF_15_IOT = Pattern.compile(
        '(?i)(iot|internet of things|device twin)'
    );
    private static final Pattern INF_16_WEB_MOBILE = Pattern.compile(
        '(?i)(mobile|app service|web app)'
    );

    private static List<String> keysByLengthDesc() {
        if (sortedMapKeys != null) {
            return sortedMapKeys;
        }
        List<String> keys = new List<String>(FOCUS_CATEGORY_MAP.keySet());
        sortedMapKeys = new List<String>();
        while (!keys.isEmpty()) {
            Integer best = 0;
            for (Integer i = 1; i < keys.size(); i++) {
                Integer lb = keys[best].length();
                Integer li = keys[i].length();
                if (li > lb) {
                    best = i;
                } else if (li == lb && keys[i].compareTo(keys[best]) < 0) {
                    best = i;
                }
            }
            sortedMapKeys.add(keys.remove(best));
        }
        return sortedMapKeys;
    }

    /**
     * First non-blank trimmed string (Rosetta: category || service_category).
     */
    @TestVisible
    static String coalesceTrim(String a, String b) {
        if (!String.isBlank(a)) {
            return a.trim();
        }
        if (!String.isBlank(b)) {
            return b.trim();
        }
        return '';
    }

    @TestVisible
    static String squishLower(String lower) {
        if (String.isBlank(lower)) {
            return '';
        }
        String s = lower.replaceAll('[^a-z0-9]+', ' ').trim();
        while (s.contains('  ')) {
            s = s.replace('  ', ' ');
        }
        return s.trim();
    }

    /**
     * Aligns with focusInference.js normalizeFocusCategory.
     */
    @TestVisible
    static String normalizeFocusCategory(String rawCategory) {
        if (rawCategory == null || String.isBlank(rawCategory)) {
            return 'Other';
        }
        String raw = rawCategory.trim();
        String lower = raw.toLowerCase();
        if (lower == 'all' || lower == 'any' || lower == '*' || lower == 'n/a' || lower == 'na') {
            return 'Other';
        }
        if (lower == 'te' || lower == 't&e' || lower == 't and e') {
            return 'Other';
        }
        String squish = squishLower(lower);
        if (squish == 'iaas' || PAT_IAAS.matcher(lower).find()) {
            return 'Compute';
        }
        if (squish == 'paas' || PAT_PAAS.matcher(lower).find()) {
            return 'Compute';
        }
        if (squish == 'saas' || PAT_SAAS.matcher(lower).find()) {
            return 'Web and Mobile';
        }
        for (String key : keysByLengthDesc()) {
            if (lower.contains(key)) {
                return FOCUS_CATEGORY_MAP.get(key);
            }
        }
        return String.isBlank(raw) ? 'Other' : raw;
    }

    /**
     * Aligns with focusInference.js inferFocusCategoryFromText (input lowercased + non-alnum to space).
     */
    @TestVisible
    static String inferFocusCategoryFromText(String text) {
        if (text == null || String.isBlank(text)) {
            return 'Other';
        }
        String t = text.toLowerCase().replaceAll('[^a-z0-9]+', ' ').trim();
        while (t.contains('  ')) {
            t = t.replace('  ', ' ');
        }
        if (String.isBlank(t)) {
            return 'Other';
        }
        if (INF_1_PRO_SERVICES.matcher(t).find()) {
            return 'Professional Services';
        }
        if (INF_1B_SAP_IMPLEMENTATION.matcher(t).find()) {
            return 'Professional Services';
        }
        if (INF_2_AI.matcher(t).find()) {
            return 'AI and Machine Learning';
        }
        if (INF_3_ANALYTICS.matcher(t).find()) {
            return 'Analytics';
        }
        if (INF_3B_SAP_COMPUTE.matcher(t).find()) {
            return 'Compute';
        }
        if (INF_4_DATABASE.matcher(t).find()) {
            return 'Database';
        }
        if (INF_5_SECURITY.matcher(t).find()) {
            return 'Security';
        }
        if (INF_6_INTEGRATION.matcher(t).find()) {
            return 'Integration';
        }
        if (INF_7_NETWORK.matcher(t).find()) {
            return 'Networking';
        }
        if (INF_8_STORAGE.matcher(t).find()) {
            return 'Storage';
        }
        if (INF_9_COMPUTE.matcher(t).find()) {
            return 'Compute';
        }
        if (INF_10_DEVOPS.matcher(t).find()) {
            return 'Developer Tools';
        }
        if (INF_11_GOV.matcher(t).find()) {
            return 'Management and Governance';
        }
        if (INF_12_MIGRATE.matcher(t).find()) {
            return 'Migration and Transfer';
        }
        if (INF_13_EUC.matcher(t).find()) {
            return 'End User Computing';
        }
        if (INF_14_MEDIA.matcher(t).find()) {
            return 'Media Services';
        }
        if (INF_15_IOT.matcher(t).find()) {
            return 'Internet of Things';
        }
        if (INF_16_WEB_MOBILE.matcher(t).find()) {
            return 'Web and Mobile';
        }
        return 'Other';
    }

    /**
     * Same order as resolvePricingFocusCategory in focusInference.js.
     */
    public static String resolveForPricingImport(
        String focusCell,
        String serviceCategoryCell,
        String title,
        String shortName,
        String description
    ) {
        String combined = coalesceTrim(focusCell, serviceCategoryCell);
        String fromCsv = normalizeFocusCategory(combined);
        String result;
        if (fromCsv != 'Other') {
            result = fromCsv;
        } else {
            String joined =
                (title != null ? title : '') +
                ' ' +
                (shortName != null ? shortName : '') +
                ' ' +
                (description != null ? description : '');
            result = inferFocusCategoryFromText(joined);
        }
        if (result != null && result.length() > MAX_FOCUS_LEN) {
            return result.substring(0, MAX_FOCUS_LEN);
        }
        return result;
    }
}

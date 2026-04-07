/**
 * FinOps FOCUS-style category labels for pricing rows.
 * Ported from RosettaStone focusInference.js (normalize + infer + resolve order).
 */
public class FinOpsFocusCategory {
    private static final Integer MAX_FOCUS_LEN = 255;

    private static final Map<String, String> FOCUS_CATEGORY_MAP = new Map<String, String>{
        'compute' => 'Compute',
        'storage' => 'Storage',
        'database' => 'Database',
        'networking' => 'Networking',
        'network' => 'Networking',
        'security' => 'Security',
        'identity' => 'Security',
        'ai' => 'AI and Machine Learning',
        'machine learning' => 'AI and Machine Learning',
        'ml' => 'AI and Machine Learning',
        'analytics' => 'Analytics',
        'big data' => 'Analytics',
        'developer tools' => 'Developer Tools',
        'devops' => 'Developer Tools',
        'management' => 'Management and Governance',
        'governance' => 'Management and Governance',
        'monitoring' => 'Management and Governance',
        'serverless' => 'Compute',
        'containers' => 'Compute',
        'web' => 'Web and Mobile',
        'mobile' => 'Web and Mobile',
        'iot' => 'Internet of Things',
        'integration' => 'Integration',
        'messaging' => 'Integration',
        'api gateway' => 'Integration',
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
    private static final Pattern INF_2_AI = Pattern.compile(
        '(?i)(bedrock|openai|vertex|genai|machine learning|\\bai\\b|inference|embedding|neural|model|token|ml )'
    );
    private static final Pattern INF_3_ANALYTICS = Pattern.compile(
        '(?i)(analytics|bigquery|synapse|athena|data lake|warehouse|spark|big data)'
    );
    private static final Pattern INF_4_DATABASE = Pattern.compile(
        '(?i)(database|sql|nosql|rds|postgres|mysql|cosmos|spanner|redis|caching)'
    );
    private static final Pattern INF_5_SECURITY = Pattern.compile(
        '(?i)(security|iam|kms|waf|guardduty|sentinel|defender|siem|threat|key management)'
    );
    private static final Pattern INF_6_INTEGRATION = Pattern.compile(
        '(?i)(api gateway|service bus|event hub|event grid|pub\\.?sub|pubsub|messaging|queue|integration|workflow|orchestration|apim)'
    );
    private static final Pattern INF_7_NETWORK = Pattern.compile(
        '(?i)(network|vpc|vpn|dns|load balancer|cdn|egress|firewall|expressroute|interconnect|nat gateway)'
    );
    private static final Pattern INF_8_STORAGE = Pattern.compile(
        '(?i)(storage|object|bucket|archive|block|blob|volume|disk|s3 )'
    );
    private static final Pattern INF_9_COMPUTE = Pattern.compile(
        '(?i)(compute|vm|virtual machine|instance|kubernetes|container|serverless|lambda|function|engine|ocpu)'
    );
    private static final Pattern INF_10_DEVOPS = Pattern.compile(
        '(?i)(devops|developer|pipeline|artifact|repo|build|deploy)'
    );
    private static final Pattern INF_11_GOV = Pattern.compile(
        '(?i)(monitor|governance|policy|logging|observability|control tower)'
    );
    private static final Pattern INF_12_MIGRATE = Pattern.compile(
        '(?i)(migrate|migration|transfer|data movement)'
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
        if (INF_2_AI.matcher(t).find()) {
            return 'AI and Machine Learning';
        }
        if (INF_3_ANALYTICS.matcher(t).find()) {
            return 'Analytics';
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

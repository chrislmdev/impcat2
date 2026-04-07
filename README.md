# impcat2

## Salesforce CloudPrism POC (this repo)

This workspace includes a Salesforce DX project under `force-app/` for a dev-org POC: **Pricing Catalog**, **Exceptions Library**, **Catalog Changes** (month-over-month diffs), and **Bulk upload** (multi-file CSV into `Catalog_Import__c` and children, small files only).

### Documentation

- **[docs/README.md](docs/README.md)** — index  
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — layers, components, security, diagrams  
- **[docs/DATA_MODEL.md](docs/DATA_MODEL.md)** — objects and relationships  
- **[docs/FLOWS.md](docs/FLOWS.md)** — end-to-end flows (Mermaid)  
- **[docs/DEPENDENCIES_AND_TOOLING.md](docs/DEPENDENCIES_AND_TOOLING.md)** — stock Salesforce vs local CLI; no extra org packages  
- **[docs/MULESOFT_CATALOG_INGEST.md](docs/MULESOFT_CATALOG_INGEST.md)** — when to use MuleSoft / Bulk API 2.0 instead of in-app upload  

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- A dev org or scratch org

### Deploy

```powershell
cd j:\git\impcat2-1
sf org login web --alias cloudprism-poc --set-default
sf project deploy start --source-dir force-app
```

Assign the **CloudPrism_POC** permission set to your user (Setup → Permission Sets → CloudPrism_POC → Manage Assignments). That set includes object access plus field-level security on the optional custom fields (required fields and master-detail columns are always available when you have object access). Without read access to a field, **anonymous Apex** that references it fails to compile with errors like “Field does not exist,” even though the field exists in Setup.

Open the **CloudPrism** app from the App Launcher and use the **Pricing**, **Exceptions**, **Catalog Changes**, and **Bulk upload** tabs.

**Bulk upload:** name each file `{YYYY-MM}_{csp}_{schema}.csv` (for example `2026-02_aws_pricing.csv`). Headers must match field API names. The UI enforces modest row and size limits; for very large catalogs, use integration (see **MULESOFT_CATALOG_INGEST.md**).

### Tests

```powershell
sf apex run test --tests CloudPrismCatalogTest --result-format human --code-coverage --wait 10
sf apex run test --tests CatalogUploadServiceTest --result-format human --code-coverage --wait 10
```

### Sample data (two months)

After deploy, assign **CloudPrism_POC** (if not already), then load demo rows with Anonymous Apex:

```powershell
sf org assign permset --name CloudPrism_POC
sf apex run --file scripts/sample-data.apex
```

If `assign permset` reports a duplicate assignment, your user already has the set; run the Apex line only.

That script inserts **16** `Catalog_Import__c` headers (four CSPs × **pricing** and **exceptions** × `2026-01` and `2026-02`), each with `Row_Count__c = 2`, plus **16** `Pricing_Item__c` and **16** `Exception_Item__c` rows. Every CSP gets the same story: pricing **removed / updated / added** and exceptions **updated / removed / added** between January and February so **Catalog Changes** is easy to demo with **All CSPs** or per-CSP filters. **Do not re-run** on the same org without deleting prior demo imports first, or you will duplicate month/CSP/schema headers.

For Data Loader instead: create the parent `Catalog_Import__c` rows you need, note their Ids, then bulk-insert children with `Catalog_Import__c` set to the parent Id. CSV column headers must match field API names.
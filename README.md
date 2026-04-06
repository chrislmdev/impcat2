# impcat2

## Salesforce CloudPrism POC (this repo)

This workspace includes a Salesforce DX project under `force-app/` for a dev-org POC: **Pricing Catalog**, **Exceptions Library**, and **Catalog Changes** (month-over-month diffs).

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- A dev org or scratch org

### Deploy

```powershell
cd j:\git\impcat2-1
sf org login web --alias cloudprism-poc --set-default
sf project deploy start --source-dir force-app
```

Assign the **CloudPrism_POC** permission set to your user (Setup → Permission Sets → CloudPrism_POC → Manage Assignments).

Open the **CloudPrism** app from the App Launcher and use the **Pricing**, **Exceptions**, and **Catalog Changes** tabs.

### Tests

```powershell
sf apex run test --tests CloudPrismCatalogTest --result-format human --code-coverage --wait 10
```

### Sample data (two months)

After deploy, load demo rows with Anonymous Apex:

```powershell
sf apex run --file scripts/sample-data.apex
```

That script inserts `Catalog_Import__c` headers for `2026-01` and `2026-02` (pricing and exceptions) plus child `Pricing_Item__c` and `Exception_Item__c` rows with intentional adds, removes, and updates. Use **Catalog Changes** with **From** `2026-01` and **To** `2026-02` to verify.

For Data Loader instead: create four `Catalog_Import__c` records first (two months × pricing/exceptions), note their Ids, then bulk-insert children with `Catalog_Import__c` set to the parent Id. CSV column headers must match field API names.
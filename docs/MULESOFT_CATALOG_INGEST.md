# MuleSoft and large-catalog ingest (outside the POC UI)

The **Bulk upload** tab in the CloudPrism app is intentionally **small-file only**: it guards row count and payload size so interactive users do not hit Apex heap, CPU, or synchronous timeout limits.

## When to use integration instead

Use **MuleSoft** (or another integration layer), often fed from **SharePoint** or an export pipeline, when:

- Catalogs approach **hundreds of thousands or millions of rows** per month.
- Files exceed the in-app limits documented in the app banner and in [README.md](../README.md).
- You need **scheduling, retries, monitoring, and idempotent loads** at enterprise scale.

## Recommended Salesforce API

For large volumes, prefer **Bulk API 2.0**:

- Chunk large CSV input into jobs Salesforce can process asynchronously.
- Avoid long-running synchronous Apex for whole-file parsing.

High-level flow:

1. **Land** the authoritative file in a controlled store (e.g. SharePoint) or object storage.
2. **MuleSoft** validates naming and schema, then creates a Bulk API 2.0 job and uploads batches.
3. **Salesforce** persists `Catalog_Import__c` parents and child `Pricing_Item__c` / `Exception_Item__c` rows (same object model as the POC).
4. **Optional:** post-job callback or polling in MuleSoft to set `Catalog_Import__c.Status__c` and `Row_Count__c` to match your operational semantics.

## Filename convention (same as in-app upload)

Align automation with the interactive convention:

`{YYYY-MM}_{csp}_{schema}.csv`

- `csp`: `aws`, `azure`, `gcp`, `oracle`
- `schema`: `pricing`, `exceptions`, or `parent` (header-only parent row in Salesforce; no child lines required for `parent`)

CSV column headers should match **Salesforce field API names**, consistent with Data Loader and the bulk-upload LWC.

## Security

Grant the integration user a **dedicated permission set** (or integration profile) with least privilege: create on `Catalog_Import__c`, `Pricing_Item__c`, and `Exception_Item__c`, plus field access as required. Do not reuse personal user accounts for unattended loads.

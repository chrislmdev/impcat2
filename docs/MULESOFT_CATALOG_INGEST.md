# MuleSoft and large-catalog ingest (outside the POC UI)

The in-app **Bulk upload** tab only accepts **small** files so interactive users stay within Apex limits. For large or automated loads, use **Bulk API 2.0** from the CLI, **MuleSoft**, or another integration.

## When to use integration

- Very large row counts or files beyond the in-app limits ([README.md](../README.md), in-app banner).
- You need **scheduling, retries, monitoring**, or **idempotent** enterprise-scale loads.

Typical pattern: land files in a controlled store → integration validates and uploads via **Bulk API 2.0** → Salesforce inserts `Catalog_Import__c` and child `Pricing_Item__c` / `Exception_Item__c` rows (same model as this POC).

## The three steps (pricing bulk load)

1. **Standardize** the CSP export to Bulk-ready `Pricing_Item__c` columns (Python **stdlib only** — no pip packages).
2. **Import** the parent `Catalog_Import__c` row, then **patch** child rows with the real parent Id (`sf__Id`), then **import** `Pricing_Item__c`.
3. **Match line endings** to your CSV bytes on every `sf data import bulk` (see table below).

Step 1 uses the same header **fingerprints and aliases** as in-app upload ([`CatalogUploadService.cls`](../force-app/main/default/classes/CatalogUploadService.cls)). Optional JSON maps cover CSP-specific column names beyond the shared config.

## Line endings and `sf`

| Environment | Typical | `sf` flag |
|-------------|---------|-----------|
| Windows | CRLF | `--line-ending CRLF` |
| macOS / Linux | LF | `--line-ending LF` |

Mismatch causes `ClientInputError: LineEnding is invalid on user data`.

## Step 1 — Standardize pricing CSV

**Prerequisite:** [Python 3](https://www.python.org/downloads/) on PATH (`python3` or `python`). No extra libraries.

| Artifact | Role |
|----------|------|
| [`standardize_pricing_csv.py`](../demo-data/bulk-api-test/standardize_pricing_csv.py) | Core: reads config, rewrites headers, fills `Catalog_Import__c` placeholder and `CSP__c` |
| [`catalog_pricing_standard_config.json`](../demo-data/bulk-api-test/catalog_pricing_standard_config.json) | Preferred column order + aliases (keep in sync with Apex when aliases change) |
| [`standardize-pricing-csv.ps1`](../demo-data/bulk-api-test/standardize-pricing-csv.ps1) | Windows launcher |
| [`standardize-pricing-csv.sh`](../demo-data/bulk-api-test/standardize-pricing-csv.sh) | Mac/Linux launcher (`chmod +x` once per clone) |
| [`pricing_column_map.example.json`](../demo-data/bulk-api-test/pricing_column_map.example.json) | Optional **`column_mappings`** for extra source header → API name |

Examples:

```powershell
cd <repo-root>
.\demo-data\bulk-api-test\standardize-pricing-csv.ps1 --input .\raw.csv --output .\bulk-ready.csv --csp aws --line-ending CRLF
# Optional quirks: --map .\my_map.json
```

```bash
cd <repo-root>
./demo-data/bulk-api-test/standardize-pricing-csv.sh --input ./raw.csv --output ./bulk-ready.csv --csp aws --line-ending LF
```

You can then run `sf data import bulk` yourself, or use **Step 2** wizard which calls the same standardizer.

## Step 2 — Wizard (parent import, patch, child import)

**Needs:** `sf` on PATH, logged-in org, **Python 3** (same as Step 1).

| File | Role |
|------|------|
| [`write-bulk-import-csv.ps1`](../demo-data/bulk-api-test/write-bulk-import-csv.ps1) | Windows: writes parent CSV, runs standardizer, walks `sf` bulk + results + replace |
| [`write-bulk-import-csv.sh`](../demo-data/bulk-api-test/write-bulk-import-csv.sh) | Same on macOS/Linux |
| [`replace-pricing-parent-id.ps1` / `.sh`](../demo-data/bulk-api-test/replace-pricing-parent-id.ps1) | Replaces parent placeholder in `pricing_*.csv` with `sf__Id` |

```powershell
.\demo-data\bulk-api-test\write-bulk-import-csv.ps1 -Interactive
# Optional: -PricingCsv "...\source.csv" -ColumnMapPath "...\extra-map.json"
```

```bash
./demo-data/bulk-api-test/write-bulk-import-csv.sh --interactive
# Optional: --pricing-csv /path/source.csv --column-map /path/extra-map.json
```

**Important:** Use placeholder `PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV` in **`Catalog_Import__c`** until you patch with **`sf__Id`** from `*-success-records.csv`. Do **not** use the bulk **Job Id** (`750…`) as the parent Id on child rows.

Once per clone (Unix): `chmod +x demo-data/bulk-api-test/write-bulk-import-csv.sh demo-data/bulk-api-test/replace-pricing-parent-id.sh demo-data/bulk-api-test/standardize-pricing-csv.sh`

## Step 3 — Manual CLI only (no wizard)

1. **Parent:** `sf data import bulk --sobject Catalog_Import__c --file ... -o YOUR_ORG --wait 10m --line-ending <CRLF|LF>`
2. **Results:** `sf data bulk results -o YOUR_ORG --job-id JOB_ID` (Job Id often `750…`; use only for this call).
3. **Id:** From `*-success-records.csv`, copy **`sf__Id`** (not the Job Id).
4. **Patch:** `replace-pricing-parent-id` with the new Id, or edit the pricing CSV manually.
5. **Children:** `sf data import bulk --sobject Pricing_Item__c --file ...` with matching `--line-ending`.
6. **Failures:** `sf data bulk results` using the child job id.

**Lost the success CSV?**

```text
sf data query -o YOUR_ORG -q "SELECT Id FROM Catalog_Import__c WHERE Import_Month__c = '2025-12' AND CSP__c = 'aws' AND Schema__c = 'pricing'"
```

## File naming (same as UI)

`{YYYY-MM}_{csp}_{schema}.csv` — `csp`: `aws` | `azure` | `gcp` | `oracle`; `schema`: `pricing` | `exceptions` | `parent`.

## Security

Use a **dedicated integration user** with least privilege: create access on `Catalog_Import__c`, `Pricing_Item__c`, and `Exception_Item__c`, plus required fields. Avoid personal accounts for unattended jobs.

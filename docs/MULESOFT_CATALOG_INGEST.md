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

### Salesforce CLI: line endings and demo CSV helpers

Bulk API 2.0 requires the CSV **bytes** to match the job’s **`--line-ending`** value. If they differ, you get `ClientInputError: LineEnding is invalid on user data`.

| Environment | Typical file | Use with `sf` |
|-------------|--------------|----------------|
| Windows | **CRLF** | `--line-ending CRLF` |
| macOS / Linux | **LF** | `--line-ending LF` |

Regenerate the sample files under [`demo-data/bulk-api-test/`](../demo-data/bulk-api-test/) after editing:

| Script | OS | Default ending |
|--------|-----|----------------|
| [`write-demo-csv.ps1`](../demo-data/bulk-api-test/write-demo-csv.ps1) | Windows (PowerShell) | CRLF |
| [`write-demo-csv.sh`](../demo-data/bulk-api-test/write-demo-csv.sh) | macOS / Linux (bash) | LF (`./write-demo-csv.sh CRLF` for Windows-style files) |

From the `demo-data/bulk-api-test` directory on a Mac, once per clone: `chmod +x write-demo-csv.sh replace-pricing-parent-id.sh`.

Optional env vars for `write-demo-csv.sh`: `CATALOG_IMPORT_ID=a0XXX` (skip manual find/replace if you already have the parent Id).

### Guided wizard (pricing only, non-technical)

**Prerequisites:** [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) on your PATH; an authenticated org (`sf org login web` or similar). **Pricing / `Pricing_Item__c` only** — exceptions and other schemas are not covered by this wizard.

The scripts prompt for **calendar year**, **month**, **CSP** (`aws` / `azure` / `gcp` / `oracle`), optional **Source_File__c** / **Imported_At__c** / **Imported_By__c**, then **org alias**, **line ending**, and walk through parent import, **`sf data bulk results`**, **`sf__Id`** extraction, patching the pricing CSV, and child import. Output files are named `catalog_import_<csp>_<YYYY-MM>.csv` and `pricing_items_<csp>_<YYYY-MM>.csv`. Bulk results are written under `demo-data/bulk-api-test/.bulk-results/` to avoid clashing with other folders.

**Windows (PowerShell)** — if execution policy blocks scripts: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (one-time).

```powershell
cd <repo-root>
.\demo-data\bulk-api-test\write-demo-csv.ps1 -Interactive
```

**macOS / Linux**

```bash
cd <repo-root>
chmod +x demo-data/bulk-api-test/write-demo-csv.sh demo-data/bulk-api-test/replace-pricing-parent-id.sh
./demo-data/bulk-api-test/write-demo-csv.sh --interactive
```

**One-shot replace (already have `sf__Id`):** [`replace-pricing-parent-id.sh`](../demo-data/bulk-api-test/replace-pricing-parent-id.sh) `[new_id] [optional/path/to/pricing.csv]`. If you omit the path, the script picks the only `pricing_items_*.csv` in that folder, or **asks you to choose** if several exist. Windows: [`replace-pricing-parent-id.ps1`](../demo-data/bulk-api-test/replace-pricing-parent-id.ps1) `-NewId a0XXX` (optional `-CsvPath` — same auto-pick / prompt behavior).

### Step-by-step: Salesforce CLI pricing import (parent, then children)

Use this when loading **`Catalog_Import__c`** first, then **`Pricing_Item__c`** (same idea for exceptions with **`Exception_Item__c`**).

1. **Import the parent snapshot** (run from repo root; adjust paths if needed). **Match `--line-ending` to your CSV** (CRLF on Windows, LF on Mac by default).

   **Windows (PowerShell)**

   ```powershell
   sf data import bulk --sobject Catalog_Import__c --file "demo-data/bulk-api-test/catalog_import_aws_2025-12.csv" --target-org YOUR_ORG_ALIAS --wait 10m --line-ending CRLF
   ```

   **macOS / Linux (bash)**

   ```bash
   sf data import bulk --sobject Catalog_Import__c --file "demo-data/bulk-api-test/catalog_import_aws_2025-12.csv" --target-org YOUR_ORG_ALIAS --wait 10m --line-ending LF
   ```

   Wait until the job finishes successfully.

2. **Download results** for that bulk job using the **Bulk ingest Job Id** from the CLI output (often starts with `750` — use this id only to call `sf data bulk results`, not as a lookup on child rows):

   ```text
   sf data bulk results -o YOUR_ORG_ALIAS --job-id JOB_ID_FROM_PREVIOUS_COMMAND
   ```

   This creates `*-success-records.csv` and `*-failed-records.csv` in the current working directory.

3. **Open `*-success-records.csv`** and copy the value in the **`sf__Id`** column. That is the **Salesforce Id of the new `Catalog_Import__c` record** (custom object ids often start with `a0`…).  
   **Do not** put the Bulk Job Id (`750…`) in the **`Catalog_Import__c`** column on pricing rows — Salesforce returns `id value of incorrect type`.

4. **Point the child CSV at that parent Id**

   - **Manual:** in `demo-data/bulk-api-test/pricing_items_aws_2025-12.csv`, find/replace the placeholder in the **`Catalog_Import__c`** column with **`sf__Id`**. Prefer **VS Code** or **Notepad++**; avoid **Excel** for this edit (it can break CSV structure or line endings).
   - **macOS / Linux:** `./replace-pricing-parent-id.sh 'a0XXXXXXXXXXXXXXX'` (optional second arg: explicit path; otherwise auto-pick or prompt among `pricing_items_*.csv`).
   - **Windows:** `.\replace-pricing-parent-id.ps1 -NewId 'a0XXXXXXXXXXXXXXX'` (optional `-CsvPath`; otherwise same auto-pick / prompt).

5. **Import pricing lines** (again, **line-ending must match the file**):

   **Windows**

   ```powershell
   sf data import bulk --sobject Pricing_Item__c --file "demo-data/bulk-api-test/pricing_items_aws_2025-12.csv" --target-org YOUR_ORG_ALIAS --wait 10m --line-ending CRLF
   ```

   **macOS / Linux**

   ```bash
   sf data import bulk --sobject Pricing_Item__c --file "demo-data/bulk-api-test/pricing_items_aws_2025-12.csv" --target-org YOUR_ORG_ALIAS --wait 10m --line-ending LF
   ```

6. **If rows fail:** run `sf data bulk results` with the **new** job id and inspect `*-failed-records.csv`.

**If you no longer have the success CSV:** query the parent Id, for example:

```text
sf data query -o YOUR_ORG_ALIAS -q "SELECT Id FROM Catalog_Import__c WHERE Import_Month__c = '2025-12' AND CSP__c = 'aws' AND Schema__c = 'pricing'"
```

## Security

Grant the integration user a **dedicated permission set** (or integration profile) with least privilege: create on `Catalog_Import__c`, `Pricing_Item__c`, and `Exception_Item__c`, plus field access as required. Do not reuse personal user accounts for unattended loads.

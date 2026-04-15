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

### Salesforce CLI: line endings and bulk import CSV helpers

Bulk API 2.0 requires the CSV **bytes** to match the job’s **`--line-ending`** value. If they differ, you get `ClientInputError: LineEnding is invalid on user data`.

| Environment | Typical file | Use with `sf` |
|-------------|--------------|----------------|
| Windows | **CRLF** | `--line-ending CRLF` |
| macOS / Linux | **LF** | `--line-ending LF` |

Files under [`demo-data/bulk-api-test/`](../demo-data/bulk-api-test/):

| Artifact | Purpose |
|----------|---------|
| [`write-bulk-import-csv.ps1`](../demo-data/bulk-api-test/write-bulk-import-csv.ps1) | Windows: parent CSV template, optional pricing **column remap**, interactive wizard (default line ending **CRLF**) |
| [`write-bulk-import-csv.sh`](../demo-data/bulk-api-test/write-bulk-import-csv.sh) | macOS / Linux: same (`./write-bulk-import-csv.sh CRLF` for Windows-style parent file) |
| [`convert_pricing_csv_to_api.py`](../demo-data/bulk-api-test/convert_pricing_csv_to_api.py) | Bash path uses Python 3 to remap headers; PowerShell can remap without Python |
| [`pricing_column_map.example.json`](../demo-data/bulk-api-test/pricing_column_map.example.json) | Copy to your own map: **source column title → Salesforce API name** |

From `demo-data/bulk-api-test` on a Mac, once per clone: `chmod +x write-bulk-import-csv.sh replace-pricing-parent-id.sh`.

Optional env for `write-bulk-import-csv.sh`: `IMPORT_MONTH`, `CSP`, `LINE_ENDING`; for the wizard, `PRICING_CSV` and `PRICING_COLUMN_MAP` match `--pricing-csv` and `--column-map`.

### Guided wizard (pricing only, non-technical)

**Prerequisites:** [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) on your PATH; an authenticated org (`sf org login web` or similar). **Bash wizard also requires Python 3** for header remapping (`convert_pricing_csv_to_api.py`). **Pricing / `Pricing_Item__c` only** — exceptions and other schemas are not covered by this wizard.

The scripts prompt for **calendar year**, **month**, **CSP** (`aws` / `azure` / `gcp` / `oracle`), **path to your source pricing export** (required), optional **column map JSON** (if your file does not already use `*__c` API names), optional **Source_File__c** / **Imported_At__c** / **Imported_By__c**, then **org alias**, **line ending**, and walk through parent import, **`sf data bulk results`**, **`sf__Id`** extraction, patching the converted pricing file, and child import. The wizard writes `catalog_import_<csp>_<YYYY-MM>.csv` and a converted `pricing_for_bulk_<csp>_<YYYY-MM>.csv` next to the script (your original export is not modified). Bulk results are written under `demo-data/bulk-api-test/.bulk-results/`.

**Windows (PowerShell)** — if execution policy blocks scripts: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (one-time).

```powershell
cd <repo-root>
.\demo-data\bulk-api-test\write-bulk-import-csv.ps1 -Interactive
# Prefill paths (optional):
.\demo-data\bulk-api-test\write-bulk-import-csv.ps1 -Interactive -PricingCsv "C:\exports\source.csv" -ColumnMapPath "C:\exports\my_map.json"
# Or env: $env:PRICING_CSV / $env:PRICING_COLUMN_MAP before -Interactive
```

**macOS / Linux**

```bash
cd <repo-root>
chmod +x demo-data/bulk-api-test/write-bulk-import-csv.sh demo-data/bulk-api-test/replace-pricing-parent-id.sh
./demo-data/bulk-api-test/write-bulk-import-csv.sh --interactive
./demo-data/bulk-api-test/write-bulk-import-csv.sh --interactive --pricing-csv /path/source.csv --column-map /path/map.json
# Or: PRICING_CSV=... PRICING_COLUMN_MAP=... ./demo-data/bulk-api-test/write-bulk-import-csv.sh --interactive
```

### Source columns → Salesforce API names

Exports from upstream systems often use **business column names**, not field API names. Copy [`pricing_column_map.example.json`](../demo-data/bulk-api-test/pricing_column_map.example.json) and set **`column_mappings`** so each **exact source header** (row 1 of your CSV) maps to the target **`Pricing_Item__c`** API name (for example `Catalog_Import__c`, `CSP__c`). If a column is **already** named with a valid API name (`Something__c`), you can omit it from the map.

- **PowerShell:** `.\write-bulk-import-csv.ps1 -PricingCsv .\source.csv -ColumnMapPath .\my_map.json` writes `pricing_for_bulk_<CSP>_<IMPORT_MONTH>.csv` (defaults `CSP=aws`, `IMPORT_MONTH=2025-12`).
- **Bash:** same with `--pricing-csv` / `--column-map`; requires **Python 3**.

**Production checklist**

- **Parent link before replace:** every child row’s **`Catalog_Import__c`** value should be the placeholder `PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV` (or a single token you pass to **`replace-pricing-parent-id`** as `-OldId` / `OLD_ID`) until you patch with the real **`sf__Id`** from `*-success-records.csv`. Do not put the Bulk ingest **Job Id** (`750…`) in that field.
- **Sandbox first:** validate end-to-end on a full sandbox copy before production.
- **Volume:** very large files usually belong in MuleSoft or another integration; these scripts still help with the parent row and CLI mechanics.

**One-shot replace (already have `sf__Id`):** [`replace-pricing-parent-id.sh`](../demo-data/bulk-api-test/replace-pricing-parent-id.sh) `[new_id] [optional/path/to/pricing.csv]`. If you omit the path, the script picks among `pricing_*.csv` in that folder, or **prompts** if several exist. Windows: [`replace-pricing-parent-id.ps1`](../demo-data/bulk-api-test/replace-pricing-parent-id.ps1) `-NewId a0XXX` (optional `-CsvPath`).

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

   `catalog_import_<csp>_<YYYY-MM>.csv` is emitted by `write-bulk-import-csv.ps1` / `.sh` (defaults `aws` / `2025-12`, or `-ImportMonth` / `IMPORT_MONTH` and `-Csp` / `CSP`).

   Wait until the job finishes successfully.

2. **Download results** for that bulk job using the **Bulk ingest Job Id** from the CLI output (often starts with `750` — use this id only to call `sf data bulk results`, not as a lookup on child rows):

   ```text
   sf data bulk results -o YOUR_ORG_ALIAS --job-id JOB_ID_FROM_PREVIOUS_COMMAND
   ```

   This creates `*-success-records.csv` and `*-failed-records.csv` in the current working directory.

3. **Open `*-success-records.csv`** and copy the value in the **`sf__Id`** column. That is the **Salesforce Id of the new `Catalog_Import__c` record** (custom object ids often start with `a0`…).  
   **Do not** put the Bulk Job Id (`750…`) in the **`Catalog_Import__c`** column on pricing rows — Salesforce returns `id value of incorrect type`.

4. **Point the child CSV at that parent Id**

   - **Manual:** in `demo-data/bulk-api-test/pricing_for_bulk_aws_2025-12.csv` (or whatever converted file you produced), find/replace the placeholder in the **`Catalog_Import__c`** column with **`sf__Id`**. Prefer **VS Code** or **Notepad++**; avoid **Excel** for this edit (it can break CSV structure or line endings).
   - **macOS / Linux:** `./replace-pricing-parent-id.sh 'a0XXXXXXXXXXXXXXX'` (optional second arg: explicit path; otherwise auto-pick or prompt among `pricing_*.csv`).
   - **Windows:** `.\replace-pricing-parent-id.ps1 -NewId 'a0XXXXXXXXXXXXXXX'` (optional `-CsvPath`; otherwise same auto-pick / prompt).

5. **Import pricing lines** (again, **line-ending must match the file**):

   **Windows**

   ```powershell
   sf data import bulk --sobject Pricing_Item__c --file "demo-data/bulk-api-test/pricing_for_bulk_aws_2025-12.csv" --target-org YOUR_ORG_ALIAS --wait 10m --line-ending CRLF
   ```

   **macOS / Linux**

   ```bash
   sf data import bulk --sobject Pricing_Item__c --file "demo-data/bulk-api-test/pricing_for_bulk_aws_2025-12.csv" --target-org YOUR_ORG_ALIAS --wait 10m --line-ending LF
   ```

6. **If rows fail:** run `sf data bulk results` with the **new** job id and inspect `*-failed-records.csv`.

**If you no longer have the success CSV:** query the parent Id, for example:

```text
sf data query -o YOUR_ORG_ALIAS -q "SELECT Id FROM Catalog_Import__c WHERE Import_Month__c = '2025-12' AND CSP__c = 'aws' AND Schema__c = 'pricing'"
```

## Security

Grant the integration user a **dedicated permission set** (or integration profile) with least privilege: create on `Catalog_Import__c`, `Pricing_Item__c`, and `Exception_Item__c`, plus field access as required. Do not reuse personal user accounts for unattended loads.

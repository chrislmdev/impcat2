# MuleSoft and large-catalog ingest (outside the POC UI)

The in-app **Bulk upload** tab only accepts **small** files so interactive users stay within Apex limits. For large or automated loads, use **Bulk API 2.0** from the CLI, **MuleSoft**, or another integration.

## When to use integration

- Very large row counts or files beyond the in-app limits ([README.md](../README.md), in-app banner).
- You need **scheduling, retries, monitoring**, or **idempotent** enterprise-scale loads.

Typical pattern: land files in a controlled store → integration validates and uploads via **Bulk API 2.0** → Salesforce inserts `Catalog_Import__c` and child `Pricing_Item__c` / `Exception_Item__c` rows (same model as this POC).

## File naming and CSV headers

**Names** (same idea as the UI): `{YYYY-MM}_{csp}_{schema}.csv` — `csp` is `aws` | `azure` | `gcp` | `oracle`; `schema` is `pricing`, `exceptions`, or `parent`.

**Headers** must be Salesforce **field API names** (or map them — see below).

## Line endings and `sf`

Bulk jobs require file bytes to match **`--line-ending`**. Mismatch causes `ClientInputError: LineEnding is invalid on user data`.

| Environment | Typical | `sf` flag |
|---------------|---------|-----------|
| Windows | CRLF | `--line-ending CRLF` |
| macOS / Linux | LF | `--line-ending LF` |

## Scripts in `demo-data/bulk-api-test/`

| File | Role |
|------|------|
| [`write-bulk-import-csv.ps1`](../demo-data/bulk-api-test/write-bulk-import-csv.ps1) | Windows: parent CSV, convert pricing headers, **interactive wizard** |
| [`write-bulk-import-csv.sh`](../demo-data/bulk-api-test/write-bulk-import-csv.sh) | Same on macOS/Linux (wizard needs **Python 3** for conversion) |
| [`convert_pricing_csv_to_api.py`](../demo-data/bulk-api-test/convert_pricing_csv_to_api.py) | Header conversion (bash / optional reference) |
| [`pricing_column_map.example.json`](../demo-data/bulk-api-test/pricing_column_map.example.json) | Copy and edit: **source column name → API name** |
| [`replace-pricing-parent-id.ps1` / `.sh`](../demo-data/bulk-api-test/replace-pricing-parent-id.ps1) | Replace parent placeholder in the pricing CSV with the real parent Id |

Once per clone (Unix): `chmod +x demo-data/bulk-api-test/write-bulk-import-csv.sh demo-data/bulk-api-test/replace-pricing-parent-id.sh`

---

### Path 1 — Interactive wizard (recommended)

**Needs:** `sf` on PATH, logged-in org. **Bash wizard:** Python 3 as well (for column conversion).

Runs: parent bulk import → download results → read **`sf__Id`** → patch pricing file → child bulk import. Writes `catalog_import_<csp>_<YYYY-MM>.csv` and `pricing_for_bulk_<csp>_<YYYY-MM>.csv` beside the script; bulk job downloads go under `.bulk-results/`.

```powershell
cd <repo-root>
.\demo-data\bulk-api-test\write-bulk-import-csv.ps1 -Interactive
# Optional: -PricingCsv "...\source.csv" -ColumnMapPath "...\map.json"
```

```bash
cd <repo-root>
./demo-data/bulk-api-test/write-bulk-import-csv.sh --interactive
# Optional: --pricing-csv /path/source.csv --column-map /path/map.json
```

**Column map:** If your export does not already use `Something__c` API names, copy [`pricing_column_map.example.json`](../demo-data/bulk-api-test/pricing_column_map.example.json), fill **`column_mappings`**, and pass it as above.

**Important:** Child rows must use placeholder `PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV` in **`Catalog_Import__c`** until you replace it with the parent **`sf__Id`** from `*-success-records.csv`. Do **not** use the bulk **Job Id** (`750…`) as the parent reference.

---

### Path 2 — Convert pricing only (no wizard)

Writes `pricing_for_bulk_<CSP>_<IMPORT_MONTH>.csv` next to the script (defaults: `aws`, `2025-12` — override with `-ImportMonth` / `-Csp` or `IMPORT_MONTH` / `CSP`).

```powershell
.\demo-data\bulk-api-test\write-bulk-import-csv.ps1 -PricingCsv .\source.csv -ColumnMapPath .\my_map.json
```

```bash
./demo-data/bulk-api-test/write-bulk-import-csv.sh --pricing-csv ./source.csv --column-map ./my_map.json
```

---

### Path 3 — Manual CLI (no helper scripts)

1. **Parent:** Import `Catalog_Import__c` (e.g. `catalog_import_<csp>_<YYYY-MM>.csv` from Path 1’s script with no extra args, or your own file). Match `--line-ending` to the file.

   ```text
   sf data import bulk --sobject Catalog_Import__c --file demo-data/bulk-api-test/catalog_import_aws_2025-12.csv -o YOUR_ORG --wait 10m --line-ending CRLF
   ```
   (Use `LF` on macOS/Linux if the file is LF.)

2. **Results:** `sf data bulk results -o YOUR_ORG --job-id JOB_ID_FROM_CLI` (Job Id is often `750…`; use it **only** for this command).

3. **Parent Id:** From `*-success-records.csv`, take **`sf__Id`** — that is the `Catalog_Import__c` record Id (often `a0…`). This is **not** the Job Id.

4. **Patch child file:** Replace the placeholder in **`Catalog_Import__c`** on each pricing row with that Id — manually or via `replace-pricing-parent-id` / `-NewId` / optional path to `pricing_*.csv`.

5. **Children:** Import `Pricing_Item__c` with the same `--line-ending` as the child CSV.

6. **Failures:** `sf data bulk results` with the **child** job id; inspect `*-failed-records.csv`.

**Lost the success CSV?** Example query:

```text
sf data query -o YOUR_ORG -q "SELECT Id FROM Catalog_Import__c WHERE Import_Month__c = '2025-12' AND CSP__c = 'aws' AND Schema__c = 'pricing'"
```

---

## Security

Use a **dedicated integration user** with least privilege: create access on `Catalog_Import__c`, `Pricing_Item__c`, and `Exception_Item__c`, plus required fields. Avoid personal accounts for unattended jobs.

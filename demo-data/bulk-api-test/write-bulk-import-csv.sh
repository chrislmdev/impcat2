#!/usr/bin/env bash
# Bulk API 2.0: Catalog_Import__c parent row + Pricing_Item__c column conversion for sf data import bulk.
#
# Non-interactive (parent snapshot only; defaults IMPORT_MONTH=2025-12 CSP=aws):
#   ./write-bulk-import-csv.sh
#   ./write-bulk-import-csv.sh CRLF
#   IMPORT_MONTH=2026-03 CSP=gcp ./write-bulk-import-csv.sh
#
# Convert source pricing to Salesforce API columns (Python 3 required):
#   ./write-bulk-import-csv.sh --pricing-csv /path/source.csv [--column-map map.json]
#   Output: pricing_for_bulk_${CSP}_${IMPORT_MONTH}.csv next to this script.
#
# Interactive wizard (sf + python3 on PATH):
#   ./write-bulk-import-csv.sh --interactive
#   ./write-bulk-import-csv.sh --interactive --pricing-csv /path/source.csv [--column-map map.json]
#
# Env: PRICING_CSV, PRICING_COLUMN_MAP (optional; same as flags for interactive).
#
# See pricing_column_map.example.json — map source headers to API names. Without a map, headers must be *__c.
#
# IMPORTANT: Catalog_Import__c on pricing rows must be the record Id after replace-pricing-parent-id.sh, not Job Id 750...
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLACEHOLDER='PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV'

join_lines() {
  local nl="$1"
  shift
  local out="" first=1
  for line in "$@"; do
    if [[ $first -eq 1 ]]; then out="$line"; first=0; else out="${out}${nl}${line}"; fi
  done
  printf '%s%s' "$out" "$nl"
}

write_utf8() {
  local nl="$1" file="$2"
  shift 2
  join_lines "$nl" "$@" >"$file"
}

write_catalog_csv() {
  local ending="$1" import_month="$2" csp="$3" catalog_path="$4" source_file="$5" imported_at="$6" imported_by="$7" row_count="${8:-0}"
  local nl
  case "$ending" in
    LF) nl=$'\n' ;;
    CRLF) nl=$'\r\n' ;;
    *) echo "Bad ending: $ending" >&2; return 1 ;;
  esac
  write_utf8 "$nl" "$catalog_path" \
    'Import_Month__c,CSP__c,Schema__c,Status__c,Source_File__c,Imported_At__c,Imported_By__c,Row_Count__c' \
    "${import_month},${csp},pricing,processing,${source_file},${imported_at},${imported_by},${row_count}"
}

run_convert_pricing() {
  local src="$1" out="$2" map_arg="$3" ending="$4"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for column conversion. Install Python 3 or use write-bulk-import-csv.ps1 on Windows." >&2
    exit 1
  fi
  local -a pyargs=( "$SCRIPT_DIR/convert_pricing_csv_to_api.py" "$src" "$out" --line-ending "$ending" )
  if [[ -n "$map_arg" ]]; then
    pyargs+=( --map "$map_arg" )
  fi
  python3 "${pyargs[@]}"
}

read_sf_id_from_success() {
  local dir="$1"
  local f
  f="$(ls -t "$dir"/*-success-records.csv 2>/dev/null | head -1)"
  if [[ -z "$f" || ! -f "$f" ]]; then
    echo ""
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$f" <<'PY'
import csv, sys
path = sys.argv[1]
with open(path, newline="", encoding="utf-8-sig") as fp:
    r = csv.DictReader(fp)
    row = next(r, None)
if not row:
    sys.exit(0)
for k, v in row.items():
    if k in ("sf__Id", "sf__id"):
        print((v or "").strip())
        sys.exit(0)
for k, v in row.items():
    if k and "sf__" in k and "Id" in k:
        print((v or "").strip())
        sys.exit(0)
print("")
PY
  else
    awk -F',' 'NR==2 {gsub(/^"|"$/,"",$1); print $1; exit}' "$f"
  fi
}

interactive_wizard() {
  if ! command -v sf >/dev/null 2>&1; then
    echo "Salesforce CLI (sf) not found on PATH. Install: https://developer.salesforce.com/tools/salesforcecli" >&2
    exit 1
  fi

  local pricing_from_cli="${1:-${PRICING_CSV:-}}"
  local map_from_cli="${2:-${PRICING_COLUMN_MAP:-}}"

  echo ""
  echo "=== Bulk import wizard (pricing only) ==="
  echo "You need: source pricing CSV, import month, CSP, org alias, Bulk Job Id from sf output."
  echo ""

  local year month mm import_month csp src_in at_in by_in default_source default_by utc_now
  while true; do
    read -r -p "Calendar year (e.g. 2025): " year
    if [[ "$year" =~ ^[0-9]{4}$ ]] && (( year >= 2020 && year <= 2035 )); then break; fi
    echo "Enter a 4-digit year between 2020 and 2035."
  done

  while true; do
    read -r -p "Month (1-12): " month
    if [[ "$month" =~ ^[0-9]{1,2}$ ]]; then
      m10=$((10#$month))
      if (( m10 >= 1 && m10 <= 12 )); then
        printf -v mm '%02d' "$m10"
        break
      fi
    fi
    echo "Enter a month 1-12."
  done

  import_month="${year}-${mm}"

  echo ""
  echo "CSP: 1) aws  2) azure  3) gcp  4) oracle"
  while true; do
    read -r -p "Choose 1-4 (or type aws/azure/gcp/oracle): " c
    case "$c" in
      1) csp=aws; break ;;
      2) csp=azure; break ;;
      3) csp=gcp; break ;;
      4) csp=oracle; break ;;
      aws|azure|gcp|oracle) csp="$c"; break ;;
    esac
    echo "Invalid choice."
  done

  default_source="${import_month}_${csp}_pricing.csv"
  read -r -p "Source_File__c [${default_source}]: " src_in
  if [[ -z "${src_in// }" ]]; then src_in="$default_source"; fi

  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
  read -r -p "Imported_At__c UTC [${utc_now}]: " at_in
  if [[ -z "${at_in// }" ]]; then at_in="$utc_now"; fi

  default_by="${USER:-bulk_import}"
  read -r -p "Imported_By__c [${default_by}]: " by_in
  if [[ -z "${by_in// }" ]]; then by_in="$default_by"; fi

  if [[ -z "${pricing_from_cli// }" ]]; then
    read -r -p "Path to source pricing CSV (your export): " pricing_from_cli
  fi
  if [[ -z "${pricing_from_cli// }" ]]; then
    echo "Source pricing CSV is required." >&2
    exit 1
  fi
  if [[ ! -f "$pricing_from_cli" ]]; then
    echo "Pricing file not found: $pricing_from_cli" >&2
    exit 1
  fi
  pricing_from_cli="$(cd "$(dirname "$pricing_from_cli")" && pwd)/$(basename "$pricing_from_cli")"

  if [[ -z "${map_from_cli// }" ]]; then
    read -r -p "Path to column map JSON (optional; Enter if headers are already *__c): " map_from_cli
  fi
  local map_resolved=""
  if [[ -n "${map_from_cli// }" ]]; then
    if [[ ! -f "$map_from_cli" ]]; then
      echo "Column map not found: $map_from_cli" >&2
      exit 1
    fi
    map_resolved="$(cd "$(dirname "$map_from_cli")" && pwd)/$(basename "$map_from_cli")"
  fi

  local catalog_name catalog_path bulk_pricing_path
  catalog_name="catalog_import_${csp}_${import_month}.csv"
  catalog_path="${SCRIPT_DIR}/${catalog_name}"
  bulk_pricing_path="${SCRIPT_DIR}/pricing_for_bulk_${csp}_${import_month}.csv"

  echo ""
  echo "--- Summary ---"
  echo "  Import_Month__c: $import_month"
  echo "  CSP:             $csp"
  echo "  Source_File__c:  $src_in"
  echo "  Catalog file:    $catalog_name"
  echo "  Source pricing:  $pricing_from_cli"
  echo "  Converted file:  $bulk_pricing_path"
  if [[ -n "$map_resolved" ]]; then
    echo "  Column map:      $map_resolved"
  fi
  echo "  Placeholder:     $PLACEHOLDER in Catalog_Import__c until parent succeeds."
  echo ""
  read -r -p "Continue? (y/n): " ok
  if [[ ! "$ok" =~ ^[yY] ]]; then echo "Cancelled."; exit 0; fi

  read -r -p "Salesforce org alias or username (sf org list): " org
  if [[ -z "${org// }" ]]; then echo "Org is required." >&2; exit 1; fi

  local default_le le_choice ending
  default_le="LF"
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) default_le="CRLF" ;;
  esac
  read -r -p "Line ending CRLF or LF [${default_le}]: " le_choice
  if [[ -z "${le_choice// }" ]]; then
    ending="$default_le"
  else
    ending="$(printf '%s' "$le_choice" | tr '[:lower:]' '[:upper:]')"
  fi
  if [[ "$ending" != "CRLF" && "$ending" != "LF" ]]; then
    echo "Use CRLF or LF." >&2
    exit 1
  fi

  run_convert_pricing "$pricing_from_cli" "$bulk_pricing_path" "$map_resolved" "$ending"

  write_catalog_csv "$ending" "$import_month" "$csp" "$catalog_path" "$src_in" "$at_in" "$by_in" 0

  echo ""
  echo "Wrote:"
  echo "  $catalog_path"
  echo "  $bulk_pricing_path (Salesforce API columns)"
  echo ""
  echo "NOTE: Bulk JOB Id (750...) is only for downloading results."
  echo "      RECORD Id (sf__Id, often a0...) goes in Catalog_Import__c on pricing rows."
  echo ""

  sf data import bulk --sobject Catalog_Import__c --file "$catalog_path" --target-org "$org" --wait 10m --line-ending "$ending"
  local parent_st=$?
  if (( parent_st != 0 )); then
    echo "Parent import failed." >&2
    exit "$parent_st"
  fi

  local job_id
  while true; do
    read -r -p "Paste the Bulk ingest Job Id (750...): " job_id
    job_id="$(printf '%s' "$job_id" | tr -d '[:space:]')"
    if [[ "$job_id" =~ ^[a-zA-Z0-9]{15,18}$ ]]; then break; fi
    echo "Expected 15-18 alphanumeric characters."
  done

  local results_dir="${SCRIPT_DIR}/.bulk-results"
  mkdir -p "$results_dir"
  ( cd "$results_dir" && sf data bulk results -o "$org" --job-id "$job_id" )
  local res_st=$?
  if (( res_st != 0 )); then
    echo "sf data bulk results failed." >&2
    exit "$res_st"
  fi
  echo "Results files under: $results_dir"

  local sf_id
  sf_id="$(read_sf_id_from_success "$results_dir")"
  sf_id="$(printf '%s' "$sf_id" | tr -d '[:space:]')"
  if [[ -z "$sf_id" ]]; then
    read -r -p "Paste Catalog_Import__c Id (sf__Id, NOT 750 Job Id): " sf_id
    sf_id="$(printf '%s' "$sf_id" | tr -d '[:space:]')"
  fi

  if [[ "$sf_id" == 750* ]]; then
    echo "That looks like a Bulk Job Id. Use sf__Id from the success CSV." >&2
    exit 1
  fi

  "$SCRIPT_DIR/replace-pricing-parent-id.sh" "$sf_id" "$bulk_pricing_path"

  echo ""
  sf data import bulk --sobject Pricing_Item__c --file "$bulk_pricing_path" --target-org "$org" --wait 10m --line-ending "$ending"
  local child_st=$?
  if (( child_st != 0 )); then
    echo "Pricing import failed. Check output. sf data bulk results -o $org --job-id <id>" >&2
    exit "$child_st"
  fi

  echo ""
  echo "Done. If any rows failed, run sf data bulk results with that job's id."
}

# ---- argument parsing ----
INTERACTIVE=0
PRICING=""
COLUMN_MAP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interactive|-i)
      INTERACTIVE=1
      shift
      ;;
    --pricing-csv)
      if [[ $# -lt 2 ]]; then echo "Missing path after --pricing-csv" >&2; exit 1; fi
      PRICING="$2"
      shift 2
      ;;
    --column-map)
      if [[ $# -lt 2 ]]; then echo "Missing path after --column-map" >&2; exit 1; fi
      COLUMN_MAP="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

IMPORT_MONTH="${IMPORT_MONTH:-2025-12}"
CSP="${CSP:-aws}"

if [[ $INTERACTIVE -eq 1 ]]; then
  interactive_wizard "${PRICING:-}" "${COLUMN_MAP:-}"
  exit 0
fi

if [[ -n "${COLUMN_MAP// }" ]] && [[ -z "${PRICING// }" ]]; then
  echo "--column-map requires --pricing-csv or --interactive" >&2
  exit 1
fi

if [[ -n "${PRICING// }" ]]; then
  if [[ -n "${COLUMN_MAP// }" ]] && [[ ! -f "$COLUMN_MAP" ]]; then
    echo "Column map not found: $COLUMN_MAP" >&2
    exit 1
  fi
  if [[ ! -f "$PRICING" ]]; then
    echo "Pricing file not found: $PRICING" >&2
    exit 1
  fi
  ENDING="${1:-${LINE_ENDING:-LF}}"
  ENDING="$(printf '%s' "$ENDING" | tr '[:lower:]' '[:upper:]')"
  case "$ENDING" in
    LF|CRLF) ;;
    *)
      echo "After --pricing-csv, optional line ending: LF | CRLF (default LF)." >&2
      exit 1
      ;;
  esac
  OUT="${SCRIPT_DIR}/pricing_for_bulk_${CSP}_${IMPORT_MONTH}.csv"
  MAP_ARG=""
  if [[ -n "${COLUMN_MAP// }" ]]; then
    MAP_ARG="$COLUMN_MAP"
  fi
  run_convert_pricing "$(cd "$(dirname "$PRICING")" && pwd)/$(basename "$PRICING")" "$OUT" "$MAP_ARG" "$ENDING"
  echo "Converted pricing written: $OUT ($ENDING)"
  exit 0
fi

ENDING="${1:-${LINE_ENDING:-LF}}"
ENDING="$(printf '%s' "$ENDING" | tr '[:lower:]' '[:upper:]')"

case "$ENDING" in
  LF) ;;
  CRLF) ;;
  *)
    echo "Usage: $0 [LF|CRLF]" >&2
    echo "       $0 --interactive [--pricing-csv path [--column-map path]]" >&2
    echo "       $0 --pricing-csv path [--column-map path] [LF|CRLF]" >&2
    echo "  Env: IMPORT_MONTH CSP LINE_ENDING" >&2
    exit 1
    ;;
esac

utc="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
write_catalog_csv "$ENDING" "$IMPORT_MONTH" "$CSP" "${SCRIPT_DIR}/catalog_import_${CSP}_${IMPORT_MONTH}.csv" \
  "${IMPORT_MONTH}_${CSP}_pricing.csv" \
  "$utc" \
  "${USER:-bulk_import}" \
  0

echo "Wrote UTF-8 ${ENDING}: catalog_import_${CSP}_${IMPORT_MONTH}.csv"
echo "Convert pricing: $0 --pricing-csv <source.csv> [--column-map map.json]"
echo "Use: sf data import bulk ... --line-ending ${ENDING}"

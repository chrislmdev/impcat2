#!/usr/bin/env bash
# Demo Bulk API 2.0 CSVs for Catalog_Import__c + Pricing_Item__c (pricing schema only).
#
# Usage:
#   ./write-demo-csv.sh              # LF + fixed demo filenames (2025-12, aws)
#   ./write-demo-csv.sh CRLF
#   CATALOG_IMPORT_ID=a0XXX ./write-demo-csv.sh
#   ./write-demo-csv.sh --interactive   # full wizard (pricing only)
#
# IMPORTANT: Child Catalog_Import__c must be sf__Id from success CSV, not Bulk Job Id 750...
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

export_demo_csv_files() {
  local ending="$1" import_month="$2" csp="$3" catalog_path="$4" pricing_path="$5" parent_ph="$6" source_file="$7" imported_at="$8" imported_by="$9" row_count="${10:-0}"
  local nl
  case "$ending" in
    LF) nl=$'\n' ;;
    CRLF) nl=$'\r\n' ;;
    *) echo "Bad ending: $ending" >&2; return 1 ;;
  esac

  local tag
  case "$csp" in
    aws) tag=AWS ;;
    azure) tag=AZURE ;;
    gcp) tag=GCP ;;
    oracle) tag=ORA ;;
    *) echo "Invalid CSP: $csp" >&2; return 1 ;;
  esac

  write_utf8 "$nl" "$catalog_path" \
    'Import_Month__c,CSP__c,Schema__c,Status__c,Source_File__c,Imported_At__c,Imported_By__c,Row_Count__c' \
    "${import_month},${csp},pricing,processing,${source_file},${imported_at},${imported_by},${row_count}"

  write_utf8 "$nl" "$pricing_path" \
    'Catalog_Import__c,CSP__c,Catalog_Item_Number__c,Title__c,CSO_Short_Name__c,Description__c,List_Unit_Price__c,Pricing_Unit__c,JWCC_Unit_Price__c,JWCC_Unit_Of_Issue__c,Discount_Premium_Fee__c,Focus_Category__c,Service_Category__c' \
    "${parent_ph},${csp},DEMO-${tag}-EC2-T3MICRO,t3.micro mock,${tag} compute,General purpose burstable; demo row,0.0104,Hour,0.0092,Hour,-12%,Compute,Compute" \
    "${parent_ph},${csp},DEMO-${tag}-S3-STD,S3 Standard storage mock,${tag} storage,Object storage per GB-month; demo,0.023,GB-Mo,0.0202,GB-Mo,,Storage,Storage" \
    "${parent_ph},${csp},DEMO-${tag}-RDS-MYSQL,db.t3.micro MySQL mock,${tag} database,Managed relational DB; demo,0.017,Hour,0.015,Hour,-10%,Database,Database" \
    "${parent_ph},${csp},DEMO-${tag}-VPC-ENDPOINT,Interface VPC endpoint mock,${tag} network,Private connectivity; demo,0.01,Hour,0.0088,Hour,,Networking,Networking"
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

  echo ""
  echo "=== Bulk import wizard (pricing only) ==="
  echo "You will need: import month, CSP, org alias, and the Bulk Job Id from sf output."
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

  default_by="${USER:-bulk_import_wizard}"
  read -r -p "Imported_By__c [${default_by}]: " by_in
  if [[ -z "${by_in// }" ]]; then by_in="$default_by"; fi

  local catalog_name pricing_name catalog_path pricing_path
  catalog_name="catalog_import_${csp}_${import_month}.csv"
  pricing_name="pricing_items_${csp}_${import_month}.csv"
  catalog_path="${SCRIPT_DIR}/${catalog_name}"
  pricing_path="${SCRIPT_DIR}/${pricing_name}"

  echo ""
  echo "--- Summary ---"
  echo "  Import_Month__c: $import_month"
  echo "  CSP:             $csp"
  echo "  Schema:          pricing (fixed)"
  echo "  Source_File__c:  $src_in"
  echo "  Files:           $catalog_name"
  echo "                   $pricing_name"
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

  export_demo_csv_files "$ending" "$import_month" "$csp" "$catalog_path" "$pricing_path" "$PLACEHOLDER" "$src_in" "$at_in" "$by_in" 0

  echo ""
  echo "Wrote:"
  echo "  $catalog_path"
  echo "  $pricing_path"
  echo ""
  echo "NOTE: Bulk JOB Id (750...) is only for downloading results."
  echo "      RECORD Id (sf__Id, often a0...) goes in the pricing file."
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

  "$SCRIPT_DIR/replace-pricing-parent-id.sh" "$sf_id" "$pricing_path"

  echo ""
  sf data import bulk --sobject Pricing_Item__c --file "$pricing_path" --target-org "$org" --wait 10m --line-ending "$ending"
  local child_st=$?
  if (( child_st != 0 )); then
    echo "Pricing import failed. Check output. sf data bulk results -o $org --job-id <id>" >&2
    exit "$child_st"
  fi

  echo ""
  echo "Done. If any rows failed, run sf data bulk results with that job's id."
}

# ---- argument parsing ----
if [[ "${1:-}" == "--interactive" || "${1:-}" == "-i" ]]; then
  interactive_wizard
  exit 0
fi

ENDING="${1:-${LINE_ENDING:-LF}}"
ENDING="$(printf '%s' "$ENDING" | tr '[:lower:]' '[:upper:]')"

case "$ENDING" in
  LF) ;;
  CRLF) ;;
  *)
    echo "Usage: $0 [LF|CRLF]" >&2
    echo "       $0 --interactive" >&2
    echo "  Or:  LINE_ENDING=LF|CRLF $0" >&2
    exit 1
    ;;
esac

CATALOG_IMPORT_ID="${CATALOG_IMPORT_ID:-$PLACEHOLDER}"

export_demo_csv_files "$ENDING" "2025-12" "aws" \
  "${SCRIPT_DIR}/catalog_import_aws_2025-12.csv" \
  "${SCRIPT_DIR}/pricing_items_aws_2025-12.csv" \
  "$CATALOG_IMPORT_ID" \
  "2025-12_aws_pricing.csv" \
  "2025-12-15T10:00:00.000Z" \
  "bulk_test_import" \
  0

echo "Wrote UTF-8 ${ENDING}: catalog_import_aws_2025-12.csv, pricing_items_aws_2025-12.csv"
echo "Use: sf data import bulk ... --line-ending ${ENDING}"

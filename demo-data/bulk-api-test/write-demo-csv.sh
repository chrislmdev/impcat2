#!/usr/bin/env bash
# Re-writes demo Bulk API CSVs as UTF-8 (no BOM).
#
# Usage:
#   ./write-demo-csv.sh              # default: LF (use: sf data import bulk ... --line-ending LF)
#   ./write-demo-csv.sh CRLF         # Windows-style (use: ... --line-ending CRLF)
#   CATALOG_IMPORT_ID=a0XXX ./write-demo-csv.sh
#
# IMPORTANT: CATALOG_IMPORT_ID must be sf__Id from *-success-records.csv (Catalog_Import__c row),
#            not the Bulk ingest Job Id (750...).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENDING="${1:-${LINE_ENDING:-LF}}"
ENDING="$(printf '%s' "$ENDING" | tr '[:lower:]' '[:upper:]')"

case "$ENDING" in
  LF)  nl=$'\n' ;;
  CRLF) nl=$'\r\n' ;;
  *)
    echo "Usage: $0 [LF|CRLF]" >&2
    echo "  Or:  LINE_ENDING=LF|CRLF $0" >&2
    exit 1
    ;;
esac

CATALOG_IMPORT_ID="${CATALOG_IMPORT_ID:-PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV}"

join_lines() {
  local out="" first=1
  for line in "$@"; do
    if [[ $first -eq 1 ]]; then
      out="$line"
      first=0
    else
      out="${out}${nl}${line}"
    fi
  done
  printf '%s%s' "$out" "$nl"
}

write_utf8() {
  local file="$1"
  shift
  # printf preserves UTF-8; no BOM
  join_lines "$@" >"$file"
}

write_utf8 "$SCRIPT_DIR/catalog_import_aws_2025-12.csv" \
  'Import_Month__c,CSP__c,Schema__c,Status__c,Source_File__c,Imported_At__c,Imported_By__c,Row_Count__c' \
  '2025-12,aws,pricing,processing,2025-12_aws_pricing.csv,2025-12-15T10:00:00.000Z,bulk_test_import,0'

write_utf8 "$SCRIPT_DIR/pricing_items_aws_2025-12.csv" \
  'Catalog_Import__c,CSP__c,Catalog_Item_Number__c,Title__c,CSO_Short_Name__c,Description__c,List_Unit_Price__c,Pricing_Unit__c,JWCC_Unit_Price__c,JWCC_Unit_Of_Issue__c,Discount_Premium_Fee__c,Focus_Category__c,Service_Category__c' \
  "${CATALOG_IMPORT_ID},aws,AWS-DEMO-EC2-T3MICRO,t3.micro Linux us-east-1 mock,CSO-COMPUTE-EC2,General purpose burstable; test row only,0.0104,Hour,0.0092,Hour,-12%,Compute,Compute" \
  "${CATALOG_IMPORT_ID},aws,AWS-DEMO-S3-STD,S3 Standard storage mock,CSO-STORAGE-S3,Object storage per GB-month; test row,0.023,GB-Mo,0.0202,GB-Mo,,Storage,Storage" \
  "${CATALOG_IMPORT_ID},aws,AWS-DEMO-RDS-MYSQL,db.t3.micro MySQL mock,CSO-DATABASE-RDS,Managed relational DB; test row,0.017,Hour,0.015,Hour,-10%,Database,Database" \
  "${CATALOG_IMPORT_ID},aws,AWS-DEMO-VPC-ENDPOINT,Interface VPC endpoint mock,CSO-NETWORK-VPC,Private connectivity; test row,0.01,Hour,0.0088,Hour,,Networking,Networking"

echo "Wrote UTF-8 ${ENDING}: catalog_import_aws_2025-12.csv, pricing_items_aws_2025-12.csv"
echo "Use: sf data import bulk ... --line-ending ${ENDING}"

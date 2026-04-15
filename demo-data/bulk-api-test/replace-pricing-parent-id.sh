#!/usr/bin/env bash
# Replace the Catalog_Import__c placeholder in the first column of a pricing CSV with the real
# parent Id (sf__Id from *-success-records.csv).
#
# Usage:
#   ./replace-pricing-parent-id.sh a0XXXXXXXXXXXXXXX
#   ./replace-pricing-parent-id.sh a0XXX /path/to/pricing_items_gcp_2025-06.csv
#   OLD_ID=oldvalue ./replace-pricing-parent-id.sh a0XXX
#
# Full guided flow: ./write-demo-csv.sh --interactive
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLD="${OLD_ID:-PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV}"

if [[ $# -lt 1 ]] || [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <Catalog_Import__c_Id_from_sf__Id> [path/to/pricing_items.csv]" >&2
  echo "  Default CSV (if omitted): $SCRIPT_DIR/pricing_items_aws_2025-12.csv" >&2
  exit 1
fi

NEW="$1"
if [[ $# -ge 2 ]] && [[ -n "${2:-}" ]]; then
  CSV="$2"
else
  CSV="$SCRIPT_DIR/pricing_items_aws_2025-12.csv"
fi

if [[ ! -f "$CSV" ]]; then
  echo "Missing file: $CSV" >&2
  exit 1
fi

tmp="${CSV}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

NEW_ESC="$(printf '%s\n' "$NEW" | sed -e 's/[\/&]/\\&/g')"
OLD_ESC="$(printf '%s\n' "$OLD" | sed -e 's/[\/&]/\\&/g')"

sed "s/${OLD_ESC}/${NEW_ESC}/g" "$CSV" >"$tmp"
mv "$tmp" "$CSV"
trap - EXIT
echo "Updated first column (Catalog_Import__c) in: $CSV"

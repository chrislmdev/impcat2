#!/usr/bin/env bash
# Replace the Catalog_Import__c placeholder column value in pricing_items_aws_2025-12.csv
# with the real parent Id (sf__Id from *-success-records.csv).
#
# Usage:
#   ./replace-pricing-parent-id.sh a0XXXXXXXXXXXXXXX
#
# Uses sed; works on macOS (BSD sed) and Linux (GNU sed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV="$SCRIPT_DIR/pricing_items_aws_2025-12.csv"
OLD="${OLD_ID:-PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV}"

if [[ $# -lt 1 ]] || [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <Catalog_Import__c_Id_from_sf__Id>" >&2
  echo "Example: $0 a0B000000000001AAA" >&2
  exit 1
fi

NEW="$1"
if [[ ! -f "$CSV" ]]; then
  echo "Missing file: $CSV" >&2
  exit 1
fi

tmp="${CSV}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

# Escape for sed: & and \ in replacement
NEW_ESC="$(printf '%s\n' "$NEW" | sed -e 's/[\/&]/\\&/g')"
OLD_ESC="$(printf '%s\n' "$OLD" | sed -e 's/[\/&]/\\&/g')"

sed "s/${OLD_ESC}/${NEW_ESC}/g" "$CSV" >"$tmp"
mv "$tmp" "$CSV"
trap - EXIT
echo "Updated first column (Catalog_Import__c) in: $CSV"

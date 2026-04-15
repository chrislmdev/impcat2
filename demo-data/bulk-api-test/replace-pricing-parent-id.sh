#!/usr/bin/env bash
# Replace the Catalog_Import__c placeholder in the first column of a pricing CSV with the real
# parent Id (sf__Id from *-success-records.csv).
#
# Usage:
#   ./replace-pricing-parent-id.sh a0XXXXXXXXXXXXXXX
#   ./replace-pricing-parent-id.sh a0XXX /path/to/pricing_items_gcp_2025-06.csv
#   OLD_ID=oldvalue ./replace-pricing-parent-id.sh a0XXX
#
# If the second argument is omitted: uses the only pricing_items_*.csv in this directory, or prompts
# if several exist (no hardcoded date in the script).
#
# Full guided flow: ./write-demo-csv.sh --interactive
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLD="${OLD_ID:-PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV}"

resolve_pricing_csv() {
  local dir="$1"
  shopt -s nullglob
  local files=( "$dir"/pricing_items_*.csv )
  shopt -u nullglob
  local n=${#files[@]}
  if (( n == 0 )); then
    echo "No pricing_items_*.csv in $dir. Run write-demo-csv.sh first or pass the CSV path as arg 2." >&2
    exit 1
  fi
  if (( n == 1 )); then
    echo "Using pricing file: $(basename "${files[0]}")" >&2
    printf '%s' "${files[0]}"
    return
  fi
  echo "Multiple pricing_items_*.csv files found — which one?" >&2
  local i=1 f
  for f in "${files[@]}"; do
    echo "  $i) $(basename "$f")" >&2
    i=$((i + 1))
  done
  local sel
  while true; do
    read -r -p "Enter number (1-${n}) or full path: " sel
    if [[ -f "$sel" ]]; then
      printf '%s' "$sel"
      return
    fi
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= n )); then
      printf '%s' "${files[$((sel - 1))]}"
      return
    fi
    echo "Invalid choice." >&2
  done
}

if [[ $# -lt 1 ]] || [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <Catalog_Import__c_Id_from_sf__Id> [path/to/pricing_items.csv]" >&2
  exit 1
fi

NEW="$1"
if [[ $# -ge 2 ]] && [[ -n "${2:-}" ]]; then
  CSV="$2"
else
  CSV="$(resolve_pricing_csv "$SCRIPT_DIR")"
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

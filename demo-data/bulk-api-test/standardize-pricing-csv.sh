#!/usr/bin/env bash
# Thin launcher: runs standardize_pricing_csv.py next to this script (Python 3 stdlib only).
# Usage: ./standardize-pricing-csv.sh --input raw.csv --output out.csv --csp aws [--map extra.json] [--line-ending LF|CRLF]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/standardize_pricing_csv.py"
if [[ ! -f "$PY" ]]; then
  echo "Not found: $PY" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found on PATH. Install Python 3 (no extra packages required)." >&2
  exit 1
fi
exec python3 "$PY" "$@"

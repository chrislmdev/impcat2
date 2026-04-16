#!/usr/bin/env python3
"""
Deprecated: use standardize_pricing_csv.py (same folder) — matches CatalogUploadService aliases + bulk parent columns.

Legacy: simple header rename via column_mappings only (no fingerprint aliases).

  python3 convert_pricing_csv_to_api.py input.csv output.csv [--map FILE] [--line-ending LF|CRLF]

Without --map, every source header must already be a valid API name (ends with __c) or the script exits with an error listing unmapped columns.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

# Preferred column order when present (extras sorted after).
PREFERRED = [
    "Catalog_Import__c",
    "CSP__c",
    "Catalog_Item_Number__c",
    "Title__c",
    "CSO_Short_Name__c",
    "Description__c",
    "List_Unit_Price__c",
    "Pricing_Unit__c",
    "JWCC_Unit_Price__c",
    "JWCC_Unit_Of_Issue__c",
    "Discount_Premium_Fee__c",
    "Focus_Category__c",
    "Service_Category__c",
]

_API_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*__c$")


def load_map(path: Path | None) -> dict[str, str]:
    if not path:
        return {}
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    raw = data.get("column_mappings") or data.get("mappings") or {}
    if not isinstance(raw, dict):
        sys.exit("Map file must contain a JSON object column_mappings (or mappings).")
    out: dict[str, str] = {}
    for k, v in raw.items():
        if k.startswith("_"):
            continue
        out[str(k)] = str(v)
    return out


def resolve_header(src: str, mappings: dict[str, str]) -> str:
    if src in mappings:
        return mappings[src]
    if _API_RE.match(src):
        return src
    raise KeyError(src)


def order_columns(names: set[str]) -> list[str]:
    pref = [c for c in PREFERRED if c in names]
    rest = sorted(names - set(pref))
    return pref + rest


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--map", "-m", type=Path, help="JSON with column_mappings")
    ap.add_argument("--line-ending", choices=("LF", "CRLF"), default="LF")
    args = ap.parse_args()

    mappings = load_map(args.map)
    out_newline = "\r\n" if args.line_ending == "CRLF" else "\n"

    with args.input.open(newline="", encoding="utf-8-sig") as fp:
        reader = csv.DictReader(fp)
        if not reader.fieldnames:
            sys.exit("Empty or invalid CSV (no header row).")

        raw_fields = [h for h in reader.fieldnames if h is not None]
        api_by_raw: dict[str, str] = {}
        errors: list[str] = []
        for raw in raw_fields:
            stripped = raw.strip() if isinstance(raw, str) else raw
            try:
                api_by_raw[raw] = resolve_header(stripped, mappings)
            except KeyError:
                errors.append(stripped)

        if errors:
            sys.stderr.write(
                "Unknown source column(s) (add to --map column_mappings or rename source headers):\n  "
                + "\n  ".join(errors)
                + "\n"
            )
            sys.exit(1)

        seen: dict[str, str] = {}
        for raw, api in api_by_raw.items():
            if api in seen and seen[api] != raw:
                sys.stderr.write(
                    f"Two source columns map to the same API name {api!r}: {seen[api]!r} and {raw!r}\n"
                )
                sys.exit(1)
            seen[api] = raw

        out_names = order_columns(set(api_by_raw.values()))

        rows_out: list[dict[str, str]] = []
        for row in reader:
            out_row: dict[str, str] = {}
            for raw, api in api_by_raw.items():
                val = row.get(raw, "")
                if val is None:
                    val = ""
                out_row[api] = str(val)
            rows_out.append(out_row)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as fp:
        w = csv.DictWriter(
            fp,
            fieldnames=out_names,
            extrasaction="ignore",
            lineterminator=out_newline,
        )
        w.writeheader()
        for r in rows_out:
            w.writerow({k: r.get(k, "") for k in out_names})


if __name__ == "__main__":
    main()

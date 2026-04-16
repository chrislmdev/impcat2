#!/usr/bin/env python3
"""
Standardize CSP pricing exports to Bulk-API-ready Pricing_Item__c CSVs.

Uses the same header fingerprint + alias rules as CatalogUploadService (in-app upload).
Python 3 standard library only (no pandas).

  python3 standardize_pricing_csv.py --input raw.csv --output bulk.csv --csp aws \\
      [--config catalog_pricing_standard_config.json] [--map extra-map.json] [--line-ending LF|CRLF]

Optional --map JSON may contain column_mappings: { \"Source Header\": \"API_Name__c\" } for CSP-specific quirks.
csp_overrides in config are merged when --csp matches.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

_PLACEHOLDER_DEFAULT = "PASTE_SF__ID_FROM_PARENT_SUCCESS_CSV"
_API_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*__c$")


def header_fingerprint(raw: str | None) -> str:
    """Match CatalogUploadService.headerFingerprint: [a-z0-9] only, lower, strip trailing __c."""
    if raw is None:
        return ""
    s = raw.strip().lower()
    if s.endswith("__c"):
        s = s[: len(s) - 3]
    out = []
    for ch in s:
        if len(ch) == 1 and (ch.isdigit() or ("a" <= ch <= "z")):
            out.append(ch)
    return "".join(out)


def build_header_resolve_map(allowed_apis: set[str]) -> dict[str, str]:
    """fingerprint -> canonical API. Raises on collision (matches Apex)."""
    fp_to_api: dict[str, str] = {}
    for api in allowed_apis:
        fp = header_fingerprint(api)
        if not fp:
            continue
        if fp in fp_to_api:
            raise ValueError(
                f'Header fingerprint collision for "{fp}": {fp_to_api[fp]} vs {api}'
            )
        fp_to_api[fp] = api
    return fp_to_api


def load_json_map(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    raw = data.get("column_mappings") or data.get("mappings") or {}
    if not isinstance(raw, dict):
        sys.exit("Map file must contain column_mappings (or mappings) object.")
    out: dict[str, str] = {}
    for k, v in raw.items():
        if str(k).startswith("_"):
            continue
        out[str(k)] = str(v)
    return out


def load_config(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def resolve_column(
    hn: str,
    pricing_headers: set[str],
    bulk_parent_headers: set[str],
    fp_to_canonical: dict[str, str],
    header_aliases: dict[str, str],
) -> str | None:
    """
    Map one CSV header to canonical API name (matches CatalogUploadService pricing loop,
    extended with Catalog_Import__c / CSP__c fingerprints for bulk files).
    """
    hn = hn.strip() if hn else ""
    if not hn:
        return None

    allowed = pricing_headers | bulk_parent_headers

    if hn in allowed:
        return hn

    fp = header_fingerprint(hn)
    canon = fp_to_canonical.get(fp)
    if canon is not None:
        return canon

    alias_target = header_aliases.get(fp)
    if alias_target is not None and alias_target in pricing_headers:
        return alias_target

    return None


def order_output_columns(
    present: set[str], preferred: list[str]
) -> list[str]:
    out: list[str] = []
    for p in preferred:
        if p in present:
            out.append(p)
    rest = sorted(present - set(out))
    out.extend(rest)
    return out


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    default_config = script_dir / "catalog_pricing_standard_config.json"

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", "-i", type=Path, required=True)
    ap.add_argument("--output", "-o", type=Path, required=True)
    ap.add_argument(
        "--config",
        "-c",
        type=Path,
        default=default_config,
        help="JSON config (default: beside this script)",
    )
    ap.add_argument(
        "--map",
        "-m",
        type=Path,
        help="Optional JSON with column_mappings (exact source header -> API name)",
    )
    ap.add_argument(
        "--csp",
        required=True,
        choices=("aws", "azure", "gcp", "oracle"),
        help="CSP for CSP__c column when missing",
    )
    ap.add_argument(
        "--line-ending",
        choices=("LF", "CRLF"),
        default="LF",
    )
    ap.add_argument(
        "--placeholder",
        default=_PLACEHOLDER_DEFAULT,
        help="Catalog_Import__c value when column absent",
    )
    args = ap.parse_args()

    if not args.config.is_file():
        sys.exit(f"Config not found: {args.config}")

    cfg = load_config(args.config)
    preferred = cfg.get("preferred_column_order") or []
    pricing_headers = set(cfg.get("pricing_headers") or [])
    header_aliases: dict[str, str] = dict(cfg.get("header_aliases") or {})

    bulk_parent = {"Catalog_Import__c", "CSP__c"}
    try:
        fp_to_canonical = build_header_resolve_map(pricing_headers)
    except ValueError as e:
        sys.exit(f"Config error: {e}")

    for api in bulk_parent:
        fp = header_fingerprint(api)
        if fp and fp not in fp_to_canonical:
            fp_to_canonical[fp] = api

    allowed_apis = pricing_headers | bulk_parent

    explicit: dict[str, str] = {}
    csp_over = cfg.get("csp_overrides") or {}
    if isinstance(csp_over, dict) and args.csp in csp_over:
        co = csp_over[args.csp]
        if isinstance(co, dict):
            for k, v in co.items():
                if not str(k).startswith("_"):
                    explicit[str(k)] = str(v)

    if args.map:
        explicit.update(load_json_map(args.map))

    newline = "\r\n" if args.line_ending == "CRLF" else "\n"

    with args.input.open(newline="", encoding="utf-8-sig") as fp:
        reader = csv.DictReader(fp)
        if not reader.fieldnames:
            sys.exit("Empty or invalid CSV (no header row).")

        raw_fields = [h for h in reader.fieldnames if h is not None]
        api_by_raw: dict[str, str] = {}
        unknown: list[str] = []

        for raw in raw_fields:
            stripped = raw.strip()
            if stripped in explicit:
                target = explicit[stripped]
                if target not in allowed_apis:
                    sys.exit(
                        f"Explicit map {stripped!r} -> {target!r} is not an allowed API name."
                    )
                if not _API_RE.match(target):
                    sys.exit(f"Invalid API name in map: {target!r}")
                api_by_raw[raw] = target
                continue
            resolved = resolve_column(
                stripped,
                pricing_headers,
                bulk_parent,
                fp_to_canonical,
                header_aliases,
            )
            if resolved is None:
                unknown.append(stripped)
                continue
            api_by_raw[raw] = resolved

        if unknown:
            sys.stderr.write(
                "Unknown column(s):\n  " + "\n  ".join(unknown) + "\n"
            )
            sys.stderr.write(
                "Add --map column_mappings, fix headers, or extend header_aliases / csp_overrides in config.\n"
            )
            sys.exit(1)

        seen: dict[str, str] = {}
        for raw, api in api_by_raw.items():
            if api in seen and seen[api] != raw:
                sys.stderr.write(
                    f"Duplicate column maps to {api!r}: {seen[api]!r} vs {raw!r}\n"
                )
                sys.exit(1)
            seen[api] = raw

        if "Catalog_Item_Number__c" not in api_by_raw.values():
            sys.exit(
                "Required column Catalog_Item_Number__c not found (map SKU or equivalent)."
            )

        rows_out: list[dict[str, str]] = []
        for row in reader:
            out_row: dict[str, str] = {}
            for raw, api in api_by_raw.items():
                val = row.get(raw, "")
                if val is None:
                    val = ""
                out_row[api] = str(val).strip() if isinstance(val, str) else str(val)
            rows_out.append(out_row)

    present = set(api_by_raw.values())
    if "Catalog_Import__c" not in present:
        present.add("Catalog_Import__c")
    if "CSP__c" not in present:
        present.add("CSP__c")

    out_cols = order_output_columns(present, list(preferred))

    for r in rows_out:
        if "Catalog_Import__c" not in r or not r.get("Catalog_Import__c"):
            r["Catalog_Import__c"] = args.placeholder
        if "CSP__c" not in r or not r.get("CSP__c"):
            r["CSP__c"] = args.csp

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as fp:
        w = csv.DictWriter(
            fp,
            fieldnames=out_cols,
            extrasaction="ignore",
            lineterminator=newline,
        )
        w.writeheader()
        for r in rows_out:
            w.writerow({k: r.get(k, "") for k in out_cols})

    print(f"Wrote {args.output} ({len(rows_out)} data rows, {args.line_ending}).")


if __name__ == "__main__":
    main()

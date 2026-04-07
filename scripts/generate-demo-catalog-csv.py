#!/usr/bin/env python3
"""
Writes demo bulk-upload CSVs under demo-data/catalog-mock/.

Usage (from repo root):
  python scripts/generate-demo-catalog-csv.py

If Python is not installed (Windows):
  powershell -NoProfile -File scripts/generate-demo-catalog-csv.ps1

Filenames match CatalogUploadService: {YYYY-MM}_{csp}_{schema}.csv
Each file has ROW_COUNT+ data rows (default 520). February files are built so
month-over-month diffs show: unchanged, updated, added, and removed lines.
"""
from __future__ import annotations

import csv
import os
from pathlib import Path

ROW_COUNT = 520
OUT_DIR = Path(__file__).resolve().parent.parent / "demo-data" / "catalog-mock"


def write_pricing_jan(path: Path) -> None:
    headers = [
        "Catalog_Item_Number__c",
        "Title__c",
        "CSO_Short_Name__c",
        "Description__c",
        "List_Unit_Price__c",
        "Pricing_Unit__c",
        "JWCC_Unit_Price__c",
        "JWCC_Unit_Of_Issue__c",
        "Discount_Premium_Fee__c",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(headers)
        for i in range(1, ROW_COUNT + 1):
            sku = f"DEMO-P-202601-{i:05d}"
            list_price = round(9.99 + (i * 0.07), 4)
            jwcc = round(list_price * 0.88, 4)
            unit = "Each" if i % 2 == 0 else "GB-Mo"
            w.writerow(
                [
                    sku,
                    f"Mock AWS catalog line {i} — compute & storage blend",
                    f"CSO-SVC-{(i % 40) + 1:02d}",
                    f"Demo description for pricing row {i}; safe for POC uploads.",
                    str(list_price),
                    unit,
                    str(jwcc),
                    unit,
                    "Standard" if i % 5 != 0 else "",
                ]
            )


def write_pricing_feb(path: Path) -> None:
    """Subset of Jan kept identical; some prices bumped; many Jan SKUs omitted; new SKUs."""
    unchanged_end = 220  # rows 1..220 same as Jan
    updated_start, updated_end = 221, 320  # same keys, higher list price
    new_count = ROW_COUNT - unchanged_end - (updated_end - updated_start + 1)
    # 220 + 100 + 200 = 520

    headers = [
        "Catalog_Item_Number__c",
        "Title__c",
        "CSO_Short_Name__c",
        "Description__c",
        "List_Unit_Price__c",
        "Pricing_Unit__c",
        "JWCC_Unit_Price__c",
        "JWCC_Unit_Of_Issue__c",
        "Discount_Premium_Fee__c",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(headers)
        for i in range(1, unchanged_end + 1):
            sku = f"DEMO-P-202601-{i:05d}"
            list_price = round(9.99 + (i * 0.07), 4)
            jwcc = round(list_price * 0.88, 4)
            unit = "Each" if i % 2 == 0 else "GB-Mo"
            w.writerow(
                [
                    sku,
                    f"Mock AWS catalog line {i} — compute & storage blend",
                    f"CSO-SVC-{(i % 40) + 1:02d}",
                    f"Demo description for pricing row {i}; safe for POC uploads.",
                    str(list_price),
                    unit,
                    str(jwcc),
                    unit,
                    "Standard" if i % 5 != 0 else "",
                ]
            )
        for i in range(updated_start, updated_end + 1):
            sku = f"DEMO-P-202601-{i:05d}"
            list_price = round(9.99 + (i * 0.07) + 2.5, 4)  # +2.50 vs Jan
            jwcc = round(list_price * 0.88, 4)
            unit = "Each" if i % 2 == 0 else "GB-Mo"
            w.writerow(
                [
                    sku,
                    f"Mock AWS catalog line {i} — compute & storage blend",
                    f"CSO-SVC-{(i % 40) + 1:02d}",
                    f"Demo description for pricing row {i}; safe for POC uploads.",
                    str(list_price),
                    unit,
                    str(jwcc),
                    unit,
                    "Standard" if i % 5 != 0 else "",
                ]
            )
        for j in range(1, new_count + 1):
            sku = f"DEMO-P-202602-NEW-{j:05d}"
            list_price = round(19.5 + (j * 0.05), 4)
            jwcc = round(list_price * 0.9, 4)
            unit = "Each"
            w.writerow(
                [
                    sku,
                    f"New February 2026 SKU {j}",
                    f"CSO-NEW-{(j % 12) + 1:02d}",
                    "Net-new item for added-row demo.",
                    str(list_price),
                    unit,
                    str(jwcc),
                    unit,
                    "",
                ]
            )


def write_exceptions_jan(path: Path) -> None:
    headers = [
        "Exception_Unique_Id__c",
        "CSO_Short_Name__c",
        "Impact_Level__c",
        "Exception_Status__c",
        "Exception_PWS_Requirement__c",
        "Exception_Basis_For_Request__c",
        "Exception_Security__c",
    ]
    impacts = ("Low", "Medium", "High")
    statuses = ("Draft", "Open", "In Review", "Approved")
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(headers)
        for i in range(1, ROW_COUNT + 1):
            uid = f"DEMO-X-202601-{i:05d}"
            w.writerow(
                [
                    uid,
                    f"Workload-{(i % 35) + 1:02d}",
                    impacts[i % 3],
                    statuses[i % 4],
                    "PWS required" if i % 3 == 0 else "Not required",
                    "Cost optimization" if i % 2 == 0 else "Architecture alignment",
                    "FedRAMP Moderate" if i % 4 == 0 else "IL5",
                ]
            )


def write_exceptions_feb(path: Path) -> None:
    unchanged_end = 200
    updated_start, updated_end = 201, 290
    new_count = ROW_COUNT - unchanged_end - (updated_end - updated_start + 1)

    headers = [
        "Exception_Unique_Id__c",
        "CSO_Short_Name__c",
        "Impact_Level__c",
        "Exception_Status__c",
        "Exception_PWS_Requirement__c",
        "Exception_Basis_For_Request__c",
        "Exception_Security__c",
    ]
    impacts = ("Low", "Medium", "High")
    statuses = ("Draft", "Open", "In Review", "Approved")
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(headers)
        for i in range(1, unchanged_end + 1):
            uid = f"DEMO-X-202601-{i:05d}"
            w.writerow(
                [
                    uid,
                    f"Workload-{(i % 35) + 1:02d}",
                    impacts[i % 3],
                    statuses[i % 4],
                    "PWS required" if i % 3 == 0 else "Not required",
                    "Cost optimization" if i % 2 == 0 else "Architecture alignment",
                    "FedRAMP Moderate" if i % 4 == 0 else "IL5",
                ]
            )
        for i in range(updated_start, updated_end + 1):
            uid = f"DEMO-X-202601-{i:05d}"
            # Same row except status bumped forward in workflow (updated vs Jan)
            st = statuses[(i % 4 + 1) % 4]
            w.writerow(
                [
                    uid,
                    f"Workload-{(i % 35) + 1:02d}",
                    impacts[i % 3],
                    st,
                    "PWS required" if i % 3 == 0 else "Not required",
                    "Cost optimization" if i % 2 == 0 else "Architecture alignment",
                    "FedRAMP Moderate" if i % 4 == 0 else "IL5",
                ]
            )
        for j in range(1, new_count + 1):
            uid = f"DEMO-X-202602-NEW-{j:05d}"
            w.writerow(
                [
                    uid,
                    f"NewEx-{(j % 20) + 1:02d}",
                    "High",
                    "Open",
                    "PWS required",
                    "New capability onboarding",
                    "IL5",
                ]
            )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    files = [
        ("2026-01_aws_pricing.csv", write_pricing_jan),
        ("2026-02_aws_pricing.csv", write_pricing_feb),
        ("2026-01_aws_exceptions.csv", write_exceptions_jan),
        ("2026-02_aws_exceptions.csv", write_exceptions_feb),
    ]
    for name, fn in files:
        p = OUT_DIR / name
        fn(p)
        with p.open("r", encoding="utf-8") as fh:
            lines = sum(1 for _ in fh)
        print(f"Wrote {p} ({lines} lines including header)")


if __name__ == "__main__":
    main()

# Operational flows (with diagrams)

## 1. User opens Pricing Catalog

```mermaid
sequenceDiagram
    participant User
    participant LWC as pricingCatalog_LWC
    participant Apex as CloudPrismCatalogController
    participant DB as Salesforce_DB

    User->>LWC: Open_CloudPrism_Pricing_tab
    LWC->>Apex: getPricingItems_csp_searchKey_rowLimit
    Apex->>DB: SOQL_Pricing_Item__c_with_parent_filter
    DB-->>Apex: rows
    Apex-->>LWC: List_Pricing_Item__c
    LWC-->>User: lightning_datatable
```

Search applies to **Title**, **Catalog_Item_Number**, **CSO_Short_Name** only (long text fields are not filterable in SOQL `WHERE`).

---

## 2. User opens Exceptions Library

Same pattern as pricing, with `getExceptionItems` and `Exception_Item__c`; search excludes long-text PWS/basis/security columns from the `WHERE` clause.

```mermaid
sequenceDiagram
    participant User
    participant LWC as exceptionsLibrary_LWC
    participant Apex as CloudPrismCatalogController
    participant DB as Salesforce_DB

    User->>LWC: Open_Cloud_Prism_Exceptions_tab
    LWC->>Apex: getExceptionItems
    Apex->>DB: SOQL_Exception_Item__c
    DB-->>Apex: rows
    Apex-->>LWC: List_Exception_Item__c
    LWC-->>User: lightning_datatable
```

---

## 3. Catalog Changes — load months and diff grid

```mermaid
sequenceDiagram
    participant User
    participant LWC as catalogChanges_LWC
    participant Apex as CloudPrismCatalogController
    participant PS as PricingChangeService
    participant ES as ExceptionChangeService
    participant DB as Salesforce_DB

    User->>LWC: Select_mode_pricing_or_exceptions
    LWC->>Apex: getDistinctImportMonths_schemaName
    Apex->>DB: Aggregate_Catalog_Import__c_by_month
    DB-->>LWC: month_options

    User->>LWC: Select_from_to_CSP_changeType_Compare
    LWC->>Apex: getCatalogChangeRows_entity_months_filters
    alt entity_pricing
        Apex->>PS: compare
        PS->>DB: SOQL_two_month_snapshots
        PS-->>Apex: List_PricingChangeRow
    else entity_exceptions
        Apex->>ES: compare
        ES->>DB: SOQL_two_month_snapshots
        ES-->>Apex: List_ExceptionChangeRow
    end
    Apex-->>LWC: rows
    LWC-->>User: lightning_datatable
```

### Internal diff pipeline (pricing)

```mermaid
flowchart TD
    A[Input_monthFrom_monthTo_optional_CSP_changeType] --> B[latestPricingForMonth_from]
    A --> C[latestPricingForMonth_to]
    B --> D[Map_key_csp_catalogNumber]
    C --> D
    D --> E[Union_keys]
    E --> F{For_each_key}
    F --> G[Classify_added_removed_updated]
    G --> H[Filter_CSP_and_changeType]
    H --> I[Sort_and_return_DTOs]
```

**Updated (pricing)** when any of these differ between months: JWCC price, commercial list price, discount/premium string, JWCC unit, commercial unit.

### Internal diff pipeline (exceptions)

```mermaid
flowchart TD
    A[Input_monthFrom_monthTo_optional_CSP_changeType] --> B[latestExceptionsForMonth_from]
    A --> C[latestExceptionsForMonth_to]
    B --> D[Map_key_csp_exceptionId]
    C --> D
    D --> E[Union_keys_classify]
    E --> F[Compare_text_fields_for_update]
    F --> G[Return_ExceptionChangeRow]
```

**Updated (exceptions)** when impact level, status, PWS, basis, security, or CSO short name differ.

---

## 4. Sample data load (developer)

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant CLI as Salesforce_CLI
    participant Apex as Anonymous_Apex
    participant DB as Salesforce_DB

    Dev->>CLI: sf_apex_run_file_sample_data_apex
    CLI->>Apex: execute_anonymous
    Apex->>DB: insert_Catalog_Import_x16
    Apex->>DB: insert_Pricing_Item_x16
    Apex->>DB: insert_Exception_Item_x16
    DB-->>Dev: demo_rows_ready
```

Requires **CloudPrism_POC** (or equivalent FLS) on the running user. Re-running duplicates headers unless old demo trees are deleted.

---

## 5. Metadata deploy (CI or laptop)

```mermaid
flowchart LR
    A[Edit_metadata_in_repo] --> B[sf_project_deploy_start]
    B --> C{Tests_required}
    C -->|optional| D[sf_apex_run_test]
    B --> E[Org_updated]
```

---

## 6. Target production-style load (future — not implemented in repo)

```mermaid
flowchart TB
    subgraph sharepoint [SharePoint]
        F[Monthly_CSV_files]
    end

    subgraph mule [MuleSoft_optional]
        M[Poll_or_schedule]
        M --> N[Parse_name_and_map_columns]
        N --> O[Upsert_Catalog_Import]
        O --> P[Bulk_API_2_child_load]
    end

    subgraph org [Salesforce]
        DB[(Custom_objects)]
    end

    F --> M
    P --> DB
    DB --> Q[CloudPrism_UI_and_diffs]
```

This integration is **architectural** only; implement MuleSoft (or another ETL) separately.

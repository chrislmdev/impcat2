# Dependencies and tooling

## Inside the Salesforce org (runtime)

**No third-party managed packages or AppExchange components are required** for this POC. Everything deploys as **your org’s own metadata**:

- Custom objects, fields, tabs, layouts  
- Apex classes (controller + change services + tests)  
- Lightning Web Components using **platform** modules only  
- Custom application **CloudPrism**, FlexiPages, permission set **CloudPrism_POC**

### LWC imports (all stock platform)

LWCs use:

- `lwc` (`LightningElement`, `wire`, `track`)  
- `@salesforce/apex/...` (generated bindings to your Apex)  
- **Lightning Base Components** in markup: `lightning-card`, `lightning-datatable`, `lightning-combobox`, `lightning-input`, `lightning-button`, etc.

There is **no `package.json`** in this repo and **no npm libraries** bundled into the bundle. Salesforce compiles and serves LWCs from metadata.

### Apex

Standard **Salesforce Apex** on the Lightning Platform: SOQL, DML, `@AuraEnabled`, `with sharing`. No callouts to external services in the POC read/diff path.

---

## On your machine (not “in Salesforce”)

These are **developer/operator tools**. They are **not deployed** into the org and are **not** Salesforce product features inside the UI.

| Tool | Role |
|------|------|
| **Salesforce CLI** (`sf`) | Login, deploy metadata (`sf project deploy start`), run Anonymous Apex (`sf apex run`), run tests (`sf apex run test`), optional Bulk/Data commands |
| **Git** | Version control for this repository |

Optional: **VS Code / Cursor** with Salesforce extensions for editing; still optional.

---

## Summary

| Question | Answer |
|----------|--------|
| Did we download libraries into the org? | **No** — no managed packages. |
| Did we use npm packages for LWCs? | **No** — no `package.json`. |
| What must be installed locally to deploy? | **Salesforce CLI** (and a browser for `sf org login web`). |
| What must users have in the org? | A **Salesforce license** with Lightning + custom objects/Apex/LWC enabled (typical Enterprise / dev org). |

Future integrations (e.g. **MuleSoft** loading CSVs from SharePoint) would be **separate** from this repo’s metadata: they call Salesforce **standard APIs** (REST, Bulk API 2.0) and do not change the “no extra org packages” fact unless you later add a connector package by choice.

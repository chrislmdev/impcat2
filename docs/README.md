# CloudPrism Salesforce POC — documentation

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Layers, runtime components, security, deployment topology |
| [DATA_MODEL.md](./DATA_MODEL.md) | Custom objects, relationships, key fields |
| [FLOWS.md](./FLOWS.md) | End-to-end flows with Mermaid diagrams (UI, diffs, sample load, CI) |
| [END_TO_END_WALKTHROUGH.md](./END_TO_END_WALKTHROUGH.md) | Narrative walkthrough from login through upload, browse, and Catalog Changes |
| [DEPENDENCIES_AND_TOOLING.md](./DEPENDENCIES_AND_TOOLING.md) | What ships with Salesforce vs what you install locally; no third-party org packages |
| [MULESOFT_CATALOG_INGEST.md](./MULESOFT_CATALOG_INGEST.md) | Large-catalog ingest; **guided wizard** + SF CLI step-by-step (parent then child, `sf__Id`) vs in-app upload |

Start with **ARCHITECTURE.md** for the big picture, **END_TO_END_WALKTHROUGH.md** for a single guided story, then **FLOWS.md** for diagram-heavy behavior.

# README.md - Diff: Old vs New

This document shows exactly what will change in `README.md` when executed.

---

## Summary of Changes

1. **Add new header section** - NSReady / NSWare Platform introduction
2. **Replace "Project Structure"** - Update with full folder tree and explanations
3. **Add backend organization explanation** - Clarify split across folders
4. **Add documentation layout** - Explain docs/ vs master_docs/
5. **Add future reorganization note** - Light mention of optional future work
6. **Add "How to Work" sections** - NSReady vs NSWare guidance
7. **Fix security doc reference** - Remove broken link, use neutral reference

---

## Detailed Diff

### Change 1: New Header Section (INSERT at top)

**Location:** Replace lines 1-9

**OLD:**
```markdown
## NTPPL NS-Ready Data Collection and Configuration Platform (Tier-1 – Local)

This repository contains a minimal, production-ready Docker scaffold for a local Tier-1 deployment with:
- **admin_tool** (FastAPI, port 8000)
- **collector_service** (FastAPI, port 8001)
- **PostgreSQL 15 with TimescaleDB**
- **NATS** message queue

Phase-1 focuses on the operational environment only (no business logic yet).
```

**NEW:**
```markdown
# NSReady / NSWare Platform – Project Root

This repository contains **two related but separate tracks**:

1. **NSReady – Data Collection Software**  
   Lightweight, secure data collection + SCADA export layer with tenant isolation.  
   👉 This is the **active work now**.

2. **NSWare – Frontend Dashboard / Full Platform (Future)**  
   Industrial analytics + dashboards + KPI/alert engine + AI/ML.  
   👉 This is a **later phase**, not the current focus.

The root folder is the common home for both, but each track has its own subfolder and lifecycle.

---

## NTPPL NS-Ready Data Collection and Configuration Platform (Tier-1 – Local)

This repository contains a minimal, production-ready Docker scaffold for a local Tier-1 deployment with:
- **admin_tool** (FastAPI, port 8000)
- **collector_service** (FastAPI, port 8001)
- **PostgreSQL 15 with TimescaleDB**
- **NATS** message queue

Phase-1 focuses on the operational environment only (no business logic yet).
```

---

### Change 2: Replace "Project Structure" Section

**Location:** Replace lines 29-50

**⚠️ CRITICAL: Remove old section completely - no duplicates!**

**OLD:**
```markdown
### Project Structure
```
ntppl_nsready_platform/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── Makefile
├── admin_tool/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── collector_service/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
└── db/
    ├── init.sql
    ├── migrations/
    │   └── (placeholder)
    └── Dockerfile
```
```

**NEW:**
```markdown
## Repository Structure

```text
ntppl_nsready_platform/

├── admin_tool/              # NSReady backend – Admin APIs, configuration, registry
├── collector_service/       # NSReady backend – Data ingestion pipeline
├── db/                      # NSReady database (schema, migrations, init scripts)
├── frontend_dashboard/      # NSWare UI (future dashboard work)
├── contracts/               # NSReady data contracts (schemas, interfaces)
├── deploy/                  # Kubernetes/Helm deployment manifests
├── scripts/                 # Operational tools and helper scripts
├── tests/                   # Test suite (security, negative, data-flow, etc.)
├── docs/                    # Implementation & module documentation
├── master_docs/             # High-level design, security, and roadmap documents
├── docker-compose.yml        # Local Docker development
├── Makefile                 # Build and test shortcuts
└── README.md                # This file
```

**NSReady backend is split across three main folders:**

- `admin_tool/` – Admin APIs, configuration, registry, parameter/metadata management
- `collector_service/` – Telemetry ingestion pipeline and queue/worker logic
- `db/` – Database schema, migrations, initialization scripts

### Documentation Layout

- `docs/` – Module/implementation docs (00–13, operations, manuals).
- `master_docs/` – High-level architecture, security position, and NSReady/NSWare planning.

**Note:** In the future, the backend folders (`admin_tool/`, `collector_service/`, `db/`) may be grouped under a single parent (e.g. `nsready_backend/`) for cleaner structure. For now, this README reflects the actual, current layout.
```

---

### Change 3: Add NSReady Section (INSERT after Repository Structure)

**Location:** Insert after new Repository Structure section

**NEW:**
```markdown
---

## NSReady – Data Collection Software (Current Focus)

NSReady is the data collection and SCADA export engine:

- Ingests data from field devices / SCADA
- Uses a multi-tenant model (Customer = Tenant)
- Provides registry tools, parameter templates, and SCADA-friendly views
- Exposes APIs for data collection and internal dashboards

### Security & Testing (NSReady)

NSReady already includes:

- ✅ Tenant isolation
- ✅ X-Customer-ID header for tenant scoping
- ✅ Engineers can access without tenant header; customers see only their own data
- ✅ Bearer-token authentication on admin endpoints
- ✅ Negative tests for invalid UUIDs, malformed JSON, bad payloads
- ✅ Data flow verification from collector → queue → worker → DB → SCADA views
- ✅ Error hygiene (no internal stack traces or SQL in API responses)

See:
- `tests/` for test suites
- `master_docs/` for security position and planning documents

For a deeper NSReady vs NSWare security and roadmap view, refer to the planning documents under `master_docs/` (a dedicated `NSREADY_VS_NSWARE_SECURITY_SPLIT.md` will be added there in a future update).

**⚠️ NOTE: This is neutral text only - NO markdown link like `[text](path.md)` - just plain text reference.**

---

## NSWare – Frontend Dashboard / Full Platform (Future)

NSWare is the future full platform:

- Multi-level dashboards (customer / zone / plant / global)
- KPI & alert engines
- AI/ML pipelines and scoring
- IAM, JWT, RBAC, MFA, billing, etc.

This work will primarily live in:

- `frontend_dashboard/`
- Additional backend modules, when they are created

For now:

- NSWare items in the docs are design and roadmap only.
- No NSWare security or IAM features are assumed to be active in the NSReady code.

---

## How to Work in This Repo (For Humans & AI)

### Working on NSReady (Data Collection Software)

If you are working on the NSReady data collection backend, focus on:

- `admin_tool/`
- `collector_service/`
- `db/`
- `contracts/`
- `tests/` (NSReady test suites)

**Typical tasks:**
- API changes
- Ingestion pipeline
- SCADA views
- Backend tests and scripts

**When asking AI (e.g., in Cursor), be explicit:**

> "This change is for the NSReady backend (`admin_tool/`, `collector_service/`, `db/`) – not for the `frontend_dashboard`."

### Working on NSWare (Frontend Dashboard – Future)

If you are working on the NSWare frontend dashboard, focus on:

- `frontend_dashboard/`

**Typical tasks:**
- UI components
- Dashboard layouts
- API integration with NSReady

**When asking AI:**

> "This change is for the NSWare dashboard in `frontend_dashboard/`."

---

## NSReady vs NSWare – Security, Testing & Roadmap

A detailed split of what applies now to NSReady vs what is planned for NSWare later is maintained in:

- `master_docs/` (planning documents)

That documentation covers:

- NSReady security controls (implemented + tested)
- NSWare future security roadmap (JWT, IAM, SSO, etc.)
- Joint requirements (logging, monitoring, policies)
- Roadmap from NSReady hardening → NSWare platform → SaaS

---

## Next Steps

1. Finalize the folder structure documentation (this README).
2. Keep this root README.md aligned with the real structure.
3. Add more details into:
   - `admin_tool/README.md`
   - `collector_service/README.md`
   - `frontend_dashboard/README.md`
4. Keep all cross-cutting design docs under `master_docs/`.

---

This README is intentionally written to make the boundaries between NSReady and NSWare explicit for both developers and AI tools (e.g., Cursor) so that changes and suggestions stay in the correct part of the project.

---
```

---

### Change 4: Keep Existing Sections (PRESERVE)

**Location:** Keep all existing sections below the new content

**PRESERVE:**
- NSReady v1 Tenant Model section
- Prerequisites
- Environment Variables
- Build and Run
- Health Checks
- Tear Down
- Testing (all subsections)
- Notes

**These sections remain unchanged** - they're still accurate and useful.

---

## Visual Summary

```
README.md (NEW STRUCTURE)
│
├── [NEW] NSReady / NSWare Platform Header
├── [NEW] Repository Structure (updated)
├── [NEW] NSReady Section
├── [NEW] NSWare Section
├── [NEW] How to Work in This Repo
├── [NEW] NSReady vs NSWare Security/Roadmap
├── [NEW] Next Steps
│
├── [KEEP] NSReady v1 Tenant Model
├── [KEEP] Prerequisites
├── [KEEP] Project Structure (old - REMOVE)
├── [KEEP] Environment Variables
├── [KEEP] Build and Run
├── [KEEP] Health Checks
├── [KEEP] Tear Down
├── [KEEP] Testing
└── [KEEP] Notes
```

---

## Validation Checklist

After applying changes, verify:

**Folder Names:**
- [ ] All folder names match actual structure (no typos)
- [ ] `admin_tool/` exists ✓
- [ ] `collector_service/` exists ✓
- [ ] `db/` exists ✓
- [ ] `frontend_dashboard/` exists ✓
- [ ] `contracts/` exists ✓
- [ ] `deploy/` exists ✓
- [ ] `scripts/` exists ✓
- [ ] `tests/` exists ✓
- [ ] `docs/` exists ✓
- [ ] `master_docs/` exists ✓

**Structure:**
- [ ] **Only ONE structure section exists** (old "Project Structure" completely removed)
- [ ] **Heading levels correct** - Only one `#` at top, rest are `##` or `###`
- [ ] No duplicate headings

**Content:**
- [ ] No broken internal links
- [ ] **Security doc reference** - No markdown links like `[text](path.md)`, just neutral text
- [ ] NSReady vs NSWare distinction is clear
- [ ] Backend organization is explained
- [ ] Documentation layout is clarified
- [ ] Existing sections maintain consistent heading levels

---

## Ready to Apply

When you're ready to execute:

1. Backup: `cp README.md README.md.backup`
2. Apply changes from this diff
3. Run validation checklist
4. Commit when satisfied

**Estimated time:** 30 minutes


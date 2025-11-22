# ADR-003: NSReady Tenant Model Decision (v1)

**Status:** Accepted  
**Date:** 2025-11-18  
**Decision Owner:** Niraj Desai  
**Applies To:** NSReady v1, NSWare v1.x  
**Linked Docs:** ALLIDHRA_GROUP_MODEL_ANALYSIS.md, TENANT_MODEL_SUMMARY.md

---

## 1. Context

NSReady must support:

- Multiple customers
- Group-level reporting (Customer Group → multiple subsidiaries)
- Strong data isolation
- SCADA filtering
- SaaS-style multi-tenant AI/ML in the future

The schema already contains `customers → projects → sites → devices`, but no explicit "tenant" layer.

---

## 2. Decision

### **Tenant = customer_id**

Each individual company is treated as a separate tenant.

### **parent_customer_id = grouping only**

Used for:

- Group dashboards
- Group exports
- Group KPI rollups
- Parent-level reporting

**Parent is NOT a tenant in v1.**

This ensures:

- Zero breaking changes
- No ingestion / SCADA / API rework
- Clean isolation boundaries
- Future scalability without migration

---

## 3. Alternatives Considered

### Option A – True Tenant Table (NOT SELECTED)

Adding `tenants` table and linking customers → tenant.

❌ Too heavy  
❌ Requires major schema migration  
❌ Not needed for NSReady v1

---

### Option B – Use metadata only (NOT SELECTED)

Encoding hierarchy in JSON metadata.

❌ Query complexity  
❌ No FK integrity  
❌ Hard to maintain

---

### Option C – Add parent_customer_id (SELECTED ✔️)

Reasoning:

- Minimal change
- Supports unlimited hierarchy
- Clear isolation boundaries
- Future compatible with NSWare AI/ML architecture

---

## 4. Consequences

### Positive (✔️)

- Data isolation guaranteed
- Safe for SCADA/dashboards
- Compatible with future multi-tenant ML
- Simple to operate & reason about
- Zero refactoring needed later

### Negative (⚠️)

- Parent-level access control must be implemented manually (not automatic)

---

## 5. Future Evolution (v2+)

- Promote parent → tenant (if needed)
- Introduce `organizations` table (if needed)
- Add per-tenant RBAC model
- Tenant-specific SCADA profiles and dashboards

These require **no rework** because v1 design cleanly separates:

- Isolation (tenant)
- Grouping (parent)

---

## 6. Status

**This decision is final for NSReady v1.**  
All documentation and code will follow this rule.

---

## Related Documentation

- **TENANT_MODEL_SUMMARY.md** – Quick reference for all teams
- **TENANT_MODEL_DIAGRAM.md** – Visual diagrams and logical views
- **ALLIDHRA_GROUP_MODEL_ANALYSIS.md** – Detailed analysis with examples
- **Module 0** – Introduction and Terminology (Section 7.1 Tenant Model)
- **Module 2** – System Architecture and DataFlow (Tenant Boundary notes)
- **Module 3** – Environment and PostgreSQL Storage Manual (Tenant Storage Model)



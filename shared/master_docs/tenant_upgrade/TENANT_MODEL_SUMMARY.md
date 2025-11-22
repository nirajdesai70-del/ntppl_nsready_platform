# NSReady Tenant Model – Summary (v1)

**Quick Reference for Engineers, SCADA Team, Dashboard Team, and AI Team**

---

## 1. Core Rule (NS-TENANT-01)

In NSReady v1:

**tenant_id = customer_id**  
**Each individual company = one tenant**

This ensures:

- Complete data isolation
- Permission clarity
- Clean routing for SCADA, dashboards, exports
- Safe foundation for NSWare AI / ML

### Tenant = Company

Example:

- Customer Group Textool → Tenant
- Customer Group Texpin → Tenant
- Customer Group XYZ → Tenant

---

## 2. Hierarchical Customer Model (NS-TENANT-02)

The `parent_customer_id` column supports **grouping only**:

```
Customer Group (parent customer)
├── Customer Group Textool  (tenant)
├── Customer Group Texpin   (tenant)
├── Customer Group XYZ      (tenant)
└── Customer Group ABC      (tenant)
```

**Parent = Not a tenant**  
Parent is only a reporting layer.

---

## 3. Why This Model (v1)?

- Zero rework
- No schema break
- Allows immediate multi-company onboarding
- Compatible with SCADA filtering
- Compatible with dashboards & exports
- Safe foundation for future ML per-tenant models

---

## 4. Isolation Rules (NS-TENANT-BOUNDARY)

Each customer (company) gets isolated access:

- SCADA views filter by `customer_id`
- Dashboards filter by `customer_id`
- Data exports filter by `customer_id`
- AI model training uses `customer_id` boundary
- Users cannot see other customer's data

Parent customers cannot automatically "see inside" children unless enabled in reporting logic.

---

## 5. Group Reporting (Future-Ready)

`parent_customer_id` enables:

- Group dashboards
- Group exports
- Consolidated KPI rollups
- NSWare Fleet Management (future)
- Per-group billing / usage metering

---

## 6. Future Upgrade Path (NS-TENANT-FUTURE)

Later, if needed:

- Parent can become a **true tenant** (v2)
- "Tenant organization" table can be added
- Multi-layer role-based access can be expanded

No rework required because:

- The hierarchy is already in place
- Isolation and grouping are already separated logically

---

## 7. TL;DR

- **Tenant = each company**
- **Parent = grouping only**
- **No schema change needed in future**
- **100% aligned with NSReady + NSWare architecture**

---

## Related Documentation

- **Module 0** – Introduction and Terminology (Section 7.1 Tenant Model)
- **Module 2** – System Architecture and DataFlow (Tenant Boundary notes)
- **Module 3** – Environment and PostgreSQL Storage Manual (Tenant Storage Model)
- **Module 9** – SCADA Integration Manual (Tenant SCADA Boundary)
- **Module 12** – API Developer Manual (Tenant API Boundary)
- **TENANT_DECISION_RECORD.md** – Architecture Decision Record (ADR-003)
- **TENANT_MODEL_DIAGRAM.md** – Visual diagrams and logical views
- **ALLIDHRA_GROUP_MODEL_ANALYSIS.md** – Detailed analysis with examples



# Tenant Model Diagram (NSReady v1)

**Visual Reference for Architecture and Data Flow**

---

## 1. Logical View (What Exists in Code)

Tenant (NSReady v1) = customer_id

```
customer_id (tenant)
    ↓
projects
    ↓
sites
    ↓
devices
    ↓
ingest_events
```

---

## 2. Hierarchical Model (With parent_customer_id)

```
                    ┌────────────────────┐
                    │   Customer Group   │  <-- parent_customer_id = NULL
                    └──────────┬─────────┘
                               │ grouping only
    ┌──────────────────────────┼───────────────────────────┐
    │                          │                           │

┌──────────────┐          ┌────────────────┐          ┌────────────────┐
│ Customer     │          │ Customer       │          │ Customer       │
│ Group        │          │ Group          │          │ Group          │
│ Textool      │          │ Texpin         │          │ XYZ            │
└──────────────┘          └────────────────┘          └────────────────┘
tenant_id = cust_id       tenant_id = cust_id         tenant_id = cust_id
(parent_customer_id        (parent_customer_id         (parent_customer_id
= Customer Group)          = Customer Group)           = Customer Group)
```

**Legend:**

- **Tenant boundary** = company
- **Parent boundary** = reporting layer

---

## 3. Isolation Boundary (What the system enforces)

Each customer_id = isolated tenant

Meaning:

- SCADA cannot mix tenants
- Dashboards cannot mix tenants
- AI cannot mix tenants

Unless grouping is explicitly requested.

---

## 4. Future Expansion Diagram (NSWare-ready)

```
Organization / Tenant (future)
    │
Customers (child units)
    │
Projects
    │
Sites
    │
Devices
    │
Telemetry / Features
```

This future model is possible **without rework** because v1 uses a clean customer hierarchy.

---

## 5. Usage Summary

- **Use customer_id for tenant filtering**
- **Use parent_customer_id for group rollups**
- **Keep Customer Group at parent level**
- **Keep subsidiary companies as tenants**

---

## 6. Data Flow Example

### Individual Company Report (Tenant Isolation)

```
Filter: customer_id = 'uuid-textool'
  ↓
projects (where customer_id = 'uuid-textool')
  ↓
sites
  ↓
devices
  ↓
ingest_events
```

### Group Report (Parent Aggregation)

```
Filter: parent_customer_id = 'uuid-customer-group' OR id = 'uuid-customer-group'
  ↓
All customers under Customer Group
  ↓
All projects under those customers
  ↓
All sites
  ↓
All devices
  ↓
All ingest_events (aggregated)
```

---

## Related Documentation

- **TENANT_MODEL_SUMMARY.md** – Quick reference for all teams
- **TENANT_DECISION_RECORD.md** – Architecture Decision Record (ADR-003)
- **ALLIDHRA_GROUP_MODEL_ANALYSIS.md** – Detailed analysis with examples
- **Module 0** – Introduction and Terminology (Section 7.1 Tenant Model)
- **Module 2** – System Architecture and DataFlow (Tenant Boundary notes)



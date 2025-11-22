# Allidhra Group Scenario – Correct Tenant/Customer Model

**Your Scenario:**
- **Allidhra Group** = OEM (parent organization)
- **6 Internal Companies** = Individual companies:
  - Allidhra Textool
  - Allidhra Texpin
  - Allidhra [Company 3]
  - Allidhra [Company 4]
  - Allidhra [Company 5]
  - Allidhra [Company 6]

**Requirements:**
- Group reports → Aggregate across all 6 companies (Allidhra Group level)
- Individual company reports → Filter by specific company (Allidhra Textool, etc.)

---

## Your Understanding: Is It Correct?

### Your Proposed Model:
- **Tenant** = Allidhra Group (parent)
- **Customer** = Individual companies (Allidhra Textool, Allidhra Texpin, etc.)

### ✅ **YES - Conceptually Correct!**

This is a **hierarchical multi-tenant** model, which is exactly right for your use case **conceptually**.

**However, in NSReady v1 implementation:**
- We keep **tenant isolation at the company level** (`tenant_id = customer_id` for each company)
- The **parent (Allidhra Group) is used for grouping/reporting**, not as the tenant boundary
- This keeps security and isolation simple while still enabling group-level dashboards

---

## Current Schema Analysis

### Current Hierarchy:
```
customers (id, name)
  ↓
projects (id, customer_id, name)
  ↓
sites (id, project_id, name)
  ↓
devices (id, site_id, name)
```

### Problem:
- Current schema has `customers` as the top level
- No parent-child relationship for customers
- Can't model "Allidhra Group" as parent of "Allidhra Textool"

---

## Solution Options

### Option 1: Add `parent_customer_id` to `customers` table (RECOMMENDED)

**Schema Change:**
```sql
ALTER TABLE customers 
ADD COLUMN parent_customer_id UUID REFERENCES customers(id);

-- Allidhra Group (parent, no parent_customer_id = NULL)
INSERT INTO customers (id, name) VALUES 
  ('uuid-allidhra-group', 'Allidhra Group');

-- Individual companies (children, parent_customer_id = Allidhra Group)
INSERT INTO customers (id, name, parent_customer_id) VALUES 
  ('uuid-textool', 'Allidhra Textool', 'uuid-allidhra-group'),
  ('uuid-texpin', 'Allidhra Texpin', 'uuid-allidhra-group');
```

**Model (Conceptual):**
- **Parent/OEM** = Allidhra Group (`parent_customer_id IS NULL`)
- **Customer** = Individual companies (`parent_customer_id = Allidhra Group UUID`)

**Model (NSReady v1 Implementation):**
- **Tenant** = Each individual company (`tenant_id = customer_id`)
- **Parent** = Used for grouping/reporting only (`parent_customer_id`)

**Benefits:**
- ✅ Minimal schema change
- ✅ Supports unlimited hierarchy levels
- ✅ Group reports: Filter by `parent_customer_id = 'uuid-allidhra-group'`
- ✅ Individual reports: Filter by `customer_id = 'uuid-textool'`

---

### Option 2: Add `organizations` or `tenants` table above `customers`

**Schema Change:**
```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE customers 
ADD COLUMN organization_id UUID REFERENCES organizations(id);
```

**Model:**
- **Tenant/Organization** = Allidhra Group (in `organizations` table)
- **Customer** = Individual companies (in `customers` table with `organization_id`)

**Benefits:**
- ✅ Clear separation of tenant vs customer
- ✅ Supports multiple tenants in future
- ✅ More explicit hierarchy

**Drawbacks:**
- ❌ More schema changes
- ❌ More complex queries

---

### Option 3: Use Current Schema with Metadata (Quick Fix)

**No Schema Change:**
```sql
-- Allidhra Group
INSERT INTO customers (id, name, metadata) VALUES 
  ('uuid-allidhra-group', 'Allidhra Group', 
   '{"type": "parent", "is_tenant": true}'::jsonb);

-- Individual companies
INSERT INTO customers (id, name, metadata) VALUES 
  ('uuid-textool', 'Allidhra Textool', 
   '{"type": "child", "parent_id": "uuid-allidhra-group"}'::jsonb);
```

**Model:**
- **Tenant** = Customers where `metadata->>'is_tenant' = 'true'`
- **Customer** = Customers where `metadata->>'type' = 'child'`

**Benefits:**
- ✅ No schema migration needed
- ✅ Works immediately

**Drawbacks:**
- ❌ Less explicit (relies on metadata)
- ❌ Harder to query efficiently
- ❌ No foreign key enforcement

---

## Recommended Solution: Option 1 (parent_customer_id) – For Grouping, Not Tenant Boundary (v1)

We have adopted **Option 1** by adding `parent_customer_id` to the `customers` table.  
This unlocks **hierarchical customers** like:

- Allidhra Group (parent)
- Allidhra Textool (child)
- Allidhra Texpin (child)
- etc.

However, for **NSReady v1**, we intentionally **keep tenant isolation at the individual company level**, not at the group level.

### Effective Model in NSReady v1

- **Tenant** (for access, SCADA, AI isolation):  
  ```text
  tenant_id = customer_id    (individual legal entity)
  ```
  e.g.:
  - `tenant_id = Allidhra Textool`
  - `tenant_id = Allidhra Texpin`

- **Group / OEM / Parent** (for reporting only):  
  - Represented using `parent_customer_id`
  - e.g. `parent = Allidhra Group`, `children = Textool, Texpin, etc.`

This means:

- A company-level user (e.g. Allidhra Textool ops) sees only their own `customer_id` (tenant).
- A group-level dashboard for Allidhra Group aggregates over all customers where `parent_customer_id = Allidhra Group` (and optionally the parent itself).

### Why We Keep Tenant = customer_id (For Now)

- ✅ Keeps isolation & security simple and explicit
- ✅ Aligns with existing code, queries, and documentation (`tenant_id = customer_id`)
- ✅ `parent_customer_id` is a reporting/grouping feature, not a security boundary in v1
- ✅ Allows us to support OEMs/groups (like Allidhra) without forcing every customer into a strict parent/child structure now

**Later**, if we decide that some OEMs truly want full "group as tenant" behaviour (shared data and models, but isolated from other OEMs), we can:

- Promote the parent-level (`parent_customer_id IS NULL`) to be the conceptual tenant for those cases
- Keep this backward compatible by deriving `tenant_id` using either:
  - `customer_id` (company-level tenant) OR
  - `parent_customer_id` (group-level tenant) when explicitly configured

For now, we deliberately keep it simple.

### Efficient Queries

```sql
-- Group report (all companies under Allidhra Group)
SELECT * FROM ingest_events 
WHERE device_id IN (
  SELECT id FROM devices WHERE site_id IN (
    SELECT id FROM sites WHERE project_id IN (
      SELECT id FROM projects WHERE customer_id IN (
        SELECT id FROM customers 
        WHERE parent_customer_id = 'uuid-allidhra-group'
        OR id = 'uuid-allidhra-group'
      )
    )
  )
);

-- Individual company report (Allidhra Textool only)
-- Note: This uses customer_id directly (tenant isolation)
SELECT * FROM ingest_events 
WHERE device_id IN (
  SELECT id FROM devices WHERE site_id IN (
    SELECT id FROM sites WHERE project_id IN (
      SELECT id FROM projects WHERE customer_id = 'uuid-textool'
    )
  )
);
```

---

## Implementation Plan (What is Actually in v1)

### Step 1: DB Migration (Already Applied) ✅

```sql
-- Migration: 150_customer_hierarchy.sql
ALTER TABLE customers 
ADD COLUMN parent_customer_id UUID REFERENCES customers(id);

CREATE INDEX IF NOT EXISTS idx_customers_parent 
ON customers(parent_customer_id);

COMMENT ON COLUMN customers.parent_customer_id IS 
  'Parent customer ID for hierarchical organizations. NULL = top-level customer.';
```

**NOTE:** This migration is backward-compatible. Existing customers have `parent_customer_id = NULL`.

### Step 2: Usage in NSReady v1

- **Tenant isolation:**
  - `tenant_id = customer_id` (per individual company)

- **Group-level reporting** (e.g., Allidhra Group):
  - Queries use:
    ```sql
    -- Group report for Allidhra Group
    SELECT ...
    FROM ingest_events e
    JOIN devices d ON e.device_id = d.id
    JOIN sites s ON d.site_id = s.id
    JOIN projects p ON s.project_id = p.id
    JOIN customers c ON p.customer_id = c.id
    WHERE c.id = 'uuid-allidhra-group'
       OR c.parent_customer_id = 'uuid-allidhra-group';
    ```

In other words: **`parent_customer_id` is used for rollup/group views only in v1.**

---

## Your Model: Still Correct, With a Clarification ✅

### Your Understanding:
- **Tenant conceptually** = Allidhra Group (parent)
- **Customers** = Individual internal companies

This is a **valid conceptual view**.

### In NSReady v1 (Implementation Reality):

- We treat **each internal company as a tenant** (`tenant_id = customer_id`)  
  for isolation, security, SCADA segmentation, and AI routing.

- We use `parent_customer_id` to model **Allidhra Group as a reporting/ownership parent**,  
  so that we can produce:
  - Group-level dashboards (Allidhra Group)
  - Company-level dashboards (Textool, Texpin, etc.)

**Summary:**
- ✅ Your conceptual understanding is correct
- ✅ The schema supports it (`parent_customer_id` added)
- ✅ In v1, tenant isolation = company-level, group = reporting feature

---

## Summary

| Question | Answer |
|----------|--------|
| **Is your understanding correct?** | ✅ **YES** (conceptually) |
| **Tenant = Allidhra Group?** | ⚠️ **Conceptually YES, but in v1: tenant = each company** |
| **Customer = Individual companies?** | ✅ **YES** |
| **Do we need schema change?** | ✅ **YES** - Add `parent_customer_id` (✅ **DONE**) |
| **Is this a breaking change?** | ❌ **NO** - Backward compatible |
| **Can we scale with this?** | ✅ **YES** - Supports unlimited hierarchy |

### NSReady v1 Decision:

- **Tenant isolation:** `tenant_id = customer_id` (company-level)
- **Group reporting:** `parent_customer_id` used for OEM/group aggregation
- **Future flexibility:** Can promote parent to tenant if needed, without schema changes

**Action:**
1. ✅ Add `parent_customer_id` column (Option 1) - **COMPLETE**
2. ✅ Update documentation with tenant concept - **COMPLETE**
3. ✅ Add examples for Allidhra Group scenario - **COMPLETE**

---

## TL;DR

- ✅ You did not do anything wrong.
- ✅ Adding `parent_customer_id` is safe and useful.
- ✅ For now:
  - **Tenant isolation stays at company-level** (`tenant_id = customer_id`).
  - **`parent_customer_id` is used for OEM/group reporting**, not as the tenant key.
- ✅ The schema supports future evolution to group-level tenants if needed.


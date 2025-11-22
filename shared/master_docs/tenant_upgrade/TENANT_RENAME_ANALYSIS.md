# Should We Rename "Customer" to "Tenant" in Code?

**Answer: ❌ NO - Do NOT rename in code**

---

## Why NOT to Rename

### 1. The Proposal Says `tenant_id = customer_id` (Conceptual Mapping)

The proposal explicitly states:
- `tenant_id = customer_id` (they're the same thing)
- This is a **conceptual mapping**, not a code change
- Documentation only - to clarify that "customer" acts as a "tenant"

### 2. Renaming Would Be a MAJOR Breaking Change

**What Would Need to Change:**

#### Database Schema:
```sql
-- Current:
CREATE TABLE customers (...)
CREATE TABLE projects (customer_id UUID ...)

-- Would need to become:
CREATE TABLE tenants (...)
CREATE TABLE projects (tenant_id UUID ...)
```

**Impact:**
- ❌ Database migration required (rename table + column)
- ❌ All foreign keys need updating
- ❌ All indexes need updating
- ❌ All views need updating
- ❌ Breaking change for all existing data

#### API Endpoints:
```python
# Current:
router = APIRouter(prefix="/customers", ...)
@router.get("/{customer_id}", ...)

# Would need to become:
router = APIRouter(prefix="/tenants", ...)
@router.get("/{tenant_id}", ...)
```

**Impact:**
- ❌ All API endpoints break
- ❌ All integrations break
- ❌ All scripts break
- ❌ SCADA integrations break

#### Code References:
- ❌ `admin_tool/api/customers.py` → rename to `tenants.py`
- ❌ All SQL queries: `SELECT * FROM customers` → `SELECT * FROM tenants`
- ❌ All variable names: `customer_id` → `tenant_id`
- ❌ All model names: `CustomerIn`, `CustomerOut` → `TenantIn`, `TenantOut`
- ❌ All scripts: `import_registry.sh`, CSV templates, etc.

#### Documentation:
- ❌ All 13 modules need updates
- ❌ All scripts documentation
- ❌ All API documentation
- ❌ All SCADA documentation

### 3. Effort vs Benefit

| Aspect | Rename in Code | Documentation Only |
|--------|----------------|-------------------|
| **Effort** | 🔴 **WEEKS** (migration, code, tests, docs) | 🟢 **30-45 minutes** |
| **Risk** | 🔴 **HIGH** (breaking changes, data migration) | 🟢 **ZERO** |
| **Benefit** | 🟡 **Same** (just different terminology) | 🟢 **Same** (conceptual clarity) |
| **Breaking Changes** | 🔴 **YES** (all integrations) | 🟢 **NO** |
| **Data Migration** | 🔴 **REQUIRED** | 🟢 **NOT NEEDED** |

### 4. The Proposal Is Clear: Documentation Only

The proposal explicitly states:
- "minimal additions"
- "documentation only"
- "conceptual mapping"
- No code changes mentioned

---

## What We Should Do Instead

### Keep Code As-Is:
- ✅ Keep `customers` table name
- ✅ Keep `customer_id` column name
- ✅ Keep `/customers` API endpoints
- ✅ Keep all existing code

### Add Documentation:
- ✅ Document that `tenant_id = customer_id` (conceptual)
- ✅ Use "tenant" terminology in documentation for clarity
- ✅ Explain that "customer" acts as "tenant boundary"
- ✅ No code changes needed

### Example Documentation:
```markdown
### Tenant Model (NS-TENANT-01)

NSReady/NSWare defines each `customer` as a **tenant**.

- `tenant_id = customer_id` (conceptual mapping)

All routing, SCADA exports, dashboards, access control, and future AI models
are expected to operate within a single tenant boundary defined by `customer_id`.
```

**Note:** The code still uses `customer_id`, but we document that it acts as `tenant_id`.

---

## Real-World Analogy

Think of it like this:
- **Code/Database:** Uses "customer" (the business term)
- **Documentation/Design:** Uses "tenant" (the technical/architectural term)
- **They're the same thing** - just different terminology for different contexts

Like:
- Database: `user_id`
- Documentation: "user acts as account owner"
- Same thing, different terminology

---

## Recommendation

### ✅ **DO NOT RENAME IN CODE**

**Reasons:**
1. ✅ Proposal says documentation only
2. ✅ Renaming = major breaking change
3. ✅ No benefit to renaming (same functionality)
4. ✅ High risk, high effort, low value
5. ✅ Documentation achieves the same goal

**Action:**
- ✅ Add documentation explaining `tenant_id = customer_id`
- ✅ Use "tenant" terminology in docs for clarity
- ✅ Keep all code using "customer" terminology
- ✅ No code changes needed

---

## Summary

| Question | Answer |
|----------|--------|
| **Rename in code?** | ❌ **NO** |
| **Why not?** | Major breaking change, not needed |
| **What to do?** | Document `tenant_id = customer_id` conceptually |
| **Code changes?** | ❌ **ZERO** |
| **Documentation changes?** | ✅ **YES** (add tenant concept) |

**Conclusion:** Keep code as-is, add documentation only.


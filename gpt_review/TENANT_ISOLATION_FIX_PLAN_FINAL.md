# Tenant Isolation Fix Plan – Final Version

**Date**: 2025-01-23  
**Status**: Ready for Implementation  
**Context**: Incremental fix plan mapped to existing test suite

---

## Executive Summary

This plan provides a **phased, test-driven approach** to implementing tenant isolation across the NSReady backend API. Each phase is:
- **Small and manageable** (1-3 days per phase)
- **Test-driven** (validated against existing `test_tenant_isolation.sh`)
- **Low risk** (can stop after any phase if priorities change)
- **Incremental** (builds on previous phases)

**Total Estimated Time:** 2-4 weeks (depending on pace)

---

## 0. Goals & Constraints

### Goals

* Enforce tenant isolation according to your model:
  * `customer_id` is the tenant boundary
  * `X-Customer-ID` header identifies the tenant
* Align behaviour with expectations in the tests:
  * Tests 1–5 & 10 in `test_tenant_isolation.sh`
* Keep **Engineer/Admin mode** behaviour intact (no header = global view)

### Constraints

* Must not break engineer workflows
* Must be test-driven (prove each phase via existing scripts)
* Should preserve performance (indexes / query tuning as needed)
* Should allow rollback per endpoint (small commits, feature flags if needed)

### Error Code Policy

For consistency across all endpoints, we use the following policy:

* **Invalid UUID format** → `400 Bad Request`
* **Resource doesn't exist at all** → `404 Not Found`
* **Resource exists but not in this tenant** → `404 Not Found` (to avoid user enumeration and hide tenant boundaries in error messages)

This means `verify_tenant_access()` will consistently raise `404` when a resource belongs to another tenant, not `403`. Tests should be updated to expect `404` for cross-tenant access attempts.

---

## 1. Test Mapping (What We're Fixing)

From `test_tenant_isolation.sh`:

| Test # | Behaviour Gap | Endpoint(s) | Target Phase |
|--------|---------------|-------------|--------------|
| 1 | Customer A sees all customers, not just self | `GET /admin/customers` | Phase 1 |
| 2 | Customer A can read Customer B's record (200) | `GET /admin/customers/{id}` | Phase 1 |
| 3 | Engineer sees all customers (correct) | `GET /admin/customers` | Phase 1 (regression check) |
| 4 | Invalid UUID not rejected (200) | `GET /admin/customers` (and similar) | Phase 2 |
| 5 | Non-existent customer not rejected (200) | `GET /admin/customers` | Phase 2 |
| 10 | Projects not filtered by tenant | `GET /admin/projects` | Phase 1 |

**Note:** Exports (Tests 6–9) are **not** the first priority and can be addressed later under Phase 3/exports.

---

## 2. Phase 1 – Read-only Tenant Filters (GET endpoints)

**Duration:** ~1 week  
**Goal:** Apply **read filters** for Customer role on main listing endpoints, while preserving Engineer/Admin behaviour.

### Scope

* `GET /admin/customers`
* `GET /admin/customers/{id}`
* `GET /admin/projects`
* `GET /admin/sites`
* `GET /admin/devices`

### Design

#### 2.1 Tenant Header Handling (Shared Dependency)

**File:** `nsready_backend/admin_tool/api/deps.py`

**Note:** Adjust import paths (`from api.deps` vs `from .deps`) to match the actual package layout in your project. The examples below use relative imports (`from .deps`), but you may need absolute imports depending on your structure.

**Important:** All DB helpers (`verify_customer_exists`, `verify_tenant_access`) are `async` and use `AsyncSession`, matching existing patterns in admin_tool. These are not simple sync helpers.

Create/refine dependency functions:

**1. `get_tenant_customer_id()` - Extract and validate header**

```python
from fastapi import Header, HTTPException, status
from typing import Optional
import uuid


async def get_tenant_customer_id(
    x_customer_id: Optional[str] = Header(None, alias="X-Customer-ID")
) -> Optional[uuid.UUID]:
    """
    Extract and validate X-Customer-ID header.
    
    Returns:
        - uuid.UUID if header is provided and valid
        - None if header is not provided (engineer/admin mode)
    
    Raises:
        - HTTPException 400 if header is invalid UUID format
    """
    if x_customer_id is None:
        # No header = engineer/admin mode (can see all tenants)
        return None
    
    # Validate UUID format
    try:
        customer_id = uuid.UUID(x_customer_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID format for X-Customer-ID: {x_customer_id}"
        )
    
    return customer_id
```

**2. `verify_customer_exists()` - Check customer exists**

```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


async def verify_customer_exists(
    customer_id: uuid.UUID,
    session: AsyncSession
) -> bool:
    """Check if customer exists in database."""
    result = await session.execute(
        text("SELECT 1 FROM customers WHERE id = :id"),
        {"id": str(customer_id)}
    )
    return result.scalar() is not None
```

**3. `verify_tenant_access()` - Verify tenant access to resource**

```python
async def verify_tenant_access(
    tenant_id: uuid.UUID,
    resource_customer_id: str,
    session: AsyncSession
) -> None:
    """
    Verify that the tenant customer_id matches the resource's customer_id.
    
    Raises:
        - HTTPException 404 if customer doesn't exist (for security)
        - HTTPException 403 if tenant doesn't have access to resource
    """
    # First check if customer exists
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found"
        )
    
    # Verify tenant access
    # Policy: Return 404 (not 403) to avoid user enumeration and hide tenant boundaries
    if str(tenant_id) != resource_customer_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resource not found"
        )
```

These helpers centralize tenant behaviour and can be reused by all endpoints.

---

#### 2.2 `GET /admin/customers`

**File:** `nsready_backend/admin_tool/api/customers.py`

**Expected behaviour:**
* **Engineer (no header):** list all customers (current behaviour)
* **Customer (with `X-Customer-ID`):** list only their own customer record

**Implementation:**

```python
from api.deps import get_tenant_customer_id, verify_customer_exists
from typing import Optional
import uuid

@router.get("", response_model=list[CustomerOut])
async def list_customers(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    """
    List customers.
    
    - If X-Customer-ID header is provided: Return only that customer (test 1)
    - If X-Customer-ID header is missing: Return all customers (engineer mode, test 3)
    - If X-Customer-ID is invalid UUID: Return 400 (test 4 - handled in deps)
    - If X-Customer-ID doesn't exist: Return 404 (test 5)
    """
    # If no tenant_id, engineer mode - return all customers
    if tenant_id is None:
        result = await session.execute(
            text("SELECT id::text, name, metadata, created_at FROM customers ORDER BY created_at DESC")
        )
        rows = result.mappings().all()
        return [CustomerOut(**row) for row in rows]
    
    # Verify customer exists (test 5)
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found"
        )
    
    # Filter by tenant_id (test 1)
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id ORDER BY created_at DESC"),
        {"id": str(tenant_id)}
    )
    rows = result.mappings().all()
    return [CustomerOut(**row) for row in rows]
```

**Tests:**
* Test 1 – Customer sees only own customer
* Test 3 – Engineer sees all customers (regression check)
* Tests 4 & 5 partly addressed if headers are present

---

#### 2.3 `GET /admin/customers/{id}`

**File:** `nsready_backend/admin_tool/api/customers.py`

**Expected behaviour:**
* If Engineer (no header) → can read any existing customer
* If Customer:
  * If `{id}` is their own → 200
  * If `{id}` is another tenant's → 404 (per error code policy)
* If `{id}` invalid UUID → 400 (Phase 2 finalizes this)

**Implementation:**

```python
from api.deps import get_tenant_customer_id, verify_tenant_access

@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(
    customer_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    """
    Get customer by ID.
    
    - If X-Customer-ID header is provided: Verify customer_id matches tenant (test 2)
    - If X-Customer-ID header is missing: Allow access (engineer mode)
    - If customer_id doesn't exist: Return 404
    - If tenant doesn't have access: Return 404 (per error code policy, test 2)
    """
    # Get customer from DB
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id"),
        {"id": customer_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Customer not found")
    
    # If tenant_id provided, verify access (test 2)
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, customer_id, session)
    
    return CustomerOut(**row)
```

**Tests:**
* Test 2 – Customer A blocked from accessing Customer B

---

#### 2.4 `GET /admin/projects`

**File:** `nsready_backend/admin_tool/api/projects.py`

**Expected behaviour:**
* Engineer (no header) → all projects
* Customer (with header) → only projects where `projects.customer_id = X-Customer-ID`

**Implementation:**

```python
from api.deps import get_tenant_customer_id, verify_customer_exists

@router.get("", response_model=list[ProjectOut])
async def list_projects(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    """
    List projects.
    
    - If X-Customer-ID header is provided: Return only that customer's projects (test 10)
    - If X-Customer-ID header is missing: Return all projects (engineer mode)
    - If X-Customer-ID is invalid UUID: Return 400 (handled in deps)
    - If X-Customer-ID doesn't exist: Return 404
    """
    # If no tenant_id, engineer mode - return all projects
    if tenant_id is None:
        result = await session.execute(
            text(
                "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
                "FROM projects ORDER BY created_at DESC"
            )
        )
        return [ProjectOut(**row) for row in result.mappings().all()]
    
    # Verify customer exists
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found"
        )
    
    # Filter by tenant_id (test 10)
    result = await session.execute(
        text(
            "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
            "FROM projects WHERE customer_id = :customer_id ORDER BY created_at DESC"
        ),
        {"customer_id": str(tenant_id)}
    )
    return [ProjectOut(**row) for row in result.mappings().all()]
```

**Tests:**
* Test 10 – Projects endpoint filters by tenant

---

#### 2.5 `GET /admin/sites` and `/admin/devices`

**File:** `nsready_backend/admin_tool/api/sites.py` and `devices.py`

Same pattern as projects, but with joins:

**Sites:**
```python
from api.deps import get_tenant_customer_id, verify_customer_exists

@router.get("", response_model=list[SiteOut])
async def list_sites(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    """List sites, filtered by tenant if X-Customer-ID provided."""
    if tenant_id is None:
        # Engineer mode - return all sites
        result = await session.execute(
            text(
                "SELECT id::text, project_id::text AS project_id, name, location, created_at "
                "FROM sites ORDER BY created_at DESC"
            )
        )
        return [SiteOut(**row) for row in result.mappings().all()]
    
    # Verify customer exists
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found"
        )
    
    # Filter by tenant (sites → projects → customers)
    result = await session.execute(
        text("""
            SELECT s.id::text, s.project_id::text AS project_id, s.name, s.location, s.created_at
            FROM sites s
            JOIN projects p ON p.id = s.project_id
            WHERE p.customer_id = :customer_id
            ORDER BY s.created_at DESC
        """),
        {"customer_id": str(tenant_id)}
    )
    return [SiteOut(**row) for row in result.mappings().all()]
```

**Devices:**
```python
from api.deps import get_tenant_customer_id, verify_customer_exists

@router.get("", response_model=list[DeviceOut])
async def list_devices(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    """List devices, filtered by tenant if X-Customer-ID provided."""
    if tenant_id is None:
        # Engineer mode - return all devices
        result = await session.execute(
            text(
                "SELECT id::text, site_id::text AS site_id, name, device_type, external_id, status, created_at "
                "FROM devices ORDER BY created_at DESC"
            )
        )
        return [DeviceOut(**row) for row in result.mappings().all()]
    
    # Verify customer exists
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found"
        )
    
    # Filter by tenant (devices → sites → projects → customers)
    result = await session.execute(
        text("""
            SELECT d.id::text, d.site_id::text AS site_id, d.name, d.device_type, d.external_id, d.status, d.created_at
            FROM devices d
            JOIN sites s ON s.id = d.site_id
            JOIN projects p ON p.id = s.project_id
            WHERE p.customer_id = :customer_id
            ORDER BY d.created_at DESC
        """),
        {"customer_id": str(tenant_id)}
    )
    return [DeviceOut(**row) for row in result.mappings().all()]
```

**Tests:**
* Indirectly validates via multi-customer tests and downstream queries

---

### Phase 1 Validation Checklist

Before moving to Phase 2:

- [ ] Test 1 passes: Customer sees only own customer
- [ ] Test 2 passes: Customer blocked from Customer B
- [ ] Test 3 passes: Engineer sees all customers
- [ ] Test 10 passes: Projects filtered by tenant
- [ ] Baseline tests still green (`backend_tests.yml`)
- [ ] No obvious performance regression (check basic query plans)

---

## 3. Phase 2 – ID Validation & Error Codes

**Duration:** ~3–5 days  
**Goal:** Ensure invalid/non-existent IDs return correct HTTP codes.

### Scope

* `GET /admin/customers/{id}`
* And similar "by id" endpoints:
  * `/admin/projects/{id}`
  * `/admin/sites/{id}`
  * `/admin/devices/{id}`

### Design

#### 3.1 Shared UUID Validator

**File:** `nsready_backend/admin_tool/api/deps.py`

Add:

```python
def validate_uuid(uuid_str: str, field_name: str = "ID") -> uuid.UUID:
    """Validate UUID format and return UUID object."""
    try:
        return uuid.UUID(uuid_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID format for {field_name}: {uuid_str}"
        )
```

#### 3.2 Consistent Handling

For each `GET /resource/{id}`:

* Validate UUID with `validate_uuid()`
* If resource doesn't exist → 404
* If tenant header present and resource belongs to a different customer → 404 (per error code policy)

**Pattern:**
```python
@router.get("/{resource_id}", response_model=ResourceOut)
async def get_resource(
    resource_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    # Validate UUID format
    validate_uuid(resource_id, field_name="resource_id")
    
    # Get resource from DB
    result = await session.execute(...)
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Resource not found")
    
    # Verify tenant access if tenant_id provided
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, row.customer_id, session)
    
    return ResourceOut(**row)
```

### Tests

* `test_tenant_isolation.sh`:
  * Test 4 – Invalid UUID rejected (400)
  * Test 5 – Non-existent customer rejected (404)

---

## 4. Phase 3 – Cross-Tenant Protection for Write & Export

**Duration:** ~1 week  
**Goal:** Prevent cross-tenant writes / modifications.

### Scope

* `POST /admin/projects`, `/admin/sites`, `/admin/devices`
* `PUT` / `PATCH` / `DELETE` equivalents (where applicable)
* Export scripts and related APIs:
  * e.g. registry/SCADA export with `--customer-id`

### Design

#### 4.1 Create/Update Endpoints

**Pattern:**

* Customer role (with `X-Customer-ID`):
  * Ensure the resource's `customer_id` (or project/site chain) matches tenant
  * If not → 403/404

**Example:**

* `POST /admin/projects`:
  * Payload contains `customer_id`
  * If `tenant_id` present and `payload.customer_id != tenant_id` → 403/404

* `POST /admin/sites`:
  * Payload has `project_id`
  * Join project → check its `customer_id` vs `tenant_id`

#### 4.2 Delete Endpoints

Before delete:
* Lookup resource
* Verify resource's customer → equal to `tenant_id` if present
* Reject otherwise

#### 4.3 Exports

* Require `--customer-id` for customer role (already partly enforced)
* Validate:
  * UUID format (400 on CLI or 1 with clear message)
  * Customer exists and belongs to tenant
* Filter exported rows by tenant, similar to read paths

### Tests

You'll need simple write-oriented tests; but even if you don't write full scripts immediately, this phase is conceptually separate and can be plugged later.

---

## 5. Phase 4 – CI Policy Tightening

**Duration:** ~3–5 days  
**Goal:** Once behaviour is correct and stable, use tenant tests as **real gates**.

### Steps

1. Run `test_tenant_isolation.sh` locally until all tests pass
2. In `backend_extended_tests.yml`:
   * Remove `set +e` wrapper around `test_tenant_isolation.sh`
   * Optionally do the same for `final_test_drive.sh` once K8s is wired
3. Decide CI policy:
   * Keep Extended workflow manual but strict (red when tenant breaks)
   * Or create a separate `backend_tenant_tests.yml` that runs on key branches

**File:** `.github/workflows/backend_extended_tests.yml`

**Before:**
```yaml
# Tenant isolation test – known gap, do not fail workflow
set +e
./shared/scripts/test_tenant_isolation.sh
TENANT_RC=$?
set -e
if [ "$TENANT_RC" -ne 0 ]; then
  echo "⚠️ Tenant isolation test failed..."
fi
```

**After:**
```yaml
# Tenant isolation test – now a strict gate
./shared/scripts/test_tenant_isolation.sh
```

---

## 6. Risk & Mitigation

### Breaking Changes

**Risk:** Customer-facing APIs for `/admin/...` may start returning fewer rows or stricter errors.

**Mitigation:**
* Preserve Engineer/Admin global visibility
* **Feature Flag Implementation:** Implement `ENABLE_TENANT_FILTERING` in a central settings module (e.g., environment variable or config), and check it in `get_tenant_customer_id()` and/or in the list endpoints. That way we can turn filtering on/off per environment without patching each route.
* Roll out per endpoint (customers → projects → sites → devices)

### Performance

**Risk:** Extra joins and filters could slow queries under load.

**Mitigation:**
* Ensure `customer_id` is indexed on all relevant tables (`projects`, maybe `customers` already)
* Use your existing `test_stress_load.sh` to compare before/after
* Use `EXPLAIN ANALYZE` during dev if needed

---

## 7. How to Execute Practically

### 7.1 Recommended Cadence

* **Week 1:**
  * Phase 1.1–1.5 (customers, projects, sites, devices)
  * Run `test_tenant_isolation.sh` after each small change and log progress

* **Week 2:**
  * Phase 2 (UUID/error handling)
  * Confirm Tests 4 & 5 are green

* **Week 3–4:**
  * Phase 3 (writes & exports) if needed for your tenant model
  * Phase 4 (CI policy) once behaviour is stable

### 7.2 Low-Risk Starting Approach

**Start very small to minimize risk:**

1. **Implement Phase 1.1 + `/admin/customers` only:**
   * Add `get_tenant_customer_id`, `verify_customer_exists`, `verify_tenant_access` to `deps.py`
   * Wire into `GET /admin/customers` and `GET /admin/customers/{id}` only
   * Run `./shared/scripts/test_tenant_isolation.sh` and `test_roles_access.sh`
   * Commit: `fix: add tenant filters to customers endpoints`

2. **Pause and review:**
   * Confirm behaviour is correct for:
     * Engineer (no header) → sees all customers
     * Customer with header → sees only own customer
   * Check that nothing weird shows up in CI or local flows
   * Verify no breaking changes for existing consumers

3. **Then continue incrementally:**
   * Projects → Sites → Devices (one at a time)

This keeps the risk **very low** and gives you time to see if any existing consumers are depending on "global" behaviour on the customer endpoints.

### 7.3 Each Endpoint Change Process

**For each endpoint change:**

1. Implement filter/validation
2. Run `test_tenant_isolation.sh` and `test_roles_access.sh`
3. Test manually:
   * Engineer mode (no header)
   * Customer mode (with `X-Customer-ID`)
   * Invalid UUID (should return 400)
   * Non-existent resource (should return 404)
   * Cross-tenant access (should return 404)
4. Commit with a small message:
   * `"fix: add tenant filter to GET /admin/customers"`
   * `"fix: enforce UUID validation on GET /admin/customers/{id}"`

This makes rollback trivial if anything misbehaves.

---

## 8. Success Criteria (All Phases)

**Must Pass:**
- [ ] All 10 tests in `test_tenant_isolation.sh` pass
- [ ] All baseline tests still pass
- [ ] No performance regression
- [ ] Documentation updated
- [ ] CI treats tenant isolation as strict gate

**Nice to Have:**
- [ ] Performance tests show acceptable query overhead
- [ ] Code review complete
- [ ] API docs updated (OpenAPI spec)

---

## 9. Next Steps

### 9.1 Immediate Next Step

**Recommended:** Start with **just** `GET /admin/customers` endpoint:

1. Implement Phase 1.1 (Infrastructure Setup)
2. Wire tenant filtering into `GET /admin/customers` and `GET /admin/customers/{id}` only
3. Validate with test suite
4. Review and confirm behaviour
5. Then proceed to other endpoints incrementally

This gives you a working example and validates the approach before expanding to other endpoints.

### 9.2 General Execution Steps

1. **Review this plan** and adjust as needed
2. **Start Phase 1.1** (Infrastructure Setup - Day 1)
3. **Start with customers endpoint only** (low-risk first move)
4. **Commit after each endpoint fix** for easy rollback
5. **Validate with test suite** after each change
6. **Stop after any phase** if priorities change

### 9.3 Getting Exact Code

If you want help turning the plan snippets into **exact code** that fits your current file layout (imports, models, types), we can:
- Review your actual `customers.py` structure
- Generate exact code ready to paste
- Ensure imports match your package layout

---

**Last Updated:** 2025-01-23  
**Status:** Ready for Implementation


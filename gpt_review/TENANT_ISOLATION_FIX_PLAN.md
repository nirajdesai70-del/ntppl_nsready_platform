# Tenant Isolation Fix Plan – Phased Implementation

**Date**: 2025-01-23  
**Status**: Ready for Implementation  
**Context**: Incremental fix plan mapped to existing test suite

---

## Executive Summary

This plan provides a **phased approach** to implementing tenant isolation across the NSReady backend API. Each phase is:
- **Small and manageable** (1-3 days per phase)
- **Test-driven** (validated against existing `test_tenant_isolation.sh`)
- **Low risk** (can stop after any phase if priorities change)
- **Incremental** (builds on previous phases)

**Total Estimated Time:** 2-4 weeks (depending on pace)

---

## Test Suite Mapping

### Tests 1-5: API Endpoints (In Scope for This Plan)

| Test # | Test Name | Endpoint | Current Behavior | Expected Behavior | Phase |
|--------|-----------|----------|-----------------|-------------------|-------|
| 1 | Customer A sees only own customer | `GET /admin/customers` | Returns all customers | Returns 1 customer (filtered by `X-Customer-ID`) | Phase 1 |
| 2 | Customer A blocked from Customer B | `GET /admin/customers/{id}` | Returns Customer B's data | Returns 403 or 404 | Phase 1 |
| 3 | Engineer sees all customers | `GET /admin/customers` | Returns all customers | Returns all customers (no header) | Phase 1 |
| 4 | Invalid UUID rejected | `GET /admin/customers` | Returns 200 | Returns 400 | Phase 2 |
| 5 | Non-existent customer ID rejected | `GET /admin/customers` | Returns 200 | Returns 404 | Phase 2 |
| 10 | Projects endpoint filters by tenant | `GET /admin/projects` | Returns all projects | Returns only tenant's projects | Phase 1 |

### Tests 6-9: Export Scripts (Out of Scope for This Plan)

These tests cover shell scripts (`export_registry_data.sh`) and can be handled separately if needed.

---

## Phase 1: Read-Only Filters (GET Endpoints)

**Duration:** 1 week  
**Goal:** Fix tenant filtering for read-only GET endpoints  
**Test Coverage:** Tests 1, 2, 3, 10

### 1.1 Infrastructure Setup (Day 1)

#### Step 1: Create Tenant Dependency Function

**File:** `nsready_backend/admin_tool/api/deps.py`

**Add:**
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
        - HTTPException 404 if header is valid UUID but customer doesn't exist
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
    
    # Validate customer exists (will be checked in route handler with DB)
    # We just return the UUID here for use in queries
    return customer_id
```

#### Step 2: Add Helper Function for Customer Existence Check

**File:** `nsready_backend/admin_tool/api/deps.py`

**Add:**
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

#### Step 3: Create Tenant Verification Function

**File:** `nsready_backend/admin_tool/api/deps.py`

**Add:**
```python
async def verify_tenant_access(
    customer_id: uuid.UUID,
    resource_customer_id: str,
    session: AsyncSession
) -> None:
    """
    Verify that the tenant customer_id matches the resource's customer_id.
    
    Raises:
        - HTTPException 403 if tenant doesn't have access to resource
        - HTTPException 404 if customer doesn't exist (for security)
    """
    # First check if customer exists
    if not await verify_customer_exists(customer_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {customer_id} not found"
        )
    
    # Verify tenant access
    if str(customer_id) != resource_customer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied - resource does not belong to your tenant"
        )
```

**Validation:**
- Run `python -m pytest` if you have unit tests
- Check syntax: `python -m py_compile nsready_backend/admin_tool/api/deps.py`

---

### 1.2 Fix `/admin/customers` GET (Days 2-3)

**File:** `nsready_backend/admin_tool/api/customers.py`

#### Current Implementation (Lines 12-16):
```python
@router.get("", response_model=list[CustomerOut])
async def list_customers(session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("SELECT id::text, name, metadata, created_at FROM customers ORDER BY created_at DESC"))
    rows = result.mappings().all()
    return [CustomerOut(**row) for row in rows]
```

#### Updated Implementation:
```python
from api.deps import get_tenant_customer_id, verify_customer_exists
from fastapi import Header

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

**Validation:**
1. Start services: `docker compose up -d`
2. Run test: `./shared/scripts/test_tenant_isolation.sh`
3. Verify Tests 1, 3, 4, 5 pass
4. Commit: `git commit -m "fix: Add tenant filtering to GET /admin/customers"`

---

### 1.3 Fix `/admin/customers/{customer_id}` GET (Day 3)

**File:** `nsready_backend/admin_tool/api/customers.py`

#### Current Implementation (Lines 31-40):
```python
@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(customer_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id"),
        {"id": customer_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Customer not found")
    return CustomerOut(**row)
```

#### Updated Implementation:
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
    - If tenant doesn't have access: Return 403 (test 2)
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

**Validation:**
1. Run test: `./shared/scripts/test_tenant_isolation.sh`
2. Verify Test 2 passes
3. Commit: `git commit -m "fix: Add tenant access check to GET /admin/customers/{id}"`

---

### 1.4 Fix `/admin/projects` GET (Days 4-5)

**File:** `nsready_backend/admin_tool/api/projects.py`

#### Current Implementation (Lines 12-20):
```python
@router.get("", response_model=list[ProjectOut])
async def list_projects(session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
            "FROM projects ORDER BY created_at DESC"
        )
    )
    return [ProjectOut(**row) for row in result.mappings().all()]
```

#### Updated Implementation:
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

**Validation:**
1. Run test: `./shared/scripts/test_tenant_isolation.sh`
2. Verify Test 10 passes
3. Commit: `git commit -m "fix: Add tenant filtering to GET /admin/projects"`

---

### 1.5 Fix `/admin/sites` and `/admin/devices` GET (Days 5-6)

**Approach:** Same pattern as projects, but need to join through customer hierarchy:

- Sites → Projects → Customers
- Devices → Sites → Projects → Customers

#### For `/admin/sites` GET:

**File:** `nsready_backend/admin_tool/api/sites.py`

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

#### For `/admin/devices` GET:

**File:** `nsready_backend/admin_tool/api/devices.py`

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

**Validation:**
1. Run test: `./shared/scripts/test_tenant_isolation.sh`
2. Verify all Phase 1 tests pass (Tests 1, 2, 3, 10)
3. Commit: `git commit -m "fix: Add tenant filtering to GET /admin/sites and /admin/devices"`

---

### 1.6 Phase 1 Validation Checklist

**Before moving to Phase 2, verify:**

- [ ] Test 1 passes: Customer A sees only own customer
- [ ] Test 2 passes: Customer A blocked from Customer B
- [ ] Test 3 passes: Engineer sees all customers
- [ ] Test 10 passes: Projects endpoint filters by tenant
- [ ] All existing tests still pass (baseline set)
- [ ] No performance regression (check query plans)
- [ ] Code reviewed and documented

**Success Criteria:**
- All Phase 1 tests pass
- No breaking changes for engineer/admin users
- Tenant filtering works correctly

---

## Phase 2: ID Validation & Error Codes

**Duration:** 3-5 days  
**Goal:** Proper error handling for invalid/non-existent IDs  
**Test Coverage:** Tests 4, 5 (partially in Phase 1, but need to ensure consistency)

### 2.1 Review Current Error Handling

**Check:** Ensure all endpoints handle invalid UUIDs consistently.

**Action Items:**
- Review all GET `/{id}` endpoints
- Ensure 400 for invalid UUIDs
- Ensure 404 for non-existent resources
- Ensure 403 for tenant violations

**Files to Review:**
- `nsready_backend/admin_tool/api/customers.py` (GET `/{id}`)
- `nsready_backend/admin_tool/api/projects.py` (GET `/{id}`)
- `nsready_backend/admin_tool/api/sites.py` (GET `/{id}`)
- `nsready_backend/admin_tool/api/devices.py` (GET `/{id}`)

### 2.2 Add UUID Validation Helper

**File:** `nsready_backend/admin_tool/api/deps.py`

```python
from fastapi import HTTPException, status
import uuid


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

### 2.3 Update All GET `/{id}` Endpoints

**Pattern for all endpoints:**
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

**Validation:**
1. Run test: `./shared/scripts/test_tenant_isolation.sh`
2. Verify Tests 4, 5 pass
3. Test with invalid UUIDs manually
4. Commit: `git commit -m "fix: Add consistent UUID validation and error handling"`

---

## Phase 3: Cross-Tenant Checks on Write Endpoints

**Duration:** 1 week  
**Goal:** Prevent cross-tenant writes (POST, PUT, DELETE)

### 3.1 POST Endpoints (Create)

**Endpoints to fix:**
- `POST /admin/customers` (engineer-only, skip)
- `POST /admin/projects` (verify customer_id matches tenant)
- `POST /admin/sites` (verify project belongs to tenant)
- `POST /admin/devices` (verify site belongs to tenant)

**Pattern:**
```python
@router.post("", response_model=ProjectOut)
async def create_project(
    payload: ProjectIn,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session)
):
    # If tenant_id provided, verify customer_id matches
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, payload.customer_id, session)
    
    # Continue with creation...
```

### 3.2 PUT Endpoints (Update)

**Pattern:** Verify resource belongs to tenant before allowing update.

### 3.3 DELETE Endpoints

**Pattern:** Verify resource belongs to tenant before allowing delete.

**Validation:**
1. Create tests for write operations with tenant violations
2. Verify 403 responses
3. Commit: `git commit -m "fix: Add tenant checks to write endpoints"`

---

## Phase 4: CI Integration

**Duration:** 3-5 days  
**Goal:** Make tenant isolation tests strict gates

### 4.1 Update Workflow

**File:** `.github/workflows/backend_extended_tests.yml`

**Change:** Remove non-blocking behavior for `test_tenant_isolation.sh`

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

### 4.2 Option: Create Separate Workflow

**Alternative:** Create `.github/workflows/backend_tenant_tests.yml` as a strict gate for tenant isolation.

### 4.3 Update Documentation

**Files to update:**
- `nsready_backend/tests/README_BACKEND_TESTS.md`
- `gpt_review/TEST_CI_DESIGN_SUMMARY.md`

**Validation:**
1. Run workflow manually
2. Verify tenant tests are strict gates
3. Update documentation
4. Commit: `git commit -m "ci: Make tenant isolation tests strict gates"`

---

## Success Criteria (All Phases)

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

## Risk Mitigation

### Breaking Changes

**Risk:** Existing integrations may break

**Mitigation:**
- Engineer/admin mode (no header) still works
- Feature flag: `ENABLE_TENANT_FILTERING=true/false`
- Gradual rollout per endpoint

### Performance

**Risk:** Query overhead from joins/filters

**Mitigation:**
- Ensure `customer_id` is indexed
- Use `EXPLAIN ANALYZE` on all queries
- Run `test_stress_load.sh` after changes

### Testing

**Risk:** Miss edge cases

**Mitigation:**
- Use existing test suite
- Add manual testing with different roles
- Monitor logs after deployment

---

## Next Steps

1. **Review this plan** and adjust as needed
2. **Start Phase 1.1** (Infrastructure Setup)
3. **Commit after each endpoint fix** for easy rollback
4. **Validate with test suite** after each change
5. **Stop after any phase** if priorities change

---

**Last Updated:** 2025-01-23  
**Status:** Ready for Implementation


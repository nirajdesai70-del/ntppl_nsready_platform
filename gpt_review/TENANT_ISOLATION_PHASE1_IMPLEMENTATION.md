# Tenant Isolation Phase 1.1 – Implementation Code

**Date**: 2025-01-23  
**Status**: Ready to Paste  
**Scope**: Phase 1.1 + `/admin/customers` endpoint only

---

## Overview

This document provides **exact, paste-ready code** for implementing tenant isolation on the `/admin/customers` endpoints. The code matches your current project structure with relative imports.

---

## Step 1: Update `deps.py` – Add Tenant Helpers

**File:** `nsready_backend/admin_tool/api/deps.py`

**Action:** Add these functions to your existing `deps.py` (don't replace the file, just add to it).

```python
# Add these imports at the top (if not already present)
from typing import Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

# Add these functions after your existing bearer_auth function

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

    try:
        customer_id = uuid.UUID(x_customer_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID format for X-Customer-ID: {x_customer_id}",
        )

    return customer_id


async def verify_customer_exists(customer_id: uuid.UUID, session: AsyncSession) -> bool:
    """
    Check if a customer exists in the database.
    """
    result = await session.execute(
        text("SELECT 1 FROM customers WHERE id = :id"),
        {"id": str(customer_id)},
    )
    return result.scalar() is not None


async def verify_tenant_access(
    tenant_id: uuid.UUID,
    resource_customer_id: str,
    session: AsyncSession,
) -> None:
    """
    Verify that the tenant (X-Customer-ID) has access to a resource.

    Policy:
      - If tenant customer does not exist -> 404
      - If resource belongs to a different customer -> 404
        (We deliberately use 404 to avoid tenant enumeration.)
    """
    # Customer must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
        )

    # Resource must belong to this tenant
    if str(tenant_id) != resource_customer_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resource not found",
        )
```

**Complete `deps.py` should look like:**

```python
import os
from fastapi import Header, HTTPException, status, Depends
from typing import Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


def get_bearer_token_from_env() -> str:
    return os.getenv("ADMIN_BEARER_TOKEN", "devtoken")


async def bearer_auth(authorization: str | None = Header(default=None)) -> None:
    expected = f"Bearer {get_bearer_token_from_env()}"
    if authorization != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")


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

    try:
        customer_id = uuid.UUID(x_customer_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID format for X-Customer-ID: {x_customer_id}",
        )

    return customer_id


async def verify_customer_exists(customer_id: uuid.UUID, session: AsyncSession) -> bool:
    """
    Check if a customer exists in the database.
    """
    result = await session.execute(
        text("SELECT 1 FROM customers WHERE id = :id"),
        {"id": str(customer_id)},
    )
    return result.scalar() is not None


async def verify_tenant_access(
    tenant_id: uuid.UUID,
    resource_customer_id: str,
    session: AsyncSession,
) -> None:
    """
    Verify that the tenant (X-Customer-ID) has access to a resource.

    Policy:
      - If tenant customer does not exist -> 404
      - If resource belongs to a different customer -> 404
        (We deliberately use 404 to avoid tenant enumeration.)
    """
    # Customer must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
        )

    # Resource must belong to this tenant
    if str(tenant_id) != resource_customer_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resource not found",
        )
```

---

## Step 2: Update `customers.py` – Add Tenant Filtering

**File:** `nsready_backend/admin_tool/api/customers.py`

**Action:** Replace the `list_customers` and `get_customer` functions with the versions below.

### 2.1 Update Imports

**Add to the top of the file (after existing imports):**

```python
from typing import Optional
import uuid
```

**Update the import from deps to include the new functions:**

```python
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists, verify_tenant_access
```

### 2.2 Replace `list_customers` Function

**Replace this:**
```python
@router.get("", response_model=list[CustomerOut])
async def list_customers(session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("SELECT id::text, name, metadata, created_at FROM customers ORDER BY created_at DESC"))
    rows = result.mappings().all()
    return [CustomerOut(**row) for row in rows]
```

**With this:**
```python
@router.get("", response_model=list[CustomerOut])
async def list_customers(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    List customers.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): return all customers (current behaviour).
    - Customer (with X-Customer-ID): return only that customer.

    Tests:
    - Test 1: Customer A sees only own customer.
    - Test 3: Engineer sees all customers.
    """
    # Engineer/Admin mode: no tenant filter
    if tenant_id is None:
        result = await session.execute(
            text("SELECT id::text, name, metadata, created_at FROM customers ORDER BY created_at DESC")
        )
        rows = result.mappings().all()
        return [CustomerOut(**row) for row in rows]

    # Customer mode: tenant_id must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
        )

    # Filter by tenant_id
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id ORDER BY created_at DESC"),
        {"id": str(tenant_id)},
    )
    rows = result.mappings().all()
    return [CustomerOut(**row) for row in rows]
```

### 2.3 Replace `get_customer` Function

**Replace this:**
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

**With this:**
```python
@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(
    customer_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Get customer by ID.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can access any existing customer.
    - Customer (with X-Customer-ID):
        - If this is their own ID: 200
        - If other tenant: 404
    - If customer_id does not exist: 404

    Tests:
    - Test 2: Customer A blocked from Customer B.
    """
    # Fetch the customer
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id"),
        {"id": customer_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Customer not found")

    # If tenant_id is present, verify this customer belongs to the tenant
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, customer_id, session)

    return CustomerOut(**row)
```

### 2.4 Complete Updated `customers.py`

**For reference, here's the complete file structure (showing only the changed parts):**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import Optional
import uuid

from core.db import get_session
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists, verify_tenant_access
from api.models import CustomerIn, CustomerOut

router = APIRouter(prefix="/customers", tags=["customers"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[CustomerOut])
async def list_customers(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    List customers.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): return all customers (current behaviour).
    - Customer (with X-Customer-ID): return only that customer.

    Tests:
    - Test 1: Customer A sees only own customer.
    - Test 3: Engineer sees all customers.
    """
    # Engineer/Admin mode: no tenant filter
    if tenant_id is None:
        result = await session.execute(
            text("SELECT id::text, name, metadata, created_at FROM customers ORDER BY created_at DESC")
        )
        rows = result.mappings().all()
        return [CustomerOut(**row) for row in rows]

    # Customer mode: tenant_id must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
        )

    # Filter by tenant_id
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id ORDER BY created_at DESC"),
        {"id": str(tenant_id)},
    )
    rows = result.mappings().all()
    return [CustomerOut(**row) for row in rows]


@router.post("", response_model=CustomerOut)
async def create_customer(payload: CustomerIn, session: AsyncSession = Depends(get_session)):
    # ... existing code unchanged ...


@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(
    customer_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Get customer by ID.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can access any existing customer.
    - Customer (with X-Customer-ID):
        - If this is their own ID: 200
        - If other tenant: 404
    - If customer_id does not exist: 404

    Tests:
    - Test 2: Customer A blocked from Customer B.
    """
    # Fetch the customer
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id"),
        {"id": customer_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Customer not found")

    # If tenant_id is present, verify this customer belongs to the tenant
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, customer_id, session)

    return CustomerOut(**row)


@router.put("/{customer_id}", response_model=CustomerOut)
async def update_customer(customer_id: str, payload: CustomerIn, session: AsyncSession = Depends(get_session)):
    # ... existing code unchanged ...


@router.delete("/{customer_id}")
async def delete_customer(customer_id: str, session: AsyncSession = Depends(get_session)):
    # ... existing code unchanged ...
```

**Note:** You need to add `status` import for the HTTPException in `list_customers`. Add this to imports:

```python
from fastapi import APIRouter, Depends, HTTPException, status
```

---

## Step 3: Testing

### 3.1 Start Services

```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform
docker compose up -d
```

### 3.2 Run Tests

```bash
# Run tenant isolation tests (they cover these behaviours)
./shared/scripts/test_tenant_isolation.sh

# Also good to run roles test:
./shared/scripts/test_roles_access.sh
```

### 3.3 Expected Results

After this Phase 1 change for `/admin/customers`:

* **Test 1:** Customer sees only own customer → Should **PASS** ✅
* **Test 2:** Customer blocked from Customer B → Should **PASS** ✅ (returns 404 instead of 200)
* **Test 3:** Engineer sees all customers → Should **PASS** ✅ (no regression)

### 3.4 Manual Testing

You can also test manually:

```bash
# Engineer mode (no header) - should see all customers
curl -H "Authorization: Bearer devtoken" http://localhost:8000/admin/customers

# Customer mode (with header) - should see only that customer
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: <customer-uuid>" \
     http://localhost:8000/admin/customers

# Customer trying to access another customer - should get 404
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: <customer-a-uuid>" \
     http://localhost:8000/admin/customers/<customer-b-uuid>
```

---

## Step 4: Commit

Once tests pass:

```bash
git add nsready_backend/admin_tool/api/deps.py nsready_backend/admin_tool/api/customers.py
git commit -m "fix: add tenant filters to customers endpoints (Phase 1.1)

- Add get_tenant_customer_id, verify_customer_exists, verify_tenant_access helpers
- Update GET /admin/customers to filter by X-Customer-ID header
- Update GET /admin/customers/{id} to verify tenant access
- Engineer/Admin mode (no header) still sees all customers
- Customer mode (with header) sees only own customer
- Cross-tenant access returns 404 (per error code policy)

Tests: 1, 2, 3 should now pass"
```

---

## Troubleshooting

### Import Errors

If you get import errors, check:
- `from api.deps import ...` matches your package structure
- `from core.db import get_session` matches your structure
- All imports are relative to `nsready_backend/admin_tool/api/`

### Test Failures

If tests fail:
1. Check that services are running: `docker compose ps`
2. Check logs: `docker compose logs admin_tool`
3. Verify database has test data (customers "Test Customer A" and "Test Customer B")
4. Check that `X-Customer-ID` header is being sent correctly

### Common Issues

**Issue:** "Customer not found" when customer exists
- **Fix:** Check UUID format in header (must be valid UUID)

**Issue:** Still seeing all customers with header
- **Fix:** Verify `tenant_id` is not None in the function
- **Fix:** Check that `get_tenant_customer_id` is being called correctly

**Issue:** 403 instead of 404 for cross-tenant access
- **Fix:** Verify `verify_tenant_access` raises 404, not 403

---

## Next Steps

Once this is working:

1. **Review and validate** the behaviour
2. **Proceed to Phase 1.4:** `/admin/projects` endpoint (same pattern)
3. **Then Phase 1.5:** `/admin/sites` and `/admin/devices` (with joins)

---

**Last Updated:** 2025-01-23  
**Status:** Ready to Implement


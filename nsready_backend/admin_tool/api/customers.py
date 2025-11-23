from fastapi import APIRouter, Depends, HTTPException, status
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
    import json
    result = await session.execute(
        text("INSERT INTO customers(name, metadata) VALUES (:name, CAST(:metadata AS jsonb)) RETURNING id::text, name, metadata, created_at"),
        {"name": payload.name, "metadata": json.dumps(payload.metadata or {})},
    )
    await session.commit()
    row = result.mappings().one()
    return CustomerOut(**row)


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
    import json
    result = await session.execute(
        text(
            "UPDATE customers SET name = :name, metadata = CAST(:metadata AS jsonb) WHERE id = :id "
            "RETURNING id::text, name, metadata, created_at"
        ),
        {"id": customer_id, "name": payload.name, "metadata": json.dumps(payload.metadata or {})},
    )
    await session.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Customer not found")
    return CustomerOut(**row)


@router.delete("/{customer_id}")
async def delete_customer(customer_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("DELETE FROM customers WHERE id = :id"), {"id": customer_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Customer not found")
    return {"status": "ok"}



from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from core.db import get_session
from api.deps import bearer_auth
from api.models import CustomerIn, CustomerOut

router = APIRouter(prefix="/customers", tags=["customers"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[CustomerOut])
async def list_customers(session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("SELECT id::text, name, metadata, created_at FROM customers ORDER BY created_at DESC"))
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
async def get_customer(customer_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text("SELECT id::text, name, metadata, created_at FROM customers WHERE id = :id"),
        {"id": customer_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Customer not found")
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



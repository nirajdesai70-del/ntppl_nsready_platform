from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import Optional
import uuid

from core.db import get_session
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists
from api.models import DeviceIn, DeviceOut

router = APIRouter(prefix="/devices", tags=["devices"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[DeviceOut])
async def list_devices(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    List devices.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): return all devices (current behaviour).
    - Customer (with X-Customer-ID): return only that customer's devices (via sites → projects).

    Filtering: devices → sites → projects → customers
    """
    # Engineer/Admin mode: no tenant filter
    if tenant_id is None:
        result = await session.execute(
            text(
                "SELECT id::text, site_id::text AS site_id, name, device_type, external_id, status, created_at "
                "FROM devices ORDER BY created_at DESC"
            )
        )
        return [DeviceOut(**row) for row in result.mappings().all()]

    # Customer mode: tenant_id must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
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
        {"customer_id": str(tenant_id)},
    )
    return [DeviceOut(**row) for row in result.mappings().all()]


@router.post("", response_model=DeviceOut)
async def create_device(payload: DeviceIn, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "INSERT INTO devices(site_id, name, device_type, external_id, status) "
            "VALUES (:site_id, :name, :device_type, :external_id, :status) "
            "RETURNING id::text, site_id::text AS site_id, name, device_type, external_id, status, created_at"
        ),
        {
            "site_id": payload.site_id,
            "name": payload.name,
            "device_type": payload.device_type,
            "external_id": payload.external_id,
            "status": payload.status or "active",
        },
    )
    await session.commit()
    return DeviceOut(**result.mappings().one())


@router.get("/{device_id}", response_model=DeviceOut)
async def get_device(device_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "SELECT id::text, site_id::text AS site_id, name, device_type, external_id, status, created_at "
            "FROM devices WHERE id = :id"
        ),
        {"id": device_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Device not found")
    return DeviceOut(**row)


@router.put("/{device_id}", response_model=DeviceOut)
async def update_device(device_id: str, payload: DeviceIn, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "UPDATE devices SET site_id = :site_id, name = :name, device_type = :device_type, "
            "external_id = :external_id, status = :status "
            "WHERE id = :id "
            "RETURNING id::text, site_id::text AS site_id, name, device_type, external_id, status, created_at"
        ),
        {
            "id": device_id,
            "site_id": payload.site_id,
            "name": payload.name,
            "device_type": payload.device_type,
            "external_id": payload.external_id,
            "status": payload.status or "active",
        },
    )
    await session.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Device not found")
    return DeviceOut(**row)


@router.delete("/{device_id}")
async def delete_device(device_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("DELETE FROM devices WHERE id = :id"), {"id": device_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Device not found")
    return {"status": "ok"}



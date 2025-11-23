from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import Optional
import uuid

from core.db import get_session
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists, verify_tenant_access, validate_uuid, verify_site_belongs_to_tenant, verify_device_belongs_to_tenant
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
async def create_device(
    payload: DeviceIn,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Create a new device.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can create devices under any site.
    - Customer (with X-Customer-ID): can only create devices under sites belonging to their tenant.

    Phase 3: Write protection
    """
    # Phase 3: If tenant_id is present, verify site belongs to tenant
    if tenant_id is not None:
        validate_uuid(payload.site_id, field_name="site_id")
        await verify_site_belongs_to_tenant(payload.site_id, tenant_id, session)
    
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
async def get_device(
    device_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Get device by ID.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can access any existing device.
    - Customer (with X-Customer-ID):
        - If this device belongs to their customer (via site → project): 200
        - If other tenant: 404
    - If device_id invalid UUID: 400 (Phase 2)
    - If device_id does not exist: 404
    """
    # Validate UUID format (Phase 2)
    validate_uuid(device_id, field_name="device_id")

    # Fetch the device with its project's customer_id (via site)
    result = await session.execute(
        text("""
            SELECT d.id::text, d.site_id::text AS site_id, d.name, d.device_type, d.external_id, d.status, d.created_at,
                   p.customer_id::text AS customer_id
            FROM devices d
            JOIN sites s ON s.id = d.site_id
            JOIN projects p ON p.id = s.project_id
            WHERE d.id = :id
        """),
        {"id": device_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Device not found")

    # If tenant_id is present, verify this device belongs to the tenant
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, row["customer_id"], session)

    # Return device data (without customer_id in response)
    return DeviceOut(
        id=row["id"],
        site_id=row["site_id"],
        name=row["name"],
        device_type=row["device_type"],
        external_id=row["external_id"],
        status=row["status"],
        created_at=row["created_at"],
    )


@router.put("/{device_id}", response_model=DeviceOut)
async def update_device(
    device_id: str,
    payload: DeviceIn,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Update a device.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can update any device.
    - Customer (with X-Customer-ID):
        - Existing device must belong to tenant
        - New site_id (if changed) must belong to tenant

    Phase 3: Write protection
    """
    # Validate UUID format (Phase 2)
    validate_uuid(device_id, field_name="device_id")
    validate_uuid(payload.site_id, field_name="site_id")
    
    # Phase 3: If tenant_id is present, verify access
    if tenant_id is not None:
        # First, verify the existing device belongs to tenant
        await verify_device_belongs_to_tenant(device_id, tenant_id, session)
        
        # Verify new site_id (if changed) also belongs to tenant
        result = await session.execute(
            text("SELECT site_id::text FROM devices WHERE id = :id"),
            {"id": device_id},
        )
        existing = result.mappings().first()
        if existing and existing["site_id"] != payload.site_id:
            await verify_site_belongs_to_tenant(payload.site_id, tenant_id, session)
    
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
async def delete_device(
    device_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Delete a device.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can delete any device.
    - Customer (with X-Customer-ID): can only delete devices belonging to their tenant.

    Phase 3: Write protection
    """
    # Validate UUID format (Phase 2)
    validate_uuid(device_id, field_name="device_id")
    
    # Phase 3: If tenant_id is present, verify device belongs to tenant
    if tenant_id is not None:
        await verify_device_belongs_to_tenant(device_id, tenant_id, session)
    
    result = await session.execute(text("DELETE FROM devices WHERE id = :id"), {"id": device_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Device not found")
    return {"status": "ok"}



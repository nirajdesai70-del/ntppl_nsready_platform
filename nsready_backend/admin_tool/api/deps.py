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


def validate_uuid(uuid_str: str, field_name: str = "ID") -> uuid.UUID:
    """
    Validate UUID format and return UUID object.

    Raises:
        - HTTPException 400 if UUID format is invalid
    """
    try:
        return uuid.UUID(uuid_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID format for {field_name}: {uuid_str}",
        )


async def verify_project_belongs_to_tenant(
    project_id: str,
    tenant_id: uuid.UUID,
    session: AsyncSession,
) -> str:
    """
    Verify that a project belongs to the tenant and return its customer_id.

    Raises:
        - HTTPException 404 if project does not exist or belongs to different tenant
    """
    result = await session.execute(
        text("SELECT customer_id::text FROM projects WHERE id = :id"),
        {"id": project_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    
    customer_id = row["customer_id"]
    await verify_tenant_access(tenant_id, customer_id, session)
    return customer_id


async def verify_site_belongs_to_tenant(
    site_id: str,
    tenant_id: uuid.UUID,
    session: AsyncSession,
) -> str:
    """
    Verify that a site belongs to the tenant (via project) and return its customer_id.

    Raises:
        - HTTPException 404 if site does not exist or belongs to different tenant
    """
    result = await session.execute(
        text("""
            SELECT p.customer_id::text AS customer_id
            FROM sites s
            JOIN projects p ON p.id = s.project_id
            WHERE s.id = :id
        """),
        {"id": site_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")
    
    customer_id = row["customer_id"]
    await verify_tenant_access(tenant_id, customer_id, session)
    return customer_id


async def verify_device_belongs_to_tenant(
    device_id: str,
    tenant_id: uuid.UUID,
    session: AsyncSession,
) -> str:
    """
    Verify that a device belongs to the tenant (via site → project) and return its customer_id.

    Raises:
        - HTTPException 404 if device does not exist or belongs to different tenant
    """
    result = await session.execute(
        text("""
            SELECT p.customer_id::text AS customer_id
            FROM devices d
            JOIN sites s ON s.id = d.site_id
            JOIN projects p ON p.id = s.project_id
            WHERE d.id = :id
        """),
        {"id": device_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")
    
    customer_id = row["customer_id"]
    await verify_tenant_access(tenant_id, customer_id, session)
    return customer_id



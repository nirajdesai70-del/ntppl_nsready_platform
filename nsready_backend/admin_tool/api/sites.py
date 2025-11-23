from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import Optional
import uuid

from core.db import get_session
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists, verify_tenant_access, validate_uuid, verify_project_belongs_to_tenant, verify_site_belongs_to_tenant
from api.models import SiteIn, SiteOut

router = APIRouter(prefix="/sites", tags=["sites"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[SiteOut])
async def list_sites(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    List sites.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): return all sites (current behaviour).
    - Customer (with X-Customer-ID): return only that customer's sites (via projects).

    Filtering: sites → projects → customers
    """
    # Engineer/Admin mode: no tenant filter
    if tenant_id is None:
        result = await session.execute(
            text(
                "SELECT id::text, project_id::text AS project_id, name, location, created_at "
                "FROM sites ORDER BY created_at DESC"
            )
        )
        return [SiteOut(**row) for row in result.mappings().all()]

    # Customer mode: tenant_id must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
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
        {"customer_id": str(tenant_id)},
    )
    return [SiteOut(**row) for row in result.mappings().all()]


@router.post("", response_model=SiteOut)
async def create_site(
    payload: SiteIn,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Create a new site.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can create sites under any project.
    - Customer (with X-Customer-ID): can only create sites under projects belonging to their tenant.

    Phase 3: Write protection
    """
    # Phase 3: If tenant_id is present, verify project belongs to tenant
    if tenant_id is not None:
        validate_uuid(payload.project_id, field_name="project_id")
        await verify_project_belongs_to_tenant(payload.project_id, tenant_id, session)
    
    import json
    result = await session.execute(
        text(
            "INSERT INTO sites(project_id, name, location) "
            "VALUES (:project_id, :name, CAST(:location AS jsonb)) "
            "RETURNING id::text, project_id::text AS project_id, name, location, created_at"
        ),
        {"project_id": payload.project_id, "name": payload.name, "location": json.dumps(payload.location or {})},
    )
    await session.commit()
    return SiteOut(**result.mappings().one())


@router.get("/{site_id}", response_model=SiteOut)
async def get_site(
    site_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Get site by ID.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can access any existing site.
    - Customer (with X-Customer-ID):
        - If this site belongs to their customer (via project): 200
        - If other tenant: 404
    - If site_id invalid UUID: 400 (Phase 2)
    - If site_id does not exist: 404
    """
    # Validate UUID format (Phase 2)
    validate_uuid(site_id, field_name="site_id")

    # Fetch the site with its project's customer_id
    result = await session.execute(
        text("""
            SELECT s.id::text, s.project_id::text AS project_id, s.name, s.location, s.created_at,
                   p.customer_id::text AS customer_id
            FROM sites s
            JOIN projects p ON p.id = s.project_id
            WHERE s.id = :id
        """),
        {"id": site_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Site not found")

    # If tenant_id is present, verify this site belongs to the tenant
    if tenant_id is not None:
        await verify_tenant_access(tenant_id, row["customer_id"], session)

    # Return site data (without customer_id in response)
    return SiteOut(
        id=row["id"],
        project_id=row["project_id"],
        name=row["name"],
        location=row["location"],
        created_at=row["created_at"],
    )


@router.put("/{site_id}", response_model=SiteOut)
async def update_site(
    site_id: str,
    payload: SiteIn,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Update a site.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can update any site.
    - Customer (with X-Customer-ID):
        - Existing site must belong to tenant
        - New project_id (if changed) must belong to tenant

    Phase 3: Write protection
    """
    # Validate UUID format (Phase 2)
    validate_uuid(site_id, field_name="site_id")
    validate_uuid(payload.project_id, field_name="project_id")
    
    # Phase 3: If tenant_id is present, verify access
    if tenant_id is not None:
        # First, verify the existing site belongs to tenant
        await verify_site_belongs_to_tenant(site_id, tenant_id, session)
        
        # Verify new project_id (if changed) also belongs to tenant
        result = await session.execute(
            text("SELECT project_id::text FROM sites WHERE id = :id"),
            {"id": site_id},
        )
        existing = result.mappings().first()
        if existing and existing["project_id"] != payload.project_id:
            await verify_project_belongs_to_tenant(payload.project_id, tenant_id, session)
    
    import json
    result = await session.execute(
        text(
            "UPDATE sites SET project_id = :project_id, name = :name, location = CAST(:location AS jsonb) "
            "WHERE id = :id "
            "RETURNING id::text, project_id::text AS project_id, name, location, created_at"
        ),
        {"id": site_id, "project_id": payload.project_id, "name": payload.name, "location": json.dumps(payload.location or {})},
    )
    await session.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Site not found")
    return SiteOut(**row)


@router.delete("/{site_id}")
async def delete_site(
    site_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Delete a site.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can delete any site.
    - Customer (with X-Customer-ID): can only delete sites belonging to their tenant.

    Phase 3: Write protection
    """
    # Validate UUID format (Phase 2)
    validate_uuid(site_id, field_name="site_id")
    
    # Phase 3: If tenant_id is present, verify site belongs to tenant
    if tenant_id is not None:
        await verify_site_belongs_to_tenant(site_id, tenant_id, session)
    
    result = await session.execute(text("DELETE FROM sites WHERE id = :id"), {"id": site_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Site not found")
    return {"status": "ok"}



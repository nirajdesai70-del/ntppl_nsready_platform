from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import Optional
import uuid

from core.db import get_session
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists
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
async def create_site(payload: SiteIn, session: AsyncSession = Depends(get_session)):
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
async def get_site(site_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "SELECT id::text, project_id::text AS project_id, name, location, created_at "
            "FROM sites WHERE id = :id"
        ),
        {"id": site_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Site not found")
    return SiteOut(**row)


@router.put("/{site_id}", response_model=SiteOut)
async def update_site(site_id: str, payload: SiteIn, session: AsyncSession = Depends(get_session)):
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
async def delete_site(site_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("DELETE FROM sites WHERE id = :id"), {"id": site_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Site not found")
    return {"status": "ok"}



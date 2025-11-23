from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import Optional
import uuid

from core.db import get_session
from api.deps import bearer_auth, get_tenant_customer_id, verify_customer_exists
from api.models import ProjectIn, ProjectOut

router = APIRouter(prefix="/projects", tags=["projects"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[ProjectOut])
async def list_projects(
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    List projects.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): return all projects (current behaviour).
    - Customer (with X-Customer-ID): return only that customer's projects.

    Tests:
    - Test 10: Projects endpoint filters by tenant.
    """
    # Engineer/Admin mode: no tenant filter
    if tenant_id is None:
        result = await session.execute(
            text(
                "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
                "FROM projects ORDER BY created_at DESC"
            )
        )
        return [ProjectOut(**row) for row in result.mappings().all()]

    # Customer mode: tenant_id must exist
    if not await verify_customer_exists(tenant_id, session):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Customer {tenant_id} not found",
        )

    # Filter by tenant_id
    result = await session.execute(
        text(
            "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
            "FROM projects WHERE customer_id = :customer_id ORDER BY created_at DESC"
        ),
        {"customer_id": str(tenant_id)},
    )
    return [ProjectOut(**row) for row in result.mappings().all()]


@router.post("", response_model=ProjectOut)
async def create_project(payload: ProjectIn, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "INSERT INTO projects(customer_id, name, description) "
            "VALUES (:customer_id, :name, :description) "
            "RETURNING id::text, customer_id::text AS customer_id, name, description, created_at"
        ),
        {"customer_id": payload.customer_id, "name": payload.name, "description": payload.description},
    )
    await session.commit()
    return ProjectOut(**result.mappings().one())


@router.get("/{project_id}", response_model=ProjectOut)
async def get_project(
    project_id: str,
    tenant_id: Optional[uuid.UUID] = Depends(get_tenant_customer_id),
    session: AsyncSession = Depends(get_session),
):
    """
    Get project by ID.

    Behaviour:
    - Engineer/Admin (no X-Customer-ID): can access any existing project.
    - Customer (with X-Customer-ID):
        - If this project belongs to their customer: 200
        - If other tenant: 404
    - If project_id does not exist: 404
    """
    # Fetch the project
    result = await session.execute(
        text(
            "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
            "FROM projects WHERE id = :id"
        ),
        {"id": project_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Project not found")

    # If tenant_id is present, verify this project belongs to the tenant
    if tenant_id is not None:
        from api.deps import verify_tenant_access
        await verify_tenant_access(tenant_id, row["customer_id"], session)

    return ProjectOut(**row)


@router.put("/{project_id}", response_model=ProjectOut)
async def update_project(project_id: str, payload: ProjectIn, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "UPDATE projects SET customer_id = :customer_id, name = :name, description = :description "
            "WHERE id = :id "
            "RETURNING id::text, customer_id::text AS customer_id, name, description, created_at"
        ),
        {
            "id": project_id,
            "customer_id": payload.customer_id,
            "name": payload.name,
            "description": payload.description,
        },
    )
    await session.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Project not found")
    return ProjectOut(**row)


@router.delete("/{project_id}")
async def delete_project(project_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("DELETE FROM projects WHERE id = :id"), {"id": project_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Project not found")
    return {"status": "ok"}



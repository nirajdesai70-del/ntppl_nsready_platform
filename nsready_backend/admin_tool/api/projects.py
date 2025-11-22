from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from core.db import get_session
from api.deps import bearer_auth
from api.models import ProjectIn, ProjectOut

router = APIRouter(prefix="/projects", tags=["projects"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[ProjectOut])
async def list_projects(session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text(
            "SELECT id::text, customer_id::text AS customer_id, name, description, created_at "
            "FROM projects ORDER BY created_at DESC"
        )
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
async def get_project(project_id: str, session: AsyncSession = Depends(get_session)):
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



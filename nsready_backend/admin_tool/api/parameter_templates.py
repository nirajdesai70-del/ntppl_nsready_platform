from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from core.db import get_session
from api.deps import bearer_auth
from api.models import ParamTemplateIn, ParamTemplateOut

router = APIRouter(prefix="/parameter_templates", tags=["parameter_templates"], dependencies=[Depends(bearer_auth)])


@router.get("", response_model=list[ParamTemplateOut])
async def list_param_templates(session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text("SELECT id::text, key, name, unit, metadata, created_at FROM parameter_templates ORDER BY created_at DESC")
    )
    return [ParamTemplateOut(**row) for row in result.mappings().all()]


@router.post("", response_model=ParamTemplateOut)
async def create_param_template(payload: ParamTemplateIn, session: AsyncSession = Depends(get_session)):
    import json
    result = await session.execute(
        text(
            "INSERT INTO parameter_templates(key, name, unit, metadata) "
            "VALUES (:key, :name, :unit, CAST(:metadata AS jsonb)) "
            "RETURNING id::text, key, name, unit, metadata, created_at"
        ),
        {"key": payload.key, "name": payload.name, "unit": payload.unit, "metadata": json.dumps(payload.metadata or {})},
    )
    await session.commit()
    return ParamTemplateOut(**result.mappings().one())


@router.get("/{template_id}", response_model=ParamTemplateOut)
async def get_param_template(template_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        text("SELECT id::text, key, name, unit, metadata, created_at FROM parameter_templates WHERE id = :id"),
        {"id": template_id},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Parameter template not found")
    return ParamTemplateOut(**row)


@router.put("/{template_id}", response_model=ParamTemplateOut)
async def update_param_template(template_id: str, payload: ParamTemplateIn, session: AsyncSession = Depends(get_session)):
    import json
    result = await session.execute(
        text(
            "UPDATE parameter_templates SET key = :key, name = :name, unit = :unit, metadata = CAST(:metadata AS jsonb) "
            "WHERE id = :id "
            "RETURNING id::text, key, name, unit, metadata, created_at"
        ),
        {"id": template_id, "key": payload.key, "name": payload.name, "unit": payload.unit, "metadata": json.dumps(payload.metadata or {})},
    )
    await session.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Parameter template not found")
    return ParamTemplateOut(**row)


@router.delete("/{template_id}")
async def delete_param_template(template_id: str, session: AsyncSession = Depends(get_session)):
    result = await session.execute(text("DELETE FROM parameter_templates WHERE id = :id"), {"id": template_id})
    await session.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Parameter template not found")
    return {"status": "ok"}



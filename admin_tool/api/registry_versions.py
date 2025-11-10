from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from core.db import get_session
from api.deps import bearer_auth
from api.models import PublishIn, PublishOut

router = APIRouter(prefix="/projects", tags=["registry_versions"], dependencies=[Depends(bearer_auth)])


@router.post("/{project_id}/versions/publish", response_model=PublishOut)
async def publish_version(project_id: str, payload: PublishIn, session: AsyncSession = Depends(get_session)):
    # Ensure project exists
    proj = await session.execute(text("SELECT id FROM projects WHERE id = :id"), {"id": project_id})
    if not proj.first():
        raise HTTPException(status_code=404, detail="Project not found")

    # Compute next version
    res = await session.execute(
        text("SELECT COALESCE(MAX(version), 0) AS maxv FROM registry_versions WHERE project_id = :pid"),
        {"pid": project_id},
    )
    maxv = res.scalar_one()
    next_version = int(maxv) + 1

    # Build full config snapshot (customers/projects/sites/devices/param templates minimal form)
    cfg_customers = (await session.execute(text("SELECT id::text, name, metadata FROM customers"))).mappings().all()
    cfg_projects = (await session.execute(text("SELECT id::text, customer_id::text AS customer_id, name, description FROM projects"))).mappings().all()
    cfg_sites = (await session.execute(text("SELECT id::text, project_id::text AS project_id, name, location FROM sites"))).mappings().all()
    cfg_devices = (await session.execute(text("SELECT id::text, site_id::text AS site_id, name, device_type, external_id, status FROM devices"))).mappings().all()
    cfg_params = (await session.execute(text("SELECT id::text, key, name, unit, metadata FROM parameter_templates"))).mappings().all()
    full_config = {
        "customers": cfg_customers,
        "projects": cfg_projects,
        "sites": cfg_sites,
        "devices": cfg_devices,
        "parameter_templates": cfg_params,
    }

    # Insert version row
    await session.execute(
        text(
            "INSERT INTO registry_versions(project_id, version, diff_json, author, full_config, checksum, description) "
            "VALUES (:pid, :ver, :diff, :author, :full_config, :checksum, :description)"
        ),
        {
            "pid": project_id,
            "ver": next_version,
            "diff": payload.diff_json,
            "author": payload.author,
            "full_config": full_config,
            "checksum": f"v{next_version}",  # placeholder checksum
            "description": f"Published by {payload.author}",
        },
    )
    await session.commit()
    return PublishOut(status="ok", config_version=f"v{next_version}")


@router.get("/{project_id}/versions/latest")
async def latest_version(project_id: str, session: AsyncSession = Depends(get_session)):
    row = await session.execute(
        text(
            "SELECT version, full_config FROM registry_versions "
            "WHERE project_id = :pid ORDER BY version DESC LIMIT 1"
        ),
        {"pid": project_id},
    )
    latest = row.mappings().first()
    if not latest:
        raise HTTPException(status_code=404, detail="No versions")
    return {"config_version": f"v{latest['version']}", "config": latest["full_config"]}



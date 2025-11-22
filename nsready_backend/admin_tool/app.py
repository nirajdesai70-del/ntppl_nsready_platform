import contextlib
from fastapi import FastAPI
from core.db import create_engine, create_sessionmaker, healthcheck
from api.customers import router as customers_router
from api.projects import router as projects_router
from api.sites import router as sites_router
from api.devices import router as devices_router
from api.parameter_templates import router as param_templates_router
from api.registry_versions import router as registry_versions_router

engine = create_engine()
SessionLocal = create_sessionmaker(engine)

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    await healthcheck(engine)
    yield
    await engine.dispose()

app = FastAPI(title="NTPPL NS-Ready Admin Tool", lifespan=lifespan)

app.include_router(customers_router, prefix="/admin")
app.include_router(projects_router, prefix="/admin")
app.include_router(sites_router, prefix="/admin")
app.include_router(devices_router, prefix="/admin")
app.include_router(param_templates_router, prefix="/admin")
app.include_router(registry_versions_router, prefix="/admin")

@app.get("/health")
def health():
    return {"service": "ok"}



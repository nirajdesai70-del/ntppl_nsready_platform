import contextlib
import logging
from fastapi import FastAPI
from fastapi.responses import Response
from core.db import create_engine, create_sessionmaker, healthcheck
from core.nats_client import init_nats_client, close_nats_client, get_nats_client
from core.worker import IngestWorker
from core.metrics import get_metrics_response, queue_depth_gauge
from api.ingest import router as ingest_router
from api.models import HealthResponse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize database
engine = create_engine()
SessionLocal = create_sessionmaker(engine)

# Global worker instance
worker: IngestWorker | None = None


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    global worker
    
    # Startup
    logger.info("Starting collector service...")
    
    # Check database connection
    try:
        await healthcheck(engine)
        logger.info("Database connection verified")
    except Exception as e:
        logger.error(f"Database healthcheck failed: {e}")
        raise
    
    # Connect to NATS
    try:
        nats_client = await init_nats_client()
        logger.info("NATS client connected")
    except Exception as e:
        logger.error(f"Failed to connect to NATS: {e}")
        raise
    
    # Start worker
    try:
        worker = IngestWorker(nats_client.nc, SessionLocal, subject=nats_client.subject)
        await worker.start()
        logger.info("Ingest worker started")
    except Exception as e:
        logger.error(f"Failed to start worker: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Shutting down collector service...")
    
    if worker:
        await worker.stop()
    
    await close_nats_client()
    await engine.dispose()
    
    logger.info("Collector service stopped")


app = FastAPI(
    title="NTPPL NS-Ready Collector Service",
    description="Telemetry ingestion service with NATS queuing",
    version="1.0.0",
    lifespan=lifespan
)

# Include routers
app.include_router(ingest_router)


@app.get("/v1/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    try:
        # Check database
        await healthcheck(engine)
        db_status = "connected"
    except Exception as e:
        logger.error(f"Database healthcheck failed: {e}")
        db_status = "disconnected"
    
    # Check NATS and get queue depth
    try:
        nats_client = get_nats_client()
        queue_depth = await nats_client.get_queue_depth()
        queue_depth_gauge.set(queue_depth)
    except Exception:
        queue_depth = 0
    
    return HealthResponse(
        service="ok",
        queue_depth=queue_depth,
        db=db_status
    )


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return get_metrics_response()

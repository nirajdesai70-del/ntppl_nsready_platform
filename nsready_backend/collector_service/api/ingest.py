import uuid
import logging
from fastapi import APIRouter, HTTPException, Depends
from api.models import NormalizedEvent, IngestResponse
from core.nats_client import get_nats_client, NATSClient
from core.metrics import ingest_counter, error_counter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1", tags=["ingest"])


async def validate_event(event: NormalizedEvent) -> None:
    """Validate event fields"""
    if not event.project_id:
        raise HTTPException(status_code=400, detail="project_id is required")
    if not event.site_id:
        raise HTTPException(status_code=400, detail="site_id is required")
    if not event.device_id:
        raise HTTPException(status_code=400, detail="device_id is required")
    if not event.metrics or len(event.metrics) == 0:
        raise HTTPException(status_code=400, detail="metrics array must contain at least one metric")
    if not event.protocol:
        raise HTTPException(status_code=400, detail="protocol is required")
    if not event.source_timestamp:
        raise HTTPException(status_code=400, detail="source_timestamp is required")


@router.post("/ingest", response_model=IngestResponse)
async def ingest_event(
    event: NormalizedEvent,
    nats_client: NATSClient = Depends(get_nats_client)
):
    """
    Ingest telemetry event.
    
    Accepts NormalizedEvent v1.0 schema and queues it for async processing.
    """
    try:
        # Validate event
        await validate_event(event)
        
        # Generate trace_id
        trace_id = str(uuid.uuid4())
        
        # Prepare message payload
        message_data = {
            "trace_id": trace_id,
            "event": event.model_dump(mode="json"),
            "config_version": event.config_version or "unknown"
        }
        
        # Publish to NATS
        await nats_client.publish_event(message_data)
        
        # Increment metrics
        ingest_counter.labels(status="queued").inc()
        
        logger.info(f"Event queued: trace_id={trace_id}, device_id={event.device_id}, metrics={len(event.metrics)}")
        
        return IngestResponse(
            status="queued",
            trace_id=trace_id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        error_counter.labels(error_type="ingest_error").inc()
        logger.error(f"Error ingesting event: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


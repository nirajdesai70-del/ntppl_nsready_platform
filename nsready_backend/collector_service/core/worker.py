import json
import logging
from typing import Optional
from uuid import UUID
from sqlalchemy import text, bindparam
from sqlalchemy.exc import IntegrityError
from nats.aio.client import Client as NATS
from nats.aio.subscription import Subscription
from core.db import create_sessionmaker
from core.metrics import ingest_counter, error_counter, queue_depth_gauge
from api.models import NormalizedEvent

logger = logging.getLogger(__name__)


class IngestWorker:
    """Async worker to consume events from NATS and write to database"""
    
    def __init__(self, nc: NATS, session_factory, subject: str = "ingress.events"):
        self.nc = nc
        self.session_factory = session_factory
        self.subject = subject
        self.subscription: Optional[Subscription] = None
        self.running = False
    
    async def start(self) -> None:
        """Start the worker"""
        if self.running:
            return
        
        self.running = True
        self.subscription = await self.nc.subscribe(self.subject, cb=self._handle_message)
        logger.info(f"Worker started, subscribed to {self.subject}")
    
    async def stop(self) -> None:
        """Stop the worker"""
        self.running = False
        if self.subscription:
            await self.subscription.unsubscribe()
            logger.info("Worker stopped")
    
    async def _handle_message(self, msg) -> None:
        """Handle incoming NATS message"""
        try:
            data = json.loads(msg.data.decode())
            trace_id = data.get("trace_id")
            event_data = data.get("event")
            
            if not event_data:
                logger.error(f"Invalid message format: missing event data")
                error_counter.labels(error_type="invalid_format").inc()
                return
            
            # Parse event
            event = NormalizedEvent(**event_data)
            
            # Process event
            await self._process_event(event, trace_id)
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to decode message: {e}")
            error_counter.labels(error_type="json_decode").inc()
        except Exception as e:
            logger.error(f"Error handling message: {e}", exc_info=True)
            error_counter.labels(error_type="processing").inc()
    
    async def _process_event(self, event: NormalizedEvent, trace_id: str) -> None:
        """Process a single event and insert into database"""
        async with self.session_factory() as session:
            try:
                # Insert each metric as a separate row in ingest_events
                for metric in event.metrics:
                    # Generate unique event_id per metric for idempotency
                    # If event.event_id is provided, append parameter_key to make it unique per metric
                    if event.event_id:
                        event_id = f"{event.event_id}:{metric.parameter_key}"
                    else:
                        event_id = f"{event.device_id}:{event.source_timestamp.isoformat()}:{metric.parameter_key}"
                    
                    # Use ON CONFLICT to handle idempotency
                    # PostgreSQL will use the unique constraint on (time, device_id, parameter_key)
                    insert_stmt = text("""
                        INSERT INTO ingest_events (
                            time, device_id, parameter_key, value, quality, 
                            source, event_id, attributes, created_at
                        ) VALUES (
                            :time, CAST(:device_id AS uuid), :parameter_key, :value, :quality,
                            :source, :event_id, CAST(:attributes AS jsonb), NOW()
                        )
                        ON CONFLICT (time, device_id, parameter_key) 
                        DO UPDATE SET
                            value = EXCLUDED.value,
                            quality = EXCLUDED.quality,
                            source = EXCLUDED.source,
                            event_id = EXCLUDED.event_id,
                            attributes = EXCLUDED.attributes
                    """)
                    
                    await session.execute(insert_stmt, {
                        "time": event.source_timestamp,
                        "device_id": event.device_id,
                        "parameter_key": metric.parameter_key,
                        "value": metric.value,
                        "quality": metric.quality,
                        "source": event.protocol,
                        "event_id": event_id,
                        "attributes": json.dumps(metric.attributes or {})
                    })
                
                await session.commit()
                ingest_counter.labels(status="success").inc()
                logger.debug(f"Event processed: trace_id={trace_id}, device_id={event.device_id}")
                
            except IntegrityError as e:
                await session.rollback()
                # This might be a foreign key constraint violation
                logger.warning(f"Integrity error for trace_id={trace_id}: {e}")
                error_counter.labels(error_type="integrity").inc()
            except Exception as e:
                await session.rollback()
                logger.error(f"Error processing event trace_id={trace_id}: {e}", exc_info=True)
                error_counter.labels(error_type="database").inc()
                raise


from datetime import datetime
from typing import Optional, Any, List
from pydantic import BaseModel, Field, field_validator
from uuid import UUID


class Metric(BaseModel):
    """Single metric value in a telemetry event"""
    parameter_key: str
    value: Optional[float] = None
    quality: int = Field(default=0, ge=0, le=255)
    attributes: Optional[dict[str, Any]] = Field(default_factory=dict)


class NormalizedEvent(BaseModel):
    """NormalizedEvent v1.0 schema for telemetry ingestion"""
    project_id: str
    site_id: str
    device_id: str
    metrics: List[Metric] = Field(min_length=1)
    protocol: str  # e.g., "SMS", "GPRS", "HTTP"
    source_timestamp: datetime
    config_version: Optional[str] = None
    event_id: Optional[str] = None  # For idempotency
    metadata: Optional[dict[str, Any]] = Field(default_factory=dict)

    @field_validator('device_id')
    @classmethod
    def validate_uuid(cls, v: str) -> str:
        """Validate device_id is a valid UUID"""
        try:
            UUID(v)
        except ValueError:
            raise ValueError(f"device_id must be a valid UUID: {v}")
        return v

    @field_validator('project_id', 'site_id')
    @classmethod
    def validate_uuid_fields(cls, v: str) -> str:
        """Validate project_id and site_id are valid UUIDs"""
        try:
            UUID(v)
        except ValueError:
            raise ValueError(f"Field must be a valid UUID: {v}")
        return v


class IngestResponse(BaseModel):
    """Response from ingest endpoint"""
    status: str
    trace_id: str


class HealthResponse(BaseModel):
    """Health check response"""
    service: str
    queue_depth: int
    db: str


# NTPPL NS-Ready Collector Service

Telemetry ingestion service with NATS message queuing and asynchronous database writes.

## Overview

The Collector Service provides a REST API for ingesting telemetry data from devices. It validates incoming events, queues them via NATS, and processes them asynchronously to write to TimescaleDB.

## Architecture

- **API Layer**: FastAPI endpoints for ingestion and health checks
- **NATS Queue**: Message broker for async event processing
- **Worker**: Background consumer that processes events from NATS and writes to database
- **Database**: PostgreSQL with TimescaleDB for time-series data storage

## Endpoints

### POST /v1/ingest

Ingest a telemetry event. Accepts NormalizedEvent v1.0 schema.

**Request Body:**
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "site_id": "550e8400-e29b-41d4-a716-446655440001",
  "device_id": "550e8400-e29b-41d4-a716-446655440002",
  "metrics": [
    {
      "parameter_key": "voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": {}
    },
    {
      "parameter_key": "current",
      "value": 10.2,
      "quality": 192
    }
  ],
  "protocol": "SMS",
  "source_timestamp": "2024-01-15T10:30:00Z",
  "config_version": "v1.0",
  "event_id": "optional-idempotency-key"
}
```

**Response:**
```json
{
  "status": "queued",
  "trace_id": "550e8400-e29b-41d4-a716-446655440003"
}
```

**Status Codes:**
- `200`: Event queued successfully
- `400`: Validation error (missing/invalid fields)
- `500`: Internal server error

### GET /v1/health

Health check endpoint with service status, queue depth, and database connection status.

**Response:**
```json
{
  "service": "ok",
  "queue_depth": 0,
  "db": "connected"
}
```

### GET /metrics

Prometheus metrics endpoint. Exposes:
- `ingest_events_total`: Total events ingested (by status)
- `ingest_errors_total`: Total errors (by error_type)
- `ingest_queue_depth`: Current queue depth
- `ingest_rate_per_second`: Current ingestion rate

## Sample Payloads

### SMS Protocol
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "site_id": "550e8400-e29b-41d4-a716-446655440001",
  "device_id": "550e8400-e29b-41d4-a716-446655440002",
  "metrics": [
    {
      "parameter_key": "voltage",
      "value": 230.5,
      "quality": 192
    }
  ],
  "protocol": "SMS",
  "source_timestamp": "2024-01-15T10:30:00Z"
}
```

### GPRS Protocol
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "site_id": "550e8400-e29b-41d4-a716-446655440001",
  "device_id": "550e8400-e29b-41d4-a716-446655440002",
  "metrics": [
    {
      "parameter_key": "voltage",
      "value": 230.5,
      "quality": 192
    },
    {
      "parameter_key": "current",
      "value": 10.2,
      "quality": 192
    },
    {
      "parameter_key": "power",
      "value": 2351.1,
      "quality": 192
    }
  ],
  "protocol": "GPRS",
  "source_timestamp": "2024-01-15T10:30:00Z",
  "config_version": "v1.2"
}
```

## cURL Examples

### Ingest Event
```bash
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "550e8400-e29b-41d4-a716-446655440000",
    "site_id": "550e8400-e29b-41d4-a716-446655440001",
    "device_id": "550e8400-e29b-41d4-a716-446655440002",
    "metrics": [
      {
        "parameter_key": "voltage",
        "value": 230.5,
        "quality": 192
      }
    ],
    "protocol": "SMS",
    "source_timestamp": "2024-01-15T10:30:00Z"
  }'
```

### Health Check
```bash
curl http://localhost:8001/v1/health
```

### Metrics
```bash
curl http://localhost:8001/metrics
```

## Configuration

Environment variables (from `.env`):

- `POSTGRES_DB`: Database name (default: `nsready`)
- `POSTGRES_USER`: Database user (default: `postgres`)
- `POSTGRES_PASSWORD`: Database password (default: `postgres`)
- `DB_HOST`: Database host (default: `db`)
- `DB_PORT`: Database port (default: `5432`)
- `NATS_HOST`: NATS server host (default: `nats`)
- `NATS_PORT`: NATS server port (default: `4222`)
- `QUEUE_SUBJECT`: NATS subject for events (default: `ingress.events`)

## Data Flow

1. Client sends POST request to `/v1/ingest` with telemetry event
2. API validates event schema (project_id, site_id, device_id, metrics, protocol, timestamps)
3. Event is published to NATS subject `ingress.events` with trace_id
4. API returns `{ "status": "queued", "trace_id": "..." }`
5. Background worker consumes message from NATS
6. Worker inserts data into `ingest_events` table
7. Idempotency enforced on `(device_id, source_timestamp, parameter_key)`

## Idempotency

Events are idempotent based on:
- `device_id`
- `source_timestamp`
- `parameter_key`

Duplicate events with the same combination will be updated rather than creating duplicates.

## Error Handling

- Validation errors return `400` with error details
- Database errors are logged and tracked in metrics
- NATS connection failures trigger retry logic on startup
- Failed events are logged to `error_logs` table (if configured)

## Monitoring

View Prometheus metrics at `/metrics`:
- `ingest_events_total{status="success"}`: Successful ingestions
- `ingest_errors_total{error_type="..."}`: Error counts by type
- `ingest_queue_depth`: Current queue depth

## Development

Run with Docker Compose:
```bash
docker compose up --build collector_service
```

The service will:
1. Connect to database (with retry)
2. Connect to NATS (with retry, up to 10 attempts)
3. Start background worker
4. Accept requests on port 8001

## Testing

See `tests/sample_event.json` for example payloads.


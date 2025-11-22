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
  "project_id": "8212caa2-b928-4213-b64e-9f5b86f4cad1",
  "site_id": "89a66770-bdcc-4c95-ac97-e1829cb7a960",
  "device_id": "bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad",
  "protocol": "GPRS",
  "source_timestamp": "2025-11-14T12:00:00Z",
  "metrics": [
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": { "unit": "V" }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:current",
      "value": 10.2,
      "quality": 192,
      "attributes": { "unit": "A" }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:power",
      "value": 2455.8,
      "quality": 192,
      "attributes": { "unit": "W" }
    }
  ],
  "config_version": "v1.0",
  "event_id": "device-001-2025-11-14T12:00:00Z",
  "metadata": {}
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
  "project_id": "8212caa2-b928-4213-b64e-9f5b86f4cad1",
  "site_id": "89a66770-bdcc-4c95-ac97-e1829cb7a960",
  "device_id": "bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad",
  "metrics": [
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": { "unit": "V" }
    }
  ],
  "protocol": "SMS",
  "source_timestamp": "2025-11-14T12:00:00Z"
}
```

### GPRS Protocol
```json
{
  "project_id": "8212caa2-b928-4213-b64e-9f5b86f4cad1",
  "site_id": "89a66770-bdcc-4c95-ac97-e1829cb7a960",
  "device_id": "bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad",
  "metrics": [
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": { "unit": "V" }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:current",
      "value": 10.2,
      "quality": 192,
      "attributes": { "unit": "A" }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:power",
      "value": 2455.8,
      "quality": 192,
      "attributes": { "unit": "W" }
    }
  ],
  "protocol": "GPRS",
  "source_timestamp": "2025-11-14T12:00:00Z",
  "config_version": "v1.0"
}
```

## cURL Examples

### Ingest Event

You can send this event using:

```bash
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @collector_service/tests/sample_event.json
```

> ⚠️ **NOTE (API & DB CONTRACT):**  
> The `parameter_key` shown above uses the full canonical format  
> `project:<project_uuid>:<parameter_name>`.  
> This MUST match the `parameter_templates.key` value in the database.  
> Short-form keys (e.g., `"voltage"`) will cause database foreign-key errors and can  
> break downstream analytics/AI pipelines that rely on stable keys.  
>  
> For more details, see **Module 6 – Parameter Template Manual**.

### Tenant Identity (NS-TENANT-ID)

The ingestion pipeline automatically resolves the **tenant** from the  
`project_id → site_id → device_id` chain.

Internally:

- `tenant_id` = `customer_id`

- No device or API caller needs to send a separate tenant field.

This remains compatible with full NSWare multi-tenant mode.

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

### Sample Event

See `tests/sample_event.json` for example payloads.

### Test Scripts

Comprehensive data flow testing is available via bash scripts in the `scripts/` directory:

**Basic Data Flow Test:**
```bash
DB_CONTAINER=nsready_db ./scripts/test_data_flow.sh
```
Tests end-to-end flow: ingestion → queue → database → SCADA views → export.

**Batch Ingestion Test:**
```bash
./scripts/test_batch_ingestion.sh --count 100
```
Tests sequential and parallel batch ingestion with throughput measurement.

**Stress/Load Test:**
```bash
./scripts/test_stress_load.sh --events 1000 --rate 50
```
Tests system under sustained high load with queue depth monitoring.

**Negative Test Cases:**
```bash
./scripts/test_negative_cases.sh
```
Tests system behavior with invalid data (missing fields, wrong formats, etc.).

**Multi-Customer Test:**
```bash
./scripts/test_multi_customer_flow.sh --customers 5
```
Tests data flow with multiple customers and verifies tenant isolation.

See `scripts/TEST_SCRIPTS_README.md` and `master_docs/DATA_FLOW_TESTING_GUIDE.md` for complete testing documentation.



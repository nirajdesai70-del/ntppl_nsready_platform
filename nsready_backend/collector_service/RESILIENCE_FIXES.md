# Resilience Fixes - Phase 4 Collector Service

## Issues Fixed

### 1. ✅ NATS Downtime → Lost Events

**Root Cause:** Publisher didn't retry or persist events locally; returned `"queued"` before verifying publish success.

**Fix Implemented:**
- Added exponential backoff retry logic (3 attempts: 0.5s, 1s, 2s delays)
- Automatic reconnection attempt on publish failure
- Events sent to Dead-Letter Queue (DLQ) if all retries fail
- JetStream persistence enabled for message durability

**Code Changes:**
- `core/nats_client.py`: `publish_event()` now includes retry logic with exponential backoff
- Failed publishes automatically route to DLQ subject `ingress.events.dlq`
- JetStream stream "INGRESS" created automatically on connection

### 2. ✅ Queue Depth Metric Placeholder

**Root Cause:** Collector didn't read actual queue info from NATS.

**Fix Implemented:**
- Real queue depth tracking using JetStream `stream_info()`
- Returns actual message count from JetStream stream state
- Falls back gracefully if JetStream is unavailable

**Code Changes:**
- `core/nats_client.py`: `get_queue_depth()` now uses `js.stream_info("INGRESS")` to get real queue depth
- Returns `state.messages` from stream info

### 3. ✅ Dead-Letter Queue (DLQ)

**Root Cause:** Failed publish events vanished.

**Fix Implemented:**
- DLQ subject: `ingress.events.dlq` (configurable via `DLQ_SUBJECT` env var)
- Failed events automatically published to DLQ with error reason
- DLQ events include original event data + `dlq_reason` and `dlq_timestamp`
- Metrics tracking: `ingest_dlq_total` counter with reason labels

**Code Changes:**
- `core/nats_client.py`: `_publish_to_dlq()` method added
- `core/metrics.py`: `dlq_counter` metric added
- `api/ingest.py`: DLQ metrics tracking on publish failures

## Configuration

New environment variables:
- `DLQ_SUBJECT`: Dead-letter queue subject (default: `ingress.events.dlq`)

## Metrics Added

- `ingest_dlq_total{reason="publish_failed"}`: Count of events sent to DLQ
- `ingest_events_total{status="dlq"}`: Events that went to DLQ (still counted as queued)

## Testing

To test the fixes:

1. **Test retry logic:**
   ```bash
   docker compose stop nats
   curl -X POST http://localhost:8001/v1/ingest -H "Content-Type: application/json" -d @collector_service/tests/sample_event.json
   docker compose start nats
   # Event should be retried and eventually published
   ```

2. **Test queue depth:**
   ```bash
   curl http://localhost:8001/v1/health
   # queue_depth should show actual JetStream message count
   ```

3. **Test DLQ:**
   ```bash
   # Stop NATS and send events - they should go to DLQ
   docker compose stop nats
   curl -X POST http://localhost:8001/v1/ingest -H "Content-Type: application/json" -d @collector_service/tests/sample_event.json
   # Check metrics for DLQ count
   curl http://localhost:8001/metrics | grep ingest_dlq_total
   ```

## Notes

- JetStream must be enabled in NATS (already configured in docker-compose.yml with `-js` flag)
- DLQ messages can be reprocessed by subscribing to `ingress.events.dlq` subject
- Retry delays: 0.5s, 1s, 2s (exponential backoff)
- Maximum retries: 3 attempts before sending to DLQ



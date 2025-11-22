# Performance Optimizations - Phase 5 Enhancements

## Overview

This document describes the performance optimizations implemented based on the recommendations for improving async worker throughput, batch DB inserts, NATS JetStream tuning, and benchmark realism.

## 1. ✅ Async Worker Throughput - Worker Pool

### Implementation
- **Worker Pool Size**: Configurable via `WORKER_POOL_SIZE` environment variable (default: 4 workers)
- **Location**: `collector_service/app.py`
- **Changes**: 
  - Changed from single worker to worker pool (3-5 workers recommended)
  - All workers share the same JetStream durable consumer for load balancing
  - Each worker processes messages independently in parallel

### Benefits
- **3-5x throughput improvement** by processing messages in parallel
- Better resource utilization across CPU cores
- Improved resilience (if one worker fails, others continue)

### Configuration
```bash
WORKER_POOL_SIZE=4  # Number of parallel workers (default: 4)
```

## 2. ✅ Batch DB Inserts

### Implementation
- **Batch Size**: Configurable via `WORKER_BATCH_SIZE` environment variable (default: 50 messages)
- **Batch Timeout**: Configurable via `WORKER_BATCH_TIMEOUT` environment variable (default: 0.5 seconds)
- **Location**: `collector_service/core/worker.py`
- **Changes**:
  - Messages are collected into batches before database insertion
  - Bulk INSERT with multiple VALUES clauses (up to 1000 rows per chunk to avoid SQL parameter limits)
  - Single transaction per batch for atomicity
  - ON CONFLICT handling for idempotency maintained

### Benefits
- **Significant reduction in database round-trips** (50:1 reduction with default batch size)
- **Improved database throughput** by reducing transaction overhead
- **Better I/O efficiency** with larger write operations

### Configuration
```bash
WORKER_BATCH_SIZE=50        # Number of messages to batch (default: 50)
WORKER_BATCH_TIMEOUT=0.5     # Max wait time for batch in seconds (default: 0.5)
```

## 3. ✅ NATS JetStream Tuning

### Implementation
- **Pull Consumer with Batching**: Uses JetStream pull consumer instead of push subscription
- **Pull Batch Size**: Configurable via `NATS_PULL_BATCH_SIZE` environment variable (default: 100 messages)
- **Ack Batching**: Messages are acknowledged in batches after successful DB insert
- **Consumer Configuration**:
  - `max_deliver=3`: Maximum retry attempts
  - `ack_wait=30`: Acknowledgment wait time (30 seconds)
  - `max_ack_pending=1000`: Maximum unacknowledged messages per worker
- **Location**: `collector_service/core/worker.py`

### Benefits
- **Reduced NATS round-trips** by pulling multiple messages at once
- **Better message distribution** across worker pool via durable consumer
- **Improved resilience** with configurable retry and ack policies
- **Lower latency** by reducing network overhead

### Configuration
```bash
NATS_PULL_BATCH_SIZE=100  # Number of messages to pull per batch (default: 100)
```

## 4. ✅ Benchmark Realism - Separate Latency Measurements

### Implementation
- **API Latency Tracking**: Measures time from POST request to response (time to queue)
- **Queue Latency Estimation**: Tracks queue depth via health endpoint to estimate processing time
- **Location**: `tests/performance/locustfile.py`
- **Changes**:
  - Added custom event tracking for API latency
  - Added queue depth monitoring via health endpoint
  - Separate metrics for API time vs queue processing time

### Benefits
- **Accurate performance analysis** by separating API latency from queue latency
- **Better bottleneck identification** (API vs worker processing)
- **Realistic performance metrics** for production planning

### Metrics Tracked
1. **API Latency**: Time from HTTP POST to response (includes validation + NATS publish)
2. **Queue Depth**: Number of messages waiting in NATS (indicates queue latency)
3. **Throughput**: Events per second
4. **Error Rate**: Percentage of failed requests

## Performance Impact Summary

| Optimization | Expected Improvement | Status |
|-------------|----------------------|--------|
| Worker Pool (4 workers) | 3-5x throughput | ✅ Implemented |
| Batch DB Inserts (50 msg/batch) | 50x fewer DB round-trips | ✅ Implemented |
| JetStream Pull Batching (100 msg/batch) | 100x fewer NATS round-trips | ✅ Implemented |
| Separate Latency Metrics | Better analysis | ✅ Implemented |

## Testing

Run performance benchmarks:
```bash
make benchmark
```

This will:
- Simulate 50 concurrent users
- Measure API latency separately from queue latency
- Generate performance report in `tests/reports/`

## Environment Variables

Add these to your `.env` file for tuning:

```bash
# Worker Configuration
WORKER_POOL_SIZE=4              # Number of parallel workers (3-5 recommended)
WORKER_BATCH_SIZE=50             # Messages per batch
WORKER_BATCH_TIMEOUT=0.5         # Batch timeout in seconds

# NATS Configuration
NATS_PULL_BATCH_SIZE=100         # Messages per NATS pull
```

## Notes

- **Worker Pool**: All workers share the same durable consumer name (`ingest_workers`) for automatic load balancing
- **Batch Processing**: Batches are processed when either:
  - Batch size is reached (`WORKER_BATCH_SIZE`)
  - Batch timeout expires (`WORKER_BATCH_TIMEOUT`)
  - Service is shutting down
- **Idempotency**: Maintained via `ON CONFLICT` clause in batch inserts
- **Error Handling**: Failed batches are NACK'd for retry, individual message failures are handled gracefully

## Future Enhancements

1. **Adaptive Batching**: Adjust batch size based on queue depth
2. **Metrics Export**: Export batch processing metrics to Prometheus
3. **Queue Latency Measurement**: Direct measurement via trace_id tracking in database
4. **Worker Health Monitoring**: Track individual worker performance



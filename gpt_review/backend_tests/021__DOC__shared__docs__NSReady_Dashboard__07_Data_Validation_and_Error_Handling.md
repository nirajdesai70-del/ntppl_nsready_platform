# Module 7 – Data Validation & Error Handling

_NSReady Data Collection Platform_

*(Suggested path: `docs/07_Data_Validation_and_Error_Handling.md`)*

---

## 1. Purpose of This Document

This module provides a comprehensive guide to data validation and error handling in the NSReady Data Collection Platform. It covers:

- Validation rules and procedures at each system layer
- Error types and their handling strategies
- Error recovery mechanisms
- Monitoring and alerting for validation failures
- Best practices for error prevention
- Troubleshooting common validation issues

This module is essential for:
- **Engineers** configuring and deploying the system
- **Developers** integrating with the NSReady API
- **Operators** monitoring system health and troubleshooting issues
- **SCADA teams** understanding data quality guarantees

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 5 – Configuration Import Manual
- Module 6 – Parameter Template Manual

---

## 2. Validation Architecture Overview

Data validation in NSReady occurs at multiple layers, each serving a specific purpose:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: API Request Validation (Collector Service)        │
│ - Schema validation (Pydantic models)                      │
│ - Required field checks                                     │
│ - UUID format validation                                    │
│ - Timestamp format validation                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Business Logic Validation (Worker Pool)           │
│ - Device existence check                                    │
│ - Parameter template validation                             │
│ - Metric value range validation                             │
│ - Foreign key constraint validation                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Database Constraint Validation (PostgreSQL)        │
│ - Foreign key constraints                                   │
│ - Unique constraints                                        │
│ - Check constraints                                         │
│ - Not null constraints                                      │
└─────────────────────────────────────────────────────────────┘
```

**Validation Philosophy:**

- **Fail Fast** - Validate as early as possible to avoid unnecessary processing
- **Clear Error Messages** - Provide actionable error details
- **Graceful Degradation** - Isolate failures to prevent system-wide impact
- **Audit Trail** - Log all validation failures for analysis

---

## 3. Layer 1: API Request Validation

### 3.1 Collector Service Validation

The Collector Service (`collector_service`) performs the first layer of validation when receiving telemetry events via the `/v1/ingest` endpoint.

#### 3.1.1 Schema Validation

**Pydantic Model Validation:**

All incoming events are validated against the `NormalizedEvent` Pydantic model:

```python
class NormalizedEvent(BaseModel):
    project_id: str  # UUID format required
    site_id: str      # UUID format required
    device_id: str    # UUID format required
    metrics: List[Metric]  # At least one metric required
    protocol: str     # Required (e.g., "GPRS", "SMS", "MQTT")
    source_timestamp: str  # ISO 8601 format required
    trace_id: Optional[str]  # Optional UUID for tracing
```

**Automatic Validation:**

- **Type checking** - Fields must match expected types
- **UUID format** - `project_id`, `site_id`, `device_id` must be valid UUIDs
- **Required fields** - Missing required fields trigger validation errors
- **Array validation** - `metrics` array must contain at least one metric

#### 3.1.2 Custom Validation Functions

**UUID Validation:**

```python
@validator('device_id')
def validate_uuid(cls, v: str) -> str:
    """Validate device_id is a valid UUID"""
    try:
        uuid.UUID(v)
        return v
    except ValueError:
        raise ValueError(f"device_id must be a valid UUID: {v}")
```

**Required Field Validation:**

```python
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
```

#### 3.1.3 Validation Error Responses

**HTTP Status Codes:**

- **400 Bad Request** - Validation error (missing/invalid fields)
- **422 Unprocessable Entity** - Schema validation failure (Pydantic)
- **500 Internal Server Error** - Unexpected server error

**Error Response Format:**

```json
{
  "detail": "project_id is required"
}
```

Or for Pydantic validation errors:

```json
{
  "detail": [
    {
      "loc": ["body", "device_id"],
      "msg": "device_id must be a valid UUID",
      "type": "value_error"
    }
  ]
}
```

#### 3.1.4 Validation Flow

```
1. Request received at /v1/ingest
   ↓
2. FastAPI parses JSON body
   ↓
3. Pydantic model validation (automatic)
   ↓
4. Custom validate_event() function
   ↓
5. If valid → Queue to NATS
   ↓
6. If invalid → Return 400/422 error immediately
```

**Key Point:** Invalid requests are rejected **before** queuing, preventing queue pollution.

---

## 4. Layer 2: Business Logic Validation

### 4.1 Worker Pool Validation

After events are queued to NATS, workers pull messages and perform business logic validation before database insertion.

#### 4.1.1 Device Existence Validation

**Purpose:** Ensure the device exists in the registry before processing metrics.

**Validation Logic:**

```python
# Worker checks device exists in database
device = db_session.query(Device).filter(
    Device.id == event.device_id,
    Device.project_id == event.project_id,
    Device.site_id == event.site_id
).first()

if not device:
    logger.warning(f"Device not found: {event.device_id}")
    error_counter.labels(error_type="device_not_found").inc()
    # Message is NACKed for potential retry or DLQ
```

**Error Handling:**

- **Device not found** → Log warning, increment error metric, NACK message
- **Device inactive** → Same handling as device not found
- **Device belongs to different project/site** → Validation failure

#### 4.1.2 Parameter Template Validation

**Purpose:** Ensure all metrics reference valid parameter templates.

**Validation Logic:**

```python
for metric in event.metrics:
    # Check parameter_key exists in parameter_templates table
    param_template = db_session.query(ParameterTemplate).filter(
        ParameterTemplate.key == metric.parameter_key
    ).first()
    
    if not param_template:
        logger.error(f"Parameter template not found: {metric.parameter_key}")
        error_counter.labels(error_type="parameter_not_found").inc()
        # Validation failure
```

**Why This Matters:**

- Foreign key constraint in `ingest_events` table requires valid `parameter_key`
- Missing parameter templates cause database insertion failures
- Parameter templates must be imported before data ingestion (see Module 6)

#### 4.1.3 Metric Value Range Validation

**Purpose:** Validate metric values against parameter template constraints.

**Validation Logic:**

```python
# If parameter template defines min/max values
if param_template.min_value is not None:
    if metric.value < param_template.min_value:
        logger.warning(f"Value below minimum: {metric.value} < {param_template.min_value}")
        # Optionally: reject, clamp, or flag as outlier

if param_template.max_value is not None:
    if metric.value > param_template.max_value:
        logger.warning(f"Value above maximum: {metric.value} > {param_template.max_value}")
        # Optionally: reject, clamp, or flag as outlier
```

**Validation Strategies:**

1. **Reject** - NACK message, don't insert (strict mode)
2. **Clamp** - Adjust value to min/max, insert with flag (permissive mode)
3. **Flag** - Insert with outlier flag, allow downstream filtering

**Configuration:**

Validation strategy can be configured per parameter template or globally.

#### 4.1.4 Timestamp Validation

**Purpose:** Ensure timestamps are valid and within acceptable ranges.

**Validation Checks:**

- **Format validation** - ISO 8601 format required
- **Range validation** - Timestamp not too far in past/future
- **Ordering validation** - `source_timestamp` should be reasonable

**Example:**

```python
from datetime import datetime, timedelta

source_ts = datetime.fromisoformat(event.source_timestamp)
now = datetime.utcnow()

# Reject timestamps more than 24 hours in the future
if source_ts > now + timedelta(hours=24):
    logger.warning(f"Future timestamp detected: {source_ts}")
    # Reject or flag

# Accept timestamps up to 90 days in the past (configurable)
if source_ts < now - timedelta(days=90):
    logger.warning(f"Very old timestamp: {source_ts}")
    # Reject or flag
```

---

## 5. Layer 3: Database Constraint Validation

### 5.1 PostgreSQL Constraint Validation

Even after business logic validation, database constraints provide the final layer of data integrity.

#### 5.1.1 Foreign Key Constraints

**Key Constraints:**

```sql
-- ingest_events table foreign keys
ALTER TABLE ingest_events
    ADD CONSTRAINT fk_device
        FOREIGN KEY (device_id) REFERENCES devices(id),
    ADD CONSTRAINT fk_parameter
        FOREIGN KEY (parameter_key) REFERENCES parameter_templates(key);
```

**Error Handling:**

```python
try:
    db_session.add(ingest_event)
    db_session.commit()
except IntegrityError as e:
    logger.warning(f"Integrity error for trace_id={trace_id}: {e}")
    error_counter.labels(error_type="integrity").inc()
    db_session.rollback()
    # Message is NACKed for retry
```

**Common Integrity Errors:**

- **Device not found** - `device_id` doesn't exist in `devices` table
- **Parameter not found** - `parameter_key` doesn't exist in `parameter_templates` table
- **Referential integrity** - Foreign key violation

#### 5.1.2 Unique Constraints

**Purpose:** Prevent duplicate event insertion.

**Example Constraint:**

```sql
-- Prevent duplicate events (if trace_id is unique)
CREATE UNIQUE INDEX idx_ingest_events_trace_id 
    ON ingest_events(trace_id) 
    WHERE trace_id IS NOT NULL;
```

**Error Handling:**

- Duplicate `trace_id` → IntegrityError, message NACKed
- Idempotency protection → Prevents duplicate processing

#### 5.1.3 Check Constraints

**Purpose:** Enforce value range constraints at database level.

**Example:**

```sql
-- Ensure metric value is within reasonable range (if applicable)
ALTER TABLE ingest_events
    ADD CONSTRAINT chk_value_range
        CHECK (value >= -999999 AND value <= 999999);
```

**Note:** Check constraints are typically not used for parameter-specific ranges (handled in Layer 2), but for global sanity checks.

#### 5.1.4 Not Null Constraints

**Purpose:** Ensure required fields are always present.

**Key Fields:**

- `device_id` - NOT NULL
- `parameter_key` - NOT NULL
- `value` - NOT NULL
- `timestamp` - NOT NULL

**Error Handling:**

- Missing required field → Database rejects insert
- Worker logs error and NACKs message

---

## 6. Error Types and Classification

### 6.1 Error Categories

Errors in NSReady are classified into categories for monitoring and handling:

| Error Type | Description | HTTP Status | Recovery Strategy |
|------------|-------------|-------------|-------------------|
| `invalid_format` | Invalid JSON or message format | 400 | Reject, no retry |
| `json_decode` | JSON parsing failure | 400 | Reject, no retry |
| `validation_error` | Schema validation failure | 400/422 | Reject, no retry |
| `device_not_found` | Device doesn't exist in registry | - | NACK, retry after config update |
| `parameter_not_found` | Parameter template missing | - | NACK, retry after template import |
| `integrity` | Database foreign key violation | - | NACK, retry after config fix |
| `database` | Database connection/query error | 500 | NACK, retry with backoff |
| `processing` | Unexpected processing error | 500 | NACK, retry with backoff |
| `timeout` | Operation timeout | 500 | NACK, retry |

### 6.2 Error Metrics

**Prometheus Metrics:**

```python
error_counter = Counter(
    'ingest_errors_total',
    'Total number of ingestion errors',
    ['error_type']
)
```

**Metric Labels:**

- `error_type` - One of the error categories above
- Example: `ingest_errors_total{error_type="device_not_found"}`

**Monitoring:**

- Track error rates by type
- Alert on high error rates
- Identify configuration issues (missing devices/parameters)

---

## 7. Error Recovery Mechanisms

### 7.1 Message Queue Recovery

**NATS JetStream Redelivery:**

- **Automatic redelivery** - Messages not ACKed are redelivered
- **Max redeliveries** - Configurable limit (default: 5)
- **Dead Letter Queue (DLQ)** - Failed messages after max redeliveries

**Recovery Flow:**

```
1. Worker processes message
   ↓
2. Validation fails or DB error
   ↓
3. Worker NACKs message (no ACK)
   ↓
4. NATS redelivers message after timeout
   ↓
5. Retry up to max_redeliveries
   ↓
6. If still failing → Move to DLQ
```

### 7.2 Configuration-Driven Recovery

**Scenario:** Device or parameter template missing

**Recovery Steps:**

1. **Identify error** - Monitor `ingest_errors_total{error_type="device_not_found"}`
2. **Fix configuration** - Import missing device via Module 5
3. **Automatic recovery** - Next message redelivery will succeed
4. **No manual intervention** - System self-heals after config fix

### 7.3 Database Transaction Recovery

**Transaction Safety:**

```python
try:
    # Batch insert events
    db_session.add_all(events)
    db_session.commit()
except Exception as e:
    # Rollback on any error
    db_session.rollback()
    logger.error(f"Transaction failed: {e}")
    # NACK all messages in batch
```

**Benefits:**

- **Atomicity** - All or nothing insertion
- **Consistency** - Database remains in valid state
- **Recovery** - Failed transactions don't corrupt data

---

## 8. Error Logging and Monitoring

### 8.1 Error Logging

**Log Levels:**

- **ERROR** - Critical failures requiring attention
- **WARNING** - Recoverable issues (missing device, validation warnings)
- **INFO** - Normal operation, validation passes

**Log Format:**

```python
logger.error(f"Error processing event trace_id={trace_id}: {e}", exc_info=True)
logger.warning(f"Device not found: {event.device_id}")
logger.info(f"Event validated successfully: trace_id={trace_id}")
```

### 8.2 Error Metrics

**Key Metrics:**

- `ingest_errors_total{error_type="..."}` - Total errors by type
- `ingest_counter` - Total successful ingestions
- `queue_depth_gauge` - Current queue depth

**Monitoring Queries:**

```promql
# Error rate
rate(ingest_errors_total[5m])

# Error rate by type
rate(ingest_errors_total{error_type="device_not_found"}[5m])

# Success rate
rate(ingest_counter[5m]) / (rate(ingest_counter[5m]) + rate(ingest_errors_total[5m]))
```

### 8.3 Alerting

**Recommended Alerts:**

1. **High Error Rate**
   - Condition: `rate(ingest_errors_total[5m]) > 10`
   - Action: Investigate error types and root causes

2. **Device Not Found Errors**
   - Condition: `rate(ingest_errors_total{error_type="device_not_found"}[5m]) > 5`
   - Action: Check device registry, import missing devices

3. **Parameter Not Found Errors**
   - Condition: `rate(ingest_errors_total{error_type="parameter_not_found"}[5m]) > 5`
   - Action: Check parameter templates, import missing templates

4. **Database Errors**
   - Condition: `rate(ingest_errors_total{error_type="database"}[5m]) > 1`
   - Action: Check database connectivity and health

---

## 9. Best Practices for Error Prevention

### 9.1 Pre-Ingestion Configuration

**Critical Steps (Before Data Ingestion):**

1. **Import Registry** (Module 5)
   - Ensure all devices exist in `devices` table
   - Verify device-project-site relationships

2. **Import Parameter Templates** (Module 6)
   - Ensure all expected parameters have templates
   - Verify parameter keys match device output

3. **Validate Configuration**
   - Run configuration validation scripts
   - Check for missing devices/parameters

### 9.2 API Integration Best Practices

**For Developers Integrating with NSReady API:**

1. **Validate Before Sending**
   - Validate UUIDs client-side
   - Ensure required fields are present
   - Validate timestamp format (ISO 8601)

2. **Handle Errors Gracefully**
   - Check HTTP status codes
   - Parse error messages
   - Implement retry logic for transient errors

3. **Use Trace IDs**
   - Include `trace_id` in events for tracking
   - Correlate errors with trace IDs

### 9.3 Monitoring and Proactive Management

**Regular Checks:**

1. **Monitor Error Metrics** - Daily review of error rates
2. **Review Error Logs** - Weekly analysis of error patterns
3. **Validate Configuration** - Monthly audit of device/parameter registry
4. **Test Error Scenarios** - Periodic testing of error handling

---

## 10. Troubleshooting Common Validation Issues

### 10.1 "Device Not Found" Errors

**Symptoms:**
- High `ingest_errors_total{error_type="device_not_found"}` rate
- Events rejected at worker layer

**Diagnosis:**

```bash
# Check if device exists
psql -d nsready -c "SELECT * FROM devices WHERE id = 'DEVICE_UUID';"

# Check device-project-site relationship
psql -d nsready -c "
    SELECT d.id, d.name, p.name as project, s.name as site
    FROM devices d
    JOIN projects p ON d.project_id = p.id
    JOIN sites s ON d.site_id = s.id
    WHERE d.id = 'DEVICE_UUID';
"
```

**Resolution:**

1. Import missing device via Module 5
2. Verify device-project-site hierarchy
3. Check device status (active/inactive)

### 10.2 "Parameter Not Found" Errors

**Symptoms:**
- High `ingest_errors_total{error_type="parameter_not_found"}` rate
- Events rejected at worker layer

**Diagnosis:**

```bash
# Check if parameter template exists
psql -d nsready -c "SELECT * FROM parameter_templates WHERE key = 'PARAMETER_KEY';"

# List all parameter templates
psql -d nsready -c "SELECT key, parameter_name FROM parameter_templates;"
```

**Resolution:**

1. Import missing parameter template via Module 6
2. Verify parameter key matches device output
3. Check parameter template is active

### 10.3 "Invalid UUID Format" Errors

**Symptoms:**
- HTTP 400 errors at API layer
- Error message: "device_id must be a valid UUID"

**Diagnosis:**

- Check event payload format
- Verify UUIDs are properly formatted

**Resolution:**

1. Ensure UUIDs are in standard format: `550e8400-e29b-41d4-a716-446655440000`
2. Validate UUIDs client-side before sending
3. Check for typos in device/project/site IDs

### 10.4 "Database Integrity Error" Errors

**Symptoms:**
- High `ingest_errors_total{error_type="integrity"}` rate
- Database constraint violations

**Diagnosis:**

```bash
# Check foreign key constraints
psql -d nsready -c "
    SELECT conname, conrelid::regclass, confrelid::regclass
    FROM pg_constraint
    WHERE contype = 'f';
"
```

**Resolution:**

1. Verify all foreign key relationships exist
2. Check for orphaned records
3. Ensure configuration is complete before ingestion

---

## 11. Error Handling Configuration

### 11.1 Worker Configuration

**Environment Variables:**

```bash
# Worker pool size
WORKER_POOL_SIZE=4

# Batch size
WORKER_BATCH_SIZE=50

# Max redeliveries
NATS_MAX_REDELIVERIES=5

# Error handling mode (strict/permissive)
ERROR_HANDLING_MODE=strict
```

### 11.2 Validation Modes

**Strict Mode:**
- Reject invalid values
- NACK messages on validation failure
- Require all validations to pass

**Permissive Mode:**
- Allow some validation failures with warnings
- Clamp values to min/max ranges
- Flag outliers but still insert

**Configuration:**

```python
# Global validation mode
VALIDATION_MODE = os.getenv("VALIDATION_MODE", "strict")

# Per-parameter validation override
parameter_template.validation_mode = "permissive"
```

---

## 12. Summary

### 12.1 Key Takeaways

1. **Multi-Layer Validation** - Validation occurs at API, worker, and database layers
2. **Fail Fast** - Invalid requests are rejected early to prevent queue pollution
3. **Graceful Recovery** - Automatic retry and DLQ mechanisms handle transient failures
4. **Comprehensive Monitoring** - Error metrics and logging provide visibility
5. **Configuration-Driven** - Most errors are resolved by fixing configuration

### 12.2 Related Modules

- **Module 0** - Introduction and Terminology
- **Module 2** - System Architecture and Data Flow
- **Module 5** - Configuration Import Manual
- **Module 6** - Parameter Template Manual
- **Module 8** - Ingestion Worker & Queue Processing (upcoming)
- **Module 11** - Testing Strategy & Test Suite Overview (upcoming)

### 12.3 Next Steps

After understanding validation and error handling:

1. **Configure System** - Import devices and parameter templates (Modules 5-6)
2. **Monitor Errors** - Set up error metrics and alerting
3. **Test Validation** - Verify validation rules work as expected
4. **Review Module 8** - Understand worker processing and queue management

---

**Module Created:** 2025-11-22  
**Last Updated:** 2025-11-22  
**Status:** Complete


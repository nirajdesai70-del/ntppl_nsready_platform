# Module 12 – API Developer Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/12_API_Developer_Manual.md`)*

---

## 1. Purpose of This Document

This module provides a comprehensive guide for developers integrating with the NSReady Data Collection Platform APIs. It covers:

- API overview and architecture
- Authentication and authorization
- All API endpoints with detailed specifications
- Request and response formats
- Error handling and status codes
- Integration examples and code samples
- Best practices and guidelines
- OpenAPI documentation access

This module is essential for:
- **Developers** integrating field devices or external systems
- **Frontend Developers** building dashboards or UIs
- **SCADA Engineers** integrating SCADA systems
- **System Integrators** connecting third-party systems
- **QA Engineers** testing API integrations

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 5 – Configuration Import Manual
- Module 7 – Data Validation & Error Handling

---

## 2. API Overview

### 2.1 API Services

The NSReady platform exposes two main API services:

1. **Collector Service API** (Port 8001)
   - Telemetry ingestion endpoints
   - Health and monitoring endpoints
   - Public-facing (no authentication required for ingestion)

2. **Admin Tool API** (Port 8000)
   - Configuration management endpoints
   - Registry and parameter template management
   - Protected (Bearer token authentication required)

### 2.2 Base URLs

**Development:**
- Collector Service: `http://localhost:8001`
- Admin Tool: `http://localhost:8000`

**Production:**
- Collector Service: `https://collector.your-domain.com`
- Admin Tool: `https://admin.your-domain.com`

### 2.3 API Versioning

- **Collector Service:** Uses `/v1` prefix for ingestion endpoints
- **Admin Tool:** Uses `/admin` prefix (no versioning yet)

**Versioning Strategy:**
- Current version: `v1`
- Future versions will use `/v2`, `/v3`, etc.
- Old versions will be maintained for backward compatibility

### 2.4 Content Types

All APIs use:
- **Request Content-Type:** `application/json`
- **Response Content-Type:** `application/json`
- **Character Encoding:** UTF-8

---

## 3. Authentication

### 3.1 Collector Service API

**No Authentication Required:**
- The Collector Service ingestion endpoint (`POST /v1/ingest`) is **public** and does not require authentication.
- This allows field devices and external systems to send telemetry data without managing credentials.

**Security Considerations:**
- In production, consider:
  - Network-level security (VPN, firewall rules)
  - Rate limiting
  - IP whitelisting
  - API key authentication (future enhancement)

### 3.2 Admin Tool API

**Bearer Token Authentication:**
- All Admin Tool endpoints require Bearer token authentication.
- Token is configured via environment variable: `ADMIN_BEARER_TOKEN`
- Default development token: `devtoken`

**Authentication Header:**
```http
Authorization: Bearer <token>
```

**Example:**
```bash
curl -H "Authorization: Bearer devtoken" \
     -H "Content-Type: application/json" \
     http://localhost:8000/admin/customers
```

**Error Response (401 Unauthorized):**
```json
{
  "detail": "Unauthorized"
}
```

### 3.3 Token Management

**Development:**
- Token set in `.env` file: `ADMIN_BEARER_TOKEN=devtoken`
- Token can be changed by updating environment variable

**Production:**
- Use strong, randomly generated tokens
- Store tokens securely (environment variables, secrets management)
- Rotate tokens periodically
- Use different tokens for different environments

---

## 4. Collector Service API

### 4.1 Base URL

```
http://localhost:8001
```

### 4.2 Endpoints

#### 4.2.1 POST /v1/ingest

**Purpose:** Ingest telemetry event from field devices or external systems.

**Authentication:** None required

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
      "attributes": {
        "unit": "V",
        "source": "meter_1"
      }
    },
    {
      "parameter_key": "current",
      "value": 10.2,
      "quality": 192,
      "attributes": {
        "unit": "A"
      }
    }
  ],
  "protocol": "GPRS",
  "source_timestamp": "2024-01-15T10:30:00Z",
  "config_version": "v1.2",
  "event_id": "device-001-20240115-103000",
  "metadata": {
    "firmware_version": "1.0.3",
    "signal_strength": -85
  }
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project_id` | string (UUID) | Yes | Project UUID |
| `site_id` | string (UUID) | Yes | Site UUID |
| `device_id` | string (UUID) | Yes | Device UUID |
| `metrics` | array | Yes | Array of metric objects (min 1) |
| `metrics[].parameter_key` | string | Yes | Parameter key (must exist in parameter templates) |
| `metrics[].value` | number | No | Metric value |
| `metrics[].quality` | integer | No | Quality code (0-255, default: 0) |
| `metrics[].attributes` | object | No | Additional attributes (key-value pairs) |
| `protocol` | string | Yes | Protocol used (e.g., "SMS", "GPRS", "HTTP") |
| `source_timestamp` | string (ISO 8601) | Yes | Timestamp when data was collected |
| `config_version` | string | No | Configuration version (e.g., "v1.2") |
| `event_id` | string | No | Event ID for idempotency |
| `metadata` | object | No | Additional metadata (key-value pairs) |

**Response (200 OK):**
```json
{
  "status": "queued",
  "trace_id": "550e8400-e29b-41d4-a716-446655440003"
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Status of ingestion ("queued") |
| `trace_id` | string (UUID) | Unique trace ID for tracking |

**Error Responses:**

**400 Bad Request** - Validation Error:
```json
{
  "detail": "project_id is required"
}
```

**500 Internal Server Error:**
```json
{
  "detail": "Internal server error: <error message>"
}
```

**Example (cURL):**
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
    "protocol": "GPRS",
    "source_timestamp": "2024-01-15T10:30:00Z"
  }'
```

**Example (Python):**
```python
import requests
from datetime import datetime

url = "http://localhost:8001/v1/ingest"
payload = {
    "project_id": "550e8400-e29b-41d4-a716-446655440000",
    "site_id": "550e8400-e29b-41d4-a716-446655440001",
    "device_id": "550e8400-e29b-41d4-a716-446655440002",
    "metrics": [
        {
            "parameter_key": "voltage",
            "value": 230.5,
            "quality": 192,
            "attributes": {"unit": "V"}
        }
    ],
    "protocol": "GPRS",
    "source_timestamp": datetime.utcnow().isoformat() + "Z"
}

response = requests.post(url, json=payload)
if response.status_code == 200:
    result = response.json()
    print(f"Event queued: {result['trace_id']}")
else:
    print(f"Error: {response.status_code} - {response.text}")
```

**Example (JavaScript/Node.js):**
```javascript
const axios = require('axios');

const url = 'http://localhost:8001/v1/ingest';
const payload = {
  project_id: '550e8400-e29b-41d4-a716-446655440000',
  site_id: '550e8400-e29b-41d4-a716-446655440001',
  device_id: '550e8400-e29b-41d4-a716-446655440002',
  metrics: [
    {
      parameter_key: 'voltage',
      value: 230.5,
      quality: 192,
      attributes: { unit: 'V' }
    }
  ],
  protocol: 'GPRS',
  source_timestamp: new Date().toISOString()
};

axios.post(url, payload)
  .then(response => {
    console.log(`Event queued: ${response.data.trace_id}`);
  })
  .catch(error => {
    console.error(`Error: ${error.response.status} - ${error.response.data.detail}`);
  });
```

#### 4.2.2 GET /v1/health

**Purpose:** Health check endpoint for monitoring and load balancers.

**Authentication:** None required

**Response (200 OK):**
```json
{
  "service": "ok",
  "queue_depth": 0,
  "db": "connected"
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `service` | string | Service status ("ok" or "error") |
| `queue_depth` | integer | Current NATS queue depth |
| `db` | string | Database connection status ("connected" or "disconnected") |

**Example:**
```bash
curl http://localhost:8001/v1/health
```

#### 4.2.3 GET /metrics

**Purpose:** Prometheus metrics endpoint for monitoring.

**Authentication:** None required

**Response:** Prometheus metrics format

**Example Metrics:**
```
# HELP ingest_events_total Total events ingested
# TYPE ingest_events_total counter
ingest_events_total{status="queued"} 1234

# HELP ingest_errors_total Total errors
# TYPE ingest_errors_total counter
ingest_errors_total{error_type="validation"} 5

# HELP ingest_queue_depth Current queue depth
# TYPE ingest_queue_depth gauge
ingest_queue_depth 42

# HELP ingest_rate_per_second Current ingestion rate
# TYPE ingest_rate_per_second gauge
ingest_rate_per_second 10.5
```

**Example:**
```bash
curl http://localhost:8001/metrics
```

---

## 5. Admin Tool API

### 5.1 Base URL

```
http://localhost:8000
```

### 5.2 Base Path

All Admin Tool endpoints are prefixed with `/admin`.

### 5.3 Endpoints

#### 5.3.1 Customers

**Base Path:** `/admin/customers`

##### GET /admin/customers

**Purpose:** List all customers.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Acme Corporation",
    "metadata": {
      "industry": "Manufacturing",
      "region": "North America"
    },
    "created_at": "2024-01-15T10:00:00Z"
  }
]
```

**Example:**
```bash
curl -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/customers
```

##### POST /admin/customers

**Purpose:** Create a new customer.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "name": "Acme Corporation",
  "metadata": {
    "industry": "Manufacturing",
    "region": "North America"
  }
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Customer name |
| `metadata` | object | No | Additional metadata (key-value pairs) |

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Acme Corporation",
  "metadata": {
    "industry": "Manufacturing",
    "region": "North America"
  },
  "created_at": "2024-01-15T10:00:00Z"
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/admin/customers \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Corporation",
    "metadata": {"industry": "Manufacturing"}
  }'
```

##### GET /admin/customers/{customer_id}

**Purpose:** Get a specific customer by ID.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Acme Corporation",
  "metadata": {},
  "created_at": "2024-01-15T10:00:00Z"
}
```

**Error Response (404 Not Found):**
```json
{
  "detail": "Customer not found"
}
```

##### PUT /admin/customers/{customer_id}

**Purpose:** Update an existing customer.

**Authentication:** Bearer token required

**Request Body:** Same as POST /admin/customers

**Response (200 OK):** Same as GET /admin/customers/{customer_id}

##### DELETE /admin/customers/{customer_id}

**Purpose:** Delete a customer.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "status": "ok"
}
```

#### 5.3.2 Projects

**Base Path:** `/admin/projects`

##### GET /admin/projects

**Purpose:** List all projects.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "customer_id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Project Alpha",
    "description": "Main project for Acme Corporation",
    "created_at": "2024-01-15T10:00:00Z"
  }
]
```

##### POST /admin/projects

**Purpose:** Create a new project.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "customer_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Project Alpha",
  "description": "Main project for Acme Corporation"
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `customer_id` | string (UUID) | Yes | Customer UUID |
| `name` | string | Yes | Project name |
| `description` | string | No | Project description |

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "customer_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Project Alpha",
  "description": "Main project for Acme Corporation",
  "created_at": "2024-01-15T10:00:00Z"
}
```

##### GET /admin/projects/{project_id}

**Purpose:** Get a specific project by ID.

**Authentication:** Bearer token required

**Response (200 OK):** Same format as POST response

##### PUT /admin/projects/{project_id}

**Purpose:** Update an existing project.

**Authentication:** Bearer token required

**Request Body:** Same as POST /admin/projects

**Response (200 OK):** Same format as GET response

##### DELETE /admin/projects/{project_id}

**Purpose:** Delete a project.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "status": "ok"
}
```

#### 5.3.3 Sites

**Base Path:** `/admin/sites`

##### GET /admin/sites

**Purpose:** List all sites.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "project_id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "Site A",
    "location": {
      "latitude": 40.7128,
      "longitude": -74.0060,
      "address": "123 Main St, New York, NY"
    },
    "created_at": "2024-01-15T10:00:00Z"
  }
]
```

##### POST /admin/sites

**Purpose:** Create a new site.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440001",
  "name": "Site A",
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060,
    "address": "123 Main St, New York, NY"
  }
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project_id` | string (UUID) | Yes | Project UUID |
| `name` | string | Yes | Site name |
| `location` | object | No | Location metadata (key-value pairs) |

**Response (200 OK):** Same format as GET response

##### GET /admin/sites/{site_id}

**Purpose:** Get a specific site by ID.

**Authentication:** Bearer token required

**Response (200 OK):** Same format as GET /admin/sites

##### PUT /admin/sites/{site_id}

**Purpose:** Update an existing site.

**Authentication:** Bearer token required

**Request Body:** Same as POST /admin/sites

**Response (200 OK):** Same format as GET response

##### DELETE /admin/sites/{site_id}

**Purpose:** Delete a site.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "status": "ok"
}
```

#### 5.3.4 Devices

**Base Path:** `/admin/devices`

##### GET /admin/devices

**Purpose:** List all devices.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440003",
    "site_id": "550e8400-e29b-41d4-a716-446655440002",
    "name": "Device 001",
    "device_type": "data_logger",
    "external_id": "DL-001",
    "status": "active",
    "created_at": "2024-01-15T10:00:00Z"
  }
]
```

##### POST /admin/devices

**Purpose:** Create a new device.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "site_id": "550e8400-e29b-41d4-a716-446655440002",
  "name": "Device 001",
  "device_type": "data_logger",
  "external_id": "DL-001",
  "status": "active"
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `site_id` | string (UUID) | Yes | Site UUID |
| `name` | string | Yes | Device name |
| `device_type` | string | Yes | Device type (e.g., "data_logger", "controller") |
| `external_id` | string | No | External device identifier |
| `status` | string | No | Device status (default: "active") |

**Response (200 OK):** Same format as GET response

##### GET /admin/devices/{device_id}

**Purpose:** Get a specific device by ID.

**Authentication:** Bearer token required

**Response (200 OK):** Same format as GET /admin/devices

##### PUT /admin/devices/{device_id}

**Purpose:** Update an existing device.

**Authentication:** Bearer token required

**Request Body:** Same as POST /admin/devices

**Response (200 OK):** Same format as GET response

##### DELETE /admin/devices/{device_id}

**Purpose:** Delete a device.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "status": "ok"
}
```

#### 5.3.5 Parameter Templates

**Base Path:** `/admin/parameter_templates`

##### GET /admin/parameter_templates

**Purpose:** List all parameter templates.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440004",
    "key": "voltage",
    "name": "Voltage",
    "unit": "V",
    "metadata": {
      "min_value": 0,
      "max_value": 500
    },
    "created_at": "2024-01-15T10:00:00Z"
  }
]
```

##### POST /admin/parameter_templates

**Purpose:** Create a new parameter template.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "key": "voltage",
  "name": "Voltage",
  "unit": "V",
  "metadata": {
    "min_value": 0,
    "max_value": 500
  }
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | Yes | Parameter key (unique identifier) |
| `name` | string | Yes | Parameter display name |
| `unit` | string | No | Engineering unit (e.g., "V", "A", "kW") |
| `metadata` | object | No | Additional metadata (key-value pairs) |

**Response (200 OK):** Same format as GET response

##### GET /admin/parameter_templates/{template_id}

**Purpose:** Get a specific parameter template by ID.

**Authentication:** Bearer token required

**Response (200 OK):** Same format as GET /admin/parameter_templates

##### PUT /admin/parameter_templates/{template_id}

**Purpose:** Update an existing parameter template.

**Authentication:** Bearer token required

**Request Body:** Same as POST /admin/parameter_templates

**Response (200 OK):** Same format as GET response

##### DELETE /admin/parameter_templates/{template_id}

**Purpose:** Delete a parameter template.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "status": "ok"
}
```

#### 5.3.6 Registry Versions

**Base Path:** `/admin/projects/{project_id}/versions`

##### POST /admin/projects/{project_id}/versions/publish

**Purpose:** Publish a new registry version for a project.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "author": "admin@example.com",
  "diff_json": {
    "note": "Initial configuration",
    "changes": ["Added 5 new devices"]
  }
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `author` | string | Yes | Author identifier (email, username) |
| `diff_json` | object | No | Change description and metadata |

**Response (200 OK):**
```json
{
  "status": "ok",
  "config_version": "v1"
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Status ("ok") |
| `config_version` | string | Version identifier (e.g., "v1", "v2") |

**Example:**
```bash
curl -X POST http://localhost:8000/admin/projects/550e8400-e29b-41d4-a716-446655440001/versions/publish \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "author": "admin@example.com",
    "diff_json": {"note": "Initial configuration"}
  }'
```

##### GET /admin/projects/{project_id}/versions/latest

**Purpose:** Get the latest registry version for a project.

**Authentication:** Bearer token required

**Response (200 OK):**
```json
{
  "config_version": "v1",
  "config": {
    "customers": [...],
    "projects": [...],
    "sites": [...],
    "devices": [...],
    "parameter_templates": [...]
  }
}
```

**Error Response (404 Not Found):**
```json
{
  "detail": "No versions"
}
```

---

## 6. Error Handling

### 6.1 HTTP Status Codes

| Status Code | Meaning | When Used |
|-------------|---------|-----------|
| 200 | OK | Successful GET, PUT, DELETE |
| 201 | Created | Successful POST (future) |
| 400 | Bad Request | Validation error, invalid request format |
| 401 | Unauthorized | Missing or invalid authentication token |
| 404 | Not Found | Resource not found |
| 500 | Internal Server Error | Server error, unexpected failure |

### 6.2 Error Response Format

All error responses follow this format:

```json
{
  "detail": "Error message description"
}
```

**Example (400 Bad Request):**
```json
{
  "detail": "project_id is required"
}
```

**Example (404 Not Found):**
```json
{
  "detail": "Customer not found"
}
```

**Example (500 Internal Server Error):**
```json
{
  "detail": "Internal server error: Database connection failed"
}
```

### 6.3 Validation Errors

Validation errors occur when:
- Required fields are missing
- Field types are incorrect
- UUIDs are invalid
- Values are out of range
- Arrays are empty when minimum length is required

**Example:**
```json
{
  "detail": "device_id must be a valid UUID: invalid-uuid"
}
```

### 6.4 Error Handling Best Practices

1. **Check Status Codes** - Always check HTTP status codes before processing responses
2. **Handle Errors Gracefully** - Implement retry logic for transient errors (5xx)
3. **Log Errors** - Log error responses for debugging
4. **User-Friendly Messages** - Display user-friendly error messages to end users
5. **Retry Logic** - Implement exponential backoff for retries

**Example (Python with retry):**
```python
import requests
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session_with_retry():
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[500, 502, 503, 504]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session

session = create_session_with_retry()
response = session.post(url, json=payload)
if response.status_code != 200:
    print(f"Error: {response.status_code} - {response.json()['detail']}")
```

---

## 7. Rate Limiting and Best Practices

### 7.1 Rate Limiting

**Current Status:** Rate limiting is not implemented in the current version.

**Future Enhancements:**
- Per-IP rate limiting
- Per-token rate limiting
- Rate limit headers in responses

### 7.2 Best Practices

#### 7.2.1 Request Optimization

1. **Batch Operations** - When possible, batch multiple operations
2. **Use Appropriate HTTP Methods** - Use GET for reads, POST for creates, PUT for updates, DELETE for deletes
3. **Minimize Payload Size** - Only include required fields in requests
4. **Use Compression** - Enable gzip compression for large payloads (future)

#### 7.2.2 Error Handling

1. **Implement Retry Logic** - Retry transient errors (5xx) with exponential backoff
2. **Handle Validation Errors** - Display clear error messages for validation failures (4xx)
3. **Log Errors** - Log all errors for debugging and monitoring

#### 7.2.3 Security

1. **Use HTTPS in Production** - Always use HTTPS for production APIs
2. **Protect Tokens** - Store authentication tokens securely
3. **Validate Input** - Validate all input data before sending requests
4. **Sanitize Output** - Sanitize API responses before displaying to users

#### 7.2.4 Performance

1. **Connection Pooling** - Reuse HTTP connections when possible
2. **Async Requests** - Use async/await for concurrent requests
3. **Caching** - Cache frequently accessed data (configuration, parameter templates)
4. **Monitor Performance** - Monitor API response times and error rates

---

## 8. Integration Examples

### 8.1 Complete Integration Workflow

**Step 1: Create Customer**
```bash
curl -X POST http://localhost:8000/admin/customers \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{"name": "Acme Corporation"}'
```

**Step 2: Create Project**
```bash
curl -X POST http://localhost:8000/admin/projects \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "<customer_id_from_step1>",
    "name": "Project Alpha",
    "description": "Main project"
  }'
```

**Step 3: Create Site**
```bash
curl -X POST http://localhost:8000/admin/sites \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "<project_id_from_step2>",
    "name": "Site A"
  }'
```

**Step 4: Create Device**
```bash
curl -X POST http://localhost:8000/admin/devices \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "site_id": "<site_id_from_step3>",
    "name": "Device 001",
    "device_type": "data_logger"
  }'
```

**Step 5: Create Parameter Template**
```bash
curl -X POST http://localhost:8000/admin/parameter_templates \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "voltage",
    "name": "Voltage",
    "unit": "V"
  }'
```

**Step 6: Publish Registry Version**
```bash
curl -X POST http://localhost:8000/admin/projects/<project_id>/versions/publish \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "author": "admin@example.com",
    "diff_json": {"note": "Initial configuration"}
  }'
```

**Step 7: Ingest Telemetry Data**
```bash
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "<project_id>",
    "site_id": "<site_id>",
    "device_id": "<device_id>",
    "metrics": [
      {
        "parameter_key": "voltage",
        "value": 230.5,
        "quality": 192
      }
    ],
    "protocol": "GPRS",
    "source_timestamp": "2024-01-15T10:30:00Z"
  }'
```

### 8.2 Python SDK Example

```python
import requests
from datetime import datetime
from typing import Dict, List, Optional

class NSReadyClient:
    def __init__(self, admin_base_url: str, collector_base_url: str, token: str):
        self.admin_base_url = admin_base_url
        self.collector_base_url = collector_base_url
        self.token = token
        self.admin_headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        self.collector_headers = {
            "Content-Type": "application/json"
        }
    
    def create_customer(self, name: str, metadata: Optional[Dict] = None) -> Dict:
        """Create a customer."""
        url = f"{self.admin_base_url}/admin/customers"
        payload = {"name": name, "metadata": metadata or {}}
        response = requests.post(url, json=payload, headers=self.admin_headers)
        response.raise_for_status()
        return response.json()
    
    def create_project(self, customer_id: str, name: str, description: Optional[str] = None) -> Dict:
        """Create a project."""
        url = f"{self.admin_base_url}/admin/projects"
        payload = {
            "customer_id": customer_id,
            "name": name,
            "description": description
        }
        response = requests.post(url, json=payload, headers=self.admin_headers)
        response.raise_for_status()
        return response.json()
    
    def ingest_event(self, project_id: str, site_id: str, device_id: str,
                     metrics: List[Dict], protocol: str,
                     source_timestamp: Optional[str] = None) -> Dict:
        """Ingest a telemetry event."""
        url = f"{self.collector_base_url}/v1/ingest"
        if source_timestamp is None:
            source_timestamp = datetime.utcnow().isoformat() + "Z"
        
        payload = {
            "project_id": project_id,
            "site_id": site_id,
            "device_id": device_id,
            "metrics": metrics,
            "protocol": protocol,
            "source_timestamp": source_timestamp
        }
        response = requests.post(url, json=payload, headers=self.collector_headers)
        response.raise_for_status()
        return response.json()

# Usage
client = NSReadyClient(
    admin_base_url="http://localhost:8000",
    collector_base_url="http://localhost:8001",
    token="devtoken"
)

# Create customer
customer = client.create_customer("Acme Corporation")
print(f"Created customer: {customer['id']}")

# Create project
project = client.create_project(
    customer_id=customer['id'],
    name="Project Alpha"
)
print(f"Created project: {project['id']}")

# Ingest event
result = client.ingest_event(
    project_id=project['id'],
    site_id="<site_id>",
    device_id="<device_id>",
    metrics=[{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
    protocol="GPRS"
)
print(f"Event queued: {result['trace_id']}")
```

---

## 9. OpenAPI Documentation

### 9.1 Interactive API Documentation

Both services provide interactive OpenAPI (Swagger) documentation:

**Admin Tool:**
- URL: `http://localhost:8000/docs`
- Alternative (ReDoc): `http://localhost:8000/redoc`

**Collector Service:**
- URL: `http://localhost:8001/docs`
- Alternative (ReDoc): `http://localhost:8001/redoc`

### 9.2 OpenAPI Schema

OpenAPI schemas are available at:
- Admin Tool: `http://localhost:8000/openapi.json`
- Collector Service: `http://localhost:8001/openapi.json`

These schemas can be used to:
- Generate client SDKs
- Import into API testing tools (Postman, Insomnia)
- Generate API documentation
- Validate API requests/responses

---

## 10. Testing and Debugging

### 10.1 Testing Tools

**Recommended Tools:**
- **cURL** - Command-line HTTP client
- **Postman** - API testing and documentation
- **Insomnia** - REST API client
- **HTTPie** - User-friendly HTTP client
- **Python requests** - Python HTTP library
- **JavaScript axios** - JavaScript HTTP library

### 10.2 Debugging Tips

1. **Check Health Endpoints** - Verify services are running: `GET /v1/health`
2. **Verify Authentication** - Ensure Bearer token is correct for Admin Tool
3. **Validate Request Format** - Check JSON syntax and required fields
4. **Check Logs** - Review service logs for error details
5. **Use OpenAPI Docs** - Use interactive docs to test endpoints
6. **Test with cURL** - Use cURL for quick testing and debugging

### 10.3 Common Issues

**Issue: 401 Unauthorized**
- **Cause:** Missing or invalid Bearer token
- **Solution:** Check `Authorization` header format: `Bearer <token>`

**Issue: 400 Bad Request - "project_id is required"**
- **Cause:** Missing required field in request
- **Solution:** Ensure all required fields are included in request body

**Issue: 400 Bad Request - "device_id must be a valid UUID"**
- **Cause:** Invalid UUID format
- **Solution:** Ensure UUIDs are in correct format: `550e8400-e29b-41d4-a716-446655440000`

**Issue: 404 Not Found**
- **Cause:** Resource doesn't exist
- **Solution:** Verify resource ID is correct and resource exists

---

## 11. Future Enhancements

### 11.1 Planned Features

- **API Key Authentication** - Alternative authentication method for Collector Service
- **Rate Limiting** - Per-IP and per-token rate limiting
- **Webhooks** - Event notifications via webhooks
- **GraphQL API** - Alternative query interface
- **Bulk Operations** - Batch create/update/delete operations
- **Filtering and Pagination** - Advanced query capabilities for list endpoints
- **API Versioning** - Explicit versioning strategy for Admin Tool
- **SDK Libraries** - Official SDKs for Python, JavaScript, Go

### 11.2 API Evolution

- **Backward Compatibility** - Old API versions will be maintained
- **Deprecation Policy** - Deprecated endpoints will be announced 6 months in advance
- **Version Migration** - Migration guides will be provided for version upgrades

---

## 12. Summary

This module provides a comprehensive guide to the NSReady Data Collection Platform APIs.

**Key Takeaways:**
- Two API services: Collector Service (ingestion) and Admin Tool (configuration)
- Bearer token authentication for Admin Tool
- RESTful API design with JSON request/response format
- Comprehensive error handling with standard HTTP status codes
- Interactive OpenAPI documentation available

**Next Steps:**
- Review OpenAPI documentation at `/docs` endpoints
- Set up authentication tokens for Admin Tool
- Test API endpoints using provided examples
- Integrate APIs into your applications

**Related Modules:**
- Module 5 – Configuration Import Manual (configuration setup)
- Module 7 – Data Validation & Error Handling (validation rules)
- Module 8 – Ingestion Worker & Queue Processing (async processing)
- Module 11 – Testing Strategy & Test Suite Overview (API testing)

---

**Document Version:** 1.0  
**Last Updated:** 2024-01-15  
**Author:** NSReady Platform Team


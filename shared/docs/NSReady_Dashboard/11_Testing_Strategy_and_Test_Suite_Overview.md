# Module 11 – Testing Strategy & Test Suite Overview

_NSReady Data Collection Platform_

*(Suggested path: `docs/11_Testing_Strategy_and_Test_Suite_Overview.md`)*

---

## 1. Purpose of This Document

This module provides a comprehensive guide to testing strategies and test suite organization for the NSReady Data Collection Platform. It covers:

- Testing philosophy and principles
- Test suite organization and structure
- Unit, integration, and end-to-end testing approaches
- Regression testing strategy
- Performance and load testing
- Resilience and fault tolerance testing
- Test data management
- Test execution and automation
- CI/CD integration
- Best practices and guidelines

This module is essential for:
- **Developers** writing and maintaining tests
- **QA Engineers** designing test strategies
- **DevOps Engineers** setting up test automation
- **Team Leads** ensuring code quality and reliability
- **Operators** understanding system validation

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 7 – Data Validation & Error Handling
- Module 8 – Ingestion Worker & Queue Processing

---

## 2. Testing Philosophy

### 2.1 Core Principles

The NSReady platform follows a **multi-layered testing strategy** that ensures reliability, performance, and resilience across all system components.

**Key Principles:**

1. **Defense in Depth** - Testing at multiple layers (unit, integration, system, end-to-end)
2. **Fail Fast** - Catch errors early in the development cycle
3. **Automation First** - Automated tests run on every change
4. **Real-World Scenarios** - Tests mirror production workloads and failure modes
5. **Performance Awareness** - Performance tests validate scalability requirements
6. **Resilience Validation** - Tests verify system behavior under failure conditions

### 2.2 Testing Pyramid

```
                    ┌─────────────┐
                    │   E2E Tests │  (Few, Critical Paths)
                    │  (System)   │
                    └──────┬──────┘
                           │
                ┌──────────┴──────────┐
                │  Integration Tests │  (Moderate, Key Flows)
                │   (Components)     │
                └──────────┬──────────┘
                           │
            ┌──────────────┴──────────────┐
            │      Unit Tests             │  (Many, Fast, Isolated)
            │   (Functions, Classes)      │
            └────────────────────────────┘
```

**Distribution:**
- **Unit Tests** (70%) - Fast, isolated, test individual functions/classes
- **Integration Tests** (20%) - Test component interactions (API + DB, Worker + NATS)
- **End-to-End Tests** (10%) - Test complete workflows (ingestion → queue → storage → SCADA)

---

## 3. Test Suite Organization

### 3.1 Directory Structure

The test suite is organized into three main categories:

```
tests/
├── regression/          # Regression test suite
│   ├── api/            # API endpoint tests
│   ├── worker/         # Worker processing tests
│   ├── validation/     # Data validation tests
│   └── integration/    # Cross-component tests
│
├── performance/         # Performance and load tests
│   ├── load/           # Load testing scenarios
│   ├── stress/         # Stress testing (beyond capacity)
│   ├── throughput/     # Throughput measurement
│   └── reports/        # Performance test reports
│
└── resilience/          # Resilience and fault tolerance tests
    ├── failure/        # Component failure scenarios
    ├── recovery/       # Recovery and retry tests
    ├── queue/          # Queue behavior under load
    └── network/        # Network partition scenarios
```

### 3.2 Test Naming Conventions

**Unit Tests:**
- Pattern: `test_<function_name>_<scenario>.py`
- Example: `test_validate_event_schema_valid.py`, `test_validate_event_schema_missing_field.py`

**Integration Tests:**
- Pattern: `test_<component>_<component>_<scenario>.py`
- Example: `test_collector_nats_publish.py`, `test_worker_db_insert.py`

**End-to-End Tests:**
- Pattern: `test_e2e_<workflow>_<scenario>.py`
- Example: `test_e2e_ingestion_to_scada.py`, `test_e2e_config_import_to_ingestion.py`

**Performance Tests:**
- Pattern: `test_perf_<metric>_<scenario>.py`
- Example: `test_perf_throughput_1000_events.py`, `test_perf_latency_p95.py`

**Resilience Tests:**
- Pattern: `test_resilience_<failure_mode>_<recovery>.py`
- Example: `test_resilience_db_connection_loss_recovery.py`, `test_resilience_nats_redelivery.py`

---

## 4. Unit Testing

### 4.1 Scope

Unit tests validate individual functions, classes, and methods in isolation.

**What to Test:**
- Data validation functions (schema validation, field checks)
- Business logic (device mapping, parameter resolution)
- Utility functions (timestamp parsing, UUID validation)
- Error handling (exception paths, edge cases)
- Data transformations (normalization, formatting)

**What NOT to Test:**
- External dependencies (database, NATS, HTTP clients)
- Framework code (FastAPI, Pydantic internals)
- Third-party libraries

### 4.2 Example Unit Test Structure

```python
# tests/regression/validation/test_event_validation.py

import pytest
from collector_service.api.models import NormalizedEvent
from collector_service.core.validation import validate_event_schema

def test_validate_event_schema_valid():
    """Test validation with valid event schema."""
    event_data = {
        "project_id": "550e8400-e29b-41d4-a716-446655440000",
        "site_id": "550e8400-e29b-41d4-a716-446655440001",
        "device_id": "550e8400-e29b-41d4-a716-446655440002",
        "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
        "protocol": "GPRS",
        "source_timestamp": "2024-01-15T10:30:00Z"
    }
    
    result = validate_event_schema(event_data)
    assert result.is_valid is True
    assert result.errors == []

def test_validate_event_schema_missing_project_id():
    """Test validation fails when project_id is missing."""
    event_data = {
        "site_id": "550e8400-e29b-41d4-a716-446655440001",
        "device_id": "550e8400-e29b-41d4-a716-446655440002",
        "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
        "protocol": "GPRS",
        "source_timestamp": "2024-01-15T10:30:00Z"
    }
    
    result = validate_event_schema(event_data)
    assert result.is_valid is False
    assert "project_id" in result.errors[0]

def test_validate_event_schema_invalid_uuid():
    """Test validation fails with invalid UUID format."""
    event_data = {
        "project_id": "invalid-uuid",
        "site_id": "550e8400-e29b-41d4-a716-446655440001",
        "device_id": "550e8400-e29b-41d4-a716-446655440002",
        "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
        "protocol": "GPRS",
        "source_timestamp": "2024-01-15T10:30:00Z"
    }
    
    result = validate_event_schema(event_data)
    assert result.is_valid is False
    assert "project_id" in result.errors[0].lower()
```

### 4.3 Unit Test Best Practices

1. **Isolation** - Each test should be independent and not rely on other tests
2. **Fast Execution** - Unit tests should run in milliseconds
3. **Clear Assertions** - Use descriptive assertion messages
4. **Edge Cases** - Test boundary conditions, null values, empty collections
5. **Mock External Dependencies** - Use mocks for database, NATS, HTTP calls
6. **Test Coverage** - Aim for >80% code coverage on business logic

---

## 5. Integration Testing

### 5.1 Scope

Integration tests validate interactions between components (API + Database, Worker + NATS, API + Worker).

**What to Test:**
- API endpoints with real database connections
- Worker processing with real NATS queue
- Database migrations and schema changes
- Cross-service communication (admin_tool ↔ collector_service)
- Data flow through multiple components

### 5.2 Test Environment Setup

Integration tests require a **test environment** with:
- Test database (PostgreSQL with TimescaleDB)
- Test NATS instance
- Test containers (Docker Compose test stack)

**Test Database:**
- Separate database: `nsready_test`
- Automatic cleanup between tests (transaction rollback or truncate)
- Test data fixtures for consistent scenarios

**Test NATS:**
- Test stream: `INGRESS_TEST`
- Test consumer: `worker_test`
- Automatic cleanup of messages after tests

### 5.3 Example Integration Test

```python
# tests/regression/integration/test_collector_worker_db.py

import pytest
import asyncio
from httpx import AsyncClient
from collector_service.app import app
from collector_service.core.db import get_session
from sqlalchemy import select
from models import IngestEvent

@pytest.mark.asyncio
async def test_ingestion_flow_end_to_end():
    """Test complete ingestion flow: API → NATS → Worker → DB."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # 1. Send event to API
        event = {
            "project_id": "550e8400-e29b-41d4-a716-446655440000",
            "site_id": "550e8400-e29b-41d4-a716-446655440001",
            "device_id": "550e8400-e29b-41d4-a716-446655440002",
            "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
            "protocol": "GPRS",
            "source_timestamp": "2024-01-15T10:30:00Z"
        }
        
        response = await client.post("/v1/ingest", json=event)
        assert response.status_code == 200
        trace_id = response.json()["trace_id"]
        
        # 2. Wait for worker to process (with timeout)
        await asyncio.sleep(2)  # Allow worker to consume and process
        
        # 3. Verify data in database
        async with get_session() as session:
            result = await session.execute(
                select(IngestEvent).where(IngestEvent.trace_id == trace_id)
            )
            stored_event = result.scalar_one_or_none()
            
            assert stored_event is not None
            assert stored_event.device_id == event["device_id"]
            assert stored_event.project_id == event["project_id"]
            assert len(stored_event.metrics) == 1
            assert stored_event.metrics[0]["parameter_key"] == "voltage"
            assert stored_event.metrics[0]["value"] == 230.5
```

### 5.4 Integration Test Best Practices

1. **Test Containers** - Use Docker Compose for consistent test environment
2. **Test Data Fixtures** - Pre-populate test data (customers, projects, devices)
3. **Cleanup** - Always clean up test data after tests
4. **Timeouts** - Use reasonable timeouts for async operations
5. **Idempotency** - Tests should be repeatable and not depend on execution order

---

## 6. API Testing

### 6.1 Scope

API tests validate REST endpoints, request/response handling, authentication, and error responses.

**Endpoints to Test:**
- **Collector Service:**
  - `POST /v1/ingest` - Event ingestion
  - `GET /v1/health` - Health check
  - `GET /metrics` - Prometheus metrics
- **Admin Tool:**
  - `POST /admin/customers` - Create customer
  - `POST /admin/projects` - Create project
  - `POST /admin/sites` - Create site
  - `POST /admin/devices` - Create device
  - `POST /admin/projects/{id}/versions/publish` - Publish registry version
  - `GET /admin/projects/{id}/versions/latest` - Get latest version

### 6.2 API Test Categories

**Positive Tests:**
- Valid requests return expected responses
- Status codes are correct (200, 201, 204)
- Response schemas match expected format
- Headers are set correctly

**Negative Tests:**
- Invalid requests return appropriate error codes (400, 401, 404, 500)
- Error messages are descriptive and actionable
- Validation errors list all invalid fields
- Authentication failures are handled correctly

**Edge Cases:**
- Empty request bodies
- Missing required fields
- Invalid data types
- Boundary values (max string length, max array size)
- Special characters and encoding

### 6.3 Example API Test

```python
# tests/regression/api/test_collector_ingest_api.py

import pytest
from httpx import AsyncClient
from collector_service.app import app

@pytest.mark.asyncio
async def test_ingest_valid_event():
    """Test successful event ingestion."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        event = {
            "project_id": "550e8400-e29b-41d4-a716-446655440000",
            "site_id": "550e8400-e29b-41d4-a716-446655440001",
            "device_id": "550e8400-e29b-41d4-a716-446655440002",
            "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
            "protocol": "GPRS",
            "source_timestamp": "2024-01-15T10:30:00Z"
        }
        
        response = await client.post("/v1/ingest", json=event)
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "queued"
        assert "trace_id" in data
        assert len(data["trace_id"]) == 36  # UUID format

@pytest.mark.asyncio
async def test_ingest_missing_project_id():
    """Test ingestion fails when project_id is missing."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        event = {
            "site_id": "550e8400-e29b-41d4-a716-446655440001",
            "device_id": "550e8400-e29b-41d4-a716-446655440002",
            "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
            "protocol": "GPRS",
            "source_timestamp": "2024-01-15T10:30:00Z"
        }
        
        response = await client.post("/v1/ingest", json=event)
        
        assert response.status_code == 400
        error = response.json()
        assert "project_id" in error["detail"].lower()

@pytest.mark.asyncio
async def test_ingest_empty_metrics():
    """Test ingestion fails when metrics array is empty."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        event = {
            "project_id": "550e8400-e29b-41d4-a716-446655440000",
            "site_id": "550e8400-e29b-41d4-a716-446655440001",
            "device_id": "550e8400-e29b-41d4-a716-446655440002",
            "metrics": [],
            "protocol": "GPRS",
            "source_timestamp": "2024-01-15T10:30:00Z"
        }
        
        response = await client.post("/v1/ingest", json=event)
        
        assert response.status_code == 400
        error = response.json()
        assert "metrics" in error["detail"].lower()
```

---

## 7. Regression Testing

### 7.1 Purpose

Regression tests ensure that new changes do not break existing functionality.

**Test Coverage:**
- All critical user workflows
- All API endpoints
- All data validation rules
- All error handling paths
- All configuration import/export flows

### 7.2 Regression Test Suite Structure

```
tests/regression/
├── api/
│   ├── test_collector_ingest_api.py
│   ├── test_collector_health_api.py
│   ├── test_admin_customers_api.py
│   ├── test_admin_projects_api.py
│   └── test_admin_devices_api.py
│
├── worker/
│   ├── test_worker_processing.py
│   ├── test_worker_batch_processing.py
│   └── test_worker_error_handling.py
│
├── validation/
│   ├── test_event_validation.py
│   ├── test_device_mapping.py
│   └── test_parameter_resolution.py
│
└── integration/
    ├── test_collector_worker_db.py
    ├── test_config_import_flow.py
    └── test_scada_export_flow.py
```

### 7.3 Regression Test Execution

**Local Execution:**
```bash
# Run all regression tests
pytest tests/regression/ -v

# Run specific test category
pytest tests/regression/api/ -v

# Run specific test file
pytest tests/regression/api/test_collector_ingest_api.py -v

# Run with coverage
pytest tests/regression/ --cov=nsready_backend --cov-report=html
```

**CI/CD Execution:**
- Regression tests run on every pull request
- All tests must pass before merge
- Coverage reports generated and tracked

---

## 8. Performance Testing

### 8.1 Purpose

Performance tests validate system behavior under load, measure throughput, latency, and resource utilization.

**Key Metrics:**
- **Throughput** - Events processed per second
- **Latency** - P50, P95, P99 response times
- **Queue Depth** - Message queue size under load
- **Database Performance** - Query execution times, connection pool usage
- **Resource Utilization** - CPU, memory, disk I/O

### 8.2 Performance Test Scenarios

**Load Testing:**
- Steady-state load (normal production traffic)
- Gradual ramp-up (increasing load over time)
- Sustained load (constant load for extended period)

**Stress Testing:**
- Beyond capacity (load exceeding system limits)
- Resource exhaustion (CPU, memory, disk)
- Connection pool exhaustion

**Throughput Testing:**
- Maximum events per second
- Batch processing efficiency
- Database insert performance

### 8.3 Example Performance Test

```python
# tests/performance/load/test_ingestion_throughput.py

import pytest
import asyncio
import time
from httpx import AsyncClient
from collector_service.app import app

@pytest.mark.performance
@pytest.mark.asyncio
async def test_ingestion_throughput_1000_events():
    """Test system can handle 1000 events in reasonable time."""
    async with AsyncClient(app=app, base_url="http://test", timeout=30.0) as client:
        events = []
        for i in range(1000):
            events.append({
                "project_id": "550e8400-e29b-41d4-a716-446655440000",
                "site_id": "550e8400-e29b-41d4-a716-446655440001",
                "device_id": f"550e8400-e29b-41d4-a716-44665544000{i:02d}",
                "metrics": [{"parameter_key": "voltage", "value": 230.5 + i, "quality": 192}],
                "protocol": "GPRS",
                "source_timestamp": "2024-01-15T10:30:00Z"
            })
        
        start_time = time.time()
        
        # Send all events concurrently
        tasks = [client.post("/v1/ingest", json=event) for event in events]
        responses = await asyncio.gather(*tasks)
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Verify all requests succeeded
        success_count = sum(1 for r in responses if r.status_code == 200)
        assert success_count == 1000, f"Only {success_count}/1000 events succeeded"
        
        # Calculate throughput
        throughput = 1000 / duration
        print(f"Throughput: {throughput:.2f} events/second")
        
        # Assert minimum throughput requirement
        assert throughput >= 100, f"Throughput {throughput} < 100 events/second"
        
        # Assert maximum latency (P95)
        latencies = [r.elapsed.total_seconds() for r in responses]
        latencies.sort()
        p95_latency = latencies[int(len(latencies) * 0.95)]
        assert p95_latency < 1.0, f"P95 latency {p95_latency} > 1.0 seconds"
```

### 8.4 Performance Test Best Practices

1. **Baseline Metrics** - Establish baseline performance metrics
2. **Realistic Load** - Use production-like load patterns
3. **Resource Monitoring** - Monitor CPU, memory, disk during tests
4. **Gradual Ramp-Up** - Start with low load and gradually increase
5. **Warm-Up Period** - Allow system to warm up before measuring
6. **Multiple Runs** - Run tests multiple times and average results
7. **Report Generation** - Generate detailed performance reports

---

## 9. Resilience Testing

### 9.1 Purpose

Resilience tests validate system behavior under failure conditions and verify recovery mechanisms.

**Failure Scenarios:**
- Database connection loss
- NATS connection loss
- Worker process crashes
- Network partitions
- Resource exhaustion (CPU, memory, disk)
- Message queue overflow
- Invalid data floods

### 9.2 Resilience Test Scenarios

**Component Failure:**
- Database becomes unavailable → System should queue messages and retry
- NATS becomes unavailable → System should buffer and retry connection
- Worker crashes → Messages should be redelivered automatically

**Recovery Testing:**
- System recovers after database restart
- System recovers after NATS restart
- System recovers after worker restart
- Messages are not lost during failures

**Queue Behavior:**
- Queue depth under load
- Dead letter queue (DLQ) for failed messages
- Message redelivery after worker recovery

### 9.3 Example Resilience Test

```python
# tests/resilience/failure/test_db_connection_loss_recovery.py

import pytest
import asyncio
from httpx import AsyncClient
from collector_service.app import app
from collector_service.core.db import get_session

@pytest.mark.resilience
@pytest.mark.asyncio
async def test_db_connection_loss_recovery():
    """Test system recovers after database connection loss."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # 1. Send event (should succeed)
        event = {
            "project_id": "550e8400-e29b-41d4-a716-446655440000",
            "site_id": "550e8400-e29b-41d4-a716-446655440001",
            "device_id": "550e8400-e29b-41d4-a716-446655440002",
            "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
            "protocol": "GPRS",
            "source_timestamp": "2024-01-15T10:30:00Z"
        }
        
        response = await client.post("/v1/ingest", json=event)
        assert response.status_code == 200
        
        # 2. Simulate database connection loss (stop DB container)
        # In real test: docker-compose stop db
        
        # 3. Send another event (should still queue to NATS)
        event2 = {
            "project_id": "550e8400-e29b-41d4-a716-446655440000",
            "site_id": "550e8400-e29b-41d4-a716-446655440001",
            "device_id": "550e8400-e29b-41d4-a716-446655440003",
            "metrics": [{"parameter_key": "current", "value": 10.2, "quality": 192}],
            "protocol": "GPRS",
            "source_timestamp": "2024-01-15T10:31:00Z"
        }
        
        response2 = await client.post("/v1/ingest", json=event2)
        assert response2.status_code == 200  # API should still accept
        
        # 4. Restore database connection
        # In real test: docker-compose start db
        await asyncio.sleep(5)  # Wait for DB to be ready
        
        # 5. Verify worker processes queued messages after recovery
        await asyncio.sleep(10)  # Allow worker to process
        
        # 6. Verify both events are in database
        async with get_session() as session:
            # Check both events exist
            # (Implementation depends on test DB setup)
            pass
```

### 9.4 Resilience Test Best Practices

1. **Controlled Failures** - Use test infrastructure to simulate failures
2. **Recovery Validation** - Verify system recovers correctly
3. **Data Integrity** - Ensure no data loss during failures
4. **Message Redelivery** - Verify NATS redelivery works correctly
5. **Graceful Degradation** - System should degrade gracefully, not crash

---

## 10. Test Data Management

### 10.1 Test Fixtures

Test fixtures provide consistent, reusable test data.

**Fixture Types:**
- **Database Fixtures** - Pre-populated customers, projects, sites, devices
- **Event Fixtures** - Sample telemetry events (valid and invalid)
- **Configuration Fixtures** - Parameter templates, registry versions

**Example Fixture:**
```python
# conftest.py

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

@pytest.fixture
async def test_db_session():
    """Create test database session."""
    engine = create_async_engine("postgresql+asyncpg://test_user:test_pass@localhost/nsready_test")
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        yield session
        await session.rollback()  # Cleanup

@pytest.fixture
def sample_event():
    """Sample valid telemetry event."""
    return {
        "project_id": "550e8400-e29b-41d4-a716-446655440000",
        "site_id": "550e8400-e29b-41d4-a716-446655440001",
        "device_id": "550e8400-e29b-41d4-a716-446655440002",
        "metrics": [{"parameter_key": "voltage", "value": 230.5, "quality": 192}],
        "protocol": "GPRS",
        "source_timestamp": "2024-01-15T10:30:00Z"
    }
```

### 10.2 Test Data Cleanup

**Strategies:**
1. **Transaction Rollback** - Roll back transactions after each test
2. **Truncate Tables** - Truncate test tables between tests
3. **Test Database** - Use separate test database, drop/recreate between test runs
4. **Test Containers** - Use Docker containers, destroy/recreate for clean state

**Best Practice:**
- Use transaction rollback for fast cleanup
- Use test database for integration tests
- Use test containers for end-to-end tests

---

## 11. Test Execution and Automation

### 11.1 Local Test Execution

**Run All Tests:**
```bash
pytest tests/ -v
```

**Run by Category:**
```bash
# Regression tests only
pytest tests/regression/ -v

# Performance tests only
pytest tests/performance/ -v

# Resilience tests only
pytest tests/resilience/ -v
```

**Run with Coverage:**
```bash
pytest tests/ --cov=nsready_backend --cov-report=html --cov-report=term
```

**Run Specific Test:**
```bash
pytest tests/regression/api/test_collector_ingest_api.py::test_ingest_valid_event -v
```

### 11.2 Test Markers

Use pytest markers to categorize tests:

```python
# Mark performance tests
@pytest.mark.performance
def test_perf_throughput():
    pass

# Mark resilience tests
@pytest.mark.resilience
def test_resilience_db_failure():
    pass

# Mark slow tests
@pytest.mark.slow
def test_e2e_full_workflow():
    pass
```

**Run by Marker:**
```bash
# Run only performance tests
pytest -m performance

# Run only fast tests (exclude slow)
pytest -m "not slow"

# Run regression and performance (exclude resilience)
pytest -m "regression or performance" -m "not resilience"
```

### 11.3 CI/CD Integration

**GitHub Actions Workflow:**
```yaml
# .github/workflows/test.yml

name: Test Suite

on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: nsready_test
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      nats:
        image: nats:latest
        options: >-
          --health-cmd "nats --server=nats://localhost:4222 ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r nsready_backend/collector_service/requirements.txt
          pip install -r nsready_backend/admin_tool/requirements.txt
          pip install pytest pytest-asyncio pytest-cov httpx
      
      - name: Run regression tests
        run: |
          pytest tests/regression/ -v --cov=nsready_backend --cov-report=xml
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```

---

## 12. Test Best Practices and Guidelines

### 12.1 Writing Good Tests

**AAA Pattern (Arrange, Act, Assert):**
```python
def test_example():
    # Arrange - Set up test data and conditions
    event = create_sample_event()
    
    # Act - Execute the code under test
    result = process_event(event)
    
    # Assert - Verify the results
    assert result.status == "success"
    assert result.trace_id is not None
```

**Test Independence:**
- Each test should be independent and not rely on other tests
- Tests should be able to run in any order
- Tests should not share mutable state

**Clear Test Names:**
- Use descriptive test function names
- Include scenario in test name: `test_ingest_valid_event`, `test_ingest_missing_project_id`
- Use docstrings to explain test purpose

### 12.2 Test Maintenance

**Keep Tests Updated:**
- Update tests when requirements change
- Remove obsolete tests
- Refactor tests to match code changes

**Test Coverage:**
- Aim for >80% code coverage on business logic
- Focus on critical paths and error handling
- Don't obsess over 100% coverage (edge cases may not be worth testing)

**Test Performance:**
- Keep unit tests fast (<100ms each)
- Keep integration tests reasonable (<5s each)
- Mark slow tests and run them separately

### 12.3 Common Pitfalls

**Avoid:**
- Testing implementation details instead of behavior
- Over-mocking (mocking everything makes tests less valuable)
- Flaky tests (tests that sometimes pass, sometimes fail)
- Slow tests (tests that take too long to run)
- Test interdependencies (tests that depend on other tests)

**Do:**
- Test behavior, not implementation
- Use real dependencies when possible (database, NATS in integration tests)
- Make tests deterministic and repeatable
- Keep tests fast and focused
- Write tests that fail for the right reasons

---

## 13. Test Reporting and Metrics

### 13.1 Test Reports

**Coverage Reports:**
- HTML coverage reports: `pytest --cov-report=html`
- Terminal coverage: `pytest --cov-report=term`
- XML coverage (for CI/CD): `pytest --cov-report=xml`

**Performance Reports:**
- Performance test results stored in `tests/performance/tests/reports/`
- Include metrics: throughput, latency (P50/P95/P99), resource utilization
- Compare against baseline metrics

**Test Execution Reports:**
- Pytest HTML reports: `pytest --html=report.html --self-contained-html`
- JUnit XML (for CI/CD): `pytest --junitxml=report.xml`

### 13.2 Test Metrics

**Key Metrics to Track:**
- **Test Count** - Total number of tests
- **Pass Rate** - Percentage of tests passing
- **Coverage** - Code coverage percentage
- **Execution Time** - Total test execution time
- **Flaky Tests** - Tests that fail intermittently

**Monitoring:**
- Track test metrics over time
- Alert on decreasing pass rate or coverage
- Identify and fix flaky tests quickly

---

## 14. Future Enhancements

### 14.1 Planned Improvements

**Test Infrastructure:**
- Automated test data generation
- Test environment provisioning automation
- Performance test baseline tracking
- Resilience test failure injection framework

**Test Coverage:**
- End-to-end tests for complete workflows
- SCADA integration tests
- Multi-tenant isolation tests
- Security and authentication tests

**Test Automation:**
- Pre-commit hooks for running fast tests
- Automated performance regression detection
- Automated resilience test execution
- Test result analysis and reporting

---

## 15. Summary

This module provides a comprehensive guide to testing strategies and test suite organization for the NSReady Data Collection Platform.

**Key Takeaways:**
- Multi-layered testing strategy (unit, integration, end-to-end)
- Three test suites: regression, performance, resilience
- Automated test execution in CI/CD
- Test data management and cleanup strategies
- Best practices for writing and maintaining tests

**Next Steps:**
- Review existing test structure and identify gaps
- Implement missing test categories
- Set up CI/CD test automation
- Establish performance baselines
- Create test data fixtures

**Related Modules:**
- Module 7 – Data Validation & Error Handling (validation testing)
- Module 8 – Ingestion Worker & Queue Processing (worker testing)
- Module 12 – API Developer Manual (API testing)
- Module 13 – Operational Checklist & Runbook (operational testing)

---

**Document Version:** 1.0  
**Last Updated:** 2024-01-15  
**Author:** NSReady Platform Team


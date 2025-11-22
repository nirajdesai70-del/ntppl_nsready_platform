# Test Suite - NTPPL NS-Ready Platform

Automated validation and benchmark framework for the Tier-1 stack (Admin Tool + Collector Service + DB + NATS + Metrics).

## Structure

```
tests/
├── regression/          # Regression tests (pytest + httpx)
│   ├── test_api_endpoints.py
│   └── test_ingestion_flow.py
├── performance/         # Performance tests (Locust)
│   └── locustfile.py
├── resilience/          # Resilience tests
│   └── test_recovery.py
├── utils/               # Test utilities
│   └── reporting.py
├── reports/             # Generated test reports
├── pytest.ini          # Pytest configuration
└── requirements.txt    # Test dependencies
```

## Prerequisites

1. **Services Running**: Ensure all services are up:
   ```bash
   docker compose up -d
   ```

2. **Install Test Dependencies**:
   ```bash
   pip install -r tests/requirements.txt
   ```

## Running Tests

### Python Test Suite (Pytest)

**All Tests:**
```bash
make test
```

Or directly:
```bash
pytest tests/ -v --maxfail=1 --disable-warnings
```

### Bash Test Scripts (Data Flow Testing)

For comprehensive data flow testing, see the bash test scripts in `scripts/`:

- **Basic Data Flow**: `./scripts/test_data_flow.sh`
- **Batch Ingestion**: `./scripts/test_batch_ingestion.sh`
- **Stress/Load**: `./scripts/test_stress_load.sh`
- **Multi-Customer**: `./scripts/test_multi_customer_flow.sh`
- **Negative Cases**: `./scripts/test_negative_cases.sh`

See `scripts/TEST_SCRIPTS_README.md` for detailed documentation.

**Quick Start:**
```bash
# Ensure services are running and registry is seeded
docker compose up -d
docker exec -i nsready_db psql -U postgres -d nsready < db/seed_registry.sql

# Run basic data flow test
DB_CONTAINER=nsready_db ./scripts/test_data_flow.sh
```

### Regression Tests Only

```bash
make test-regression
```

Or:
```bash
pytest tests/regression/ -v
```

### Resilience Tests Only

```bash
make test-resilience
```

Or:
```bash
pytest tests/resilience/ -v
```

### Performance Tests (Locust)

**Headless Mode (Automated)**:
```bash
make benchmark
```

This runs:
- 50 concurrent users
- 5 users spawned per second
- 60 seconds duration
- Results saved to `tests/reports/`

**Interactive UI Mode**:
```bash
make benchmark-ui
```

Then open http://localhost:8089 in your browser.

## Test Suites

### Regression Tests

**test_api_endpoints.py**:
- `/health` endpoints (admin and collector)
- `/metrics` endpoint
- `/v1/ingest` endpoint structure

**test_ingestion_flow.py**:
- End-to-end ingestion flow
- Database count verification
- Error rate checks
- Queue depth validation

### Performance Tests

**locustfile.py**:
- Simulates 50 concurrent users
- Tests single and multiple metric events
- Measures latency (p50, p95), throughput, error rate
- Exports results to JSON and HTML

### Resilience Tests

**test_recovery.py**:
- Database restart recovery
- NATS restart recovery
- Data loss prevention verification
- Service health recovery within 60 seconds

## Reports

Test reports are generated in `tests/reports/`:

- **Performance**: `performance_summary.json` and `locust_report.html`
- **Validation**: `validation_report_<timestamp>.json` and `.html`

### Report Fields

- `timestamp`: Test execution time
- `tests_passed`: Number of passed tests
- `tests_total`: Total number of tests
- `avg_latency`: Average response latency (ms)
- `throughput`: Requests per second
- `error_rate`: Error percentage
- `db_status`: Database connection status
- `nats_status`: NATS connection status

## Configuration

### Pytest Configuration (`pytest.ini`)

- Test discovery: `test_*.py` files
- Markers: `regression`, `integration`, `resilience`
- Max failures: 1 (stop on first failure)
- Async mode: auto

### Locust Configuration

- Default users: 50
- Spawn rate: 5 users/second
- Run time: 60 seconds
- Host: http://localhost:8001

## Troubleshooting

### Tests Fail with Connection Errors

Ensure services are running:
```bash
docker compose ps
```

### Performance Tests Show High Latency

- Check service resource usage: `docker stats`
- Verify NATS queue depth: `curl http://localhost:8001/v1/health`
- Check database connection pool settings

### Resilience Tests Timeout

- Increase wait times in `test_recovery.py` if services are slow to recover
- Verify Docker Compose is accessible: `docker compose version`

## Continuous Integration

Example CI configuration:

```yaml
# .github/workflows/test.yml
- name: Run Tests
  run: |
    docker compose up -d
    sleep 10
    make test
    make benchmark
```

## Test Scripts vs Python Tests

**Python Tests (pytest)**:
- Unit and integration tests
- API endpoint validation
- Performance benchmarks (Locust)
- Resilience/recovery tests
- Located in `tests/` directory

**Bash Test Scripts**:
- End-to-end data flow testing
- Batch ingestion testing
- Stress/load testing
- Multi-customer tenant isolation
- Negative test cases
- Located in `scripts/` directory
- See `scripts/TEST_SCRIPTS_README.md` for details

## Notes

- Regression tests require services to be running
- Resilience tests will stop/start containers (use with caution)
- Performance tests generate load - ensure adequate resources
- Reports are timestamped for historical tracking
- Bash test scripts auto-detect environment (Kubernetes/Docker Compose)



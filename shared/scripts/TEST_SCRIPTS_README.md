# Test Scripts Overview

This directory contains comprehensive test scripts for validating the NSReady data flow pipeline.

**Note:** All scripts are located in `shared/scripts/`. Run scripts from the repository root.

## Available Test Scripts

### 1. Basic Data Flow Test
**Script**: `test_data_flow.sh`

Tests the complete end-to-end data flow from dashboard input to SCADA export.

```bash
./shared/scripts/test_data_flow.sh
```

**What it tests:**
- Dashboard input → Ingestion API
- Queue processing
- Database storage
- SCADA views
- SCADA export

**Output**: `nsready_backend/tests/reports/DATA_FLOW_TEST_*.md`

---

### 2. Batch Ingestion Test
**Script**: `test_batch_ingestion.sh`

Tests sending multiple events in sequential and parallel batches.

```bash
# Sequential batch (50 events)
./shared/scripts/test_batch_ingestion.sh --sequential --count 50

# Parallel batch (100 events)
./shared/scripts/test_batch_ingestion.sh --parallel --count 100

# Both modes
./shared/scripts/test_batch_ingestion.sh --count 50
```

**What it tests:**
- Sequential ingestion throughput
- Parallel ingestion throughput
- Queue handling under batch load
- Database insertion performance

**Output**: `nsready_backend/tests/reports/BATCH_INGESTION_TEST_*.md`

---

### 3. Stress/Load Test
**Script**: `test_stress_load.sh`

Tests system under sustained high load.

```bash
# Default: 1000 events over 60s at 50 RPS
./shared/scripts/test_stress_load.sh

# Custom: 5000 events over 120s at 100 RPS
./shared/scripts/test_stress_load.sh --events 5000 --duration 120 --rate 100
```

**What it tests:**
- Sustained high-volume ingestion
- Queue depth stability
- System stability under load
- Error rates
- Throughput measurement

**Output**: `nsready_backend/tests/reports/STRESS_LOAD_TEST_*.md`

---

### 4. Multi-Customer Data Flow Test
**Script**: `test_multi_customer_flow.sh`

Tests data flow with multiple customers to verify tenant isolation.

```bash
# Test with 5 customers (default)
./shared/scripts/test_multi_customer_flow.sh

# Test with 10 customers
./shared/scripts/test_multi_customer_flow.sh --customers 10
```

**What it tests:**
- Data ingestion for multiple customers
- Tenant isolation
- Per-customer data separation
- Database integrity

**Output**: `nsready_backend/tests/reports/MULTI_CUSTOMER_FLOW_TEST_*.md`

---

### 5. Negative Test Cases
**Script**: `test_negative_cases.sh`

Tests system behavior with invalid data and error conditions.

```bash
./shared/scripts/test_negative_cases.sh
```

**What it tests:**
- Missing required fields
- Invalid UUID formats
- Non-existent parameter keys
- Invalid data types
- Malformed JSON
- Empty requests
- Non-existent references

**Expected**: All invalid requests should be rejected with appropriate HTTP status codes (400, 422)

**Output**: `nsready_backend/tests/reports/NEGATIVE_TEST_*.md`

---

## Quick Start

### Prerequisites

1. **Services Running**
   ```bash
   # Docker Compose
   docker compose up -d
   
   # Kubernetes
   kubectl get pods -n nsready-tier2
   ```

2. **Registry Seeded**
   ```bash
   # Seed the database with test data
   docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
   ```

3. **Port Forwarding** (Kubernetes only)
   - Scripts handle this automatically

### Running Tests

**Basic test:**
```bash
DB_CONTAINER=nsready_db ./shared/scripts/test_data_flow.sh
```

**All tests:**
```bash
# Basic flow
./shared/scripts/test_data_flow.sh

# Batch ingestion
./shared/scripts/test_batch_ingestion.sh --count 100

# Stress test
./shared/scripts/test_stress_load.sh --events 1000 --rate 50

# Multi-customer
./shared/scripts/test_multi_customer_flow.sh --customers 5

# Negative cases
./shared/scripts/test_negative_cases.sh
```

---

## Environment Detection

All scripts automatically detect the environment:
- **Kubernetes**: If `kubectl` is available and namespace exists
- **Docker Compose**: Otherwise

You can override defaults:
```bash
# Docker Compose
DB_CONTAINER=nsready_db ./shared/scripts/test_data_flow.sh

# Kubernetes
NS=nsready-tier2 DB_POD=nsready-db-0 ./shared/scripts/test_data_flow.sh
```

---

## Test Reports

All test reports are saved in `nsready_backend/tests/reports/` with timestamps:

- `DATA_FLOW_TEST_YYYYMMDD_HHMMSS.md`
- `BATCH_INGESTION_TEST_YYYYMMDD_HHMMSS.md`
- `STRESS_LOAD_TEST_YYYYMMDD_HHMMSS.md`
- `MULTI_CUSTOMER_FLOW_TEST_YYYYMMDD_HHMMSS.md`
- `NEGATIVE_TEST_YYYYMMDD_HHMMSS.md`

Each report includes:
- Test configuration
- Detailed results
- Metrics and statistics
- Recommendations
- Pass/fail status

---

## Integration with CI/CD

Add to your CI/CD pipeline:

```yaml
# .github/workflows/test.yml
- name: Run data flow tests
  run: |
    docker compose up -d
    sleep 10
    docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
    ./shared/scripts/test_data_flow.sh
    ./shared/scripts/test_negative_cases.sh
```

---

## Troubleshooting

### Script fails with "No device/site/project found"
**Solution**: Seed the registry first
```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

### Script fails with "Collector service not reachable"
**Solution**: 
- Check services are running: `docker ps` or `kubectl get pods`
- Check port forwarding (Kubernetes): Scripts handle this automatically

### Container name mismatch
**Solution**: Specify the correct container name
```bash
DB_CONTAINER=nsready_db ./shared/scripts/test_data_flow.sh
```

---

## Test Coverage

| Test Type | Coverage |
|-----------|----------|
| Basic Flow | ✅ End-to-end data flow |
| Batch Ingestion | ✅ Sequential & parallel batches |
| Stress/Load | ✅ High-volume sustained load |
| Multi-Customer | ✅ Tenant isolation |
| Negative Cases | ✅ Invalid data validation |

---

## Best Practices

1. **Run basic test first**: Always start with `test_data_flow.sh` to verify basic functionality
2. **Run negative tests**: Ensure invalid data is properly rejected
3. **Monitor queue depth**: During stress tests, watch queue depth metrics
4. **Check reports**: Review detailed reports for any issues
5. **Clean up**: Remove test data if needed after testing

---

## Support

For issues or questions:
1. Check the test report for detailed error messages
2. Review the [Data Flow Testing Guide](../../master_docs/tenant_upgrade/DATA_FLOW_TESTING_GUIDE.md)
3. Check service logs: `docker logs collector_service`

---

**Last Updated**: 2025-11-22


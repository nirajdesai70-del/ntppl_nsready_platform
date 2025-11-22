# Tenant Isolation Testing Guide

**Date**: 2025-01-18  
**Purpose**: Comprehensive testing strategy to verify tenant isolation implementation and identify gaps

---

## Overview

This guide provides a systematic approach to test the NSReady v1 tenant isolation implementation after the Priority 1 security fixes. It covers:

1. **Unit Testing** - Tenant validation middleware
2. **API Integration Testing** - All admin endpoints
3. **Script Testing** - Export/import scripts with tenant isolation
4. **Security Testing** - Cross-tenant access attempts
5. **Documentation Validation** - Code matches documentation
6. **End-to-End Testing** - Complete workflows

---

## Prerequisites

Before testing, ensure:

- [ ] Database is running (PostgreSQL with test data)
- [ ] At least 2 test customers exist in database
- [ ] Each customer has projects, sites, devices
- [ ] API services are running (admin-tool, collector-service)
- [ ] Test authentication tokens are configured

**Setup Test Data:**

```bash
# Create test customers
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
INSERT INTO customers (name, metadata) VALUES 
  ('Test Customer A', '{}'::jsonb),
  ('Test Customer B', '{}'::jsonb)
ON CONFLICT DO NOTHING
RETURNING id::text, name;"

# Get customer IDs
CUSTOMER_A_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT id::text FROM customers WHERE name = 'Test Customer A';" | tr -d '[:space:]')

CUSTOMER_B_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT id::text FROM customers WHERE name = 'Test Customer B';" | tr -d '[:space:]')

echo "Customer A ID: $CUSTOMER_A_ID"
echo "Customer B ID: $CUSTOMER_B_ID"
```

---

## 1. Unit Testing - Tenant Validation Middleware

### 1.1 Test UUID Validation

**Test**: Invalid UUID format should be rejected

```python
# Test in admin_tool/api/deps.py
# Should raise HTTPException with 400 status

# Invalid UUID formats
test_cases = [
    "not-a-uuid",
    "123",
    "customer-123",
    "",
    None
]

for invalid_id in test_cases:
    # Call validate_tenant_access with invalid_id
    # Should raise HTTPException(status_code=400)
```

**Expected Result**: All invalid UUIDs rejected with 400 Bad Request

---

### 1.2 Test Customer Existence Validation

**Test**: Non-existent customer_id should be rejected

```python
# Test with non-existent UUID
fake_customer_id = "00000000-0000-0000-0000-000000000000"

# Call validate_tenant_access(fake_customer_id, ...)
# Should raise HTTPException(status_code=404)
```

**Expected Result**: 404 Not Found for non-existent customer

---

### 1.3 Test Foreign Key Integrity

**Test**: Invalid project_id → customer_id chain should be rejected

```python
# Test with project_id that doesn't belong to customer
customer_a_id = "..."
project_b_id = "..."  # Belongs to Customer B

# Call validate_project_access(project_b_id, customer_a_id, ...)
# Should raise HTTPException(status_code=403)
```

**Expected Result**: 403 Forbidden when FK chain doesn't match tenant

---

## 2. API Integration Testing

### 2.1 Test Customer Users (Tenant-Restricted Access)

**Setup**: Use `X-Customer-ID` header with Customer A's ID

#### Test 2.1.1: GET /admin/customers

```bash
# As Customer A user
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/customers

# Expected: Only Customer A returned
# Should NOT see Customer B
```

**Expected Result**: 
- ✅ Returns only Customer A
- ❌ Does NOT return Customer B
- ✅ Response contains exactly 1 customer

---

#### Test 2.1.2: GET /admin/projects

```bash
# As Customer A user
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects

# Expected: Only Customer A's projects returned
```

**Expected Result**:
- ✅ Returns only projects belonging to Customer A
- ❌ Does NOT return Customer B's projects

---

#### Test 2.1.3: GET /admin/projects/{project_id} (Cross-Tenant Access Attempt)

```bash
# Get Customer B's project ID
PROJECT_B_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c \
  "SELECT id::text FROM projects WHERE customer_id = '$CUSTOMER_B_ID' LIMIT 1;" | tr -d '[:space:]')

# As Customer A user, try to access Customer B's project
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects/$PROJECT_B_ID

# Expected: 403 Forbidden or 404 Not Found
```

**Expected Result**:
- ✅ 403 Forbidden (preferred) OR 404 Not Found
- ❌ Should NOT return Customer B's project data
- ✅ Error message should not leak Customer B's information

---

#### Test 2.1.4: POST /admin/projects (Cross-Tenant Creation Attempt)

```bash
# As Customer A user, try to create project for Customer B
curl -X POST http://localhost:8000/admin/projects \
  -H "Authorization: Bearer devtoken" \
  -H "X-Customer-ID: $CUSTOMER_A_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "'$CUSTOMER_B_ID'",
    "name": "Unauthorized Project",
    "description": "Should fail"
  }'

# Expected: 403 Forbidden
```

**Expected Result**:
- ✅ 403 Forbidden
- ❌ Project should NOT be created
- ✅ Error message should not leak Customer B's information

---

#### Test 2.1.5: GET /admin/sites, /admin/devices, /admin/parameter_templates

```bash
# Test all endpoints with Customer A header
# Should only return Customer A's data

for endpoint in sites devices parameter_templates; do
  echo "Testing GET /admin/$endpoint"
  curl -H "Authorization: Bearer devtoken" \
       -H "X-Customer-ID: $CUSTOMER_A_ID" \
       http://localhost:8000/admin/$endpoint | jq .
done
```

**Expected Result**: All endpoints return only Customer A's data

---

### 2.2 Test Engineers/Admins (Cross-Tenant Access)

**Setup**: Omit `X-Customer-ID` header (engineer mode)

#### Test 2.2.1: GET /admin/customers (Engineer Mode)

```bash
# As Engineer (no X-Customer-ID header)
curl -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/customers

# Expected: All customers returned
```

**Expected Result**:
- ✅ Returns all customers (Customer A, Customer B, etc.)
- ✅ No tenant restriction

---

#### Test 2.2.2: GET /admin/projects (Engineer Mode)

```bash
# As Engineer
curl -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/projects

# Expected: All projects returned
```

**Expected Result**:
- ✅ Returns projects from all customers
- ✅ No tenant restriction

---

#### Test 2.2.3: POST /admin/projects (Engineer Mode - Create for Any Customer)

```bash
# As Engineer, create project for Customer B
curl -X POST http://localhost:8000/admin/projects \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "'$CUSTOMER_B_ID'",
    "name": "Engineer Created Project",
    "description": "Should succeed"
  }'

# Expected: 201 Created
```

**Expected Result**:
- ✅ 201 Created
- ✅ Project created successfully
- ✅ No tenant restriction for engineers

---

### 2.3 Test Invalid Inputs

#### Test 2.3.1: Invalid UUID Format

```bash
# Invalid UUID in header
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: not-a-uuid" \
     http://localhost:8000/admin/customers

# Expected: 400 Bad Request
```

**Expected Result**: 400 Bad Request with clear error message

---

#### Test 2.3.2: Non-Existent Customer ID

```bash
# Non-existent customer ID
FAKE_ID="00000000-0000-0000-0000-000000000000"
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $FAKE_ID" \
     http://localhost:8000/admin/customers

# Expected: 404 Not Found
```

**Expected Result**: 404 Not Found

---

## 3. Script Testing - Export Scripts

### 3.1 Test export_registry_data.sh

#### Test 3.1.1: Missing --customer-id (Should Fail)

```bash
# Try export without --customer-id
./scripts/export_registry_data.sh

# Expected: Error message requiring --customer-id
```

**Expected Result**:
- ✅ Script fails with clear error
- ✅ Error message: "Error: --customer-id is REQUIRED for tenant isolation"
- ✅ Script provides usage instructions

---

#### Test 3.1.2: Valid --customer-id (Should Succeed)

```bash
# Export with valid customer ID
./scripts/export_registry_data.sh --customer-id $CUSTOMER_A_ID

# Expected: Export succeeds, only Customer A's data
```

**Expected Result**:
- ✅ Export succeeds
- ✅ CSV contains only Customer A's data
- ✅ No Customer B data in export
- ✅ File named with customer name

---

#### Test 3.1.3: Invalid UUID Format

```bash
# Invalid UUID format
./scripts/export_registry_data.sh --customer-id "invalid-uuid"

# Expected: Error about invalid UUID format
```

**Expected Result**: Error: "Invalid customer_id format. Expected UUID format."

---

#### Test 3.1.4: Non-Existent Customer ID

```bash
# Non-existent customer
./scripts/export_registry_data.sh --customer-id "00000000-0000-0000-0000-000000000000"

# Expected: Error about customer not found
```

**Expected Result**: Error: "Customer ID ... not found in database."

---

### 3.2 Test export_parameter_template_csv.sh

**Same tests as 3.1, but for parameter templates:**

```bash
# Test missing --customer-id
./scripts/export_parameter_template_csv.sh

# Test valid --customer-id
./scripts/export_parameter_template_csv.sh --customer-id $CUSTOMER_A_ID

# Test invalid UUID
./scripts/export_parameter_template_csv.sh --customer-id "invalid"

# Test non-existent customer
./scripts/export_parameter_template_csv.sh --customer-id "00000000-0000-0000-0000-000000000000"
```

**Expected Results**: Same as export_registry_data.sh tests

---

## 4. Script Testing - Import Scripts

### 4.1 Test import_registry.sh

#### Test 4.1.1: Full Import (Engineer Mode - No --customer-id)

```bash
# Create test CSV with Customer A data
cat > test_registry.csv <<EOF
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
Test Customer A,Test Project,Test Description,Test Site,{},Test Device,sensor,DEV001,active
EOF

# Import without --customer-id (engineer mode)
./scripts/import_registry.sh test_registry.csv

# Expected: Import succeeds (engineer can create customers)
```

**Expected Result**: Import succeeds, customer/project/site/device created

---

#### Test 4.1.2: Tenant-Restricted Import (Customer User Mode)

```bash
# Import with --customer-id (customer user mode)
./scripts/import_registry.sh test_registry.csv --customer-id $CUSTOMER_A_ID

# Expected: Import succeeds if CSV matches Customer A
```

**Expected Result**: Import succeeds if all rows match Customer A

---

#### Test 4.1.3: Tenant-Restricted Import with Wrong Customer (Should Fail)

```bash
# Create CSV with Customer B data
cat > test_registry_wrong.csv <<EOF
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
Test Customer B,Test Project,Test Description,Test Site,{},Test Device,sensor,DEV002,active
EOF

# Try to import Customer B data with Customer A's --customer-id
./scripts/import_registry.sh test_registry_wrong.csv --customer-id $CUSTOMER_A_ID

# Expected: Import fails or skips rows with error
```

**Expected Result**:
- ✅ Import fails or skips rows
- ✅ Error message: "Row X: customer_name 'Test Customer B' does not match restricted customer 'Test Customer A'"
- ✅ No data imported for Customer B

---

#### Test 4.1.4: Invalid UUID Format

```bash
# Invalid UUID
./scripts/import_registry.sh test_registry.csv --customer-id "invalid-uuid"

# Expected: Error about invalid UUID format
```

**Expected Result**: Error: "Invalid customer_id format. Expected UUID format."

---

### 4.2 Test import_parameter_templates.sh

**Same tests as 4.1, but for parameter templates:**

```bash
# Test full import (engineer)
./scripts/import_parameter_templates.sh test_params.csv

# Test tenant-restricted import (customer user)
./scripts/import_parameter_templates.sh test_params.csv --customer-id $CUSTOMER_A_ID

# Test wrong customer (should fail)
./scripts/import_parameter_templates.sh test_params_wrong.csv --customer-id $CUSTOMER_A_ID
```

**Expected Results**: Same as import_registry.sh tests

---

## 5. Security Testing - Cross-Tenant Access Attempts

### 5.1 Test Registry Versions Endpoint

**Critical Test**: Verify `publish_version()` only includes tenant's data

```bash
# Get Customer A's project ID
PROJECT_A_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c \
  "SELECT id::text FROM projects WHERE customer_id = '$CUSTOMER_A_ID' LIMIT 1;" | tr -d '[:space:]')

# As Customer A user, publish registry version
curl -X POST http://localhost:8000/admin/projects/$PROJECT_A_ID/versions/publish \
  -H "Authorization: Bearer devtoken" \
  -H "X-Customer-ID: $CUSTOMER_A_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "author": "test",
    "diff_json": {"note": "Test version"}
  }'

# Then get the version and verify it only contains Customer A's data
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects/$PROJECT_A_ID/versions/latest | jq .

# Expected: Version JSON should ONLY contain Customer A's customers, projects, sites, devices
# Should NOT contain Customer B's data
```

**Expected Result**:
- ✅ Version JSON contains only Customer A's data
- ❌ Version JSON does NOT contain Customer B's customers, projects, sites, devices
- ✅ All foreign key relationships validated

---

### 5.2 Test Information Leakage

**Test**: Error messages should not leak cross-tenant information

```bash
# As Customer A user, try to access Customer B's resource
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects/$PROJECT_B_ID

# Check error message
# Expected: Generic error, no Customer B details leaked
```

**Expected Result**:
- ✅ Error message is generic (e.g., "Resource not found" or "Access denied")
- ❌ Error message does NOT reveal Customer B's name, ID, or any details
- ✅ Error uses `format_tenant_scoped_error()` to prevent leakage

---

## 6. Documentation Validation

### 6.1 Verify API Documentation Matches Implementation

**Test**: Compare documentation with actual API behavior

```bash
# Test each documented endpoint
# Compare actual behavior with docs/12_API_Developer_Manual.md

# Example: GET /admin/customers
# Docs say: Customer users must provide X-Customer-ID
# Test: Verify this is enforced
```

**Checklist**:
- [ ] All documented endpoints work as described
- [ ] X-Customer-ID header behavior matches documentation
- [ ] Error codes match documentation (403, 404, 400)
- [ ] Response formats match documentation

---

### 6.2 Verify Script Documentation Matches Implementation

**Test**: Compare script behavior with documentation

```bash
# Test each documented script
# Compare actual behavior with docs/10_Scripts_and_Tools_Reference_Manual.md

# Example: export_registry_data.sh
# Docs say: Requires --customer-id
# Test: Verify script fails without --customer-id
```

**Checklist**:
- [ ] All script usage examples work as documented
- [ ] Error messages match documentation
- [ ] Required parameters enforced as documented
- [ ] Output formats match documentation

---

## 7. End-to-End Testing

### 7.1 Complete Customer User Workflow

**Test**: Full workflow as Customer A user

```bash
# 1. List own customer
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/customers

# 2. List own projects
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects

# 3. Export own registry
./scripts/export_registry_data.sh --customer-id $CUSTOMER_A_ID

# 4. Export own parameters
./scripts/export_parameter_template_csv.sh --customer-id $CUSTOMER_A_ID

# 5. Import own data (if CSV prepared)
./scripts/import_registry.sh my_data.csv --customer-id $CUSTOMER_A_ID
```

**Expected Result**: All operations succeed, only Customer A's data accessed

---

### 7.2 Complete Engineer Workflow

**Test**: Full workflow as Engineer (no tenant restriction)

```bash
# 1. List all customers
curl -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/customers

# 2. List all projects
curl -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/projects

# 3. Create project for Customer B
curl -X POST http://localhost:8000/admin/projects \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{"customer_id": "'$CUSTOMER_B_ID'", "name": "Engineer Project", "description": "Test"}'

# 4. Export Customer A's registry (using --customer-id)
./scripts/export_registry_data.sh --customer-id $CUSTOMER_A_ID

# 5. Export Customer B's registry (using --customer-id)
./scripts/export_registry_data.sh --customer-id $CUSTOMER_B_ID
```

**Expected Result**: All operations succeed, engineer has full access

---

## 8. Automated Test Script

Create a comprehensive test script:

```bash
#!/bin/bash
# test_tenant_isolation.sh

set -e

ADMIN_URL="${ADMIN_URL:-http://localhost:8000}"
BEARER_TOKEN="${BEARER_TOKEN:-devtoken}"

# Get test customer IDs
CUSTOMER_A_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c \
  "SELECT id::text FROM customers WHERE name = 'Test Customer A';" | tr -d '[:space:]')

CUSTOMER_B_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c \
  "SELECT id::text FROM customers WHERE name = 'Test Customer B';" | tr -d '[:space:]')

echo "=== Tenant Isolation Test Suite ==="
echo "Customer A ID: $CUSTOMER_A_ID"
echo "Customer B ID: $CUSTOMER_B_ID"
echo ""

# Test 1: Customer A can only see own customer
echo "Test 1: Customer A can only see own customer"
RESULT=$(curl -s -H "Authorization: Bearer $BEARER_TOKEN" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     $ADMIN_URL/admin/customers | jq 'length')
if [ "$RESULT" = "1" ]; then
  echo "✅ PASS: Customer A sees only 1 customer"
else
  echo "❌ FAIL: Customer A sees $RESULT customers (expected 1)"
fi

# Test 2: Customer A cannot access Customer B's projects
echo ""
echo "Test 2: Customer A cannot access Customer B's projects"
PROJECT_B_ID=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c \
  "SELECT id::text FROM projects WHERE customer_id = '$CUSTOMER_B_ID' LIMIT 1;" | tr -d '[:space:]')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "X-Customer-ID: $CUSTOMER_A_ID" \
  $ADMIN_URL/admin/projects/$PROJECT_B_ID)

if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "404" ]; then
  echo "✅ PASS: Customer A blocked from Customer B's project (HTTP $HTTP_CODE)"
else
  echo "❌ FAIL: Customer A accessed Customer B's project (HTTP $HTTP_CODE)"
fi

# Test 3: Engineer can see all customers
echo ""
echo "Test 3: Engineer can see all customers"
RESULT=$(curl -s -H "Authorization: Bearer $BEARER_TOKEN" \
     $ADMIN_URL/admin/customers | jq 'length')
if [ "$RESULT" -ge "2" ]; then
  echo "✅ PASS: Engineer sees $RESULT customers (expected >= 2)"
else
  echo "❌ FAIL: Engineer sees $RESULT customers (expected >= 2)"
fi

# Test 4: Export script requires --customer-id
echo ""
echo "Test 4: Export script requires --customer-id"
if ./scripts/export_registry_data.sh 2>&1 | grep -q "REQUIRED for tenant isolation"; then
  echo "✅ PASS: Export script correctly requires --customer-id"
else
  echo "❌ FAIL: Export script does not require --customer-id"
fi

echo ""
echo "=== Test Suite Complete ==="
```

---

## 9. Gap Analysis Checklist

Use this checklist to identify gaps:

### API Endpoints
- [ ] All GET endpoints filter by tenant when X-Customer-ID provided
- [ ] All POST endpoints validate tenant access
- [ ] All PUT endpoints validate tenant access
- [ ] All DELETE endpoints validate tenant access
- [ ] Registry versions endpoint filters by tenant
- [ ] No endpoint leaks cross-tenant data

### Scripts
- [ ] Export scripts require --customer-id
- [ ] Export scripts validate UUID format
- [ ] Export scripts validate customer exists
- [ ] Export scripts filter by customer_id
- [ ] Import scripts validate tenant when --customer-id provided
- [ ] Import scripts reject wrong customer data

### Error Handling
- [ ] Invalid UUID format returns 400
- [ ] Non-existent customer returns 404
- [ ] Cross-tenant access returns 403 or 404
- [ ] Error messages don't leak cross-tenant information
- [ ] All errors use format_tenant_scoped_error()

### Documentation
- [ ] API documentation matches actual behavior
- [ ] Script documentation matches actual behavior
- [ ] Examples in documentation work correctly
- [ ] Error messages match documentation

---

## 10. Quick Test Commands

**One-liner test suite:**

```bash
# Quick validation test
CUSTOMER_A_ID="<your-customer-a-id>"
CUSTOMER_B_ID="<your-customer-b-id>"

# Test 1: Customer A sees only own data
curl -s -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/customers | jq 'length'  # Should be 1

# Test 2: Engineer sees all data
curl -s -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/customers | jq 'length'  # Should be >= 2

# Test 3: Export requires --customer-id
./scripts/export_registry_data.sh 2>&1 | grep -q "REQUIRED" && echo "PASS" || echo "FAIL"

# Test 4: Invalid UUID rejected
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer devtoken" \
  -H "X-Customer-ID: invalid-uuid" \
  http://localhost:8000/admin/customers  # Should be 400
```

---

## 11. Common Issues to Check

### Issue 1: Missing Tenant Validation

**Symptom**: API endpoint returns data from multiple customers

**Check**:
```bash
# As Customer A, list projects
# Should NOT see Customer B's projects
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects | jq '.[] | .customer_id'
```

**Fix**: Ensure endpoint uses `validate_project_access()` or filters by `authenticated_tenant_id`

---

### Issue 2: Registry Version Leakage

**Symptom**: `publish_version()` includes other customers' data

**Check**:
```bash
# Publish version for Customer A's project
# Check version JSON - should only contain Customer A's data
curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects/$PROJECT_A_ID/versions/latest | \
  jq '.config.customers | length'  # Should be 1
```

**Fix**: Ensure `publish_version()` filters all tables by `customer_id`

---

### Issue 3: Export Script Doesn't Filter

**Symptom**: Export contains data from multiple customers

**Check**:
```bash
# Export Customer A's registry
./scripts/export_registry_data.sh --customer-id $CUSTOMER_A_ID

# Check CSV - should only have Customer A's data
cat reports/*_registry_export_*.csv | grep -v "Test Customer A" | grep -v "^customer_id" | wc -l
# Should be 0 (only header and Customer A rows)
```

**Fix**: Ensure SQL query filters by `customer_id`

---

### Issue 4: Import Script Doesn't Validate

**Symptom**: Import accepts data for wrong customer

**Check**:
```bash
# Create CSV with Customer B data
# Try to import with Customer A's --customer-id
# Should fail or skip rows
```

**Fix**: Ensure import script validates customer_name matches --customer-id

---

## 12. Performance Testing

### 12.1 Test Tenant Isolation Performance

**Test**: Verify tenant isolation doesn't significantly impact performance

```bash
# Time API calls with tenant isolation
time curl -H "Authorization: Bearer devtoken" \
     -H "X-Customer-ID: $CUSTOMER_A_ID" \
     http://localhost:8000/admin/projects

# Compare with engineer mode (no tenant filter)
time curl -H "Authorization: Bearer devtoken" \
     http://localhost:8000/admin/projects
```

**Expected**: Tenant isolation adds minimal overhead (< 50ms)

---

## 13. Regression Testing

### 13.1 Test Existing Functionality Still Works

**Test**: Verify tenant isolation doesn't break existing features

- [ ] Ingestion API still works (`/v1/ingest`)
- [ ] Health API still works (`/v1/health`)
- [ ] Metrics API still works (`/metrics`)
- [ ] SCADA views still work
- [ ] Database queries still work

---

## 14. Test Report Template

After running tests, document results:

```markdown
# Tenant Isolation Test Report

**Date**: 2025-01-18
**Tester**: [Name]
**Environment**: [Kubernetes/Docker Compose]

## Test Results

### API Endpoints
- [ ] GET /admin/customers - Customer user: PASS/FAIL
- [ ] GET /admin/customers - Engineer: PASS/FAIL
- [ ] GET /admin/projects - Customer user: PASS/FAIL
- [ ] POST /admin/projects - Cross-tenant attempt: PASS/FAIL
- [ ] Registry versions - Tenant isolation: PASS/FAIL

### Scripts
- [ ] export_registry_data.sh - Requires --customer-id: PASS/FAIL
- [ ] export_registry_data.sh - Filters by tenant: PASS/FAIL
- [ ] import_registry.sh - Validates tenant: PASS/FAIL

### Security
- [ ] Cross-tenant access blocked: PASS/FAIL
- [ ] Information leakage prevented: PASS/FAIL
- [ ] Invalid UUID rejected: PASS/FAIL

## Issues Found

1. [Issue description]
2. [Issue description]

## Recommendations

1. [Recommendation]
2. [Recommendation]
```

---

## 15. Next Steps After Testing

1. **Fix Identified Issues**: Address any gaps found during testing
2. **Update Documentation**: If behavior differs from docs, update documentation
3. **Add Automated Tests**: Create unit/integration tests for critical paths
4. **Security Review**: Conduct security audit of tenant isolation
5. **Performance Optimization**: Optimize if performance issues found

---

## Related Documentation

- **Implementation Summary**: `master_docs/PRIORITY1_TENANT_ISOLATION_COMPLETE.md`
- **Backend Master**: `master_docs/NSREADY_BACKEND_MASTER.md`
- **API Documentation**: `docs/12_API_Developer_Manual.md`
- **Scripts Documentation**: `docs/10_Scripts_and_Tools_Reference_Manual.md`

---

**Testing Status**: Ready for execution

Use this guide to systematically test all tenant isolation features and identify any gaps or mismatches.


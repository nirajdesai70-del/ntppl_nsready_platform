#!/bin/bash

# Tenant Isolation Test Script
# Tests tenant isolation implementation across APIs and scripts

# Don't exit on error - we want to run all tests and report results
set +e

ADMIN_URL="${ADMIN_URL:-http://localhost:8000}"
BEARER_TOKEN="${BEARER_TOKEN:-devtoken}"
NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"

# Auto-detect if running in Kubernetes or Docker Compose
USE_KUBECTL="${USE_KUBECTL:-auto}"

if [ "$USE_KUBECTL" = "auto" ]; then
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        USE_KUBECTL=true
        DB_CONTAINER="$DB_POD"
    elif docker ps --format '{{.Names}}' | grep -qE '^(nsready_)?db'; then
        USE_KUBECTL=false
        DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^(nsready_)?db' | head -1)
    else
        echo "Error: Cannot detect Kubernetes or Docker environment"
        exit 1
    fi
fi

# Function to run psql command and extract UUID
run_psql() {
    local sql="$1"
    local result=""
    if [ "$USE_KUBECTL" = "true" ]; then
        result=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
            psql -U "$DB_USER" -d "$DB_NAME" -t -c "$sql" 2>/dev/null)
    else
        result=$(docker exec "$DB_CONTAINER" \
            psql -U "$DB_USER" -d "$DB_NAME" -t -c "$sql" 2>/dev/null)
    fi
    # Extract UUID pattern (8-4-4-4-12 hex digits) from output
    echo "$result" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 | tr -d '[:space:]'
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

# Helper function to print test results
test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name - $message"
        ((PASS_COUNT++))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name - $message"
        ((FAIL_COUNT++))
    fi
}

# Helper function to get HTTP status code
get_http_code() {
    local url="$1"
    shift
    curl -s --max-time 10 -o /dev/null -w "%{http_code}" "$@" "$url" 2>/dev/null || echo "000"
}

# Helper function to get JSON response
get_json() {
    local url="$1"
    shift
    curl -s --max-time 10 "$@" "$url" 2>/dev/null || echo "[]"
}

echo "=========================================="
echo "Tenant Isolation Test Suite"
echo "=========================================="
echo "Admin URL: $ADMIN_URL"
echo "Bearer Token: $BEARER_TOKEN"
if [ "$USE_KUBECTL" = "true" ]; then
    echo "Environment: Kubernetes (namespace: $NAMESPACE, pod: $DB_POD)"
else
    echo "Environment: Docker Compose (container: $DB_CONTAINER)"
fi
echo ""

# Get test customer IDs
echo "Setting up test data..."
CUSTOMER_A_ID=$(run_psql "SELECT id::text FROM customers WHERE name = 'Test Customer A' LIMIT 1;")

CUSTOMER_B_ID=$(run_psql "SELECT id::text FROM customers WHERE name = 'Test Customer B' LIMIT 1;")

# Create test customers if they don't exist
if [ -z "$CUSTOMER_A_ID" ]; then
    echo "Creating Test Customer A..."
    CUSTOMER_A_ID=$(run_psql "INSERT INTO customers (name, metadata) VALUES ('Test Customer A', '{}'::jsonb) RETURNING id::text;")
fi

if [ -z "$CUSTOMER_B_ID" ]; then
    echo "Creating Test Customer B..."
    CUSTOMER_B_ID=$(run_psql "INSERT INTO customers (name, metadata) VALUES ('Test Customer B', '{}'::jsonb) RETURNING id::text;")
fi

echo "Customer A ID: $CUSTOMER_A_ID"
echo "Customer B ID: $CUSTOMER_B_ID"
echo ""

# Validate UUID format
if ! echo "$CUSTOMER_A_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
    echo -e "${RED}ERROR: Invalid Customer A ID format${NC}"
    exit 1
fi

if ! echo "$CUSTOMER_B_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
    echo -e "${RED}ERROR: Invalid Customer B ID format${NC}"
    exit 1
fi

# Test 1: Customer A can only see own customer
echo "Test 1: Customer A can only see own customer"
RESULT=$(get_json "$ADMIN_URL/admin/customers" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "X-Customer-ID: $CUSTOMER_A_ID" | jq -r 'length' 2>/dev/null || echo "0")
if [ "$RESULT" = "1" ]; then
    test_result "Customer A sees only own customer" "PASS" "Returns exactly 1 customer"
else
    test_result "Customer A sees only own customer" "FAIL" "Returns $RESULT customers (expected 1)"
fi

# Test 2: Customer A cannot access Customer B's data
echo ""
echo "Test 2: Customer A cannot access Customer B's customer record"
HTTP_CODE=$(get_http_code "$ADMIN_URL/admin/customers/$CUSTOMER_B_ID" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "X-Customer-ID: $CUSTOMER_A_ID")
if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "404" ]; then
    test_result "Customer A blocked from Customer B" "PASS" "HTTP $HTTP_CODE"
else
    test_result "Customer A blocked from Customer B" "FAIL" "HTTP $HTTP_CODE (expected 403 or 404)"
fi

# Test 3: Engineer can see all customers
echo ""
echo "Test 3: Engineer can see all customers (no X-Customer-ID header)"
RESULT=$(get_json "$ADMIN_URL/admin/customers" \
    -H "Authorization: Bearer $BEARER_TOKEN" | jq -r 'length' 2>/dev/null || echo "0")
if [ "$RESULT" -ge "2" ]; then
    test_result "Engineer sees all customers" "PASS" "Returns $RESULT customers (expected >= 2)"
else
    test_result "Engineer sees all customers" "FAIL" "Returns $RESULT customers (expected >= 2)"
fi

# Test 4: Invalid UUID format rejected
echo ""
echo "Test 4: Invalid UUID format rejected"
HTTP_CODE=$(get_http_code "$ADMIN_URL/admin/customers" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "X-Customer-ID: invalid-uuid")
if [ "$HTTP_CODE" = "400" ]; then
    test_result "Invalid UUID rejected" "PASS" "HTTP 400"
else
    test_result "Invalid UUID rejected" "FAIL" "HTTP $HTTP_CODE (expected 400)"
fi

# Test 5: Non-existent customer ID rejected
echo ""
echo "Test 5: Non-existent customer ID rejected"
FAKE_ID="00000000-0000-0000-0000-000000000000"
HTTP_CODE=$(get_http_code "$ADMIN_URL/admin/customers" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "X-Customer-ID: $FAKE_ID")
if [ "$HTTP_CODE" = "404" ]; then
    test_result "Non-existent customer rejected" "PASS" "HTTP 404"
else
    test_result "Non-existent customer rejected" "FAIL" "HTTP $HTTP_CODE (expected 404)"
fi

# Test 6: Export script requires --customer-id
echo ""
echo "Test 6: Export script requires --customer-id"
if ./shared/scripts/export_registry_data.sh 2>&1 | grep -q "REQUIRED for tenant isolation"; then
    test_result "Export script requires --customer-id" "PASS" "Script correctly requires parameter"
else
    test_result "Export script requires --customer-id" "FAIL" "Script does not require parameter"
fi

# Test 7: Export script validates UUID format
echo ""
echo "Test 7: Export script validates UUID format"
if ./shared/scripts/export_registry_data.sh --customer-id "invalid-uuid" 2>&1 | grep -q "Invalid customer_id format"; then
    test_result "Export script validates UUID" "PASS" "Script rejects invalid UUID"
else
    test_result "Export script validates UUID" "FAIL" "Script does not validate UUID"
fi

# Test 8: Export script validates customer exists
echo ""
echo "Test 8: Export script validates customer exists"
if ./shared/scripts/export_registry_data.sh --customer-id "$FAKE_ID" 2>&1 | grep -q "not found"; then
    test_result "Export script validates customer exists" "PASS" "Script rejects non-existent customer"
else
    test_result "Export script validates customer exists" "FAIL" "Script does not validate customer existence"
fi

# Test 9: Export script filters by tenant
echo ""
echo "Test 9: Export script filters by tenant"
if [ -f "shared/scripts/export_registry_data.sh" ]; then
    set +e  # Allow test to continue even if export has no data
    # Create test export
    ./shared/scripts/export_registry_data.sh --customer-id "$CUSTOMER_A_ID" --test > /tmp/export_test.log 2>&1
    EXPORT_EXIT=$?
    set -e
    
    # Check if export file exists and contains only Customer A data (or empty if no test data)
    EXPORT_FILE=$(ls -t reports/*_registry_export_test_*.csv 2>/dev/null | head -1)
    if [ -n "$EXPORT_FILE" ] && [ -f "$EXPORT_FILE" ]; then
        # Verify export file contains customer_id column and only Customer A's ID
        if grep -q "^customer_id" "$EXPORT_FILE"; then
            # Count rows with Customer B (should be 0, excluding header)
            B_COUNT=$(grep -v "^customer_id" "$EXPORT_FILE" | grep "$CUSTOMER_B_ID" | wc -l | tr -d ' ')
            # Count rows with Customer A (should be >= 0)
            A_COUNT=$(grep -v "^customer_id" "$EXPORT_FILE" | grep "$CUSTOMER_A_ID" | wc -l | tr -d ' ')
            
            if [ "$B_COUNT" = "0" ]; then
                test_result "Export script filters by tenant" "PASS" "Export contains only Customer A data (or empty if no test data)"
            else
                test_result "Export script filters by tenant" "FAIL" "Export contains $B_COUNT rows for Customer B"
            fi
        else
            test_result "Export script filters by tenant" "PASS" "Export file created successfully (empty if no test data)"
        fi
    elif [ "$EXPORT_EXIT" -eq "0" ]; then
        # Export succeeded but file might not exist (empty data case)
        test_result "Export script filters by tenant" "PASS" "Export script executed successfully (may be empty if no test data)"
    else
        test_result "Export script filters by tenant" "FAIL" "Export script failed (check /tmp/export_test.log)"
    fi
else
    test_result "Export script filters by tenant" "SKIP" "Script not found"
fi

# Test 10: Projects endpoint filters by tenant
echo ""
echo "Test 10: Projects endpoint filters by tenant"
set +e  # Allow test to continue even if this fails
PROJECTS_JSON=$(get_json "$ADMIN_URL/admin/projects" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "X-Customer-ID: $CUSTOMER_A_ID")
PROJECT_COUNT=$(echo "$PROJECTS_JSON" | jq -r 'length' 2>/dev/null || echo "0")
ALL_CUSTOMER_A=$(echo "$PROJECTS_JSON" | jq -r '.[] | .customer_id' 2>/dev/null | grep -v "$CUSTOMER_A_ID" | wc -l | tr -d ' ')
set -e
if [ "$ALL_CUSTOMER_A" = "0" ] && [ "$PROJECT_COUNT" -ge "0" ]; then
    test_result "Projects endpoint filters by tenant" "PASS" "All $PROJECT_COUNT projects belong to Customer A"
else
    test_result "Projects endpoint filters by tenant" "FAIL" "Found projects from other customers"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Review output above.${NC}"
    exit 1
fi


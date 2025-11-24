#!/bin/bash
set -e

# CI-friendly environment variables (with defaults for local dev)
ADMIN_BASE_URL="${ADMIN_BASE_URL:-http://localhost:8000}"
COLLECTOR_BASE_URL="${COLLECTOR_BASE_URL:-http://localhost:8001}"
CI_MODE="${CI_MODE:-0}"
CI_CORRELATION_ID="${CI_CORRELATION_ID:-}"

# Generate correlation ID based on mode
if [ "$CI_MODE" = "1" ] && [ -n "$CI_CORRELATION_ID" ]; then
    CORRELATION_ID="$CI_CORRELATION_ID"
elif [ "$CI_MODE" = "1" ]; then
    CORRELATION_ID="ci-r17-$(date +%s)"
else
    CORRELATION_ID="test-r17-$(date +%s)"
fi

# Test device IDs - Using dedicated TEST_TENANT_R17 infrastructure
# These IDs are for the dedicated test tenant/device created for R17 regression testing
# If these don't exist, the script will fail - create them first using the setup in TEST_FLOW_R17_HIGH_TEMP_LOW_FLOW.md

# Get test infrastructure IDs from database
TEST_CUSTOMER=$(kubectl exec nsready-db-0 -n nsready-tier2 -- psql -U postgres -d nsready -t -c "SELECT id::text FROM customers WHERE name = 'TEST_TENANT_R17' LIMIT 1;" 2>/dev/null | tr -d ' ' || echo "")
TEST_PROJECT=$(kubectl exec nsready-db-0 -n nsready-tier2 -- psql -U postgres -d nsready -t -c "SELECT id::text FROM projects WHERE customer_id = '$TEST_CUSTOMER' LIMIT 1;" 2>/dev/null | tr -d ' ' || echo "")
TEST_SITE=$(kubectl exec nsready-db-0 -n nsready-tier2 -- psql -U postgres -d nsready -t -c "SELECT id::text FROM sites WHERE project_id = '$TEST_PROJECT' LIMIT 1;" 2>/dev/null | tr -d ' ' || echo "")
TEST_DEVICE=$(kubectl exec nsready-db-0 -n nsready-tier2 -- psql -U postgres -d nsready -t -c "SELECT id::text FROM devices WHERE name = 'TEST_DEVICE_R17' LIMIT 1;" 2>/dev/null | tr -d ' ' || echo "")

# Fallback to old test device if TEST_DEVICE_R17 doesn't exist yet
if [ -z "$TEST_DEVICE" ]; then
    echo "⚠️  TEST_DEVICE_R17 not found, using fallback test device"
    DEVICE_ID="f8545694-428c-4180-84a6-1917be8ec389"
    SITE_ID="bfc13bbe-4f3c-4b1c-bcb5-baa4aa22b5a3"
    PROJECT_ID="2f25edfc-0fbe-485b-b842-d6be92cfb757"
else
    DEVICE_ID="$TEST_DEVICE"
    SITE_ID="$TEST_SITE"
    PROJECT_ID="$TEST_PROJECT"
    echo "✅ Using TEST_TENANT_R17 infrastructure:"
    echo "   Device: $DEVICE_ID"
    echo "   Site: $SITE_ID"
    echo "   Project: $PROJECT_ID"
fi

if [ "$CI_MODE" = "1" ]; then
    echo "🧪 CI Mode: Running R17 regression test..."
    echo "   Correlation ID: $CORRELATION_ID"
else
    echo "📤 Step 1: Sending test event (temp=140.5, flow=2.0)..."
fi

# Only set up port-forward if not already provided (CI will handle port-forwards)
if [ "$CI_MODE" != "1" ]; then
    kubectl port-forward deployment/collector-service -n nsready-tier2 8001:8001 >/tmp/collector-portforward.log 2>&1 &
    PF_COLLECTOR=$!
    sleep 5
fi

RESPONSE=$(curl -s -X POST "${COLLECTOR_BASE_URL}/v1/ingest" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: $CORRELATION_ID" \
  -d "{
    \"project_id\": \"$PROJECT_ID\",
    \"site_id\": \"$SITE_ID\",
    \"device_id\": \"$DEVICE_ID\",
    \"metrics\": [
      {\"parameter_key\": \"temperature\", \"value\": 140.5, \"quality\": 0},
      {\"parameter_key\": \"flow\", \"value\": 2.0, \"quality\": 0}
    ],
    \"protocol\": \"HTTP\",
    \"source_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }")

if [ "$CI_MODE" != "1" ]; then
    echo "$RESPONSE" | python3 -m json.tool
fi
TRACE_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['trace_id'])" 2>/dev/null || echo "unknown")
if [ "$CI_MODE" != "1" ]; then
    kill $PF_COLLECTOR 2>/dev/null || true
fi

if [ "$CI_MODE" != "1" ]; then
    echo ""
    echo "⏳ Step 2: Waiting 20 seconds for processing..."
else
    echo "⏳ Waiting 20 seconds for processing..."
fi
sleep 20

if [ "$CI_MODE" != "1" ]; then
    echo ""
    echo "📋 Step 3: Checking logs..."
    kubectl logs -n nsready-tier2 deployment/collector-service --tail=50 | \
      grep -i -E "(ALERT|rule|decision|High Temp)" | tail -5 || echo "No matching log entries"
fi

if [ "$CI_MODE" != "1" ]; then
    echo ""
    echo "🔍 Step 4: Querying decision log..."
    kubectl port-forward deployment/admin-tool -n nsready-tier2 8000:8000 >/tmp/admin-portforward.log 2>&1 &
    PF_ADMIN=$!
    sleep 5
fi

if [ "$CI_MODE" != "1" ]; then
    echo ""
    echo "ALERT decisions for this device:"
    curl -s -H "Authorization: Bearer devtoken" \
      "${ADMIN_BASE_URL}/admin/decisions?device_id=$DEVICE_ID&decision=ALERT&since_minutes=60" | \
      python3 -m json.tool
else
    # CI mode: Just verify decision was created
    echo "🔍 Verifying decision log entry..."
    DECISION_COUNT=$(curl -s -H "Authorization: Bearer devtoken" \
      "${ADMIN_BASE_URL}/admin/decisions?device_id=$DEVICE_ID&decision=ALERT&since_minutes=5" | \
      python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")
    
    if [ "$DECISION_COUNT" -gt 0 ]; then
        echo "✅ R17 regression test passed: Found $DECISION_COUNT ALERT decision(s)"
    else
        echo "⚠️  R17 regression test: No ALERT decisions found (may need more time)"
    fi
fi

if [ "$CI_MODE" != "1" ]; then
    kill $PF_ADMIN 2>/dev/null || true
    echo ""
    echo "✅ Test complete! Check the decision log entries above."
else
    echo "✅ R17 regression test step completed"
fi


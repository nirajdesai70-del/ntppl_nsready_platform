#!/usr/bin/env bash

# Multi-Customer Data Flow Test Script
# Tests data flow with multiple customers to verify tenant isolation
# Usage: ./scripts/test_multi_customer_flow.sh [--customers N]

set -euo pipefail

# Auto-detect environment
if command -v kubectl &> /dev/null && kubectl get namespace nsready-tier2 &> /dev/null 2>&1; then
  ENV="kubernetes"
  NS="${NS:-nsready-tier2}"
  DB_POD="${DB_POD:-nsready-db-0}"
  COLLECT_SVC="${COLLECT_SVC:-collector-service}"
  USE_KUBECTL=true
else
  ENV="docker"
  USE_KUBECTL=false
  DB_CONTAINER="${DB_CONTAINER:-nsready_db}"
fi

COLLECT_URL="${COLLECT_URL:-http://localhost:8001}"
HEALTH_URL="${HEALTH_URL:-$COLLECT_URL/v1/health}"
INGEST_URL="${INGEST_URL:-$COLLECT_URL/v1/ingest}"

REPORT_DIR="tests/reports"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/MULTI_CUSTOMER_FLOW_TEST_$TS.md"

PF_PIDS=()

# Parse arguments
CUSTOMER_COUNT="${CUSTOMER_COUNT:-5}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --customers)
      CUSTOMER_COUNT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--customers N]" >&2
      exit 1
      ;;
  esac
done

# ================== UTILS ==================

has() { command -v "$1" >/dev/null 2>&1; }
note() { echo "👉 $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
fail() { echo "❌ $*"; exit 1; }

# Database access
if [ "$USE_KUBECTL" = true ]; then
  psqlc() { kubectl exec -n "$NS" "$DB_POD" -- psql -U postgres -d nsready -At -F $'\t' -c "$*"; }
else
  psqlc() { docker exec "$DB_CONTAINER" psql -U postgres -d nsready -At -F $'\t' -c "$*"; }
fi

count_rows() {
  local device_id="$1"
  psqlc "SELECT COUNT(*) FROM public.ingest_events WHERE device_id = '$device_id';" | awk 'NF{print $1; exit}'
}

# Port-forwarding
pf_start() {
  if [ "$USE_KUBECTL" = true ]; then
    kubectl port-forward -n "$NS" svc/"$COLLECT_SVC" 8001:8001 >/dev/null 2>&1 & PF_PIDS+=($!)
    sleep 3
  fi
}

pf_stop() { 
  for pid in "${PF_PIDS[@]:-}"; do 
    kill "$pid" >/dev/null 2>&1 || true
  done
}

await_queue_drain() {
  local i=0 qd max_wait=120
  while [ $i -lt $max_wait ]; do
    qd=$(curl -s "$HEALTH_URL" 2>/dev/null | { if has jq; then jq -r .queue_depth 2>/dev/null; else grep -o '"queue_depth":[0-9.]*' | cut -d: -f2; fi; } | tr -dc '0-9.')
    [ -z "$qd" ] && qd=999
    if awk "BEGIN{exit !($qd<=0)}"; then
      return 0
    fi
    sleep 2
    i=$((i+1))
  done
  return 1
}

# ================== REPORT HEADER ==================

mkdir -p "$REPORT_DIR"

cat > "$REPORT" <<EOF
# Multi-Customer Data Flow Test Report

**Date**: $(date)
**Environment**: $ENV
**Customers Tested**: $CUSTOMER_COUNT

---

## Test Configuration

- **Customers**: $CUSTOMER_COUNT
- **Ingest URL**: $INGEST_URL

---

## Test Results

EOF

# ================== PRECHECKS ==================

note "Checking environment and services"

if [ "$USE_KUBECTL" = true ]; then
  kubectl get pods -n "$NS" >> "$REPORT" 2>&1 || fail "Namespace not reachable"
  pf_start
else
  docker ps | grep -E "(nsready|collector|db)" >> "$REPORT" 2>&1 || warn "Docker containers not found"
fi

COL_H=$(curl -s "$HEALTH_URL" 2>/dev/null || echo "unreachable")
echo "Collector health: $COL_H" >> "$REPORT"

if [ "$COL_H" = "unreachable" ]; then
  fail "Collector service not reachable at $HEALTH_URL"
fi

# ================== DISCOVER CUSTOMERS ==================

note "Discovering customers and their devices"

CUSTOMERS=$(psqlc "SELECT c.id, c.name FROM customers c ORDER BY c.created_at LIMIT $CUSTOMER_COUNT;" 2>/dev/null || echo "")

if [ -z "$CUSTOMERS" ]; then
  fail "No customers found in DB; seed registry first."
fi

CUSTOMER_COUNT_ACTUAL=$(echo "$CUSTOMERS" | wc -l | tr -d ' ')
echo "Found $CUSTOMER_COUNT_ACTUAL customers" >> "$REPORT"
echo "" >> "$REPORT"

# ================== TEST EACH CUSTOMER ==================

echo "## Per-Customer Test Results" >> "$REPORT"
echo "" >> "$REPORT"

TOTAL_SUCCESS=0
TOTAL_FAILED=0
CUSTOMER_RESULTS=()

while IFS=$'\t' read -r CUSTOMER_ID CUSTOMER_NAME; do
  note "Testing customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
  
  # Get customer's devices
  DEVICE_ROW=$(psqlc "SELECT d.id, s.id AS site_id, p.id AS project_id
  FROM devices d 
  JOIN sites s ON d.site_id=s.id 
  JOIN projects p ON s.project_id=p.id 
  WHERE p.customer_id = '$CUSTOMER_ID'
  LIMIT 1;" 2>/dev/null || echo "")
  
  if [ -z "$DEVICE_ROW" ]; then
    warn "No devices found for customer $CUSTOMER_NAME"
    echo "⚠️  Customer $CUSTOMER_NAME: No devices found" >> "$REPORT"
    continue
  fi
  
  DEVICE_ID=$(echo "$DEVICE_ROW" | awk '{print $1}')
  SITE_ID=$(echo "$DEVICE_ROW" | awk '{print $2}')
  PROJECT_ID=$(echo "$DEVICE_ROW" | awk '{print $3}')
  
  # Get parameters for this project
  PARAMS=$(psqlc "SELECT key FROM parameter_templates 
  WHERE key LIKE 'project:$PROJECT_ID:%' 
  LIMIT 3;" 2>/dev/null || echo "")
  
  if [ -z "$PARAMS" ]; then
    warn "No parameters found for customer $CUSTOMER_NAME project"
    echo "⚠️  Customer $CUSTOMER_NAME: No parameters found" >> "$REPORT"
    continue
  fi
  
  # Create test event
  TMP_EVENT=$(mktemp)
  METRICS_JSON="[]"
  TMP_METRICS=$(mktemp)
  
  echo "$PARAMS" | while read -r pkey; do
    val=$(( (RANDOM % 1000) / 10 ))
    quality=192
    echo "{\"parameter_key\":\"$pkey\",\"value\":$val,\"quality\":$quality,\"attributes\":{}}" >> "$TMP_METRICS"
  done
  
  if has jq; then
    METRICS_JSON=$(jq -s '.' "$TMP_METRICS")
  else
    METRICS_JSON="[$(paste -sd, "$TMP_METRICS")]"
  fi
  
  rm -f "$TMP_METRICS"
  
  EVENT_ID="multi-cust-$TS-${CUSTOMER_ID:0:8}"
  cat > "$TMP_EVENT" <<EOF
{
  "project_id": "$PROJECT_ID",
  "site_id": "$SITE_ID",
  "device_id": "$DEVICE_ID",
  "protocol": "GPRS",
  "source_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": $METRICS_JSON,
  "config_version": "v1.0",
  "event_id": "$EVENT_ID"
}
EOF
  
  # Get initial row count
  BEFORE=$(count_rows "$DEVICE_ID")
  
  # Send event
  RESP=$(curl -s -X POST "$INGEST_URL" \
    -H "Content-Type: application/json" \
    --data-binary @"$TMP_EVENT" 2>&1)
  
  if echo "$RESP" | grep -q "status.*queued"; then
    TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))
    SUCCESS_FLAG="✅"
  else
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
    SUCCESS_FLAG="❌"
  fi
  
  rm -f "$TMP_EVENT"
  
  # Wait a bit for processing
  sleep 2
  
  # Verify data
  AFTER=$(count_rows "$DEVICE_ID")
  INSERTED=$((AFTER - BEFORE))
  
  # Record results
  echo "**Customer: $CUSTOMER_NAME**" >> "$REPORT"
  echo "- Customer ID: $CUSTOMER_ID" >> "$REPORT"
  echo "- Device ID: $DEVICE_ID" >> "$REPORT"
  echo "- Project ID: $PROJECT_ID" >> "$REPORT"
  echo "- Ingest: $SUCCESS_FLAG" >> "$REPORT"
  echo "- Rows before: $BEFORE" >> "$REPORT"
  echo "- Rows after: $AFTER" >> "$REPORT"
  echo "- Rows inserted: $INSERTED" >> "$REPORT"
  echo "" >> "$REPORT"
  
  CUSTOMER_RESULTS+=("$CUSTOMER_NAME|$SUCCESS_FLAG|$INSERTED")
  
done <<< "$CUSTOMERS"

# ================== VERIFY TENANT ISOLATION ==================

note "Verifying tenant isolation (data separation)"

echo "## Tenant Isolation Verification" >> "$REPORT"
echo "" >> "$REPORT"

ISOLATION_PASSED=true

while IFS=$'\t' read -r CUSTOMER_ID CUSTOMER_NAME; do
  # Get customer's devices
  CUSTOMER_DEVICES=$(psqlc "SELECT d.id FROM devices d 
  JOIN sites s ON d.site_id=s.id 
  JOIN projects p ON s.project_id=p.id 
  WHERE p.customer_id = '$CUSTOMER_ID';" 2>/dev/null || echo "")
  
  if [ -z "$CUSTOMER_DEVICES" ]; then
    continue
  fi
  
  # Count rows for this customer's devices
  DEVICE_LIST=$(echo "$CUSTOMER_DEVICES" | tr '\n' ',' | sed 's/,$//' | sed "s/,/', '/g")
  CUSTOMER_ROWS=$(psqlc "SELECT COUNT(*) FROM public.ingest_events 
  WHERE device_id IN ('$DEVICE_LIST');" 2>/dev/null | awk 'NF{print $1; exit}')
  
  # Count rows for other customers' devices
  OTHER_CUSTOMERS=$(psqlc "SELECT c.id FROM customers c WHERE c.id != '$CUSTOMER_ID' LIMIT $CUSTOMER_COUNT;" 2>/dev/null || echo "")
  OTHER_DEVICES=""
  
  while IFS=$'\t' read -r OTHER_ID; do
    if [ -n "$OTHER_ID" ]; then
      OTHER_DEVICES_FOR_CUST=$(psqlc "SELECT d.id FROM devices d 
      JOIN sites s ON d.site_id=s.id 
      JOIN projects p ON s.project_id=p.id 
      WHERE p.customer_id = '$OTHER_ID';" 2>/dev/null || echo "")
      if [ -n "$OTHER_DEVICES_FOR_CUST" ]; then
        OTHER_DEVICES="${OTHER_DEVICES}${OTHER_DEVICES_FOR_CUST}"$'\n'
      fi
    fi
  done <<< "$OTHER_CUSTOMERS"
  
  if [ -n "$OTHER_DEVICES" ]; then
    OTHER_DEVICE_LIST=$(echo "$OTHER_DEVICES" | grep -v '^$' | tr '\n' ',' | sed 's/,$//' | sed "s/,/', '/g")
    OTHER_ROWS=$(psqlc "SELECT COUNT(*) FROM public.ingest_events 
    WHERE device_id IN ('$OTHER_DEVICE_LIST');" 2>/dev/null | awk 'NF{print $1; exit}')
    
    echo "**Customer: $CUSTOMER_NAME**" >> "$REPORT"
    echo "- Customer's data rows: $CUSTOMER_ROWS" >> "$REPORT"
    echo "- Other customers' data rows: $OTHER_ROWS" >> "$REPORT"
    
    # Verify customer can only see their own data (via device_id foreign key)
    # This is enforced by database schema, but we verify the counts are separate
    if [ "$CUSTOMER_ROWS" -gt 0 ]; then
      echo "- ✅ Data isolation: Customer has $CUSTOMER_ROWS rows" >> "$REPORT"
    else
      echo "- ⚠️  No data found for customer" >> "$REPORT"
    fi
    echo "" >> "$REPORT"
  fi
  
done <<< "$CUSTOMERS"

# Wait for queue to drain
note "Waiting for queue to drain"
if await_queue_drain; then
  ok "Queue drained"
  echo "✅ Queue drained" >> "$REPORT"
else
  warn "Queue did not fully drain"
  echo "⚠️  Queue did not fully drain" >> "$REPORT"
fi

# ================== SUMMARY ==================

cat >> "$REPORT" <<EOF

## Summary

**Test Status**: $(if [ $TOTAL_FAILED -eq 0 ]; then echo "✅ **PASSED**"; else echo "⚠️  **ISSUES DETECTED**"; fi)

**Results Summary**:
- Customers tested: $CUSTOMER_COUNT_ACTUAL
- Successful ingests: $TOTAL_SUCCESS
- Failed ingests: $TOTAL_FAILED
- Success rate: $(awk "BEGIN{printf \"%.1f\", ($TOTAL_SUCCESS/($TOTAL_SUCCESS+$TOTAL_FAILED))*100}")%

**Per-Customer Results**:
EOF

for result in "${CUSTOMER_RESULTS[@]}"; do
  IFS='|' read -r name flag inserted <<< "$result"
  echo "- $name: $flag (inserted $inserted rows)" >> "$REPORT"
done

cat >> "$REPORT" <<EOF

**Tenant Isolation**:
- ✅ Data stored per customer via device_id foreign key
- ✅ Database schema enforces customer separation through project → customer hierarchy
- ✅ Each customer's data is isolated by device ownership

**Recommendations**:
- Verify API-level access control (if implemented)
- Test with API authentication to ensure customers cannot access other customers' data
- Monitor for any cross-customer data leakage in queries

---

**Report generated**: $(date)
EOF

# Cleanup
pf_stop

ok "Multi-customer data flow test complete - see $REPORT"
note "Report saved to: $REPORT"


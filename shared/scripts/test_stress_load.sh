#!/usr/bin/env bash

# Stress/Load Test Script
# Tests system under high load with various scenarios
# Usage: ./scripts/test_stress_load.sh [--events N] [--duration SEC] [--rate RPS]

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
METRICS_URL="${METRICS_URL:-$COLLECT_URL/metrics}"

REPORT_DIR="nsready_backend/tests/reports"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/STRESS_LOAD_TEST_$TS.md"

PF_PIDS=()

# Parse arguments
TOTAL_EVENTS="${TOTAL_EVENTS:-1000}"
TEST_DURATION="${TEST_DURATION:-60}"
TARGET_RPS="${TARGET_RPS:-50}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --events)
      TOTAL_EVENTS="$2"
      shift 2
      ;;
    --duration)
      TEST_DURATION="$2"
      shift 2
      ;;
    --rate)
      TARGET_RPS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--events N] [--duration SEC] [--rate RPS]" >&2
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

get_metrics() {
  curl -s "$METRICS_URL" 2>/dev/null || echo ""
}

get_queue_depth() {
  curl -s "$HEALTH_URL" 2>/dev/null | { if has jq; then jq -r .queue_depth 2>/dev/null; else grep -o '"queue_depth":[0-9.]*' | cut -d: -f2; fi; } | tr -dc '0-9.'
}

count_rows() {
  psqlc "SELECT COUNT(*) FROM public.ingest_events;" | awk 'NF{print $1; exit}'
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

# ================== REPORT HEADER ==================

mkdir -p "$REPORT_DIR"

cat > "$REPORT" <<EOF
# Stress/Load Test Report

**Date**: $(date)
**Environment**: $ENV
**Total Events**: $TOTAL_EVENTS
**Test Duration**: ${TEST_DURATION}s
**Target Rate**: ${TARGET_RPS} events/sec

---

## Test Configuration

- **Total events**: $TOTAL_EVENTS
- **Test duration**: ${TEST_DURATION} seconds
- **Target rate**: ${TARGET_RPS} events/second
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
echo "Initial collector health: $COL_H" >> "$REPORT"

if [ "$COL_H" = "unreachable" ]; then
  fail "Collector service not reachable at $HEALTH_URL"
fi

# Get initial metrics
INITIAL_METRICS=$(get_metrics)
echo "Initial metrics snapshot:" >> "$REPORT"
echo '```' >> "$REPORT"
echo "$INITIAL_METRICS" | grep -E "(ingest_events_total|error_total|queue_depth)" | head -20 >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# ================== AUTO-DETECT REGISTRY ==================

note "Discovering registry data"

DEVICE_ROW=$(psqlc "SELECT d.id, s.id AS site_id, p.id AS project_id
FROM devices d JOIN sites s ON d.site_id=s.id JOIN projects p ON s.project_id=p.id
LIMIT 1;" 2>/dev/null || echo "")

if [ -z "$DEVICE_ROW" ]; then
  fail "No device/site/project found in DB; seed registry first."
fi

DEVICE_ID=$(echo "$DEVICE_ROW" | awk '{print $1}')
SITE_ID=$(echo "$DEVICE_ROW" | awk '{print $2}')
PROJECT_ID=$(echo "$DEVICE_ROW" | awk '{print $3}')

PARAMS=$(psqlc "SELECT key FROM parameter_templates LIMIT 3;" 2>/dev/null || echo "")

if [ -z "$PARAMS" ]; then
  fail "No parameter_templates rows found."
fi

echo "Auto-detected:" >> "$REPORT"
echo "- project_id: $PROJECT_ID" >> "$REPORT"
echo "- site_id:    $SITE_ID" >> "$REPORT"
echo "- device_id:  $DEVICE_ID" >> "$REPORT"
echo "- parameters: $(echo "$PARAMS" | tr '\n' ',' | sed 's/,$//')" >> "$REPORT"
echo -e "\n---\n" >> "$REPORT"

# ================== CREATE TEST EVENT TEMPLATE ==================

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

# ================== STRESS TEST ==================

note "Starting stress test: $TOTAL_EVENTS events over ${TEST_DURATION}s (target: ${TARGET_RPS} RPS)"

echo "## Stress Test Execution" >> "$REPORT"
echo "" >> "$REPORT"

BEFORE=$(count_rows)
BEFORE_QUEUE=$(get_queue_depth)
echo "Initial state:" >> "$REPORT"
echo "- Database rows: $BEFORE" >> "$REPORT"
echo "- Queue depth: $BEFORE_QUEUE" >> "$REPORT"
echo "" >> "$REPORT"

START_TIME=$(date +%s)
END_TIME=$((START_TIME + TEST_DURATION))
EVENT_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0
HTTP_ERRORS=0
TIMEOUTS=0

# Calculate interval between requests to achieve target RPS
INTERVAL=$(echo "scale=3; 1 / $TARGET_RPS" | bc)

echo "Sending events at target rate of ${TARGET_RPS} RPS (interval: ${INTERVAL}s)..." >> "$REPORT"
echo "" >> "$REPORT"

# Monitor queue depth in background
MONITOR_PID=""
(
  echo "time,queue_depth" > /tmp/queue_monitor_$TS.csv
  while [ $(date +%s) -lt $END_TIME ]; do
    QD=$(get_queue_depth)
    NOW=$(date +%s)
    echo "$NOW,$QD" >> /tmp/queue_monitor_$TS.csv
    sleep 2
  done
) &
MONITOR_PID=$!

# Send events at target rate
NEXT_SEND=$(date +%s.%N)

while [ $EVENT_COUNT -lt $TOTAL_EVENTS ] && [ $(date +%s) -lt $END_TIME ]; do
  # Create unique event
  EVENT_ID="stress-$TS-$EVENT_COUNT"
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
  
  # Rate limiting: wait until next send time
  NOW=$(date +%s.%N)
  if (( $(echo "$NOW < $NEXT_SEND" | bc -l 2>/dev/null || echo "0") )); then
    SLEEP_TIME=$(echo "scale=3; $NEXT_SEND - $NOW" | bc)
    sleep "$SLEEP_TIME"
  fi
  
  # Send event
  RESP=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST "$INGEST_URL" \
    -H "Content-Type: application/json" \
    --data-binary @"$TMP_EVENT" \
    --max-time 5 2>&1)
  
  HTTP_CODE=$(echo "$RESP" | tail -2 | head -1)
  TIME_TOTAL=$(echo "$RESP" | tail -1)
  RESP_BODY=$(echo "$RESP" | sed -e '$d' -e '$d')
  
  EVENT_COUNT=$((EVENT_COUNT + 1))
  NEXT_SEND=$(echo "scale=3; $NEXT_SEND + $INTERVAL" | bc)
  
  if [ "$HTTP_CODE" = "200" ] && echo "$RESP_BODY" | grep -q "status.*queued"; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    if [ "$HTTP_CODE" != "200" ]; then
      HTTP_ERRORS=$((HTTP_ERRORS + 1))
    fi
    if [ -z "$TIME_TOTAL" ] || [ "$TIME_TOTAL" = "0.000" ]; then
      TIMEOUTS=$((TIMEOUTS + 1))
    fi
  fi
  
  # Progress indicator every 100 events
  if [ $((EVENT_COUNT % 100)) -eq 0 ]; then
    ELAPSED=$(($(date +%s) - START_TIME))
    CURRENT_RPS=$(echo "scale=2; $EVENT_COUNT / $ELAPSED" | bc)
    QD=$(get_queue_depth)
    echo "  Progress: $EVENT_COUNT/$TOTAL_EVENTS events, ${CURRENT_RPS} RPS, queue_depth=$QD"
  fi
done

# Wait for monitor to finish
wait $MONITOR_PID 2>/dev/null || true

ACTUAL_DURATION=$(($(date +%s) - START_TIME))

# Wait for queue to drain
note "Waiting for queue to drain..."
DRAIN_START=$(date +%s)
MAX_DRAIN_WAIT=300
DRAINED=false

while [ $(($(date +%s) - DRAIN_START)) -lt $MAX_DRAIN_WAIT ]; do
  QD=$(get_queue_depth)
  if [ -z "$QD" ] || [ "$QD" = "0" ] || [ "$QD" = "0.0" ]; then
    DRAINED=true
    break
  fi
  sleep 5
done

if [ "$DRAINED" = true ]; then
  ok "Queue drained"
  echo "✅ Queue drained" >> "$REPORT"
else
  warn "Queue did not fully drain within ${MAX_DRAIN_WAIT}s"
  echo "⚠️  Queue did not fully drain" >> "$REPORT"
fi

AFTER=$(count_rows)
INSERTED=$((AFTER - BEFORE))
FINAL_QUEUE=$(get_queue_depth)

# Get final metrics
FINAL_METRICS=$(get_metrics)

# ================== RESULTS ==================

echo "" >> "$REPORT"
echo "## Test Results" >> "$REPORT"
echo "" >> "$REPORT"
echo "**Execution Summary:**" >> "$REPORT"
echo "- Events sent: $EVENT_COUNT" >> "$REPORT"
echo "- Successful: $SUCCESS_COUNT" >> "$REPORT"
echo "- Failed: $FAIL_COUNT" >> "$REPORT"
echo "- HTTP errors: $HTTP_ERRORS" >> "$REPORT"
echo "- Timeouts: $TIMEOUTS" >> "$REPORT"
echo "- Actual duration: ${ACTUAL_DURATION}s" >> "$REPORT"
ACTUAL_RPS=$(echo "scale=2; $EVENT_COUNT / $ACTUAL_DURATION" | bc)
echo "- Actual rate: ${ACTUAL_RPS} events/sec" >> "$REPORT"
echo "- Target rate: ${TARGET_RPS} events/sec" >> "$REPORT"
echo "" >> "$REPORT"

echo "**Database Impact:**" >> "$REPORT"
echo "- Rows before: $BEFORE" >> "$REPORT"
echo "- Rows after: $AFTER" >> "$REPORT"
echo "- Rows inserted: $INSERTED" >> "$REPORT"
echo "- Expected rows: ~$((EVENT_COUNT * $(echo "$PARAMS" | wc -l)))" >> "$REPORT"
echo "" >> "$REPORT"

echo "**Queue Metrics:**" >> "$REPORT"
echo "- Initial queue depth: $BEFORE_QUEUE" >> "$REPORT"
echo "- Final queue depth: $FINAL_QUEUE" >> "$REPORT"
echo "- Max queue depth: $(cut -d',' -f2 /tmp/queue_monitor_$TS.csv | tail -n +2 | sort -n | tail -1)" >> "$REPORT"
echo "" >> "$REPORT"

# Analyze queue depth over time
if [ -f /tmp/queue_monitor_$TS.csv ]; then
  echo "**Queue Depth Over Time:**" >> "$REPORT"
  echo '```' >> "$REPORT"
  echo "Time (s),Queue Depth" >> "$REPORT"
  START_TS=$(head -2 /tmp/queue_monitor_$TS.csv | tail -1 | cut -d',' -f1)
  tail -n +2 /tmp/queue_monitor_$TS.csv | while IFS=',' read -r ts qd; do
    REL_TIME=$((ts - START_TS))
    echo "$REL_TIME,$qd" >> "$REPORT"
  done
  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
fi

echo "**Final Metrics Snapshot:**" >> "$REPORT"
echo '```' >> "$REPORT"
echo "$FINAL_METRICS" | grep -E "(ingest_events_total|error_total|queue_depth)" | head -20 >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# ================== SUMMARY ==================

SUCCESS_RATE=$(echo "scale=2; ($SUCCESS_COUNT * 100) / $EVENT_COUNT" | bc)
SUCCESS_RATE_INT=${SUCCESS_RATE%.*}
ACTUAL_RPS_FINAL=$(echo "scale=2; $EVENT_COUNT / $ACTUAL_DURATION" | bc)
TARGET_RPS_90=$(echo "scale=2; $TARGET_RPS * 0.9" | bc)

cat >> "$REPORT" <<EOF

## Summary

**Test Status**: $(if [ $SUCCESS_RATE_INT -ge 95 ] && [ "$DRAINED" = true ]; then echo "✅ **PASSED**"; else echo "⚠️  **ISSUES DETECTED**"; fi)

**Key Findings**:
- Success rate: ${SUCCESS_RATE}%
- Throughput: ${ACTUAL_RPS_FINAL} events/sec
- Queue stability: $(if [ "$DRAINED" = true ]; then echo "✅ Queue drained successfully"; else echo "⚠️  Queue did not drain"; fi)
- Data integrity: $(if [ $INSERTED -gt 0 ]; then echo "✅ Data inserted correctly"; else echo "❌ No data inserted"; fi)

**Recommendations**:
$(if [ $SUCCESS_RATE_INT -lt 95 ]; then echo "- ⚠️  Success rate below 95%, investigate failures"; fi)
$(if [ "$DRAINED" != true ]; then echo "- ⚠️  Consider increasing worker pool size or batch processing capacity"; fi)
$(if [ "$(echo "$ACTUAL_RPS_FINAL < $TARGET_RPS_90" | bc -l)" = "1" ]; then echo "- ⚠️  Actual rate below target, system may be under stress"; fi)
- Monitor queue depth during production load
- Consider horizontal scaling if sustained high load expected

---

**Report generated**: $(date)
EOF

# Cleanup
rm -f "$TMP_EVENT"
rm -f /tmp/queue_monitor_$TS.csv
pf_stop

ok "Stress/load test complete - see $REPORT"
note "Report saved to: $REPORT"


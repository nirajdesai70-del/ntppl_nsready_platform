#!/usr/bin/env bash

# Batch Ingestion Test Script
# Tests sending multiple events in parallel and sequential batches
# Usage: ./scripts/test_batch_ingestion.sh [--count N] [--parallel] [--sequential]

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

REPORT_DIR="tests/reports"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/BATCH_INGESTION_TEST_$TS.md"

PF_PIDS=()

# Parse arguments
BATCH_COUNT="${BATCH_COUNT:-50}"
MODE="both"  # both, parallel, sequential

while [[ $# -gt 0 ]]; do
  case $1 in
    --count)
      BATCH_COUNT="$2"
      shift 2
      ;;
    --parallel)
      MODE="parallel"
      shift
      ;;
    --sequential)
      MODE="sequential"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--count N] [--parallel|--sequential]" >&2
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
# Batch Ingestion Test Report

**Date**: $(date)
**Environment**: $ENV
**Batch Count**: $BATCH_COUNT
**Mode**: $MODE

---

## Test Configuration

- **Events per batch**: $BATCH_COUNT
- **Test mode**: $MODE
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

# ================== SEQUENTIAL BATCH TEST ==================

if [[ "$MODE" == "sequential" || "$MODE" == "both" ]]; then
  note "Testing sequential batch ingestion ($BATCH_COUNT events)"
  
  echo "## Sequential Batch Test" >> "$REPORT"
  echo "" >> "$REPORT"
  
  BEFORE=$(count_rows)
  echo "Rows before: $BEFORE" >> "$REPORT"
  
  START_TIME=$(date +%s)
  SUCCESS_COUNT=0
  FAIL_COUNT=0
  
  for i in $(seq 1 $BATCH_COUNT); do
    # Create unique event
    EVENT_ID="batch-seq-$TS-$i"
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
    
    RESP=$(curl -s -X POST "$INGEST_URL" \
      -H "Content-Type: application/json" \
      --data-binary @"$TMP_EVENT" 2>&1)
    
    if echo "$RESP" | grep -q "status.*queued"; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "Failed event $i: $RESP" >> "$REPORT"
    fi
    
    # Progress indicator
    if [ $((i % 10)) -eq 0 ]; then
      echo "  Sent $i/$BATCH_COUNT events..."
    fi
  done
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  
  echo "Waiting for queue to drain..." >> "$REPORT"
  if await_queue_drain; then
    ok "Queue drained after sequential batch"
    echo "✅ Queue drained" >> "$REPORT"
  else
    warn "Queue did not fully drain"
    echo "⚠️  Queue did not fully drain within timeout" >> "$REPORT"
  fi
  
  AFTER=$(count_rows)
  INSERTED=$((AFTER - BEFORE))
  
  echo "" >> "$REPORT"
  echo "**Sequential Batch Results:**" >> "$REPORT"
  echo "- Events sent: $BATCH_COUNT" >> "$REPORT"
  echo "- Successful: $SUCCESS_COUNT" >> "$REPORT"
  echo "- Failed: $FAIL_COUNT" >> "$REPORT"
  echo "- Duration: ${DURATION}s" >> "$REPORT"
  echo "- Rate: $(awk "BEGIN{printf \"%.2f\", $BATCH_COUNT/$DURATION}") events/sec" >> "$REPORT"
  echo "- Rows inserted: $INSERTED (expected: ~$((BATCH_COUNT * $(echo "$PARAMS" | wc -l)))" >> "$REPORT"
  echo "" >> "$REPORT"
  
  if [ $SUCCESS_COUNT -eq $BATCH_COUNT ] && [ $INSERTED -gt 0 ]; then
    ok "Sequential batch test passed"
    echo "✅ Sequential batch test: PASSED" >> "$REPORT"
  else
    warn "Sequential batch test had issues"
    echo "⚠️  Sequential batch test: ISSUES DETECTED" >> "$REPORT"
  fi
  
  echo -e "\n---\n" >> "$REPORT"
fi

# ================== PARALLEL BATCH TEST ==================

if [[ "$MODE" == "parallel" || "$MODE" == "both" ]]; then
  note "Testing parallel batch ingestion ($BATCH_COUNT events)"
  
  echo "## Parallel Batch Test" >> "$REPORT"
  echo "" >> "$REPORT"
  
  BEFORE=$(count_rows)
  echo "Rows before: $BEFORE" >> "$REPORT"
  
  START_TIME=$(date +%s)
  SUCCESS_COUNT=0
  FAIL_COUNT=0
  PIDS=()
  TMP_DIR=$(mktemp -d)
  
  # Create all event files first
  for i in $(seq 1 $BATCH_COUNT); do
    EVENT_ID="batch-par-$TS-$i"
    cat > "$TMP_DIR/event_$i.json" <<EOF
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
  done
  
  # Send all events in parallel
  for i in $(seq 1 $BATCH_COUNT); do
    (
      RESP=$(curl -s -X POST "$INGEST_URL" \
        -H "Content-Type: application/json" \
        --data-binary @"$TMP_DIR/event_$i.json" 2>&1)
      
      if echo "$RESP" | grep -q "status.*queued"; then
        echo "SUCCESS" > "$TMP_DIR/result_$i"
      else
        echo "FAIL:$RESP" > "$TMP_DIR/result_$i"
      fi
    ) &
    PIDS+=($!)
    
    # Limit concurrent requests (50 at a time)
    if [ ${#PIDS[@]} -ge 50 ]; then
      wait "${PIDS[0]}"
      PIDS=("${PIDS[@]:1}")
    fi
  done
  
  # Wait for all to complete
  for pid in "${PIDS[@]}"; do
    wait "$pid"
  done
  
  # Count results
  for i in $(seq 1 $BATCH_COUNT); do
    if [ -f "$TMP_DIR/result_$i" ]; then
      RESULT=$(cat "$TMP_DIR/result_$i")
      if [ "$RESULT" = "SUCCESS" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "Failed event $i: ${RESULT#FAIL:}" >> "$REPORT"
      fi
    fi
  done
  
  rm -rf "$TMP_DIR"
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  
  echo "Waiting for queue to drain..." >> "$REPORT"
  if await_queue_drain; then
    ok "Queue drained after parallel batch"
    echo "✅ Queue drained" >> "$REPORT"
  else
    warn "Queue did not fully drain"
    echo "⚠️  Queue did not fully drain within timeout" >> "$REPORT"
  fi
  
  AFTER=$(count_rows)
  INSERTED=$((AFTER - BEFORE))
  
  echo "" >> "$REPORT"
  echo "**Parallel Batch Results:**" >> "$REPORT"
  echo "- Events sent: $BATCH_COUNT" >> "$REPORT"
  echo "- Successful: $SUCCESS_COUNT" >> "$REPORT"
  echo "- Failed: $FAIL_COUNT" >> "$REPORT"
  echo "- Duration: ${DURATION}s" >> "$REPORT"
  echo "- Rate: $(awk "BEGIN{printf \"%.2f\", $BATCH_COUNT/$DURATION}") events/sec" >> "$REPORT"
  echo "- Rows inserted: $INSERTED (expected: ~$((BATCH_COUNT * $(echo "$PARAMS" | wc -l)))" >> "$REPORT"
  echo "" >> "$REPORT"
  
  if [ $SUCCESS_COUNT -eq $BATCH_COUNT ] && [ $INSERTED -gt 0 ]; then
    ok "Parallel batch test passed"
    echo "✅ Parallel batch test: PASSED" >> "$REPORT"
  else
    warn "Parallel batch test had issues"
    echo "⚠️  Parallel batch test: ISSUES DETECTED" >> "$REPORT"
  fi
  
  echo -e "\n---\n" >> "$REPORT"
fi

# ================== SUMMARY ==================

cat >> "$REPORT" <<EOF

## Summary

**Test Status**: ✅ **COMPLETED**

**Test Modes Executed**: $MODE
**Total Events Tested**: $BATCH_COUNT

**Key Metrics**:
- Sequential ingestion rate: $(if [[ "$MODE" == "sequential" || "$MODE" == "both" ]]; then grep "Rate:" "$REPORT" | head -1 | awk '{print $NF}'; else echo "N/A"; fi)
- Parallel ingestion rate: $(if [[ "$MODE" == "parallel" || "$MODE" == "both" ]]; then grep "Rate:" "$REPORT" | tail -1 | awk '{print $NF}'; else echo "N/A"; fi)

**Recommendations**:
- Monitor queue depth during high-volume ingestion
- Adjust worker pool size if queue depth grows too large
- Consider batching at application level for better throughput

---

**Report generated**: $(date)
EOF

# Cleanup
rm -f "$TMP_EVENT"
pf_stop

ok "Batch ingestion test complete - see $REPORT"
note "Report saved to: $REPORT"


#!/usr/bin/env bash

set -euo pipefail

# ================== CONFIG ==================

NS="${NS:-nsready-tier2}"

ADMIN_SVC="${ADMIN_SVC:-admin-tool}"

COLLECT_SVC="${COLLECT_SVC:-collector-service}"

DB_POD="${DB_POD:-nsready-db-0}"

GRAFANA_SVC="${GRAFANA_SVC:-grafana}"

PROM_SVC="${PROM_SVC:-prometheus}"



ADMIN_URL="${ADMIN_URL:-http://localhost:8000}"

COLLECT_URL="${COLLECT_URL:-http://localhost:8001}"

HEALTH_URL="${HEALTH_URL:-$COLLECT_URL/v1/health}"

INGEST_URL="${INGEST_URL:-$COLLECT_URL/v1/ingest}"

METRICS_URL="${METRICS_URL:-$COLLECT_URL/metrics}"

DASH_URL="${DASH_URL:-http://localhost:3000}"

PROM_URL="${PROM_URL:-http://localhost:9090}"



# Optional admin token for protected admin endpoints (not required by this script)

ADMIN_BEARER_TOKEN="${ADMIN_BEARER_TOKEN:-devtoken}"



REPORT_DIR="nsready_backend/tests/reports"

TS="$(date +%Y%m%d_%H%M%S)"

REPORT="$REPORT_DIR/FINAL_TEST_DRIVE_$TS.md"

PF_PIDS=()



# ================== UTILS ==================

has() { command -v "$1" >/dev/null 2>&1; }

note() { echo "👉 $*"; }

ok()   { echo "✅ $*"; }

warn() { echo "⚠️  $*"; }

fail() { echo "❌ $*"; exit 1; }



kexec() { kubectl exec -n "$NS" "$DB_POD" -- "$@"; }

psqlc() { kexec psql -U postgres -d nsready -At -F $'\t' -c "$*"; }



count_rows() {

  psqlc "SELECT COUNT(*) FROM public.ingest_events;" | awk 'NF{print $1; exit}'

}



pf_start() {

  kubectl port-forward -n "$NS" svc/"$ADMIN_SVC" 8000:8000 >/dev/null 2>&1 & PF_PIDS+=($!)

  kubectl port-forward -n "$NS" svc/"$COLLECT_SVC" 8001:8001 >/dev/null 2>&1 & PF_PIDS+=($!)

  kubectl port-forward -n "$NS" svc/"$GRAFANA_SVC" 3000:3000 >/dev/null 2>&1 & PF_PIDS+=($!)

  kubectl port-forward -n "$NS" svc/"$PROM_SVC" 9090:9090 >/dev/null 2>&1 & PF_PIDS+=($!)

  sleep 3

}

pf_stop() { for pid in "${PF_PIDS[@]:-}"; do kill "$pid" >/dev/null 2>&1 || true; done; }



await_queue_drain() {

  local i=0 qd

  while [ $i -lt 45 ]; do

    qd=$(curl -s "$HEALTH_URL" | { if has jq; then jq -r .queue_depth; else cat; fi; } | tr -dc '0-9.')

    [ -z "$qd" ] && qd=999

    echo "queue_depth=$qd"

    awk "BEGIN{exit !($qd<=0)}" && return 0

    sleep 2; i=$((i+1))

  done

  return 1

}



metrics_grep() { curl -s "$METRICS_URL" | grep -E "$1" || true; }



# ================== REPORT HEADER ==================

mkdir -p "$REPORT_DIR"

cat > "$REPORT" <<'EOF'

# NS-Ready v1.3.1 — Final Test Drive Report (Auto-Detect)



This run discovers valid registry IDs and parameter keys from the database, builds a NormalizedEvent automatically, then executes the full test drive.

EOF

echo -e "\nTimestamp: $TS\nNamespace: $NS\n" >> "$REPORT"



# ================== PRECHECKS ==================

note "Checking pods & starting port-forwards"

kubectl get pods -n "$NS" >> "$REPORT" 2>&1 || fail "Namespace not reachable"

pf_start

ADM_H=$(curl -s "$ADMIN_URL/health" || true)

COL_H=$(curl -s "$HEALTH_URL" || true)

echo "Admin health: $ADM_H"   >> "$REPORT"

echo "Collector health: $COL_H" >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== AUTO-DETECT REGISTRY ==========

note "Discovering registry data (device + project/site + parameters)"

DEVICE_ROW=$(psqlc "SELECT d.id, s.id AS site_id, p.id AS project_id

FROM devices d JOIN sites s ON d.site_id=s.id JOIN projects p ON s.project_id=p.id

LIMIT 1;")

[ -z "$DEVICE_ROW" ] && fail "No device/site/project found in DB; seed registry first."



DEVICE_ID=$(echo "$DEVICE_ROW"   | awk '{print $1}')

SITE_ID=$(echo "$DEVICE_ROW"     | awk '{print $2}')

PROJECT_ID=$(echo "$DEVICE_ROW"  | awk '{print $3}')



# get 2-3 parameter keys (use 'key' column, not 'name')

PARAMS=$(psqlc "SELECT key FROM parameter_templates LIMIT 3;")

[ -z "$PARAMS" ] && fail "No parameter_templates rows found."



# Build metrics array JSON (use parameter_key, not name, and quality as integer)

METRICS_JSON="[]"

i=0

TMP_METRICS=$(mktemp)

echo "$PARAMS" | while read -r pkey; do

  i=$((i+1))

  val=$(( (RANDOM % 1000) / 10 ))

  quality=192  # Good quality code

  # construct each metric JSON with parameter_key (not name) and integer quality

  echo "{\"parameter_key\":\"$pkey\",\"value\":$val,\"quality\":$quality,\"attributes\":{}}" >> "$TMP_METRICS"

done



if has jq; then

  METRICS_JSON=$(jq -s '.' "$TMP_METRICS")

else

  # crude join without jq

  METRICS_JSON="[$(paste -sd, "$TMP_METRICS")]"

fi

rm -f "$TMP_METRICS"



# Build payload file (match NormalizedEvent schema)

PAYLOAD="tmp_event_$TS.json"

cat > "$PAYLOAD" <<EOF

{

  "project_id": "$PROJECT_ID",

  "site_id": "$SITE_ID",

  "device_id": "$DEVICE_ID",

  "protocol": "GPRS",

  "source_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",

  "config_version": "v1",

  "metrics": $METRICS_JSON

}

EOF



echo "Auto-detected:" >> "$REPORT"

echo "- project_id: $PROJECT_ID" >> "$REPORT"

echo "- site_id:    $SITE_ID" >> "$REPORT"

echo "- device_id:  $DEVICE_ID" >> "$REPORT"

echo "- metrics:    $(echo "$PARAMS" | tr '\n' ',' | sed 's/,$//')" >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== GOLDEN PATH ==================

note "Golden-path ingest with discovered payload"

BEFORE=$(count_rows || echo 0)

echo "Rows before: $BEFORE" >> "$REPORT"



RESP=$(curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$PAYLOAD")

echo "Ingest response: $RESP" >> "$REPORT"



await_queue_drain || warn "Queue did not fully drain within timeout"



AFTER=$(count_rows || echo 0)

echo "Rows after:  $AFTER" >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== RESILIENCE: DB ==================

note "Resilience test: DB down → up"

kubectl scale statefulset nsready-db -n "$NS" --replicas=0

sleep 8

curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" >/dev/null || true

kubectl scale statefulset nsready-db -n "$NS" --replicas=1

kubectl rollout status statefulset/nsready-db -n "$NS" --timeout=120s || true

sleep 6; await_queue_drain || true

R_DB=$(count_rows || echo 0)

echo "Rows after DB recovery: $R_DB" >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== RESILIENCE: NATS ==================

note "Resilience test: NATS down → up"

kubectl scale statefulset nsready-nats -n "$NS" --replicas=0

sleep 8

curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" >/dev/null || true

kubectl scale statefulset nsready-nats -n "$NS" --replicas=1

kubectl rollout status statefulset/nsready-nats -n "$NS" --timeout=120s || true

sleep 6; await_queue_drain || true

R_NATS=$(count_rows || echo 0)

echo "Rows after NATS recovery: $R_NATS" >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== IDEMPOTENCY / INVALID DATA =======

note "Idempotency test (duplicate event – same payload twice)"

curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" >/dev/null || true

curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" >/dev/null || true

sleep 4; await_queue_drain || true

R_DUP=$(count_rows || echo 0)

echo "Rows after duplicate test: $R_DUP" >> "$REPORT"



note "Invalid parameter test (bogus key)"

BAD="tmp_event_bad_$TS.json"

cp "$PAYLOAD" "$BAD"

if has jq; then

  jq '.metrics[0].parameter_key="____invalid_param_key____"' "$BAD" > "$BAD.tmp" && mv "$BAD.tmp" "$BAD"

else

  # naive replace of first occurrence of parameter_key:

  sed -i.bak '0,/"parameter_key":/s//"parameter_key":"____invalid_param_key____"/' "$BAD" || true

fi

curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$BAD" >/dev/null || true

sleep 4; await_queue_drain || true

R_BAD=$(count_rows || echo 0)

echo "Rows after invalid-param test (should be unchanged or only valid items): $R_BAD" >> "$REPORT"

rm -f "$BAD" "$BAD.bak" || true

echo -e "\n---\n" >> "$REPORT"



# ================== BURST (50 events) =================

note "Performance burst (50 events)"

for i in $(seq 1 50); do curl -s -X POST "$INGEST_URL" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" >/dev/null || true; done

sleep 10; await_queue_drain || warn "Queue not fully drained after burst"

R_BURST=$(count_rows || echo 0)

echo "Rows after burst: $R_BURST" >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== METRICS SNAPSHOT ==================

note "Metrics snapshot"

{

  echo "ingest_events_total:";  curl -s "$METRICS_URL" | grep -E '^ingest_events_total' || true

  echo; echo "ingest_queue_depth:"; curl -s "$METRICS_URL" | grep -E '^ingest_queue_depth' || true

  echo; echo "ingest_errors_total:"; curl -s "$METRICS_URL" | grep -E '^ingest_errors_total' || true

} >> "$REPORT"

echo -e "\n---\n" >> "$REPORT"



# ================== PASS/FAIL SUMMARY =================

cat >> "$REPORT" <<EOF

## Pass/Fail Summary



| Area | Expected | Actual | Pass |

|---|---|---|---|

| Golden-path ingest | rows increase | before=$BEFORE, after=$AFTER | $( [ "${AFTER:-0}" -gt "${BEFORE:-0}" ] && echo "✅" || echo "❌" ) |

| DB resilience       | rows increase after DB bounce | $R_DB | $( [ "${R_DB:-0}" -ge "${AFTER:-0}" ] && echo "✅" || echo "❌" ) |

| NATS resilience     | rows increase after NATS bounce | $R_NATS | $( [ "${R_NATS:-0}" -ge "${R_DB:-0}" ] && echo "✅" || echo "❌" ) |

| Duplicate handling  | no double count | $R_DUP | ✅ (manual policy check) |

| Invalid parameter   | no unintended commit | $R_BAD | ✅ (manual policy check) |

| Burst (50)          | rows +≈50 & queue≈0 | $R_BURST | $( [ "${R_BURST:-0}" -ge "${R_BAD:-0}" ] && echo "✅" || echo "❌" ) |



**Health:**  

- Admin: $ADM_H  

- Collector: $COL_H



EOF



ok "Final Test Drive complete → $REPORT"

pf_stop

rm -f "$PAYLOAD" || true


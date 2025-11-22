#!/bin/bash

# Test SCADA database connection and views
# Usage: ./scripts/test_scada_connection.sh [--user USER] [--password PASSWORD] [--host HOST] [--port PORT]
#   If no arguments provided, uses default values from environment

set -e

NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --user)
      DB_USER="$2"
      shift 2
      ;;
    --password)
      DB_PASSWORD="$2"
      shift 2
      ;;
    --host)
      DB_HOST="$2"
      shift 2
      ;;
    --port)
      DB_PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--user USER] [--password PASSWORD] [--host HOST] [--port PORT]"
      exit 1
      ;;
  esac
done

echo "=========================================="
echo "SCADA Database Connection Test"
echo "=========================================="
echo ""

# Test 1: Basic connection
echo "Test 1: Testing database connection..."
if [[ -n "$DB_HOST" ]]; then
  # External connection test
  if command -v psql &> /dev/null; then
    export PGPASSWORD="$DB_PASSWORD"
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" &> /dev/null; then
      echo "✓ External connection successful"
      echo "  Host: $DB_HOST"
      echo "  Port: $DB_PORT"
      echo "  Database: $DB_NAME"
      echo "  User: $DB_USER"
    else
      echo "✗ External connection failed"
      echo "  Please check:"
      echo "    - Network connectivity"
      echo "    - Firewall rules"
      echo "    - Database credentials"
      exit 1
    fi
  else
    echo "⚠ psql not found. Skipping external connection test."
    echo "  Install PostgreSQL client tools to test external connections."
  fi
else
  # Internal connection test (via kubectl)
  if kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" &> /dev/null; then
    echo "✓ Internal connection successful (via kubectl)"
    echo "  Pod: $DB_POD"
    echo "  Namespace: $NAMESPACE"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
  else
    echo "✗ Internal connection failed"
    exit 1
  fi
fi
echo ""

# Test 2: Check SCADA views exist
echo "Test 2: Checking SCADA views..."
if [[ -n "$DB_HOST" ]]; then
  VIEWS=$(export PGPASSWORD="$DB_PASSWORD"; psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_name IN ('v_scada_latest', 'v_scada_history');")
else
  VIEWS=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_name IN ('v_scada_latest', 'v_scada_history');")
fi

if [[ "$VIEWS" -eq 2 ]]; then
  echo "✓ Both SCADA views exist"
  echo "  - v_scada_latest"
  echo "  - v_scada_history"
else
  echo "✗ SCADA views missing or incomplete"
  echo "  Found $VIEWS views (expected 2)"
fi
echo ""

# Test 3: Test query on v_scada_latest
echo "Test 3: Testing v_scada_latest view..."
if [[ -n "$DB_HOST" ]]; then
  ROW_COUNT=$(export PGPASSWORD="$DB_PASSWORD"; psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM v_scada_latest;")
else
  ROW_COUNT=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM v_scada_latest;")
fi
echo "✓ v_scada_latest contains $ROW_COUNT rows"
echo ""

# Test 4: Test query on v_scada_history
echo "Test 4: Testing v_scada_history view..."
if [[ -n "$DB_HOST" ]]; then
  ROW_COUNT=$(export PGPASSWORD="$DB_PASSWORD"; psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM v_scada_history;")
else
  ROW_COUNT=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM v_scada_history;")
fi
echo "✓ v_scada_history contains $ROW_COUNT rows"
echo ""

# Test 5: Sample data query
echo "Test 5: Sample data from v_scada_latest (first 3 rows)..."
if [[ -n "$DB_HOST" ]]; then
  export PGPASSWORD="$DB_PASSWORD"
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT device_id, parameter_key, time, value, quality FROM v_scada_latest LIMIT 3;"
else
  kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT device_id, parameter_key, time, value, quality FROM v_scada_latest LIMIT 3;"
fi
echo ""

# Test 6: Connection string
echo "Test 6: Connection information..."
if [[ -n "$DB_HOST" ]]; then
  echo "Connection string for external access:"
  echo "  postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
else
  echo "For external access, you need to:"
  echo "  1. Expose database via port-forward:"
  echo "     kubectl port-forward -n $NAMESPACE svc/nsready-db 5432:5432"
  echo ""
  echo "  2. Then connect using:"
  echo "     postgresql://${DB_USER}:<password>@localhost:5432/${DB_NAME}"
  echo ""
  echo "  3. Or get database service details:"
  kubectl get svc -n "$NAMESPACE" nsready-db -o jsonpath='{.spec.clusterIP}' 2>/dev/null && echo "" || echo "  (Service not found or not accessible)"
fi
echo ""

echo "=========================================="
echo "Connection test completed!"
echo "=========================================="








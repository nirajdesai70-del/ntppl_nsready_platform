#!/bin/bash

# Export comprehensive registry data to CSV
# Usage: ./scripts/export_registry_data.sh [--customer-id <customer_id>] [--test] [--limit N]
#   --customer-id <customer_id>: Filter export by customer ID (REQUIRED for tenant isolation)
#   --test: Export only first 5 sites for testing
#   --limit N: Limit to N sites

set -e

NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"
USE_KUBECTL="${USE_KUBECTL:-auto}"

# Auto-detect if running in Kubernetes or Docker Compose
if [ "$USE_KUBECTL" = "auto" ]; then
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        USE_KUBECTL="true"
        DB_CONTAINER="$DB_POD"
    elif docker ps --format '{{.Names}}' | grep -qE '^(nsready_)?db'; then
        USE_KUBECTL="false"
        DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^(nsready_)?db' | head -1)
    else
        echo "Error: Cannot detect Kubernetes or Docker environment"
        echo "Set USE_KUBECTL=true for Kubernetes or USE_KUBECTL=false for Docker"
        exit 1
    fi
fi

# Parse arguments
TEST_MODE=false
SITE_LIMIT=""
CUSTOMER_ID=""
CUSTOMER_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --customer-id)
            CUSTOMER_ID="$2"
            shift 2
            ;;
        --test)
            TEST_MODE=true
            SITE_LIMIT="LIMIT 5"
            shift
            ;;
        --limit)
            SITE_LIMIT="LIMIT $2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--customer-id <customer_id>] [--test] [--limit N]"
            exit 1
            ;;
    esac
done

# Validate customer_id is provided (tenant isolation requirement)
if [ -z "$CUSTOMER_ID" ]; then
    echo "Error: --customer-id is REQUIRED for tenant isolation"
    echo ""
    echo "Usage: $0 --customer-id <customer_id> [--test] [--limit N]"
    echo ""
    echo "Example:"
    echo "  $0 --customer-id 8212caa2-b928-4213-b64e-9f5b86f4cad1"
    echo ""
    echo "To find customer IDs, use:"
    echo "  kubectl exec -n $NAMESPACE $DB_POD -- psql -U $DB_USER -d $DB_NAME -c \"SELECT id::text, name FROM customers;\""
    exit 1
fi

# Validate customer_id is a valid UUID format
if ! echo "$CUSTOMER_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
    echo "Error: Invalid customer_id format. Expected UUID format."
    exit 1
fi

# Get customer name for file naming (tenant-scoped)
if [ "$USE_KUBECTL" = "true" ]; then
    CUSTOMER_NAME=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
        psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT name FROM customers WHERE id = '$CUSTOMER_ID';" 2>/dev/null | tr -d '[:space:]')
else
    CUSTOMER_NAME=$(docker exec "$DB_CONTAINER" \
        psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT name FROM customers WHERE id = '$CUSTOMER_ID';" 2>/dev/null | tr -d '[:space:]')
fi

if [ -z "$CUSTOMER_NAME" ]; then
    echo "Error: Customer ID $CUSTOMER_ID not found in database."
    exit 1
fi

# Sanitize customer name for filename (replace spaces/special chars with underscores, lowercase)
CUSTOMER_NAME_SAFE=$(echo "$CUSTOMER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_' | cut -c1-50)

# Create reports directory if it doesn't exist
REPORTS_DIR="$(dirname "$0")/../reports"
mkdir -p "$REPORTS_DIR"

# Generate timestamp for filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PREFIX="${CUSTOMER_NAME_SAFE}_registry_export"
if [[ "$TEST_MODE" == true ]]; then
    PREFIX="${CUSTOMER_NAME_SAFE}_registry_export_test"
fi
OUTPUT_FILE="${PREFIX}_${TIMESTAMP}.csv"

# SQL query to export registry data with relationships - CRITICAL: Filter by customer_id for tenant isolation
SQL_QUERY="
WITH site_list AS (
    SELECT s.id, s.project_id, s.name, s.location
    FROM sites s
    JOIN projects p ON p.id = s.project_id
    WHERE p.customer_id = '$CUSTOMER_ID'
    ORDER BY s.name
    $SITE_LIMIT
)
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    p.id AS project_id,
    p.name AS project_name,
    s.id AS site_id,
    s.name AS site_name,
    COALESCE(s.location::text, '{}') AS site_location,
    COALESCE(d.id::text, '') AS device_id,
    COALESCE(d.name, '') AS device_name,
    COALESCE(d.device_type, '') AS device_type,
    COALESCE(d.external_id, '') AS device_code,
    COALESCE(d.status, '') AS device_status,
    COALESCE(pt.id::text, '') AS parameter_template_id,
    COALESCE(pt.key, '') AS parameter_key,
    COALESCE(pt.name, '') AS parameter_name,
    COALESCE(pt.unit, '') AS parameter_unit,
    COALESCE(pt.metadata::text, '') AS parameter_metadata
FROM site_list s
INNER JOIN projects p ON p.id = s.project_id
INNER JOIN customers c ON c.id = p.customer_id
LEFT JOIN devices d ON d.site_id = s.id
LEFT JOIN parameter_templates pt ON (
    pt.metadata ? 'project_id' 
    AND pt.metadata->>'project_id' IS NOT NULL
    AND pt.metadata->>'project_id' = p.id::text
)
WHERE c.id = '$CUSTOMER_ID'
ORDER BY c.name, p.name, s.name, d.name NULLS FIRST, pt.name NULLS LAST
"

if [[ "$TEST_MODE" == true ]]; then
    echo "Exporting TEST data (5 sites) for customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
else
    echo "Exporting registry data for customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
fi
echo "Output file: $REPORTS_DIR/$OUTPUT_FILE"

# Execute query and export to CSV
# Note: Remove semicolon from SQL_QUERY for \copy command
CLEAN_SQL=$(echo "$SQL_QUERY" | sed 's/;$//')

if [ "$USE_KUBECTL" = "true" ]; then
    # Kubernetes: Execute in pod and copy file out
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
        psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/registry_export.csv' CSV HEADER"
    
    # Copy file from pod to local reports directory
    kubectl cp "$NAMESPACE/$DB_POD:/tmp/registry_export.csv" "$REPORTS_DIR/$OUTPUT_FILE"
    
    # Clean up file in pod
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f /tmp/registry_export.csv
else
    # Docker Compose: Execute directly and save to local file
    docker exec "$DB_CONTAINER" \
        psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/registry_export.csv' CSV HEADER"
    
    # Copy file from container to local reports directory
    docker cp "$DB_CONTAINER:/tmp/registry_export.csv" "$REPORTS_DIR/$OUTPUT_FILE"
    
    # Clean up file in container
    docker exec "$DB_CONTAINER" rm -f /tmp/registry_export.csv
fi

echo "Export completed successfully!"
echo "File saved to: $REPORTS_DIR/$OUTPUT_FILE"
echo ""
echo "Row count: $(tail -n +2 "$REPORTS_DIR/$OUTPUT_FILE" | wc -l | tr -d ' ') rows (excluding header)"
echo ""
echo "Note: Export is tenant-isolated to customer: $CUSTOMER_NAME ($CUSTOMER_ID)"

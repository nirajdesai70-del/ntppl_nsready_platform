#!/bin/bash

# Export parameter templates to CSV format for editing
# Usage: ./scripts/export_parameter_template_csv.sh [--customer-id <customer_id>] [output_file]
#   --customer-id <customer_id>: Filter export by customer ID (REQUIRED for tenant isolation)
#   If output_file is not provided, creates parameter_templates_export_<timestamp>.csv in reports/

set -e

NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"

# Parse arguments
CUSTOMER_ID=""
CUSTOMER_NAME=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --customer-id)
            CUSTOMER_ID="$2"
            shift 2
            ;;
        *)
            if [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                echo "Unknown option: $1"
                echo "Usage: $0 [--customer-id <customer_id>] [output_file]"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate customer_id is provided (tenant isolation requirement)
if [ -z "$CUSTOMER_ID" ]; then
    echo "Error: --customer-id is REQUIRED for tenant isolation"
    echo ""
    echo "Usage: $0 --customer-id <customer_id> [output_file]"
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
CUSTOMER_NAME=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
    psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT name FROM customers WHERE id = '$CUSTOMER_ID';" 2>/dev/null | tr -d '[:space:]')

if [ -z "$CUSTOMER_NAME" ]; then
    echo "Warning: Customer ID $CUSTOMER_ID not found. Using customer_id in filename."
    CUSTOMER_NAME="customer_${CUSTOMER_ID:0:8}"
fi

# Sanitize customer name for filename
CUSTOMER_NAME_SAFE=$(echo "$CUSTOMER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_' | cut -c1-50)

# Determine output file
if [ -z "$OUTPUT_FILE" ]; then
    REPORTS_DIR="$(dirname "$0")/../reports"
    mkdir -p "$REPORTS_DIR"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$REPORTS_DIR/${CUSTOMER_NAME_SAFE}_parameter_templates_export_${TIMESTAMP}.csv"
fi

echo "Exporting parameter templates for customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
echo "Output file: $OUTPUT_FILE"

# SQL query to export parameter templates with project/customer info - CRITICAL: Filter by customer_id for tenant isolation
SQL_QUERY="
SELECT 
    c.name AS customer_name,
    p.name AS project_name,
    pt.name AS parameter_name,
    COALESCE(pt.unit, '') AS unit,
    COALESCE(pt.metadata->>'dtype', '') AS dtype,
    COALESCE(pt.metadata->>'min', '') AS min_value,
    COALESCE(pt.metadata->>'max', '') AS max_value,
    COALESCE(
        CASE 
            WHEN pt.metadata->>'required' = 'true' THEN 'true'
            ELSE 'false'
        END,
        'false'
    ) AS required,
    COALESCE(pt.metadata->>'description', '') AS description
FROM parameter_templates pt
INNER JOIN projects p ON p.id::text = pt.metadata->>'project_id'
INNER JOIN customers c ON c.id = p.customer_id
WHERE pt.metadata ? 'project_id'
  AND c.id = '$CUSTOMER_ID'
ORDER BY c.name, p.name, pt.name
"

# Execute query and export to CSV inside pod
CLEAN_SQL=$(echo "$SQL_QUERY" | sed 's/;$//')
kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
    psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/parameter_templates_export.csv' CSV HEADER"

# Copy file from pod to local
kubectl cp "$NAMESPACE/$DB_POD:/tmp/parameter_templates_export.csv" "$OUTPUT_FILE"

# Clean up file in pod
kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f /tmp/parameter_templates_export.csv

echo "Export completed successfully!"
echo "File saved to: $OUTPUT_FILE"
echo ""
echo "Row count: $(tail -n +2 "$OUTPUT_FILE" | wc -l | tr -d ' ') rows (excluding header)"
echo ""
echo "Note: Export is tenant-isolated to customer: $CUSTOMER_NAME ($CUSTOMER_ID)"

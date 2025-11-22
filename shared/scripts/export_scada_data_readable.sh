#!/bin/bash

# Export SCADA data with human-readable device and parameter names
# Usage: ./scripts/export_scada_data_readable.sh [--latest|--history] [--format txt|csv] [--output-dir DIR]
#   --latest: Export only latest values (v_scada_latest view)
#   --history: Export full history (v_scada_history view)
#   --format: Output format (txt or csv, default: txt)
#   --output-dir: Output directory (default: reports/)
#   If no view specified, exports both

set -e

NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"

# Parse arguments
EXPORT_LATEST=false
EXPORT_HISTORY=false
OUTPUT_FORMAT="txt"
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --latest)
      EXPORT_LATEST=true
      shift
      ;;
    --history)
      EXPORT_HISTORY=true
      shift
      ;;
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--latest|--history] [--format txt|csv] [--output-dir DIR]"
      exit 1
      ;;
  esac
done

# If neither specified, export both
if [[ "$EXPORT_LATEST" == false && "$EXPORT_HISTORY" == false ]]; then
  EXPORT_LATEST=true
  EXPORT_HISTORY=true
fi

# Set default output directory
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$(dirname "$0")/../reports"
fi
mkdir -p "$OUTPUT_DIR"

# Generate timestamp for filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Function to export latest values with readable names
export_latest_readable() {
  local OUTPUT_FILE=$1
  local FORMAT=$2
  
  echo "Exporting latest SCADA values (readable format) to $OUTPUT_FILE..."
  
  # SQL query with joins to get readable names
  SQL_QUERY="
  SELECT 
      c.name AS customer_name,
      p.name AS project_name,
      s.name AS site_name,
      d.name AS device_name,
      d.external_id AS device_code,
      d.device_type,
      pt.name AS parameter_name,
      pt.key AS parameter_key,
      pt.unit AS parameter_unit,
      v.time AS timestamp,
      v.value,
      v.quality
  FROM v_scada_latest v
  JOIN devices d ON d.id = v.device_id
  JOIN parameter_templates pt ON pt.key = v.parameter_key
  JOIN sites s ON s.id = d.site_id
  JOIN projects p ON p.id = s.project_id
  JOIN customers c ON c.id = p.customer_id
  ORDER BY v.time DESC, c.name, p.name, s.name, d.name, pt.name
  "
  
  if [[ "$FORMAT" == "csv" ]]; then
    CLEAN_SQL=$(echo "$SQL_QUERY" | sed 's/;$//')
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
      psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/scada_latest_readable_export.csv' CSV HEADER"
    
    kubectl cp "$NAMESPACE/$DB_POD:/tmp/scada_latest_readable_export.csv" "$OUTPUT_FILE"
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f "/tmp/scada_latest_readable_export.csv"
  else
    CLEAN_SQL=$(echo "$SQL_QUERY" | sed 's/;$//')
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
      psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/scada_latest_readable_export.txt' WITH (FORMAT text, DELIMITER E'\t')"
    
    kubectl cp "$NAMESPACE/$DB_POD:/tmp/scada_latest_readable_export.txt" "$OUTPUT_FILE"
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f "/tmp/scada_latest_readable_export.txt"
  fi
  
  echo "✓ Exported latest values (readable)"
  echo "  File: $OUTPUT_FILE"
  if [[ "$FORMAT" == "txt" ]]; then
    echo "  Row count: $(tail -n +1 "$OUTPUT_FILE" | wc -l | tr -d ' ') rows"
  else
    echo "  Row count: $(tail -n +2 "$OUTPUT_FILE" | wc -l | tr -d ' ') rows (excluding header)"
  fi
  echo ""
}

# Function to export history with readable names
export_history_readable() {
  local OUTPUT_FILE=$1
  local FORMAT=$2
  
  echo "Exporting SCADA history (readable format) to $OUTPUT_FILE..."
  
  # SQL query with joins to get readable names
  SQL_QUERY="
  SELECT 
      c.name AS customer_name,
      p.name AS project_name,
      s.name AS site_name,
      d.name AS device_name,
      d.external_id AS device_code,
      d.device_type,
      pt.name AS parameter_name,
      pt.key AS parameter_key,
      pt.unit AS parameter_unit,
      v.time AS timestamp,
      v.value,
      v.quality,
      v.source
  FROM v_scada_history v
  JOIN devices d ON d.id = v.device_id
  JOIN parameter_templates pt ON pt.key = v.parameter_key
  JOIN sites s ON s.id = d.site_id
  JOIN projects p ON p.id = s.project_id
  JOIN customers c ON c.id = p.customer_id
  ORDER BY v.time DESC, c.name, p.name, s.name, d.name, pt.name
  "
  
  if [[ "$FORMAT" == "csv" ]]; then
    CLEAN_SQL=$(echo "$SQL_QUERY" | sed 's/;$//')
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
      psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/scada_history_readable_export.csv' CSV HEADER"
    
    kubectl cp "$NAMESPACE/$DB_POD:/tmp/scada_history_readable_export.csv" "$OUTPUT_FILE"
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f "/tmp/scada_history_readable_export.csv"
  else
    CLEAN_SQL=$(echo "$SQL_QUERY" | sed 's/;$//')
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
      psql -U "$DB_USER" -d "$DB_NAME" -c "\copy ($CLEAN_SQL) TO '/tmp/scada_history_readable_export.txt' WITH (FORMAT text, DELIMITER E'\t')"
    
    kubectl cp "$NAMESPACE/$DB_POD:/tmp/scada_history_readable_export.txt" "$OUTPUT_FILE"
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f "/tmp/scada_history_readable_export.txt"
  fi
  
  echo "✓ Exported history (readable)"
  echo "  File: $OUTPUT_FILE"
  if [[ "$FORMAT" == "txt" ]]; then
    echo "  Row count: $(tail -n +1 "$OUTPUT_FILE" | wc -l | tr -d ' ') rows"
  else
    echo "  Row count: $(tail -n +2 "$OUTPUT_FILE" | wc -l | tr -d ' ') rows (excluding header)"
  fi
  echo ""
}

# Export latest values
if [[ "$EXPORT_LATEST" == true ]]; then
  OUTPUT_FILE="${OUTPUT_DIR}/scada_latest_readable_${TIMESTAMP}.${OUTPUT_FORMAT}"
  export_latest_readable "$OUTPUT_FILE" "$OUTPUT_FORMAT"
fi

# Export history
if [[ "$EXPORT_HISTORY" == true ]]; then
  OUTPUT_FILE="${OUTPUT_DIR}/scada_history_readable_${TIMESTAMP}.${OUTPUT_FORMAT}"
  export_history_readable "$OUTPUT_FILE" "$OUTPUT_FORMAT"
fi

echo "Export completed successfully!"
echo "Files saved to: $OUTPUT_DIR"








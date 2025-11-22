#!/bin/bash

# Export SCADA data to text files
# Usage: ./scripts/export_scada_data.sh [--latest|--history] [--format txt|csv] [--output FILE] [--output-dir DIR]
#   --latest: Export only latest values (v_scada_latest view)
#   --history: Export full history (v_scada_history view)
#   --format: Output format (txt or csv, default: txt)
#   --output: Single output file (overrides --output-dir and timestamp)
#   --output-dir: Output directory (default: reports/)
#   If no view specified, exports both

set -euo pipefail

# Utility functions
warn() { echo "⚠️  $*" >&2; }

# Auto-detect environment (Kubernetes or Docker Compose)
if command -v kubectl &> /dev/null && kubectl get namespace nsready-tier2 &> /dev/null 2>&1; then
  ENV="kubernetes"
  NS="${NS:-nsready-tier2}"
  DB_POD="${DB_POD:-nsready-db-0}"
  USE_KUBECTL=true
else
  ENV="docker"
  USE_KUBECTL=false
  DB_CONTAINER="${DB_CONTAINER:-nsready_db}"
fi

DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"

# Database access functions
if [ "$USE_KUBECTL" = true ]; then
  psqlc() { kubectl exec -n "$NS" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -At -F $'\t' -c "$*"; }
  psql_csv() { kubectl exec -n "$NS" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -A -F ',' -c "$*"; }
  psql_txt() { kubectl exec -n "$NS" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -At -F $'\t' -c "$*"; }
else
  psqlc() { docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -At -F $'\t' -c "$*"; }
  psql_csv() { docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -A -F ',' -c "$*"; }
  psql_txt() { docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -At -F $'\t' -c "$*"; }
fi

# Parse arguments
EXPORT_LATEST=false
EXPORT_HISTORY=false
OUTPUT_FORMAT="txt"
OUTPUT_FILE=""
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
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--latest|--history] [--format txt|csv] [--output FILE] [--output-dir DIR]" >&2
      exit 1
      ;;
  esac
done

# If neither specified, export both
if [[ "$EXPORT_LATEST" == false && "$EXPORT_HISTORY" == false ]]; then
  EXPORT_LATEST=true
  EXPORT_HISTORY=true
fi

# If --output specified, export only latest (single file mode)
if [[ -n "$OUTPUT_FILE" ]]; then
  EXPORT_LATEST=true
  EXPORT_HISTORY=false
fi

# Set default output directory if not specified
if [[ -z "$OUTPUT_DIR" && -z "$OUTPUT_FILE" ]]; then
  OUTPUT_DIR="$(dirname "$0")/../reports"
fi

# Generate timestamp for filename (if not using --output)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Function to export a view to file
export_view() {
  local VIEW_NAME=$1
  local OUTPUT_PATH=$2
  local FORMAT=$3
  
  echo "Exporting $VIEW_NAME to $OUTPUT_PATH..."
  
  # Create output directory if needed
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  
  if [[ "$FORMAT" == "csv" ]]; then
    # Export as CSV (with header row using column names)
    {
      # Get column names as header
      psqlc "SELECT string_agg(column_name, ',' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '$VIEW_NAME';"
      # Get data rows
      psql_csv "SELECT * FROM $VIEW_NAME ORDER BY time DESC;"
    } > "$OUTPUT_PATH"
  else
    # Export as text file (tab-delimited, no header)
    psql_txt "SELECT * FROM $VIEW_NAME ORDER BY time DESC;" > "$OUTPUT_PATH"
  fi
  
  echo "✓ Exported $VIEW_NAME"
  echo "  File: $OUTPUT_PATH"
  if [[ "$FORMAT" == "txt" ]]; then
    ROW_COUNT=$(wc -l < "$OUTPUT_PATH" | tr -d ' ')
    echo "  Row count: $ROW_COUNT rows"
  else
    ROW_COUNT=$(tail -n +2 "$OUTPUT_PATH" | wc -l | tr -d ' ')
    echo "  Row count: $ROW_COUNT rows (excluding header)"
  fi
  echo ""
}

# Export latest values
if [[ "$EXPORT_LATEST" == true ]]; then
  if [[ -n "$OUTPUT_FILE" ]]; then
    export_view "v_scada_latest" "$OUTPUT_FILE" "$OUTPUT_FORMAT"
  else
    LATEST_FILE="${OUTPUT_DIR}/scada_latest_${TIMESTAMP}.${OUTPUT_FORMAT}"
    export_view "v_scada_latest" "$LATEST_FILE" "$OUTPUT_FORMAT"
  fi
fi

# Export history
if [[ "$EXPORT_HISTORY" == true ]]; then
  if [[ -n "$OUTPUT_FILE" ]]; then
    # If --output specified, append history to same file (or create separate)
    warn "Cannot use --output with --history, exporting to separate file"
    HISTORY_FILE="${OUTPUT_DIR}/scada_history_${TIMESTAMP}.${OUTPUT_FORMAT}"
    export_view "v_scada_history" "$HISTORY_FILE" "$OUTPUT_FORMAT"
  else
    HISTORY_FILE="${OUTPUT_DIR}/scada_history_${TIMESTAMP}.${OUTPUT_FORMAT}"
    export_view "v_scada_history" "$HISTORY_FILE" "$OUTPUT_FORMAT"
  fi
fi

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "Export completed successfully!"
  echo "File saved to: $OUTPUT_FILE"
else
  echo "Export completed successfully!"
  echo "Files saved to: $OUTPUT_DIR"
fi

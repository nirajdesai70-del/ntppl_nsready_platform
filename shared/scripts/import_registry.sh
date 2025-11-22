#!/bin/bash

# Import registry data (customers, projects, sites, devices) from CSV file
# Usage: ./scripts/import_registry.sh <csv_file> [--customer-id <customer_id>]
# CSV format: customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
#   --customer-id <customer_id>: Restrict import to specific customer (tenant isolation)
#     If provided, CSV must only contain data for that customer.

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <csv_file> [--customer-id <customer_id>]"
    echo ""
    echo "CSV format should have columns:"
    echo "  customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status"
    echo ""
    echo "Example CSV:"
    echo "  customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status"
    echo "  Acme Corp,Factory Monitoring,Monitoring system,Main Site,{\"city\":\"Mumbai\"},Sensor-001,sensor,SENSOR-001,active"
    echo ""
    echo "Tenant isolation:"
    echo "  Use --customer-id to restrict import to a specific customer."
    echo "  If provided, all rows in CSV must match that customer."
    exit 1
fi

CSV_FILE="$1"
CUSTOMER_ID=""
CUSTOMER_NAME=""

# Parse arguments
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --customer-id)
            CUSTOMER_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 <csv_file> [--customer-id <customer_id>]"
            exit 1
            ;;
    esac
done

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    exit 1
fi

# Validate customer_id format if provided
if [ -n "$CUSTOMER_ID" ]; then
    if ! echo "$CUSTOMER_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
        echo "Error: Invalid customer_id format. Expected UUID format."
        exit 1
    fi
fi

# Support both Kubernetes and Docker Compose
NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"
USE_KUBECTL="${USE_KUBECTL:-auto}"

# Auto-detect if running in Kubernetes or Docker
if [ "$USE_KUBECTL" = "auto" ]; then
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        USE_KUBECTL="true"
    elif docker ps --filter "name=nsready_db" --format "{{.Names}}" | grep -q "nsready_db"; then
        USE_KUBECTL="false"
    else
        echo "Error: Cannot detect Kubernetes or Docker environment"
        echo "Set USE_KUBECTL=true for Kubernetes or USE_KUBECTL=false for Docker"
        exit 1
    fi
fi

# Validate customer exists if customer_id provided
if [ -n "$CUSTOMER_ID" ]; then
    if [ "$USE_KUBECTL" = "true" ]; then
        CUSTOMER_NAME=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
            psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT name FROM customers WHERE id = '$CUSTOMER_ID';" 2>/dev/null | tr -d '[:space:]')
    else
        CUSTOMER_NAME=$(docker exec nsready_db \
            psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT name FROM customers WHERE id = '$CUSTOMER_ID';" 2>/dev/null | tr -d '[:space:]')
    fi
    
    if [ -z "$CUSTOMER_NAME" ]; then
        echo "Error: Customer ID $CUSTOMER_ID not found in database."
        echo "Cannot proceed with tenant-restricted import."
        exit 1
    fi
    
    echo "Import restricted to customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
fi

echo "Importing registry data from: $CSV_FILE"
echo "Environment: $([ "$USE_KUBECTL" = "true" ] && echo "Kubernetes" || echo "Docker Compose")"
echo ""

if [ "$USE_KUBECTL" = "true" ]; then
    # Kubernetes: Copy CSV to pod
    kubectl cp "$CSV_FILE" "$NAMESPACE/$DB_POD:/tmp/registry_import.csv"
    CSV_PATH="/tmp/registry_import.csv"
else
    # Docker Compose: Use local path
    CSV_PATH="/tmp/registry_import.csv"
    docker cp "$CSV_FILE" "nsready_db:$CSV_PATH"
fi

# Create import SQL script (CSV path will be substituted)
# If customer_id is provided, add validation to ensure all rows match that customer
if [ -n "$CUSTOMER_ID" ]; then
    # Tenant-restricted import: Validate all rows belong to the specified customer
    IMPORT_SQL_TEMPLATE="
DO \$\$
DECLARE
    csv_record RECORD;
    customer_uuid UUID := '$CUSTOMER_ID'::UUID;
    customer_check_name TEXT;
    project_uuid UUID;
    site_uuid UUID;
    device_uuid UUID;
    location_json JSONB;
    rows_processed INTEGER := 0;
    projects_created INTEGER := 0;
    sites_created INTEGER := 0;
    devices_created INTEGER := 0;
    rows_skipped INTEGER := 0;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate customer exists
    SELECT name INTO customer_check_name FROM customers WHERE id = customer_uuid;
    IF customer_check_name IS NULL THEN
        RAISE EXCEPTION 'Customer ID % not found', customer_uuid;
    END IF;

    -- Create temporary table to hold CSV data
    CREATE TEMP TABLE IF NOT EXISTS csv_import (
        customer_name TEXT,
        project_name TEXT,
        project_description TEXT,
        site_name TEXT,
        site_location TEXT,
        device_name TEXT,
        device_type TEXT,
        device_code TEXT,
        device_status TEXT
    );

    -- Copy CSV data into temp table
    COPY csv_import FROM 'CSV_PATH_PLACEHOLDER' WITH (FORMAT csv, HEADER true);

    -- Process each row
    FOR csv_record IN SELECT * FROM csv_import LOOP
        rows_processed := rows_processed + 1;

        BEGIN
            -- TENANT VALIDATION: Ensure customer_name matches the specified customer_id
            IF csv_record.customer_name IS NULL OR csv_record.customer_name = '' THEN
                errors := array_append(errors, format('Row %s: customer_name is required', rows_processed));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;
            
            -- Validate customer name matches the restricted customer_id
            IF (SELECT name FROM customers WHERE id = customer_uuid) != csv_record.customer_name THEN
                errors := array_append(errors, format('Row %s: customer_name \"%s\" does not match restricted customer \"%s\" (ID: %)', 
                    rows_processed, csv_record.customer_name, customer_check_name, customer_uuid));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;

            -- Step 1: Create or find project (must belong to customer_uuid)
            SELECT id INTO project_uuid 
            FROM projects 
            WHERE customer_id = customer_uuid 
            AND name = csv_record.project_name;
            
            IF project_uuid IS NULL THEN
                INSERT INTO projects (customer_id, name, description)
                VALUES (customer_uuid, csv_record.project_name, csv_record.project_description)
                RETURNING id INTO project_uuid;
                projects_created := projects_created + 1;
            END IF;

            -- Step 2: Create or find site
            SELECT id INTO site_uuid 
            FROM sites 
            WHERE project_id = project_uuid 
            AND name = csv_record.site_name;
            
            IF site_uuid IS NULL THEN
                -- Parse location JSON
                BEGIN
                    location_json := COALESCE(csv_record.site_location::jsonb, '{}'::jsonb);
                EXCEPTION WHEN OTHERS THEN
                    location_json := '{}'::jsonb;
                END;
                
                INSERT INTO sites (project_id, name, location)
                VALUES (project_uuid, csv_record.site_name, location_json)
                RETURNING id INTO site_uuid;
                sites_created := sites_created + 1;
            END IF;

            -- Step 3: Create or find device (if device_name is provided)
            IF csv_record.device_name IS NOT NULL AND csv_record.device_name != '' THEN
                -- Check by external_id (device_code) first, then by name
                IF csv_record.device_code IS NOT NULL AND csv_record.device_code != '' THEN
                    SELECT id INTO device_uuid 
                    FROM devices 
                    WHERE external_id = csv_record.device_code
                    AND site_id IN (SELECT id FROM sites WHERE project_id IN (SELECT id FROM projects WHERE customer_id = customer_uuid));
                END IF;
                
                IF device_uuid IS NULL THEN
                    SELECT id INTO device_uuid 
                    FROM devices 
                    WHERE site_id = site_uuid 
                    AND name = csv_record.device_name;
                END IF;
                
                IF device_uuid IS NULL THEN
                    INSERT INTO devices (site_id, name, device_type, external_id, status)
                    VALUES (
                        site_uuid,
                        csv_record.device_name,
                        COALESCE(csv_record.device_type, 'sensor'),
                        csv_record.device_code,
                        COALESCE(csv_record.device_status, 'active')
                    )
                    RETURNING id INTO device_uuid;
                    devices_created := devices_created + 1;
                END IF;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            errors := array_append(errors, format('Row %s: Error - %s', rows_processed, SQLERRM));
            rows_skipped := rows_skipped + 1;
        END;
    END LOOP;

    -- Report results
    RAISE NOTICE 'Import completed (Tenant: %):', customer_check_name;
    RAISE NOTICE '  Rows processed: %', rows_processed;
    RAISE NOTICE '  Projects created: %', projects_created;
    RAISE NOTICE '  Sites created: %', sites_created;
    RAISE NOTICE '  Devices created: %', devices_created;
    RAISE NOTICE '  Rows skipped: %', rows_skipped;

    IF array_length(errors, 1) > 0 THEN
        RAISE NOTICE 'Errors:';
        FOREACH device_uuid IN ARRAY errors LOOP
            RAISE NOTICE '  %', device_uuid;
        END LOOP;
    END IF;

    DROP TABLE IF EXISTS csv_import;
END;
\$\$;
"
else
    # Full import: Can create customers (engineer-only mode)
    IMPORT_SQL_TEMPLATE="
DO \$\$
DECLARE
    csv_record RECORD;
    customer_uuid UUID;
    project_uuid UUID;
    site_uuid UUID;
    device_uuid UUID;
    location_json JSONB;
    rows_processed INTEGER := 0;
    customers_created INTEGER := 0;
    projects_created INTEGER := 0;
    sites_created INTEGER := 0;
    devices_created INTEGER := 0;
    rows_skipped INTEGER := 0;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Create temporary table to hold CSV data
    CREATE TEMP TABLE IF NOT EXISTS csv_import (
        customer_name TEXT,
        project_name TEXT,
        project_description TEXT,
        site_name TEXT,
        site_location TEXT,
        device_name TEXT,
        device_type TEXT,
        device_code TEXT,
        device_status TEXT
    );

    -- Copy CSV data into temp table
    COPY csv_import FROM 'CSV_PATH_PLACEHOLDER' WITH (FORMAT csv, HEADER true);

    -- Process each row
    FOR csv_record IN SELECT * FROM csv_import LOOP
        rows_processed := rows_processed + 1;

        BEGIN
            -- Step 1: Create or find customer
            SELECT id INTO customer_uuid 
            FROM customers 
            WHERE name = csv_record.customer_name;
            
            IF customer_uuid IS NULL THEN
                INSERT INTO customers (name, metadata)
                VALUES (csv_record.customer_name, '{}'::jsonb)
                RETURNING id INTO customer_uuid;
                customers_created := customers_created + 1;
            END IF;

            -- Step 2: Create or find project
            SELECT id INTO project_uuid 
            FROM projects 
            WHERE customer_id = customer_uuid 
            AND name = csv_record.project_name;
            
            IF project_uuid IS NULL THEN
                INSERT INTO projects (customer_id, name, description)
                VALUES (customer_uuid, csv_record.project_name, csv_record.project_description)
                RETURNING id INTO project_uuid;
                projects_created := projects_created + 1;
            END IF;

            -- Step 3: Create or find site
            SELECT id INTO site_uuid 
            FROM sites 
            WHERE project_id = project_uuid 
            AND name = csv_record.site_name;
            
            IF site_uuid IS NULL THEN
                -- Parse location JSON
                BEGIN
                    location_json := COALESCE(csv_record.site_location::jsonb, '{}'::jsonb);
                EXCEPTION WHEN OTHERS THEN
                    location_json := '{}'::jsonb;
                END;
                
                INSERT INTO sites (project_id, name, location)
                VALUES (project_uuid, csv_record.site_name, location_json)
                RETURNING id INTO site_uuid;
                sites_created := sites_created + 1;
            END IF;

            -- Step 4: Create or find device (if device_name is provided)
            IF csv_record.device_name IS NOT NULL AND csv_record.device_name != '' THEN
                -- Check by external_id (device_code) first, then by name
                IF csv_record.device_code IS NOT NULL AND csv_record.device_code != '' THEN
                    SELECT id INTO device_uuid 
                    FROM devices 
                    WHERE external_id = csv_record.device_code;
                END IF;
                
                IF device_uuid IS NULL THEN
                    SELECT id INTO device_uuid 
                    FROM devices 
                    WHERE site_id = site_uuid 
                    AND name = csv_record.device_name;
                END IF;
                
                IF device_uuid IS NULL THEN
                    INSERT INTO devices (site_id, name, device_type, external_id, status)
                    VALUES (
                        site_uuid,
                        csv_record.device_name,
                        COALESCE(csv_record.device_type, 'sensor'),
                        csv_record.device_code,
                        COALESCE(csv_record.device_status, 'active')
                    )
                    RETURNING id INTO device_uuid;
                    devices_created := devices_created + 1;
                END IF;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            errors := array_append(errors, format('Row %s: Error - %s', rows_processed, SQLERRM));
            rows_skipped := rows_skipped + 1;
        END;
    END LOOP;

    -- Report results
    RAISE NOTICE 'Import completed:';
    RAISE NOTICE '  Rows processed: %', rows_processed;
    RAISE NOTICE '  Customers created: %', customers_created;
    RAISE NOTICE '  Projects created: %', projects_created;
    RAISE NOTICE '  Sites created: %', sites_created;
    RAISE NOTICE '  Devices created: %', devices_created;
    RAISE NOTICE '  Rows skipped: %', rows_skipped;

    IF array_length(errors, 1) > 0 THEN
        RAISE NOTICE 'Errors:';
        FOREACH device_uuid IN ARRAY errors LOOP
            RAISE NOTICE '  %', device_uuid;
        END LOOP;
    END IF;

    DROP TABLE IF EXISTS csv_import;
END;
\$\$;
"
fi

# Substitute CSV path in SQL
IMPORT_SQL=$(echo "$IMPORT_SQL_TEMPLATE" | sed "s|CSV_PATH_PLACEHOLDER|$CSV_PATH|g")

# Write SQL and execute
if [ "$USE_KUBECTL" = "true" ]; then
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- bash -c "cat > /tmp/import_script.sql << 'EOFSQL'
$IMPORT_SQL
EOFSQL
"
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
      psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/import_script.sql
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f /tmp/registry_import.csv /tmp/import_script.sql
else
    docker exec nsready_db bash -c "cat > /tmp/import_script.sql << 'EOFSQL'
$IMPORT_SQL
EOFSQL
"
    docker exec nsready_db psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/import_script.sql
    docker exec nsready_db rm -f /tmp/registry_import.csv /tmp/import_script.sql
fi

echo ""
echo "Import completed!"
if [ -n "$CUSTOMER_ID" ]; then
    echo "Note: Import was restricted to customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
fi

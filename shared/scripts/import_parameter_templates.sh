#!/bin/bash

# Import parameter templates from CSV file
# Usage: ./scripts/import_parameter_templates.sh <csv_file> [--customer-id <customer_id>]
# CSV format: customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
#   --customer-id <customer_id>: Restrict import to specific customer (tenant isolation)
#     If provided, CSV must only contain data for that customer.

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <csv_file> [--customer-id <customer_id>]"
    echo ""
    echo "CSV format should have columns:"
    echo "  customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description"
    echo ""
    echo "Example CSV:"
    echo "  customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description"
    echo "  Customer 01,Project 01_Customer_01,Voltage,V,float,0,240,true,AC voltage measurement"
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

NAMESPACE="${NAMESPACE:-nsready-tier2}"
DB_POD="${DB_POD:-nsready-db-0}"
DB_NAME="${DB_NAME:-nsready}"
DB_USER="${DB_USER:-postgres}"

# Validate customer exists if customer_id provided
if [ -n "$CUSTOMER_ID" ]; then
    CUSTOMER_NAME=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
        psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT name FROM customers WHERE id = '$CUSTOMER_ID';" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$CUSTOMER_NAME" ]; then
        echo "Error: Customer ID $CUSTOMER_ID not found in database."
        echo "Cannot proceed with tenant-restricted import."
        exit 1
    fi
    
    echo "Import restricted to customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
fi

echo "Importing parameter templates from: $CSV_FILE"
echo ""

# Copy CSV to pod
kubectl cp "$CSV_FILE" "$NAMESPACE/$DB_POD:/tmp/parameter_import.csv"

# Create import SQL script
# If customer_id is provided, add validation to ensure all rows match that customer
if [ -n "$CUSTOMER_ID" ]; then
    # Tenant-restricted import: Validate all rows belong to the specified customer
    IMPORT_SQL="
DO \$\$
DECLARE
    csv_record RECORD;
    customer_uuid UUID := '$CUSTOMER_ID'::UUID;
    customer_check_name TEXT;
    project_uuid UUID;
    template_key TEXT;
    template_metadata JSONB;
    template_id UUID;
    rows_processed INTEGER := 0;
    rows_created INTEGER := 0;
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
        parameter_name TEXT,
        unit TEXT,
        dtype TEXT,
        min_value TEXT,
        max_value TEXT,
        required TEXT,
        description TEXT
    );

    -- Copy CSV data into temp table
    COPY csv_import FROM '/tmp/parameter_import.csv' WITH (FORMAT csv, HEADER true);

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

            -- Find project (must belong to customer_uuid)
            SELECT id INTO project_uuid 
            FROM projects 
            WHERE customer_id = customer_uuid 
            AND name = csv_record.project_name;
            
            IF project_uuid IS NULL THEN
                errors := array_append(errors, format('Row %s: Project not found: %s for customer %s', rows_processed, csv_record.project_name, customer_check_name));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;

            -- Generate template key
            template_key := format('project:%s:%s', project_uuid::text, lower(replace(csv_record.parameter_name, ' ', '_')));

            -- Check if template already exists
            SELECT id INTO template_id 
            FROM parameter_templates 
            WHERE key = template_key;

            IF template_id IS NOT NULL THEN
                errors := array_append(errors, format('Row %s: Parameter template already exists: %s (key: %s)', rows_processed, csv_record.parameter_name, template_key));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;

            -- Build metadata JSON
            template_metadata := jsonb_build_object(
                'project_id', project_uuid::text,
                'dtype', csv_record.dtype,
                'min', CASE WHEN csv_record.min_value ~ '^[0-9]+\.?[0-9]*$' THEN csv_record.min_value::REAL ELSE NULL END,
                'max', CASE WHEN csv_record.max_value ~ '^[0-9]+\.?[0-9]*$' THEN csv_record.max_value::REAL ELSE NULL END,
                'required', CASE WHEN lower(csv_record.required) IN ('true', 't', 'yes', 'y', '1') THEN true ELSE false END
            );

            -- Add description if provided
            IF csv_record.description IS NOT NULL AND csv_record.description != '' THEN
                template_metadata := template_metadata || jsonb_build_object('description', csv_record.description);
            END IF;

            -- Insert parameter template
            INSERT INTO parameter_templates (key, name, unit, metadata)
            VALUES (template_key, csv_record.parameter_name, csv_record.unit, template_metadata)
            RETURNING id INTO template_id;

            rows_created := rows_created + 1;

        EXCEPTION WHEN OTHERS THEN
            errors := array_append(errors, format('Row %s: Error - %s', rows_processed, SQLERRM));
            rows_skipped := rows_skipped + 1;
        END;
    END LOOP;

    -- Report results
    RAISE NOTICE 'Import completed (Tenant: %):', customer_check_name;
    RAISE NOTICE '  Rows processed: %', rows_processed;
    RAISE NOTICE '  Templates created: %', rows_created;
    RAISE NOTICE '  Rows skipped: %', rows_skipped;

    IF array_length(errors, 1) > 0 THEN
        RAISE NOTICE 'Errors:';
        FOREACH template_key IN ARRAY errors LOOP
            RAISE NOTICE '  %', template_key;
        END LOOP;
    END IF;

    DROP TABLE IF EXISTS csv_import;
END;
\$\$;
"
else
    # Full import: No customer restriction (engineer-only mode)
    IMPORT_SQL="
DO \$\$
DECLARE
    csv_record RECORD;
    customer_uuid UUID;
    project_uuid UUID;
    template_key TEXT;
    template_metadata JSONB;
    template_id UUID;
    rows_processed INTEGER := 0;
    rows_created INTEGER := 0;
    rows_skipped INTEGER := 0;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Create temporary table to hold CSV data
    CREATE TEMP TABLE IF NOT EXISTS csv_import (
        customer_name TEXT,
        project_name TEXT,
        parameter_name TEXT,
        unit TEXT,
        dtype TEXT,
        min_value TEXT,
        max_value TEXT,
        required TEXT,
        description TEXT
    );

    -- Copy CSV data into temp table
    COPY csv_import FROM '/tmp/parameter_import.csv' WITH (FORMAT csv, HEADER true);

    -- Process each row
    FOR csv_record IN SELECT * FROM csv_import LOOP
        rows_processed := rows_processed + 1;

        BEGIN
            -- Find customer
            SELECT id INTO customer_uuid 
            FROM customers 
            WHERE name = csv_record.customer_name;
            
            IF customer_uuid IS NULL THEN
                errors := array_append(errors, format('Row %s: Customer not found: %s', rows_processed, csv_record.customer_name));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;

            -- Find project
            SELECT id INTO project_uuid 
            FROM projects 
            WHERE customer_id = customer_uuid 
            AND name = csv_record.project_name;
            
            IF project_uuid IS NULL THEN
                errors := array_append(errors, format('Row %s: Project not found: %s for customer %s', rows_processed, csv_record.project_name, csv_record.customer_name));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;

            -- Generate template key
            template_key := format('project:%s:%s', project_uuid::text, lower(replace(csv_record.parameter_name, ' ', '_')));

            -- Check if template already exists
            SELECT id INTO template_id 
            FROM parameter_templates 
            WHERE key = template_key;

            IF template_id IS NOT NULL THEN
                errors := array_append(errors, format('Row %s: Parameter template already exists: %s (key: %s)', rows_processed, csv_record.parameter_name, template_key));
                rows_skipped := rows_skipped + 1;
                CONTINUE;
            END IF;

            -- Build metadata JSON
            template_metadata := jsonb_build_object(
                'project_id', project_uuid::text,
                'dtype', csv_record.dtype,
                'min', CASE WHEN csv_record.min_value ~ '^[0-9]+\.?[0-9]*$' THEN csv_record.min_value::REAL ELSE NULL END,
                'max', CASE WHEN csv_record.max_value ~ '^[0-9]+\.?[0-9]*$' THEN csv_record.max_value::REAL ELSE NULL END,
                'required', CASE WHEN lower(csv_record.required) IN ('true', 't', 'yes', 'y', '1') THEN true ELSE false END
            );

            -- Add description if provided
            IF csv_record.description IS NOT NULL AND csv_record.description != '' THEN
                template_metadata := template_metadata || jsonb_build_object('description', csv_record.description);
            END IF;

            -- Insert parameter template
            INSERT INTO parameter_templates (key, name, unit, metadata)
            VALUES (template_key, csv_record.parameter_name, csv_record.unit, template_metadata)
            RETURNING id INTO template_id;

            rows_created := rows_created + 1;

        EXCEPTION WHEN OTHERS THEN
            errors := array_append(errors, format('Row %s: Error - %s', rows_processed, SQLERRM));
            rows_skipped := rows_skipped + 1;
        END;
    END LOOP;

    -- Report results
    RAISE NOTICE 'Import completed:';
    RAISE NOTICE '  Rows processed: %', rows_processed;
    RAISE NOTICE '  Templates created: %', rows_created;
    RAISE NOTICE '  Rows skipped: %', rows_skipped;

    IF array_length(errors, 1) > 0 THEN
        RAISE NOTICE 'Errors:';
        FOREACH template_key IN ARRAY errors LOOP
            RAISE NOTICE '  %', template_key;
        END LOOP;
    END IF;

    DROP TABLE IF EXISTS csv_import;
END;
\$\$;
"
fi

# Write SQL to pod and execute
kubectl exec -n "$NAMESPACE" "$DB_POD" -- bash -c "cat > /tmp/import_script.sql << 'EOFSQL'
$IMPORT_SQL
EOFSQL
"

kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
  psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/import_script.sql

# Cleanup
kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f /tmp/parameter_import.csv /tmp/import_script.sql

echo ""
echo "Import completed!"
if [ -n "$CUSTOMER_ID" ]; then
    echo "Note: Import was restricted to customer: $CUSTOMER_NAME ($CUSTOMER_ID)"
fi

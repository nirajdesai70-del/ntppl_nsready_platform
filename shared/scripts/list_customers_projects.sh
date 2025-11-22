#!/bin/bash

# List all customers and projects for CSV creation
# Usage: ./scripts/list_customers_projects.sh

set -e

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

echo "=== Customers and Projects in Database ==="
echo "Environment: $([ "$USE_KUBECTL" = "true" ] && echo "Kubernetes" || echo "Docker Compose")"
echo ""
echo "Use these EXACT names in your CSV file:"
echo ""

SQL_QUERY="SELECT c.name as customer_name, p.name as project_name \
   FROM customers c JOIN projects p ON p.customer_id = c.id \
   ORDER BY c.name, p.name;"

if [ "$USE_KUBECTL" = "true" ]; then
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
      psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL_QUERY" --csv
else
    docker exec nsready_db psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL_QUERY" --csv
fi

echo ""
echo "=== CSV Template Format ==="
echo "customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description"
echo ""
echo "Example:"
echo "Customer 01,Project 01_Customer_01,Voltage,V,float,0,240,true,AC voltage measurement"
echo "Customer 01,Project 01_Customer_01,Current,A,float,0,50,true,Current consumption"





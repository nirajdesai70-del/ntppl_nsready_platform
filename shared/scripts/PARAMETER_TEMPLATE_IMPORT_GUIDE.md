# Parameter Template Import Guide

This guide explains how engineers can define site-related parameters using CSV files and import them into the system.

## Overview

Parameter templates define what measurements/data points can be collected for each project. Engineers can:
1. Export existing parameter templates to CSV
2. Edit or create new parameter templates in CSV format
3. Import the CSV to create/update parameter templates in the database

## CSV Format

The CSV file must have the following columns (in order):

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| `customer_name` | Yes | Name of the customer | `Customer 01` |
| `project_name` | Yes | Name of the project | `Project 01_Customer_01` |
| `parameter_name` | Yes | Display name of the parameter | `Voltage`, `Current`, `Power` |
| `unit` | No | Unit of measurement | `V`, `A`, `kW`, `Hz` |
| `dtype` | No | Data type | `float`, `int`, `string` |
| `min_value` | No | Minimum allowed value | `0`, `-100` |
| `max_value` | No | Maximum allowed value | `240`, `1000` |
| `required` | No | Whether parameter is required | `true`, `false` |
| `description` | No | Description of the parameter | `AC voltage measurement` |

### Example CSV

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 01,Project 01_Customer_01,Voltage,V,float,0,240,true,AC voltage measurement
Customer 01,Project 01_Customer_01,Current,A,float,0,50,true,Current consumption
Customer 01,Project 01_Customer_01,Power,kW,float,0,100,false,Power consumption
Customer 02,Project 01_Customer_02,Temperature,°C,float,-40,85,true,Ambient temperature
Customer 02,Project 01_Customer_02,Humidity,%,float,0,100,false,Relative humidity
```

## Usage

### Step 1: Export Existing Templates (Optional)

To see the current format or export existing templates for editing:

```bash
./scripts/export_parameter_template_csv.sh
```

This creates a CSV file in the `reports/` folder with all existing parameter templates.

### Step 2: Create/Edit CSV File

**Quick Start:**
1. Get exact customer/project names: `./scripts/list_customers_projects.sh`
2. Use the template: `scripts/parameter_template_template.csv` or `scripts/example_parameters.csv`
3. Or export existing: `./scripts/export_parameter_template_csv.sh`
4. Fill in your parameter definitions

**Detailed Instructions:**
See `scripts/create_parameter_csv_guide.md` for step-by-step instructions with examples.

**Important Notes:**
- Customer and project names must match exactly what's in the database (use `list_customers_projects.sh` to get exact names)
- Parameter names should be unique within a project
- If a parameter template already exists (same key), it will be skipped
- Empty values are allowed for optional fields (unit, dtype, min_value, max_value, description)

### Step 3: Import CSV File

```bash
./scripts/import_parameter_templates.sh <path_to_csv_file>
```

Example:
```bash
./scripts/import_parameter_templates.sh my_parameters.csv
```

The script will:
- Validate customer and project names
- Generate unique keys for each parameter
- Create parameter templates in the database
- Report success/failure for each row

## Output

The import script provides feedback:
- Number of rows processed
- Number of templates created
- Number of rows skipped (with reasons)
- Any errors encountered

Example output:
```
Import completed:
  Rows processed: 5
  Templates created: 5
  Rows skipped: 0
```

## Parameter Key Generation

Parameter keys are automatically generated in the format:
```
project:<project_uuid>:<parameter_name_lowercase_with_underscores>
```

Example: `project:67e149fb-7c9f-420c-a249-4a1fcd1df53f:voltage`

## Metadata Structure

Each parameter template stores metadata as JSON:
```json
{
  "project_id": "<project_uuid>",
  "dtype": "float",
  "min": 0,
  "max": 240,
  "required": true,
  "description": "AC voltage measurement"
}
```

## Troubleshooting

### Error: Customer not found
- Verify the customer name matches exactly (case-sensitive)
- Check existing customers: `kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT name FROM customers;"`

### Error: Project not found
- Verify the project name matches exactly (case-sensitive)
- Check existing projects: `kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT c.name as customer, p.name as project FROM projects p JOIN customers c ON c.id = p.customer_id;"`

### Error: Parameter template already exists
- The parameter key already exists in the database
- Either use a different parameter name or delete the existing template first

### Empty values
- Empty strings are allowed for optional fields (unit, dtype, min_value, max_value, description)
- For `required`, use `true` or `false` (defaults to `false` if empty)

## Related Scripts

- `export_parameter_template_csv.sh` - Export existing templates to CSV
- `import_parameter_templates.sh` - Import CSV to create templates
- `export_registry_data.sh` - Export full registry data including parameters


# How to Create Parameter Template CSV File

This guide shows you exactly how to create a CSV file for importing parameter templates.

## Step-by-Step Instructions

### Step 1: Get Exact Customer and Project Names

First, you need to know the **exact** customer and project names from the database. Run:

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT c.name as customer_name, p.name as project_name \
   FROM customers c JOIN projects p ON p.customer_id = c.id \
   ORDER BY c.name, p.name;"
```

**Important**: Copy the names EXACTLY as they appear (including spaces, capitalization, underscores).

### Step 2: Create CSV File

You can create the CSV file in three ways:

#### Option A: Use the Template File

1. Copy the template:
   ```bash
   cp scripts/parameter_template_template.csv my_parameters.csv
   ```

2. Open `my_parameters.csv` in Excel, Google Sheets, or any text editor

3. Fill in your data following the format

#### Option B: Start from Scratch

Create a new file (e.g., `my_parameters.csv`) with this header:

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

Then add your data rows below.

#### Option C: Export Existing and Modify

```bash
./scripts/export_parameter_template_csv.sh
```

This creates a CSV with existing templates. You can:
- Edit existing rows
- Add new rows
- Keep the format the same

### Step 3: Fill in the CSV Data

For each parameter you want to define, add one row with these columns:

| Column | What to Put | Example | Required? |
|--------|-------------|---------|-----------|
| `customer_name` | Exact customer name from database | `Customer 01` | ✅ Yes |
| `project_name` | Exact project name from database | `Project 01_Customer_01` | ✅ Yes |
| `parameter_name` | Name of the parameter | `Voltage`, `Temperature` | ✅ Yes |
| `unit` | Unit of measurement | `V`, `°C`, `kW`, `%` | No |
| `dtype` | Data type | `float`, `int`, `string` | No |
| `min_value` | Minimum value | `0`, `-40` | No |
| `max_value` | Maximum value | `240`, `100` | No |
| `required` | `true` or `false` | `true` | No (defaults to `false`) |
| `description` | Description text | `AC voltage measurement` | No |

### Step 4: Example CSV Files

#### Example 1: Basic Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage measurement
Customer 02,Project 01_Customer_02,Current,A,float,0,50,true,Current consumption
Customer 02,Project 01_Customer_02,Power,kW,float,0,100,false,Power consumption
```

#### Example 2: Environmental Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 03,Project 01_Customer_03,Temperature,°C,float,-40,85,true,Ambient temperature
Customer 03,Project 01_Customer_03,Humidity,%,float,0,100,false,Relative humidity
Customer 03,Project 01_Customer_03,Pressure,Pa,float,0,101325,false,Atmospheric pressure
```

#### Example 3: With Empty Optional Fields

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 04,Project 01_Customer_04,Status,,string,,,false,Device status
Customer 04,Project 01_Customer_04,Count,,int,0,,true,Event count
```

### Step 5: Common Mistakes to Avoid

❌ **Wrong**: Using approximate names
```csv
customer_name,project_name,...
Customer 1,Project 1,...
```
✅ **Correct**: Use exact names from database
```csv
customer_name,project_name,...
Customer 01,Project 01_Customer_01,...
```

❌ **Wrong**: Missing commas or extra spaces
```csv
Customer 01, Project 01_Customer_01,Voltage
```
✅ **Correct**: No spaces after commas
```csv
Customer 01,Project 01_Customer_01,Voltage
```

❌ **Wrong**: Using quotes incorrectly
```csv
"Customer 01","Project 01_Customer_01","Voltage"
```
✅ **Correct**: Only quote if value contains comma
```csv
Customer 01,Project 01_Customer_01,Voltage
```

### Step 6: Validate Your CSV

Before importing, check:

1. **Header row is correct**: First line must match exactly:
   ```
   customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
   ```

2. **All required columns present**: customer_name, project_name, parameter_name

3. **No extra commas**: Each row should have exactly 9 columns (including empty ones)

4. **Customer/Project names match**: Verify against database output

### Step 7: Quick Validation Script

You can use this to check your CSV format:

```bash
# Check if CSV has correct number of columns
awk -F',' 'NR==1 {print "Header columns: " NF} NR>1 {if (NF != 9) print "Row " NR " has " NF " columns (expected 9)"}' my_parameters.csv
```

### Step 8: Import Your CSV

Once your CSV is ready:

```bash
./scripts/import_parameter_templates.sh my_parameters.csv
```

The script will tell you:
- How many rows were processed
- How many templates were created
- Any errors (like customer/project not found)

## Quick Reference

**CSV Format:**
```
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**Required Fields:**
- customer_name (must match database exactly)
- project_name (must match database exactly)
- parameter_name (unique within project)

**Optional Fields:**
- unit, dtype, min_value, max_value, required, description
- Can be left empty

**File Encoding:**
- Use UTF-8 encoding
- Save as `.csv` file
- Use comma (`,`) as delimiter

## Need Help?

If you get errors during import:
1. Check the error message - it will tell you which row has the problem
2. Verify customer/project names match exactly
3. Check CSV format (correct number of columns)
4. Make sure there are no special characters causing issues









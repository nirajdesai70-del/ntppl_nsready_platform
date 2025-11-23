# Engineer Guide: Defining Site Parameters for Data Collection

This guide will help you define parameters (measurements/data points) for each site/project so that the data collection system knows what to collect.

## 📋 Overview

**What are Parameter Templates?**
- They define what measurements can be collected for each project
- Examples: Voltage, Current, Temperature, Humidity, etc.
- Each parameter has properties like unit, data type, min/max values

**Why do I need this?**
- Before data collection can start, the system needs to know what parameters to expect
- You define these parameters once per project using a CSV file
- The CSV is then imported into the system

## 🚀 Quick Start (5 Minutes)

### Step 1: Get Customer and Project Names

Run this command to see all available customers and projects:

```bash
./shared/scripts/list_customers_projects.sh
```

**Important:** Copy the names EXACTLY as they appear (including spaces and capitalization).

Example output:
```
customer_name,project_name
Customer 01,Project 01_Customer_01
Customer 02,Project 01_Customer_02
Demo Customer,Demo Project
```

### Step 2: Create Your CSV File

**Option A: Start from Example (Recommended)**

```bash
cp shared/scripts/example_parameters.csv my_project_parameters.csv
```

Then open `my_project_parameters.csv` in Excel, Google Sheets, or any text editor.

**Option B: Start from Template**

```bash
cp shared/scripts/parameter_template_template.csv my_project_parameters.csv
```

**Option C: Export Existing and Modify**

If you want to see existing parameters first:

```bash
./shared/scripts/export_parameter_template_csv.sh
```

This creates a file in `nsready_backend/tests/reports/` folder. You can edit it and add more parameters.

### Step 3: Fill in Your CSV

Open your CSV file and add rows for each parameter you want to define.

**CSV Format:**
```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**Example:**
```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage measurement
Customer 02,Project 01_Customer_02,Current,A,float,0,50,true,Current consumption
Customer 02,Project 01_Customer_02,Power,kW,float,0,100,false,Power consumption
```

### Step 4: Import Your CSV

Once your CSV is ready, import it:

```bash
./shared/scripts/import_parameter_templates.sh my_project_parameters.csv
```

You'll see output like:
```
Import completed:
  Rows processed: 3
  Templates created: 3
  Rows skipped: 0
```

**Done!** Your parameters are now configured and ready for data collection.

---

## 📝 Detailed Instructions

### Understanding the CSV Columns

| Column | Required? | Description | Example Values |
|--------|-----------|-------------|----------------|
| `customer_name` | ✅ **Yes** | Exact customer name from database | `Customer 01`, `Demo Customer` |
| `project_name` | ✅ **Yes** | Exact project name from database | `Project 01_Customer_01` |
| `parameter_name` | ✅ **Yes** | Name of the parameter | `Voltage`, `Temperature`, `Status` |
| `unit` | No | Unit of measurement | `V`, `A`, `kW`, `°C`, `%`, `Hz` |
| `dtype` | No | Data type | `float`, `int`, `string` |
| `min_value` | No | Minimum allowed value | `0`, `-40`, `-100` |
| `max_value` | No | Maximum allowed value | `240`, `100`, `1000` |
| `required` | No | Is this parameter required? | `true` or `false` (default: `false`) |
| `description` | No | Description of the parameter | `AC voltage measurement` |

### CSV Examples

#### Example 1: Electrical Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage measurement
Customer 02,Project 01_Customer_02,Current,A,float,0,50,true,Current consumption
Customer 02,Project 01_Customer_02,Power,kW,float,0,100,false,Power consumption
Customer 02,Project 01_Customer_02,Frequency,Hz,float,45,55,true,AC frequency
```

#### Example 2: Environmental Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 03,Project 01_Customer_03,Temperature,°C,float,-40,85,true,Ambient temperature
Customer 03,Project 01_Customer_03,Humidity,%,float,0,100,false,Relative humidity
Customer 03,Project 01_Customer_03,Pressure,Pa,float,0,101325,false,Atmospheric pressure
```

#### Example 3: Mixed Parameters (Some Fields Empty)

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 04,Project 01_Customer_04,Status,,string,,,false,Device status
Customer 04,Project 01_Customer_04,Count,,int,0,,true,Event count
Customer 04,Project 01_Customer_04,Voltage,V,float,0,240,true,AC voltage
```

**Note:** Empty fields are allowed for optional columns. Just leave them blank.

### Common Parameter Types

| Parameter Type | Unit Examples | dtype | Typical Range |
|---------------|---------------|-------|---------------|
| Voltage | V, kV, mV | float | 0-240, 0-1000 |
| Current | A, mA, kA | float | 0-50, 0-1000 |
| Power | W, kW, MW | float | 0-100, 0-10000 |
| Energy | kWh, MWh | float | 0-1000000 |
| Temperature | °C, °F, K | float | -40 to 85, -40 to 150 |
| Humidity | % | float | 0-100 |
| Pressure | Pa, kPa, bar | float | 0-101325, 0-1000 |
| Frequency | Hz, kHz | float | 45-55, 0-1000 |
| Status | - | string | - |
| Count | - | int | 0-1000000 |

---

## ⚠️ Important Rules

### 1. Exact Name Matching

**❌ WRONG:**
```csv
Customer 1,Project 1,Voltage
```

**✅ CORRECT:**
```csv
Customer 01,Project 01_Customer_01,Voltage
```

**Why?** The system matches names exactly. Use `list_customers_projects.sh` to get exact names.

### 2. Unique Parameter Names

Each parameter name must be unique within a project.

**❌ WRONG (duplicate):**
```csv
Customer 02,Project 01_Customer_02,Voltage
Customer 02,Project 01_Customer_02,Voltage
```

**✅ CORRECT:**
```csv
Customer 02,Project 01_Customer_02,Voltage
Customer 02,Project 01_Customer_02,Voltage_Phase1
```

### 3. CSV Format

- Use commas (`,`) to separate columns
- No spaces after commas
- First row must be the header
- Each row should have 9 columns (even if some are empty)

**❌ WRONG:**
```csv
Customer 01, Project 01_Customer_01, Voltage
```

**✅ CORRECT:**
```csv
Customer 01,Project 01_Customer_01,Voltage
```

### 4. Data Types

- `float`: For decimal numbers (0.5, 123.45, -10.2)
- `int`: For whole numbers (0, 100, -50)
- `string`: For text values ("active", "offline", "error")

### 5. Required Field Values

For the `required` column, use:
- `true` or `false` (lowercase)
- Or leave empty (defaults to `false`)

---

## 🔧 Troubleshooting

### Error: "Customer not found"

**Problem:** The customer name in your CSV doesn't match the database.

**Solution:**
1. Run `./scripts/list_customers_projects.sh`
2. Copy the exact customer name
3. Update your CSV file

### Error: "Project not found"

**Problem:** The project name doesn't match or doesn't belong to that customer.

**Solution:**
1. Run `./scripts/list_customers_projects.sh`
2. Verify the customer-project combination exists
3. Update your CSV file

### Error: "Parameter template already exists"

**Problem:** A parameter with the same name already exists for that project.

**Solution:**
1. Use a different parameter name
2. Or check existing parameters: `./shared/scripts/export_parameter_template_csv.sh`

### CSV Format Errors

**Problem:** Import fails with format errors.

**Solution:**
1. Check you have exactly 9 columns per row
2. Verify the header row matches exactly:
   ```
   customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
   ```
3. Make sure there are no extra commas or missing commas
4. Save file as UTF-8 encoding

### Validation Check

Before importing, you can check your CSV format:

```bash
# Check column count
awk -F',' 'NR==1 {print "Header: " NF " columns"} NR>1 {if (NF != 9) print "Row " NR ": " NF " columns (expected 9)"}' my_project_parameters.csv
```

---

## 📚 Complete Workflow Example

Let's say you want to add parameters for "Customer 02":

### Step 1: Get Exact Names
```bash
./shared/scripts/list_customers_projects.sh
```
Output shows: `Customer 02,Project 01_Customer_02`

### Step 2: Create CSV
```bash
cp shared/scripts/example_parameters.csv customer02_params.csv
```

### Step 3: Edit CSV
Open `customer02_params.csv` and modify:

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage
Customer 02,Project 01_Customer_02,Current,A,float,0,50,true,Current consumption
Customer 02,Project 01_Customer_02,Power,kW,float,0,100,false,Power consumption
```

### Step 4: Import
```bash
./scripts/import_parameter_templates.sh customer02_params.csv
```

### Step 5: Verify
```bash
./shared/scripts/export_parameter_template_csv.sh
```
Check the exported file to confirm your parameters were created.

---

## 📁 Available Scripts

| Script | Purpose |
|--------|---------|
| `list_customers_projects.sh` | List all customers and projects (get exact names) |
| `export_parameter_template_csv.sh` | Export existing parameters to CSV |
| `import_parameter_templates.sh <file>` | Import CSV to create parameters |
| `export_registry_data.sh` | Export full registry data (includes parameters) |

---

## 💡 Tips

1. **Start Small:** Define 2-3 parameters first, test the import, then add more
2. **Use Examples:** Copy from `example_parameters.csv` and modify
3. **Check First:** Always run `list_customers_projects.sh` to get exact names
4. **Validate:** Check your CSV format before importing
5. **Backup:** Keep a copy of your CSV file for future reference

---

## ❓ Need Help?

1. Check the error message - it usually tells you what's wrong
2. Verify customer/project names match exactly
3. Check CSV format (9 columns, proper commas)
4. Review the examples in this guide
5. Check `shared/scripts/create_parameter_csv_guide.md` for more details

---

## ✅ Quick Checklist

Before importing your CSV, make sure:

- [ ] Customer names match exactly (use `list_customers_projects.sh`)
- [ ] Project names match exactly
- [ ] CSV has correct header row
- [ ] Each row has exactly 9 columns
- [ ] Parameter names are unique within each project
- [ ] File is saved as UTF-8 encoding
- [ ] No extra spaces after commas

---

**Ready to start?** Run `./shared/scripts/list_customers_projects.sh` and begin creating your CSV file!

---

### Backend Testing (Standard Process)

Backend test procedures are now maintained centrally in:

- `nsready_backend/tests/README_BACKEND_TESTS.md` (full SOP)
- `nsready_backend/tests/README_BACKEND_TESTS_QUICK.md` (operator quick view)

**Key commands (from repository root):**

```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform

./shared/scripts/test_data_flow.sh
./shared/scripts/test_batch_ingestion.sh --count 100
./shared/scripts/test_stress_load.sh
```

All reports are stored under:

```text
nsready_backend/tests/reports/
```

For detailed negative, roles, multi-customer, tenant, SCADA, and final-drive tests, see the Extended Test Suite section in:

- `nsready_backend/tests/README_BACKEND_TESTS.md`


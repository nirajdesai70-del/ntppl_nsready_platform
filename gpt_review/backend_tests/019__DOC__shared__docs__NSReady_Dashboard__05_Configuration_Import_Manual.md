# Module 5 – Configuration Import Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/05_Configuration_Import_Manual.md`)*

---

## 1. Introduction

This module explains how to configure the NSReady Data Collection Platform using CSV-based import tools. It covers:

- Customer creation
- Project creation
- Site registration
- Device registration
- Parameter template import

These steps must be completed **before any data ingestion or SCADA integration**.

---

## 2. High-Level Configuration Workflow

```
+--------------------+
| registry_template  |
| example_registry   |
+---------+----------+
          |
          | import_registry.sh
          v
+------------------------------+
| Customers / Projects / Sites |
| Devices                      |
+--------------+---------------+
               |
               | parameter_template_template.csv
               | example_parameters.csv
               v
+------------------------------+
| import_parameter_templates   |
+--------------+---------------+
               |
               v
+-----------------------------------------+
| NSReady Data Collector Reading Metadata |
+-----------------------------------------+
```

This manual covers both:
- **Part 1:** Registry Import (Customers → Projects → Sites → Devices)
- **Part 2:** Parameter Template Import

---

## Part 1: Registry Import (Customers, Projects, Sites, Devices)

### 3. Registry Import Overview

#### 3.1 Purpose

The registry CSV defines who, what, and where:

- **Customers** (who owns the system)
- **Projects** (logical grouping of sites)
- **Sites** (physical or logical locations)
- **Devices** (field devices/panels/controllers)

**Hierarchy:**

```
Customer → Project → Site → Device
```

#### 3.2 Files Required

All under `scripts/`:

| File | Description |
|------|-------------|
| `registry_template.csv` | Template CSV for registry import |
| `example_registry.csv` | Example registry file with sample data |
| `import_registry.sh` | Script that reads CSV and updates DB |
| `list_customers_projects.sh` | Lists current customers/projects |
| `export_registry_data.sh` | Exports current registry (read-only) |

#### 3.3 CSV Format (Registry)

The registry CSV must have the following columns in this order:

```
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
```

**ASCII summary:**

```
+----------------------+----------+-------------------------------------+
| Column               | Required | Description                         |
+----------------------+----------+-------------------------------------+
| customer_name        | Yes      | Customer identifier                 |
| project_name         | Yes      | Project under that customer         |
| project_description  | No       | Human-readable notes                |
| site_name            | Yes      | Physical/logical site name          |
| site_location        | No       | JSON location; `{}` allowed         |
| device_name          | No       | Device friendly name                |
| device_type          | No       | sensor/meter/controller             |
| device_code          | No       | External unique code (recommended)  |
| device_status        | No       | active/inactive/maintenance         |
+----------------------+----------+-------------------------------------+
```

#### 3.4 Example Registry CSV

```csv
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
Acme Corp,Factory Monitoring,Real-time monitoring,Main Factory,{"city":"Mumbai"},Sensor-001,sensor,SEN001,active
Acme Corp,Factory Monitoring,Real-time monitoring,Main Factory,{"city":"Mumbai"},Sensor-002,sensor,SEN002,active
Acme Corp,Factory Monitoring,Real-time monitoring,Boiler House,{"city":"Mumbai"},BoilerMeter-01,meter,BLR001,active
```

**Notes:**

- Multiple rows can reuse the same customer/project/site with different devices.
- `site_location` can be `{}` if you do not want to store location.

#### 3.5 Import Command (Copy & Paste)

From project root (where `scripts/` lives):

```bash
./scripts/import_registry.sh my_registry.csv
```

Where `my_registry.csv` is your filled CSV file based on the template.

**Note:** The script automatically detects whether you're using Kubernetes or Docker Compose.

#### 3.6 Expected Output (Example)

```
Importing registry data from: my_registry.csv
Environment: Kubernetes (or Docker Compose)

NOTICE:  Import completed:
NOTICE:    Rows processed: 3
NOTICE:    Customers created: 1
NOTICE:    Projects created: 1
NOTICE:    Sites created: 2
NOTICE:    Devices created: 3
NOTICE:    Rows skipped: 0

Import completed!
```

Numbers will vary based on your CSV.

#### 3.7 Verification Commands

##### 3.7.1 List customers and projects

```bash
./scripts/list_customers_projects.sh
```

Expected to see e.g.:

```
customer_name,project_name
Acme Corp,Factory Monitoring
...
```

**Note:** This script supports both Kubernetes and Docker Compose.

##### 3.7.2 Export full registry

```bash
./scripts/export_registry_data.sh
```

This creates a CSV under `reports/` showing customers, projects, sites, devices, and parameters.

##### 3.7.3 Check devices in DB

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT name, device_type, external_id FROM devices LIMIT 20;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT name, device_type, external_id FROM devices LIMIT 20;"
```

#### 3.8 Behaviour and Rules

1. **Customer handling**
   - If `customer_name` exists → reused
   - If not → created

2. **Project handling**
   - Unique per `(customer_name, project_name)`
   - Reused if exists

3. **Site handling**
   - Unique per `(project, site_name)`
   - `site_location` stored as JSON (use `{}` if unknown)

4. **Device handling**
   - Devices matched by `device_code` (preferred) or `device_name`
   - If a match is found → not duplicated
   - If no match → new device created
   - Device fields are all optional - you can have sites without devices

#### 3.9 Common Problems & Fixes

| Problem | Likely Cause | Fix |
|---------|--------------|-----|
| Customer not created | CSV not read / script failure | Check script output & path |
| "Customer not found" later | Wrong spelling or spaces | Use `list_customers_projects.sh` to copy exact name |
| Device not created | No `device_name` and no `device_code` | Provide at least one |
| Invalid JSON in `site_location` | Bad JSON string | Use `{}` or ensure proper JSON format |
| Duplicate devices | Different `device_code` for same physical device | Standardize `device_code` |
| "Cannot detect environment" | Neither Kubernetes nor Docker detected | Set `USE_KUBECTL=true` for Kubernetes or `USE_KUBECTL=false` for Docker |

#### 3.10 Checklist – Registry Import Complete

- [ ] `import_registry.sh` completed without errors
- [ ] Customers appear in `list_customers_projects.sh` (or database query)
- [ ] Projects appear under correct customers
- [ ] Sites appear under correct projects
- [ ] Devices appear under correct sites
- [ ] `export_registry_data.sh` shows expected relationships

---

## Part 2: Parameter Template Import

### 4. Parameter Template Overview

#### 4.1 Purpose

Parameter templates define **what measurements/tags** are collected for each project/site/device.

**Prerequisites:** Registry Import (Part 1) must be completed first. Customers and Projects must exist in the database before importing parameters.

#### 4.2 Parameter Template Concept

Parameter templates answer:

- **Which values** will be collected? (Voltage, Current, Power, Temperature, etc.)
- **What units** do they use? (V, A, kW, °C, etc.)
- **What type** of data? (float, int, string)
- **Valid ranges** (min/max)
- **Required or optional**?

The collector uses parameter templates to:

- Validate incoming data
- Map JSON metrics to parameters
- Support SCADA/NSWare KPIs later

#### 4.3 Files Required

All under `scripts/`:

| File | Description |
|------|-------------|
| `parameter_template_template.csv` | Empty template for parameters |
| `example_parameters.csv` | Example parameter definitions |
| `import_parameter_templates.sh` | Script to import parameter templates |
| `export_parameter_template_csv.sh` | Script to export existing parameters |

#### 4.4 CSV Format – Parameter Templates

The CSV header must be exactly:

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**ASCII table:**

```
+-------------------+----------+-------------------------------+
| Column            | Required | Description                   |
+-------------------+----------+-------------------------------+
| customer_name     | Yes      | Exact customer name           |
| project_name      | Yes      | Exact project name            |
| parameter_name   | Yes      | Name of parameter             |
| unit              | No       | "V", "A", "kW", "°C", etc.    |
| dtype             | No       | "float", "int", "string"      |
| min_value         | No       | Engineering lower limit      |
| max_value         | No       | Engineering upper limit       |
| required          | No       | "true" / "false"               |
| description       | No       | Human-readable note           |
+-------------------+----------+-------------------------------+
```

#### 4.5 Example Parameter CSV

##### 4.5.1 Electrical Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Acme Corp,Factory Monitoring,Voltage,V,float,0,240,true,AC voltage measurement
Acme Corp,Factory Monitoring,Current,A,float,0,50,true,Current consumption
Acme Corp,Factory Monitoring,Power,kW,float,0,100,false,Power consumption
Acme Corp,Factory Monitoring,Frequency,Hz,float,45,55,true,AC frequency
```

##### 4.5.2 Environmental Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Demo Customer,Demo Project,Temperature,°C,float,-40,85,true,Ambient temperature
Demo Customer,Demo Project,Humidity,%,float,0,100,false,Relative humidity
Demo Customer,Demo Project,Pressure,Pa,float,0,101325,false,Atmospheric pressure
```

**Important Notes:**

- `customer_name` and `project_name` must match exactly (case-sensitive) with what was imported in Part 1
- Use `./scripts/list_customers_projects.sh` to get exact names
- Empty values are allowed for optional fields (unit, dtype, min_value, max_value, description)

#### 4.6 Import Command (Copy & Paste)

From project root:

```bash
./scripts/import_parameter_templates.sh my_parameters.csv
```

**Note:** The script automatically detects whether you're using Kubernetes or Docker Compose.

#### 4.7 Expected Output

```
Importing parameter templates from: my_parameters.csv

NOTICE:  Import completed:
NOTICE:    Rows processed: 5
NOTICE:    Templates created: 5
NOTICE:    Rows skipped: 0

Import completed!
```

If some rows are skipped, the script will mention which ones and why:

```
NOTICE:  Errors:
NOTICE:    Row 3: Parameter template already exists: Voltage (key: project:...)
```

#### 4.8 Verification Commands

##### 4.8.1 Export current parameter templates

```bash
./scripts/export_parameter_template_csv.sh
```

This creates a CSV under `reports/` that you can open in Excel and review.

##### 4.8.2 Check DB directly

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT key, name, unit, metadata FROM parameter_templates LIMIT 20;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT key, name, unit, metadata FROM parameter_templates LIMIT 20;"
```

#### 4.9 Common Issues & Fixes

##### 4.9.1 Customer not found

**Cause:** `customer_name` in CSV does not match DB.

**Fix:**

```bash
./scripts/list_customers_projects.sh
```

Copy the exact customer name from the output and update CSV.

**Example Error:**

```
NOTICE:    Row 2: Customer not found: Acme Corp Inc
```

**Solution:** Check if the name in database is "Acme Corp" (without "Inc").

##### 4.9.2 Project not found

**Cause:** `project_name` mismatch or wrong customer/project combination.

**Fix:**

- Use `list_customers_projects.sh`
- Ensure `project_name` exactly matches a project under the given `customer_name`.

**Example Error:**

```
NOTICE:    Row 3: Project not found: Factory Monitoring for customer Acme Corp
```

**Solution:** Verify the project name is exactly "Factory Monitoring" (case-sensitive, no extra spaces).

##### 4.9.3 Parameter already exists

**Cause:** A parameter with same key already exists.

**Behaviour:** Script skips that row (does not overwrite).

**Fix:**

- Use a different `parameter_name`, or
- Delete the existing template before re-import (via Admin API or DB).

**Example Notice:**

```
NOTICE:    Row 4: Parameter template already exists: Voltage (key: project:67e149fb-...:voltage)
```

##### 4.9.4 CSV format errors

**Symptoms:**

- Script complains about invalid CSV
- Wrong number of columns per row

**Checks:**

- Header must be exactly:

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

- Each row must have exactly 9 columns, even if some are empty.

**Validation helper (optional):**

```bash
awk -F',' 'NR==1 {print "Header columns: " NF} NR>1 {if (NF != 9) print "Row " NR " has " NF " columns (expected 9)"}' my_parameters.csv
```

#### 4.10 Complete Workflow Example

##### 4.10.1 Scenario

You want to define Voltage/Current/Power for Acme Corp → Factory Monitoring.

**Steps:**

1. **List customers/projects:**

```bash
./scripts/list_customers_projects.sh
```

Expected output:

```
customer_name,project_name
Acme Corp,Factory Monitoring
```

2. **Copy example CSV:**

```bash
cp scripts/example_parameters.csv acme_factory_parameters.csv
```

3. **Edit `acme_factory_parameters.csv`:**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Acme Corp,Factory Monitoring,Voltage,V,float,0,240,true,AC voltage
Acme Corp,Factory Monitoring,Current,A,float,0,50,true,Current consumption
Acme Corp,Factory Monitoring,Power,kW,float,0,100,false,Power consumption
```

4. **Import:**

```bash
./scripts/import_parameter_templates.sh acme_factory_parameters.csv
```

5. **Verify:**

```bash
./scripts/export_parameter_template_csv.sh
```

Open the exported CSV in `reports/` to verify your parameters were imported correctly.

#### 4.11 Final Checklist – Parameter Templates

- [ ] Customer names are correct (from DB/list script)
- [ ] Project names match exactly (case-sensitive)
- [ ] CSV header is correct
- [ ] All required fields (`customer_name`, `project_name`, `parameter_name`) filled
- [ ] No duplicate parameter names per project
- [ ] Script reports no critical errors
- [ ] Parameters appear in exported CSV

---

## 5. Complete Configuration Workflow

### 5.1 Step-by-Step Process

1. **Import Registry** (Part 1)
   - Create CSV based on `registry_template.csv`
   - Run `./scripts/import_registry.sh my_registry.csv`
   - Verify with `./scripts/list_customers_projects.sh`

2. **Import Parameters** (Part 2)
   - Create CSV based on `parameter_template_template.csv`
   - Run `./scripts/import_parameter_templates.sh my_parameters.csv`
   - Verify with `./scripts/export_parameter_template_csv.sh`

3. **Verify Complete Configuration**
   - Export full registry: `./scripts/export_registry_data.sh`
   - Review exported CSV in `reports/`

### 5.2 Next Steps

After completing configuration import:

- **Module 7:** Data Ingestion and Testing Manual - Test data ingestion
- **Module 9:** SCADA Integration Manual - Set up SCADA integration
- **Module 11:** Troubleshooting and Diagnostics Manual - If issues arise

---

**End of Module 5 – Configuration Import Manual**

**Related Modules:**

- Module 3 – Environment and PostgreSQL Storage Manual
- Module 7 – Data Ingestion and Testing Manual
- Module 9 – SCADA Integration Manual
- Module 10 – Scripts and Tools Reference Manual


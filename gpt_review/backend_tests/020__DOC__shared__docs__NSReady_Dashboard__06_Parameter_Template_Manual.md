# Module 6 – Parameter Template Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/06_Parameter_Template_Manual.md`)*

---

## 1. Introduction

Parameter Templates define what values the system expects from each device.

They are critical because:

- They define all engineering measurements
- They enable data validation and mapping
- They ensure devices and SCADA speak the same "language"
- They ensure compatibility with future NSWare modules
- They prevent ingestion failures due to missing parameter definitions

Parameter templates are created **before data ingestion** and **before SCADA integration**.

**Relationship to other modules:**

- **Module 5** - Configuration Import Manual covers the basic import process
- **This module (Module 6)** - Deep technical guide for parameter template design and management

---

## 2. What Is a Parameter Template?

A parameter template is a metadata definition describing one measurement/tag.

**Example parameters:**

- **Voltage** (V)
- **Current** (A)
- **Power** (kW)
- **Temperature** (°C)
- **Humidity** (%)
- **Flow** (m³/h)
- **Pressure** (bar)
- **Frequency** (Hz)

**Each template includes:**

| Field | Meaning | Required |
|-------|---------|----------|
| `parameter_name` | Display name (e.g., "Voltage") | Yes |
| `unit` | Engineering unit (e.g., "V", "A", "kW") | No |
| `dtype` | Data type (`float`, `int`, `string`) | No |
| `min_value` | Minimum allowed value | No |
| `max_value` | Maximum allowed value | No |
| `required` | Mandatory for device? (`true`/`false`) | No |
| `description` | Human-readable explanation | No |
| `parameter_key` | Auto-generated unique key | Generated |

**Database Storage:**

- Table: `parameter_templates`
- Key field: `key` (unique, used in foreign key references)
- Metadata stored in JSONB format

---

## 3. Why Parameter Templates Are Required

### 3.1 Validating Incoming Telemetry

**Without templates:**

- Collector cannot map metrics
- Worker cannot insert values (foreign key constraint)
- SCADA cannot understand parameters
- Data ingestion fails

**With templates:**

- Worker validates `parameter_key` exists before insert
- Foreign key constraint ensures data integrity
- SCADA can map parameters to readable names

**Example error without template:**

```
ERROR: insert or update on table "ingest_events" violates foreign key constraint
"ingest_events_parameter_key_fkey"
DETAIL: Key (parameter_key)=(project:...:voltage) is not present in table "parameter_templates".
```

---

### 3.2 Ensuring Engineering Consistency

**Examples:**

- **Voltage** must always use unit "V"
- **Temperature** must always use "°C"
- **Power** must always use "kW" or "W" (consistent per project)
- **Frequency** must always use "Hz"

**Benefits:**

- SCADA systems get consistent units
- Analytics engines can aggregate correctly
- Reports are standardized
- NSWare KPIs are accurate

---

### 3.3 Preventing Data Corruption

**Templates prevent:**

- **Invalid ranges** - Values outside min/max (future validation)
- **Wrong units** - Unit metadata ensures correct interpretation
- **Missing metrics** - Required parameters flagged (future feature)
- **Duplicate parameter names** - Unique keys prevent confusion

**Data Integrity:**

- Foreign key constraint: `ingest_events.parameter_key` → `parameter_templates.key`
- ON DELETE RESTRICT: Cannot delete template if data exists
- Unique constraint: One `parameter_key` per template

---

### 3.4 NSWare Compatibility

**NSWare's KPI engine, analytics, and dashboards rely heavily on correct parameter keys.**

**Why this matters:**

- Parameter keys are used in NSWare API calls
- Analytics queries reference parameter keys
- KPIs are calculated using parameter keys
- Dashboards map parameters by key

**Format consistency:**

- Parameter keys follow deterministic format
- Keys are stable (don't change after creation)
- Keys are project-scoped

---

## 4. Parameter Template Structure (Full Definition)

### 4.1 CSV Format

Below is the complete CSV schema for parameter templates:

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**Total columns:** 9 (including header row)

---

### 4.2 Field-by-Field Explanation

#### 4.2.1 `customer_name`

**Required:** Yes

**Rules:**

- Must **EXACTLY** match the customer in the registry (case-sensitive)
- No leading/trailing spaces
- Verified using `./scripts/list_customers_projects.sh`

**Example:**

```
Customer 01
```

**Common errors:**

- ❌ `"Customer 01 "` (trailing space)
- ❌ `"customer 01"` (wrong case)
- ❌ `"Customer_01"` (underscore instead of space)

---

#### 4.2.2 `project_name`

**Required:** Yes

**Rules:**

- Must **EXACTLY** match the project name (case-sensitive)
- Underscores must match exactly
- Must belong to the specified customer

**Example:**

```
Project 01_Customer_01
```

**Common errors:**

- ❌ `"Project 01-Customer 01"` (dash instead of underscore)
- ❌ `"project 01_customer_01"` (wrong case)
- ❌ `"Project01_Customer01"` (missing spaces)

**Verification:**

```bash
./scripts/list_customers_projects.sh | grep "Customer 01"
```

---

#### 4.2.3 `parameter_name`

**Required:** Yes

**Rules:**

- Human-readable display name
- Must be **unique within a project**
- Spaces are converted to underscores in `parameter_key`
- Case preserved in `name` field, lowercase in `key`

**Examples:**

```
Voltage
Phase1_Current
Compressor_Pressure
Tank_Level
Device_Status
```

**Best practices:**

- Use clear, descriptive names
- Use underscores for multi-word names
- Avoid abbreviations unless standard (e.g., "AC", "DC")

**Common errors:**

- ❌ `"Value1"` (too vague)
- ❌ `"Data"` (not descriptive)
- ❌ `"VoltagePhase1"` (missing underscore)

---

#### 4.2.4 `unit`

**Required:** No (can be blank)

**Common units:**

| Category | Units | Examples |
|----------|-------|----------|
| Electrical | V, A, W, kW, VA, kVA, Hz, Ω | Voltage, Current, Power |
| Temperature | °C, °F, K | Temperature measurements |
| Pressure | bar, Pa, kPa, psi | Pressure sensors |
| Flow | m³/h, L/min, GPM | Flow meters |
| Humidity | % | Relative humidity |
| Distance | m, cm, mm, km | Distance measurements |
| Count | (blank) | Counters, status codes |

**Rules:**

- Leave blank for unit-less values (e.g., "Status", "Count")
- Use standard SI units when possible
- Be consistent across projects

**Examples:**

```
V
A
kW
°C
%
m³/h
bar
```

---

#### 4.2.5 `dtype` (Data Type)

**Required:** No (can be blank)

**Supported values:**

- `float` - Floating-point numbers (decimals)
- `int` - Integer numbers (whole numbers)
- `string` - Text values

**Guidelines:**

| Scenario | Recommended dtype |
|----------|------------------|
| Engineering measurements | `float` |
| Count values | `int` |
| ON/OFF, RUN/STOP | `string` or `int` (0/1) |
| Status codes | `string` |
| Temperature, pressure | `float` |
| Event counts | `int` |

**Examples:**

```
dtype
float   ← Voltage: 230.5
float   ← Temperature: 25.3
int     ← Count: 1234
string  ← Status: "RUNNING"
```

**Note:** Current implementation stores all values as `DOUBLE PRECISION` in database, but dtype metadata is stored for future validation.

---

#### 4.2.6 `min_value` / `max_value`

**Required:** No (can be blank)

**Purpose:**

- Engineering range validation (future feature)
- Documentation of expected ranges
- SCADA display hints

**Rules:**

- Must be numeric if provided
- Can be decimal (e.g., `0.5`, `-40.5`)
- Leave blank if range not applicable (e.g., status codes)

**Examples:**

| Parameter | min_value | max_value | Reason |
|-----------|-----------|-----------|--------|
| Voltage | `0` | `240` | AC voltage range |
| Temperature | `-40` | `150` | Sensor range |
| Humidity | `0` | `100` | Percentage range |
| Pressure | `0` | `10` | Bar range |
| Status | (blank) | (blank) | Not numeric |

**Validation:**

- Script validates numeric format during import
- Non-numeric values stored as NULL in metadata

---

#### 4.2.7 `required`

**Required:** No (can be blank, treated as `false`)

**Values:**

- `true` / `t` / `yes` / `y` / `1` → Required
- `false` / `f` / `no` / `n` / `0` / blank → Optional

**Purpose:**

- Future feature: Flag missing metrics as issues
- Documentation: Indicates critical parameters

**Examples:**

```
required
true    ← Voltage (always present)
true    ← Temperature (critical measurement)
false   ← Humidity (optional)
false   ← Alarm status (optional)
```

**Note:** Current implementation does not enforce required flag during ingestion, but metadata is stored for future use.

---

#### 4.2.8 `description`

**Required:** No (can be blank)

**Purpose:**

- Human-readable explanation
- Documentation for engineers
- SCADA tag descriptions

**Examples:**

```
description
AC voltage measurement
Ambient temperature sensor
Totaliser pulse count
Device operational status
Compressor discharge pressure
```

**Best practices:**

- Be concise but descriptive
- Include measurement location if relevant
- Note any special conditions

---

## 5. Parameter Key Generation (Critical)

### 5.1 Format

Each parameter is assigned a unique `parameter_key` used throughout the system.

**Format:**

```
project:<project_uuid>:<parameter_name_lowercase_with_underscores>
```

**Example:**

```
project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage
project:8212caa2-b928-4213-b64e-9f5b86f4cad1:phase1_current
project:8212caa2-b928-4213-b64e-9f5b86f4cad1:compressor_pressure
```

**Generation Logic (from import script):**

```sql
template_key := format('project:%s:%s', 
    project_uuid::text, 
    lower(replace(csv_record.parameter_name, ' ', '_')));
```

**Conversion rules:**

- Project UUID: Exact UUID from database
- Parameter name: Converted to lowercase
- Spaces replaced with underscores
- Special characters preserved as-is

---

### 5.2 Parameter Key Rules

**✔ Always lowercase**

```
❌ project:...:Voltage
✅ project:...:voltage
```

**✔ Always underscores (not spaces or dashes)**

```
❌ project:...:phase 1 current
❌ project:...:phase-1-current
✅ project:...:phase_1_current
```

**✔ Deterministic**

- Same input always produces same key
- No random elements
- Reproducible

**✔ Never change after creation**

- Key is immutable once created
- Changing name does not change key
- Ensures data integrity

**✔ Must be unique**

- Database enforces UNIQUE constraint on `key` column
- Duplicate keys cause import failure

**Examples:**

| parameter_name | parameter_key (format) |
|----------------|----------------------|
| `Voltage` | `project:<uuid>:voltage` |
| `Phase1 Current` | `project:<uuid>:phase1_current` |
| `Compressor_Pressure` | `project:<uuid>:compressor_pressure` |
| `Tank Level (%)` | `project:<uuid>:tank_level_(\%)` |

---

### 5.3 Why Key Format Matters

**NSWare compatibility:**

- NSWare KPI engine references parameters by key
- Analytics queries use parameter keys
- Dashboards map parameters by key
- API endpoints use parameter keys

**Data integrity:**

- Foreign key constraints use `parameter_key`
- Worker validates keys before insert
- SCADA maps keys to names
- Historical data linked via keys

**Never change keys after creation:**

- Changing key breaks existing data
- SCADA mappings break
- NSWare KPIs break
- Requires data migration

---

## 6. Creating Parameter Templates (Engineering Workflow)

### 6.1 Step-by-Step Process

#### Step 1: List Existing Customers/Projects

```bash
./scripts/list_customers_projects.sh
```

**Expected output:**

```
customer_name,project_name
Customer 01,Project 01_Customer_01
Customer 02,Project 01_Customer_02
Demo Customer,Demo Project
```

**Copy exact names** - They must match exactly (case-sensitive, spaces matter).

---

#### Step 2: Copy the CSV Template

```bash
cp scripts/parameter_template_template.csv my_parameters.csv
```

**Or create manually:**

```bash
cat > my_parameters.csv <<EOF
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
EOF
```

---

#### Step 3: Fill in the CSV

**Use Excel, Google Sheets, or text editor.**

**Tips:**

- Start with a small test set (5-10 parameters)
- Verify customer/project names match exactly
- Use consistent naming conventions
- Save as UTF-8 encoding

**Example:**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage measurement
Customer 02,Project 01_Customer_02,Current,A,float,0,50,true,Current consumption
Customer 02,Project 01_Customer_02,Power,kW,float,0,100,false,Power consumption
Customer 02,Project 01_Customer_02,Frequency,Hz,float,45,55,true,AC frequency
```

---

#### Step 4: Validate CSV Format

**Check column count:**

```bash
awk -F',' 'NR==1 {print "Header columns: " NF} NR>1 {if (NF != 9) print "Row " NR " has " NF " columns (expected 9)"}' my_parameters.csv
```

**Expected:** All rows have exactly 9 columns.

---

#### Step 5: Import the Parameters

**For Kubernetes:**

```bash
./scripts/import_parameter_templates.sh my_parameters.csv
```

**For Docker Compose:**

```bash
USE_KUBECTL=false ./scripts/import_parameter_templates.sh my_parameters.csv
```

**Expected output:**

```
Importing parameter templates from: my_parameters.csv

NOTICE:  Import completed:
NOTICE:    Rows processed: 4
NOTICE:    Templates created: 4
NOTICE:    Rows skipped: 0

Import completed!
```

---

#### Step 6: Verify Import

**Export parameters:**

```bash
./scripts/export_parameter_template_csv.sh
```

**Check output file in `reports/`:**

```bash
cat reports/parameter_templates_export_*.csv
```

**Verify database directly:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT key, name, unit, metadata 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_UUID>'
ORDER BY name;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT key, name, unit, metadata 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_UUID>'
ORDER BY name;"
```

---

## 7. Engineering Rules for Parameter Design (Very Important)

### 7.1 Rule: One Parameter = One Measurement Concept

**✔ Good examples:**

- `Voltage`
- `Pressure`
- `Phase1_Current`
- `Compressor_Temperature`
- `Tank_Level`

**❌ Bad examples:**

- `Value1` (too vague)
- `Data2` (not descriptive)
- `Sensor_Reading` (doesn't specify what is measured)
- `Measurement` (too generic)

**Why this matters:**

- Clear understanding of what each parameter represents
- Easier SCADA mapping
- Better documentation
- Future NSWare analytics accuracy

---

### 7.2 Rule: Keep Naming Consistent Across Projects

**Preferred (consistent):**

- `Voltage`
- `Voltage_Phase1`
- `Voltage_Phase2`
- `Current`
- `Current_Phase1`
- `Current_Phase2`

**Not preferred (inconsistent):**

- `Volt`, `Voltage`, `V` (three different names for same concept)
- `Volt_P1`, `Phase1_V`, `Voltage_Phase_1` (different formats)
- `Current`, `Amp`, `Amperage` (synonyms cause confusion)

**Benefits of consistency:**

- Easier cross-project analysis
- Standardized SCADA tag names
- Consistent NSWare KPIs
- Reduced training time

---

### 7.3 Rule: Use Correct dtype

**Decision matrix:**

| Scenario | dtype | Example |
|----------|-------|---------|
| Engineering measurements | `float` | Voltage: 230.5 |
| Count values | `int` | Pulse count: 1234 |
| ON/OFF, RUN/STOP | `string` or `int` | Status: "RUNNING" or 1/0 |
| Status codes | `string` | Alarm: "HIGH_PRESSURE" |
| Temperature, pressure | `float` | Temperature: 25.3 |
| Event counts | `int` | Total events: 5678 |

**Common mistakes:**

- ❌ Using `string` for numeric values
- ❌ Using `int` for decimal measurements
- ❌ Using `float` for status codes (0/1 can be int)

---

### 7.4 Rule: Never Use Different Units for Same Parameter

**Problem example:**

```
Project A: Voltage → unit: "V"
Project B: Voltage → unit: "mV"  ← WRONG
Project C: Voltage → unit: "kV"  ← WRONG
```

**Why this is bad:**

- SCADA systems expect consistent units
- Analytics cannot aggregate correctly
- NSWare KPIs will be incorrect
- Engineers get confused

**Solution:**

- Standardize on one unit per parameter concept
- Use unit conversion in NSWare if needed
- Document unit choice in project description

**Recommended standards:**

- Voltage: Always "V"
- Current: Always "A"
- Power: "W" or "kW" (choose one per project)
- Temperature: "°C" (or "°F" per project, but be consistent)
- Pressure: "bar" or "Pa" (choose one per project)

---

### 7.5 Rule: Unique Naming Per Project

**Reason:**

- Prevents collisions in `parameter_key` generation
- Database enforces uniqueness on `key` column
- Duplicate names cause import failure

**Example:**

```
✅ Project 1: Voltage
✅ Project 2: Voltage  (different project, OK)

❌ Project 1: Voltage
❌ Project 1: Voltage  (same project, duplicate, FAILS)
```

**If you need similar parameters:**

- Use descriptive suffixes: `Voltage_Phase1`, `Voltage_Phase2`
- Use location: `Voltage_Main`, `Voltage_Backup`
- Use device: `Voltage_Compressor1`, `Voltage_Compressor2`

---

### 7.6 Rule: Do NOT Change Parameter Keys After Creation

**Because:**

- Worker mapping uses `parameter_key`
- SCADA mapping uses `parameter_key`
- NSWare mappings use `parameter_key`
- Historical data references `parameter_key`

**If you change:**

- Existing data becomes orphaned
- SCADA stops working
- NSWare KPIs break
- Requires data migration

**If you must "change":**

- Create new parameter with new name
- Keep old parameter for historical data
- Update devices to use new parameter
- Migrate data if needed

---

## 8. Parameter Mapping Logic in Worker

### 8.1 Ingestion Process

When ingesting a `NormalizedEvent`, the worker:

**Step 1: Extract `parameter_key` from JSON**

```json
{
  "metrics": [
    {
      "parameter_key": "project:8212caa2-...:voltage",
      "value": 230.5,
      "quality": 192
    }
  ]
}
```

**Step 2: Check if key exists in `parameter_templates`**

```sql
SELECT key FROM parameter_templates WHERE key = 'project:...:voltage';
```

**Step 3: Validate dtype** (future feature)

- Check if value matches expected dtype
- Validate numeric format
- Validate string format

**Step 4: Validate value range** (future feature)

- Check if value within min/max
- Flag out-of-range values

**Step 5: Convert to DB record**

```sql
INSERT INTO ingest_events (
    time, device_id, parameter_key, value, quality, source, ...
) VALUES (
    '2025-11-14T12:00:00Z',
    'bc2c5e47-...',
    'project:...:voltage',
    230.5,
    192,
    'GPRS',
    ...
);
```

**Step 6: Foreign key constraint validates**

- Database ensures `parameter_key` exists
- ON DELETE RESTRICT prevents accidental deletion
- Data integrity enforced

---

### 8.2 Error Handling

**If `parameter_key` does not exist:**

```
ERROR: insert or update on table "ingest_events" violates foreign key constraint
"ingest_events_parameter_key_fkey"
DETAIL: Key (parameter_key)=(project:...:voltage) is not present in table "parameter_templates".
```

**Fix:**

1. Import parameter template
2. Verify parameter key format matches
3. Re-send event

---

## 9. Parameter Validation Errors (With Fixes)

### ❗ Missing `parameter_key` in Template

**Error:**

```
ERROR: insert or update on table "ingest_events" violates foreign key constraint
```

**Symptoms:**

- Event queued successfully
- Worker fails to insert
- Database error in logs

**Fix:**

**Step 1: Verify parameter exists**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT key, name FROM parameter_templates 
WHERE key = 'project:...:voltage';"
```

**Step 2: If missing, add to template CSV:**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage measurement
```

**Step 3: Import:**

```bash
./scripts/import_parameter_templates.sh missing_parameters.csv
```

**Step 4: Verify:**

```bash
./scripts/export_parameter_template_csv.sh
```

---

### ❗ Wrong dtype

**Error (future validation):**

```
expected float, got string
```

**Symptoms:**

- Value type mismatch
- Validation error in worker logs

**Fix:**

**Option 1: Correct device data**

- Ensure device sends numeric values for float parameters
- Ensure device sends strings for string parameters

**Option 2: Update template dtype**

- If measurement type changed, update template
- Note: This does not change existing data

---

### ❗ Out-of-Range Value

**Error (future validation):**

```
value 270 > max_value 240
```

**Symptoms:**

- Value outside min/max range
- Validation error in logs

**Fix:**

**Option 1: Adjust template range**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,300,true,AC voltage measurement
```

**Option 2: Correct device calibration**

- Verify device is calibrated correctly
- Check for sensor malfunction

---

### ❗ Duplicate Parameter Name

**Error:**

```
NOTICE:    Row 4: Parameter template already exists: Voltage (key: project:...:voltage)
```

**Symptoms:**

- Import script skips row
- Template not created

**Fix:**

**Option 1: Use different name**

```csv
Voltage_Phase1  ← Instead of Voltage
Voltage_Main    ← Instead of Voltage
```

**Option 2: Delete existing template**

**⚠️ Warning:** Only if no data exists for this parameter.

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
DELETE FROM parameter_templates 
WHERE key = 'project:...:voltage';"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
DELETE FROM parameter_templates 
WHERE key = 'project:...:voltage';"
```

---

### ❗ Wrong Customer or Project

**Error:**

```
NOTICE:    Row 2: Customer not found: Acme Corp Inc
NOTICE:    Row 3: Project not found: Factory Monitoring for customer Acme Corp
```

**Symptoms:**

- Import skips rows
- Templates not created

**Fix:**

**Step 1: Get exact names**

```bash
./scripts/list_customers_projects.sh
```

**Step 2: Copy exact names to CSV**

- Ensure case matches exactly
- Ensure spaces match exactly
- Ensure underscores match exactly

**Step 3: Re-import**

```bash
./scripts/import_parameter_templates.sh corrected_parameters.csv
```

---

## 10. Template Examples

### 10.1 Electrical Template Example

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 02,Project 01_Customer_02,Voltage,V,float,0,240,true,AC voltage measurement
Customer 02,Project 01_Customer_02,Current,A,float,0,50,true,Current consumption
Customer 02,Project 01_Customer_02,Power,kW,float,0,100,false,Power measurement
Customer 02,Project 01_Customer_02,Frequency,Hz,float,45,55,true,AC frequency
Customer 02,Project 01_Customer_02,Power_Factor,,float,0,1,false,Power factor
```

**Generated keys (example):**

```
project:8212caa2-...:voltage
project:8212caa2-...:current
project:8212caa2-...:power
project:8212caa2-...:frequency
project:8212caa2-...:power_factor
```

---

### 10.2 Environmental Template Example

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
PlantA,BoilerMonitoring,Temperature,°C,float,-40,200,true,Boiler temperature
PlantA,BoilerMonitoring,Humidity,%,float,0,100,false,Ambient humidity
PlantA,BoilerMonitoring,Pressure,bar,float,0,10,true,Boiler pressure
PlantA,BoilerMonitoring,Flow_Rate,m³/h,float,0,500,false,Water flow rate
```

**Generated keys (example):**

```
project:...:temperature
project:...:humidity
project:...:pressure
project:...:flow_rate
```

---

### 10.3 Status/Flag Parameters

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 03,TankSystem,Status,,string,,,true,Device state
Customer 03,TankSystem,Alarm,,string,,,false,Alarm text
Customer 03,TankSystem,Run_Time,hours,float,0,8760,false,Total operating hours
Customer 03,TankSystem,Event_Count,,int,0,,true,Total event count
```

**Generated keys (example):**

```
project:...:status
project:...:alarm
project:...:run_time
project:...:event_count
```

**Note:** Status and Alarm parameters have no unit, min/max (blank fields).

---

### 10.4 Multi-Phase Electrical System

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
FactoryA,ElectricalMonitoring,Voltage_Phase1,V,float,0,240,true,Phase 1 voltage
FactoryA,ElectricalMonitoring,Voltage_Phase2,V,float,0,240,true,Phase 2 voltage
FactoryA,ElectricalMonitoring,Voltage_Phase3,V,float,0,240,true,Phase 3 voltage
FactoryA,ElectricalMonitoring,Current_Phase1,A,float,0,100,true,Phase 1 current
FactoryA,ElectricalMonitoring,Current_Phase2,A,float,0,100,true,Phase 2 current
FactoryA,ElectricalMonitoring,Current_Phase3,A,float,0,100,true,Phase 3 current
FactoryA,ElectricalMonitoring,Total_Power,kW,float,0,300,true,Total 3-phase power
```

**Benefits:**

- Clear phase identification
- Consistent naming pattern
- Easy SCADA mapping
- Standardized analytics

---

## 11. SCADA Integration Notes

### 11.1 Parameter Templates Influence SCADA

**Parameter templates affect:**

- **`v_scada_latest`** - Latest values view uses `parameter_key`
- **`v_scada_history`** - Historical data view uses `parameter_key`
- **SCADA export TSV/CSV** - Exports include parameter names from templates
- **Readable export files** - Human-readable exports join with parameter_templates
- **Tag mapping** - SCADA systems map `parameter_key` to tag names

---

### 11.2 SCADA Mapping Process

**Step 1: SCADA queries latest values**

```sql
SELECT 
    d.name AS device_name,
    pt.name AS parameter_name,
    v.time,
    v.value,
    v.quality
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
WHERE v.device_id = '<device_uuid>';
```

**Step 2: Parameter name retrieved from template**

- `pt.name` → Human-readable name (e.g., "Voltage")
- `pt.unit` → Unit for display (e.g., "V")
- `v.parameter_key` → Key used for matching

**Step 3: SCADA maps to tag names**

- SCADA tag: `Device001_Voltage`
- Maps to: `parameter_key` = `project:...:voltage`
- Display name: "Voltage" (from template)
- Unit: "V" (from template)

---

### 11.3 Export Files Include Parameter Names

**Readable export:**

```bash
./scripts/export_scada_data_readable.sh --latest --format txt
```

**Output format:**

```
device_name    device_code    parameter_name    unit    value    quality    timestamp
Sensor-001     SEN001         Voltage           V       230.5    192        2025-11-14T12:00:00Z
Sensor-001     SEN001         Current           A       10.2     192        2025-11-14T12:00:00Z
```

**Parameter names and units come from `parameter_templates` table.**

---

### 11.4 SCADA Tag Mapping Best Practices

**Recommendation:**

1. **Define parameter templates first** - Before SCADA integration
2. **Export parameter list** - Use `export_parameter_template_csv.sh`
3. **Map SCADA tags to `parameter_key`** - Not to `parameter_name` (key is stable)
4. **Use parameter names for display** - Human-readable labels
5. **Document mapping** - Keep mapping table for reference

**Example mapping table:**

| SCADA Tag | parameter_key | parameter_name | unit |
|-----------|--------------|----------------|------|
| `Pump01_Voltage` | `project:...:voltage` | Voltage | V |
| `Pump01_Current` | `project:...:current` | Current | A |
| `Pump01_Status` | `project:...:status` | Status | (none) |

---

## 12. Best Practices Summary

### 12.1 Design Phase

- ✅ **Define templates before ingestion** - Import templates before sending data
- ✅ **Use clean, meaningful engineering names** - Avoid abbreviations and vague names
- ✅ **Maintain consistency across customers** - Standardize parameter naming
- ✅ **Use correct units and dtype** - Match engineering standards
- ✅ **Validate templates using small CSV first** - Test with 5-10 parameters

---

### 12.2 Management Phase

- ✅ **Never rename parameters once deployed** - Keys are immutable
- ✅ **Export parameters regularly for audit** - Use `export_parameter_template_csv.sh`
- ✅ **Document parameter purpose in description** - Help future engineers
- ✅ **Keep parameter list versioned** - Track changes over time
- ✅ **Review parameter usage** - Check which parameters are actually used

---

### 12.3 Integration Phase

- ✅ **Map SCADA tags to `parameter_key`** - Not to names (keys are stable)
- ✅ **Use parameter names for display** - Human-readable labels
- ✅ **Verify parameter existence before ingestion** - Prevent foreign key errors
- ✅ **Test parameter mapping** - Send test events and verify

---

## 13. Parameter Template Checklist (Copy–Paste)

### Before Import

- [ ] Customer name correct (verified via `list_customers_projects.sh`)
- [ ] Project name correct (case-sensitive, exact match)
- [ ] All parameter names unique within project
- [ ] Units correct and consistent
- [ ] dtype correct (float/int/string)
- [ ] min/max values correct (if applicable)
- [ ] Required flags set appropriately
- [ ] File saved as UTF-8 encoding
- [ ] CSV has exactly 9 columns per row
- [ ] Header row matches template exactly

### After Import

- [ ] Templates appear in database
- [ ] Export matches input (`export_parameter_template_csv.sh`)
- [ ] Parameter keys generated correctly
- [ ] No duplicate key errors
- [ ] Test ingestion works (send test event)
- [ ] SCADA mapping consistent (if applicable)

### Verification Commands

```bash
# List parameters for a project
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT key, name, unit, metadata 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_UUID>'
ORDER BY name;"

# Export all parameters
./scripts/export_parameter_template_csv.sh

# Test ingestion with parameter
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "...",
    "site_id": "...",
    "device_id": "...",
    "protocol": "GPRS",
    "source_timestamp": "2025-11-14T12:00:00Z",
    "metrics": [{
      "parameter_key": "project:...:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": {"unit": "V"}
    }]
  }'
```

---

## 14. Common Parameter Categories

### 14.1 Electrical Measurements

| Parameter | Unit | dtype | Typical Range |
|-----------|------|-------|---------------|
| Voltage | V | float | 0-240 (AC), 0-48 (DC) |
| Current | A | float | 0-100 |
| Power | kW, W | float | 0-500 |
| Energy | kWh | float | 0-∞ |
| Frequency | Hz | float | 45-55 |
| Power Factor | (none) | float | 0-1 |

---

### 14.2 Environmental Measurements

| Parameter | Unit | dtype | Typical Range |
|-----------|------|-------|---------------|
| Temperature | °C, °F | float | -40 to 150 |
| Humidity | % | float | 0-100 |
| Pressure | bar, Pa, psi | float | 0-10 |
| Flow | m³/h, L/min | float | 0-500 |
| Level | m, %, (none) | float | 0-100 |

---

### 14.3 Status/Control Parameters

| Parameter | Unit | dtype | Typical Range |
|-----------|------|-------|---------------|
| Status | (none) | string | - |
| Alarm | (none) | string | - |
| Count | (none) | int | 0-∞ |
| Run_Time | hours | float | 0-8760 |

---

## 15. Next Steps

After completing parameter template setup:

- **Module 7** - Data Ingestion and Testing Manual
  - Test ingestion with defined parameters
  - Verify parameter mapping works

- **Module 9** - SCADA Integration Manual
  - Map SCADA tags to parameter keys
  - Configure SCADA exports

- **Module 11** - Troubleshooting and Diagnostics Manual
  - Troubleshoot parameter-related errors
  - Validate parameter mappings

---

**End of Module 6 – Parameter Template Manual**

**Related Modules:**

- Module 5 – Configuration Import Manual (covers basic import process)
- Module 7 – Data Ingestion and Testing Manual (using parameters)
- Module 9 – SCADA Integration Manual (SCADA mapping)
- Module 10 – Scripts and Tools Reference Manual (import/export scripts)

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_


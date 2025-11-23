# Configuration Import User Guide

This guide explains how to import configuration data (customers, projects, sites, devices, and parameters) into the NTPPL NS-Ready Platform using CSV files.

## Overview

The configuration import process consists of **two main steps**:

1. **Step 1: Import Registry Data** (Customers, Projects, Sites, Devices)
2. **Step 2: Import Parameter Templates** (Parameters for each project)

## Table of Contents

- [Step 1: Import Registry Data](#step-1-import-registry-data)
- [Step 2: Import Parameter Templates](#step-2-import-parameter-templates)
- [File Formats](#file-formats)
- [Usage Examples](#usage-examples)
- [UI Implementation Notes](#ui-implementation-notes)
- [Troubleshooting](#troubleshooting)

---

## Step 1: Import Registry Data

### Purpose
Import the hierarchical structure: **Customers → Projects → Sites → Devices**

### Files Required

1. **Sample Template File**: `shared/scripts/registry_template.csv`
   - Template showing the required CSV format
   - Use this as a starting point for your data

2. **Example File**: `shared/scripts/example_registry.csv`
   - Example with sample data
   - Shows how to structure your data

3. **Import Script**: `shared/scripts/import_registry.sh`
   - Script that processes the CSV and creates registry entries

### CSV Format

The registry CSV file must have the following columns (in order):

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| `customer_name` | Yes | Name of the customer | `Acme Corp` |
| `project_name` | Yes | Name of the project | `Factory Monitoring System` |
| `project_description` | No | Description of the project | `Real-time monitoring system` |
| `site_name` | Yes | Name of the site | `Main Factory` |
| `site_location` | No | Location as JSON object | `{"address":"123 St","city":"Mumbai"}` |
| `device_name` | No | Name of the device | `Sensor-001` |
| `device_type` | No | Type of device | `sensor`, `meter`, `controller` |
| `device_code` | No | External/unique device code | `SENSOR-001` |
| `device_status` | No | Device status | `active`, `inactive`, `maintenance` |

### CSV Example

```csv
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
Acme Corp,Factory Monitoring System,Real-time monitoring,Main Factory,{"city":"Mumbai"},Sensor-001,sensor,SENSOR-001,active
Acme Corp,Factory Monitoring System,Real-time monitoring,Main Factory,{"city":"Mumbai"},Sensor-002,sensor,SENSOR-002,active
```

### How It Works

1. **Customer**: If customer doesn't exist, it will be created. If it exists, it will be reused.
2. **Project**: If project doesn't exist for the customer, it will be created. If it exists, it will be reused.
3. **Site**: If site doesn't exist for the project, it will be created. If it exists, it will be reused.
4. **Device**: If device doesn't exist (checked by `device_code` or `device_name`), it will be created.

### Usage

```bash
# Import registry data
./shared/scripts/import_registry.sh my_registry_data.csv
```

### Important Notes

- **Hierarchical Structure**: The system maintains relationships: Customer → Project → Site → Device
- **Duplicate Handling**: Existing customers/projects/sites/devices are reused (not duplicated)
- **Device Matching**: Devices are matched by `device_code` (external_id) first, then by `device_name`
- **Location Format**: `site_location` must be valid JSON (use `{}` for empty location)
- **Device Fields**: All device fields are optional - you can have sites without devices

---

## Step 2: Import Parameter Templates

### Purpose
Import **parameter templates** that define what measurements can be collected for each project.

### Files Required

1. **Sample Template File**: `shared/scripts/parameter_template_template.csv`
   - Template showing the required CSV format
   - Use this as a starting point

2. **Example File**: `shared/scripts/example_parameters.csv`
   - Example with sample data
   - Shows different parameter types

3. **Import Script**: `shared/scripts/import_parameter_templates.sh`
   - Script that processes the CSV and creates parameter templates

### CSV Format

The parameter template CSV file must have the following columns (in order):

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| `customer_name` | Yes | Name of the customer (must exist) | `Acme Corp` |
| `project_name` | Yes | Name of the project (must exist) | `Factory Monitoring System` |
| `parameter_name` | Yes | Display name of the parameter | `Voltage`, `Current`, `Power` |
| `unit` | No | Unit of measurement | `V`, `A`, `kW`, `Hz`, `°C` |
| `dtype` | No | Data type | `float`, `int`, `string` |
| `min_value` | No | Minimum allowed value | `0`, `-100` |
| `max_value` | No | Maximum allowed value | `240`, `1000` |
| `required` | No | Whether parameter is required | `true`, `false` |
| `description` | No | Description of the parameter | `AC voltage measurement` |

### CSV Example

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Acme Corp,Factory Monitoring System,Voltage,V,float,0,240,true,AC voltage measurement
Acme Corp,Factory Monitoring System,Current,A,float,0,50,true,Current consumption
Acme Corp,Factory Monitoring System,Power,kW,float,0,100,false,Power consumption
```

### How It Works

1. **Validation**: Script validates that customer and project exist in the database
2. **Key Generation**: Parameter key is generated as: `project:{project_id}:{parameter_name}`
3. **Duplicate Check**: If parameter already exists (same key), it will be skipped
4. **Metadata**: Parameter metadata (dtype, min, max, required) is stored in JSON format

### Usage

```bash
# Import parameter templates
./shared/scripts/import_parameter_templates.sh my_parameters.csv
```

### Important Notes

- **Prerequisites**: Customer and Project must already exist (created in Step 1)
- **Parameter Key**: Automatically generated from project ID and parameter name
- **Duplicate Handling**: Existing parameters are skipped (not updated)
- **Metadata**: All parameter metadata is stored in JSON format in the database

---

## File Formats

### Registry CSV Format

**Header Row:**
```csv
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
```

**Data Rows:**
- Each row represents one device (or site if no device)
- Multiple rows can share the same customer/project/site
- Empty device fields are allowed (sites without devices)

### Parameter Template CSV Format

**Header Row:**
```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**Data Rows:**
- Each row represents one parameter template
- Multiple parameters can be defined for the same project
- Customer and project names must match exactly (case-sensitive)

---

## Usage Examples

### Complete Workflow

```bash
# Step 1: Import registry (customers, projects, sites, devices)
./shared/scripts/import_registry.sh shared/scripts/example_registry.csv

# Step 2: Import parameters for the projects
./shared/scripts/import_parameter_templates.sh shared/scripts/example_parameters.csv
```

### Export Existing Data

```bash
# Export existing parameter templates (for editing)
./shared/scripts/export_parameter_template_csv.sh

# Export full registry data (read-only, for reference)
./shared/scripts/export_registry_data.sh
```

### Verify Import

```bash
# List customers and projects
./shared/scripts/list_customers_projects.sh
```

---

## UI Implementation Notes

This guide can be used as a reference for implementing the import functionality in the UI. Key considerations:

### Import Registry Screen

1. **File Upload**: Allow user to upload CSV file
2. **Validation**: 
   - Validate CSV format (check header row)
   - Show preview of data before import
   - Highlight any errors
3. **Progress**: Show import progress (rows processed, created, skipped)
4. **Results**: Display summary:
   - Customers created
   - Projects created
   - Sites created
   - Devices created
   - Errors (if any)

### Import Parameters Screen

1. **File Upload**: Allow user to upload CSV file
2. **Validation**:
   - Validate CSV format
   - Check that customers/projects exist
   - Show preview with validation status
3. **Progress**: Show import progress
4. **Results**: Display summary:
   - Parameters created
   - Parameters skipped (duplicates)
   - Errors (missing customers/projects)

### UI Flow

```
1. User selects "Import Registry" or "Import Parameters"
2. User uploads CSV file
3. System validates file format
4. System shows preview with validation
5. User confirms import
6. System processes import
7. System shows results summary
```

### Error Handling

- **Invalid CSV Format**: Show specific column errors
- **Missing Customers/Projects**: List which customers/projects are missing
- **Duplicate Entries**: Inform user which entries were skipped
- **Database Errors**: Show error messages clearly

### Sample Data Download

Provide download links for:
- `registry_template.csv` - Template for registry import
- `example_registry.csv` - Example registry data
- `parameter_template_template.csv` - Template for parameter import
- `example_parameters.csv` - Example parameter data

---

## Troubleshooting

### Common Issues

#### 1. "Customer not found" error
**Problem**: Parameter import fails because customer doesn't exist.

**Solution**: 
- First import registry data (Step 1)
- Ensure customer name matches exactly (case-sensitive)
- Check customer name in CSV matches database

#### 2. "Project not found" error
**Problem**: Parameter import fails because project doesn't exist.

**Solution**:
- First import registry data (Step 1)
- Ensure project name matches exactly (case-sensitive)
- Check project belongs to the correct customer

#### 3. "Parameter template already exists" warning
**Problem**: Parameter was skipped because it already exists.

**Solution**: This is normal behavior. Existing parameters are not overwritten. To update, delete and re-import, or use Admin API.

#### 4. Invalid JSON in site_location
**Problem**: Site location must be valid JSON.

**Solution**: 
- Use `{}` for empty location
- Use proper JSON format: `{"key":"value"}`
- Escape quotes properly in CSV

#### 5. Device not created
**Problem**: Device fields are all optional.

**Solution**: 
- Ensure at least `device_name` or `device_code` is provided
- Check that site exists for the device

### Validation Checklist

Before importing, verify:

- [ ] CSV file has correct header row
- [ ] All required columns are present
- [ ] Customer names match exactly (for parameter import)
- [ ] Project names match exactly (for parameter import)
- [ ] Site location is valid JSON (or empty `{}`)
- [ ] No duplicate device codes (if using device_code)
- [ ] File encoding is UTF-8
- [ ] Line endings are correct (Unix/Linux format preferred)

---

## File Locations

All files are located in the `shared/scripts/` directory:

### Template Files
- `shared/scripts/registry_template.csv` - Registry import template
- `shared/scripts/parameter_template_template.csv` - Parameter import template

### Example Files
- `shared/scripts/example_registry.csv` - Example registry data
- `shared/scripts/example_parameters.csv` - Example parameter data

### Scripts
- `shared/scripts/import_registry.sh` - Import registry data
- `shared/scripts/import_parameter_templates.sh` - Import parameters
- `shared/scripts/export_parameter_template_csv.sh` - Export parameters
- `shared/scripts/export_registry_data.sh` - Export registry (read-only)

### Documentation
- `shared/scripts/CONFIGURATION_IMPORT_USER_GUIDE.md` - This guide
- `shared/scripts/PARAMETER_TEMPLATE_IMPORT_GUIDE.md` - Detailed parameter guide
- `shared/scripts/ENGINEER_GUIDE_PARAMETER_TEMPLATES.md` - Engineer's guide

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

---

## Support

For issues or questions:
1. Check this guide and troubleshooting section
2. Review example CSV files
3. Check script error messages
4. Verify data in database using Admin API or scripts

---

**Last Updated**: 2025-11-14
**Version**: 1.0


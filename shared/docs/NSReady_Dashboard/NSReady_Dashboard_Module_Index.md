# NSReady Dashboard & Platform Documentation – Module Index

_NSReady Data Collection Platform_

**Last Updated:** 2025-11-22  
**Status:** Active Documentation Set

---

## Overview

This index provides a complete map of all NSReady Dashboard and Platform documentation modules. These modules cover the full lifecycle of the NSReady data collection platform, from introduction through operational procedures.

---

## Module List

### ✅ Completed Modules

- **00 – Introduction & Terminology**  
  _Location: `00_Introduction_and_Terminology.md`_  
  Overview of the NSReady platform, key concepts, and terminology used throughout the documentation.

- **01 – Folder Structure & File Descriptions**  
  _Location: `01_Folder_Structure_and_File_Descriptions.md`_  
  Complete repository structure, file organization, and component descriptions.

- **02 – System Architecture & Data Flow**  
  _Location: `02_System_Architecture_and_DataFlow.md`_  
  High-level architecture, component interactions, and data flow diagrams.

- **03 – Environment & PostgreSQL Storage Manual**  
  _Location: `03_Environment_and_PostgreSQL_Storage_Manual.md`_  
  Environment setup, PostgreSQL configuration, TimescaleDB setup, and storage architecture.

- **04 – Deployment & Startup Manual**  
  _Location: `04_Deployment_and_Startup_Manual.md`_  
  Step-by-step deployment procedures, startup sequences, and configuration.

- **05 – Configuration Import Manual**  
  _Location: `05_Configuration_Import_Manual.md`_  
  Customer, project, site, and device configuration import procedures.

- **06 – Parameter Template Manual**  
  _Location: `06_Parameter_Template_Manual.md`_  
  Parameter template creation, management, and registry integration.

---

### ✅ Completed Modules (Continued)

### 🔄 Modules to be Rebuilt

- **07 – Data Validation & Error Handling** ✅  
  _Location: `07_Data_Validation_and_Error_Handling.md`_  
  Data validation rules, error handling procedures, error recovery, and validation workflows.

- **08 – Ingestion Worker & Queue Processing** ✅  
  _Location: `08_Ingestion_Worker_and_Queue_Processing.md`_  
  NATS message queue architecture, worker pipeline, asynchronous processing, and queue management.

- **09 – SCADA Views & Export Mapping** ✅  
  _Location: `09_SCADA_Views_and_Export_Mapping.md`_  
  SCADA view architecture, export mapping procedures, v_scada_latest and v_scada_history views, and SCADA data flows.

- **10 – NSReady Dashboard Architecture & UI** ✅  
  _Location: `10_NSReady_Dashboard_Architecture_and_UI.md`_  
  Dashboard structure, UI components, data visualization, and user interface guidelines.

- **11 – Testing Strategy & Test Suite Overview** ✅  
  _Location: `11_Testing_Strategy_and_Test_Suite_Overview.md`_  
  Testing approach, test suite organization, regression tests, performance tests, and resilience tests.

- **12 – API Developer Manual** ✅  
  _Location: `12_API_Developer_Manual.md`_  
  NSReady API endpoints, authentication, request/response formats, and developer integration guide.

- **13 – Operational Checklist & Runbook** ✅  
  _Location: `13_Operational_Checklist_and_Runbook.md`_  
  Operational procedures, deployment checklists, monitoring, troubleshooting, and maintenance runbook.

---

## Documentation Structure

All modules are located under:

```
shared/docs/NSReady_Dashboard/
```

This location aligns with the repository reorganization structure where:
- `shared/docs/` contains user-facing documentation
- `shared/master_docs/` contains master documentation and design specs

---

## Module Dependencies

Modules build upon each other in a logical sequence:

1. **00-01**: Foundation (Introduction, Structure)
2. **02-03**: Architecture & Infrastructure
3. **04-06**: Deployment & Configuration
4. **07-09**: Data Processing & Validation
5. **10-12**: User Interfaces & Integration
6. **13**: Operations & Maintenance

---

## Recovery Status

**Recovered from iCloud Drive (2025-11-22):**
- Modules 00-06 successfully recovered and committed to git

**Rebuilt (2025-11-22):**
- Modules 07-13 successfully rebuilt using existing process documentation, architecture notes, and execution summaries located in `shared/master_docs/`

---

## Notes

- All modules follow a consistent structure and style
- Each module is self-contained but references related modules where appropriate
- Modules are version-controlled in git and part of the repository structure
- Future updates should maintain consistency with the established format

---

**Index Created:** 2025-11-22  
**Last Updated:** 2025-11-22


# Dashboard Project Connectivity & Links Validation

**Purpose:** Validate connectivity, API endpoints, database links, and data contracts between NSReady platform and Dashboard project

**Date Created:** 2025-01-XX  
**Status:** 🔄 In Progress

**Dashboard Project:** [Project Name/Path]  
**NSReady Platform:** `/Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform`

---

## Validation Sections

> **Instructions:** Paste each section below for review. Each section will be validated against:
> - API endpoint compatibility
> - Database schema alignment
> - Tenant isolation rules
> - Data format consistency
> - Authentication/authorization
> - Error handling

---

## Section 1: Database Connection & Schema

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Database connection string matches NSReady config
- [ ] Schema version compatibility checked
- [ ] Required tables accessible:
  - [ ] `customers` (with `parent_customer_id`)
  - [ ] `projects`
  - [ ] `sites`
  - [ ] `devices`
  - [ ] `parameter_templates`
  - [ ] `ingest_events`
  - [ ] `v_scada_latest`
  - [ ] `v_scada_history`
- [ ] Read-only access configured (if applicable)
- [ ] Connection pooling configured

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Schema Reference:**
- Migration files: `db/migrations/`
- Latest migration: `150_customer_hierarchy.sql` (adds `parent_customer_id`)
- Schema docs: `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

---

## Section 2: API Endpoints Used by Dashboard

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] `/v1/ingest` - Not used by dashboard (write-only)
- [ ] `/v1/health` - Dashboard health checks
- [ ] `/metrics` - Prometheus metrics (if used)
- [ ] Custom dashboard API endpoints (if any)
- [ ] Future `/monitor/*` endpoints (PLANNED - not available yet)

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady API Reference:**
- API docs: `docs/12_API_Developer_Manual.md`
- Current endpoints: `/v1/health`, `/metrics`, `/v1/ingest`
- Planned endpoints: `/monitor/*` (not implemented)

---

## Section 3: Tenant Isolation & Filtering

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] All queries filter by `customer_id` (tenant boundary)
- [ ] Group reports use `parent_customer_id` correctly
- [ ] No cross-tenant data leakage
- [ ] User access control respects tenant boundaries
- [ ] Dashboard users see only their tenant's data
- [ ] Group-level dashboards aggregate correctly

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Tenant Model:**
- Rule: `tenant_id = customer_id`
- Docs: `docs/TENANT_MODEL_SUMMARY.md`
- Isolation: Each customer = isolated tenant
- Grouping: `parent_customer_id` for reporting only

**Example Query Pattern:**
```sql
-- Individual tenant (company-level)
WHERE customer_id = 'uuid-company'

-- Group-level (parent + children)
WHERE customer_id = 'uuid-parent' 
   OR parent_customer_id = 'uuid-parent'
```

---

## Section 4: Data Format & Parameter Keys

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] `parameter_key` format: `project:<project_uuid>:<parameter_name>`
- [ ] No short-form keys (`"voltage"` is invalid)
- [ ] UUIDs match documentation standards:
  - Project: `8212caa2-b928-4213-b64e-9f5b86f4cad1`
  - Site: `89a66770-bdcc-4c95-ac97-e1829cb7a960`
  - Device: `bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad`
- [ ] Time-series data format matches `ingest_events` schema
- [ ] SCADA views (`v_scada_latest`, `v_scada_history`) used correctly

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Data Format:**
- Parameter key format: `docs/06_Parameter_Template_Manual.md` (canonical reference)
- Sample event: `collector_service/tests/sample_event.json`
- SCADA views: `docs/09_SCADA_Integration_Manual.md`

---

## Section 5: Time-Series Queries & Performance

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Uses materialized views for long time ranges (weeks/months)
- [ ] Avoids direct `ingest_events` queries for dashboards
- [ ] Uses `v_scada_latest` for current values
- [ ] Uses `v_scada_history` for historical data
- [ ] Query timeouts configured
- [ ] Pagination implemented for large datasets
- [ ] Indexes utilized (customer_id, time, device_id)

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Performance Guidelines:**
- Docs: `docs/13_Performance_and_Monitoring_Manual.md`
- Time-series strategy: Narrow + hybrid model
- Rollup views: Use continuous aggregates for dashboards
- Guardrail: Long time ranges → use rollup views, not `ingest_events`

---

## Section 6: Authentication & Authorization

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] User authentication method
- [ ] Tenant/customer assignment per user
- [ ] Role-based access control (if applicable)
- [ ] Group-level access (parent customer) handled correctly
- [ ] API keys/tokens (if used)
- [ ] Session management

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Context:**
- Tenant = customer_id (per company)
- Parent = grouping only (not security boundary in v1)
- Access control: Filter by `customer_id` for tenant isolation

---

## Section 7: Error Handling & Edge Cases

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Database connection errors handled
- [ ] Missing data (NULL values) handled
- [ ] Invalid `customer_id` handled
- [ ] Invalid `parent_customer_id` handled
- [ ] Empty result sets handled
- [ ] Timeout errors handled
- [ ] API errors (if using APIs) handled

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Error Patterns:**
- Foreign key errors: Invalid `parameter_key` format
- Missing data: Check `parameter_templates` table
- Tenant errors: Invalid `customer_id` or cross-tenant access

---

## Section 8: Data Contracts & Schema Changes

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Dashboard compatible with current schema
- [ ] `parent_customer_id` column handled (migration 150)
- [ ] Future schema changes considered
- [ ] Data contract YAML files referenced (if applicable)
- [ ] Breaking change detection

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Data Contracts:**
- Location: `contracts/nsready/*.yaml`
- Core tables: `ingest_events`, `parameter_templates`, `v_scada_latest`, `v_scada_history`
- Schema changes: Tracked in `db/migrations/`

---

## Section 9: Dashboard-Specific Queries

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Query syntax matches PostgreSQL/TimescaleDB
- [ ] Tenant filtering applied
- [ ] Time range filtering correct
- [ ] Aggregations (if any) correct
- [ ] JOINs use correct foreign keys
- [ ] Performance optimized (indexes used)

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Query Patterns:**
- Tenant filter: `WHERE customer_id = 'uuid'` or `WHERE parent_customer_id = 'uuid'`
- Time filter: `WHERE time >= 'start' AND time <= 'end'`
- SCADA views: Use `v_scada_latest` and `v_scada_history`

---

## Section 10: Configuration & Environment

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Database connection config
- [ ] Environment variables
- [ ] API endpoints configuration
- [ ] Timezone handling
- [ ] Locale/encoding settings
- [ ] Logging configuration

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Configuration:**
- Environment setup: `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`
- Deployment: `docs/04_Deployment_and_Startup_Manual.md`
- Timezone: UTC recommended for all timestamps

---

## Section 11: Testing & Validation

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Test data uses documentation UUIDs
- [ ] Test queries validate tenant isolation
- [ ] Group reporting tests included
- [ ] Performance tests for time-series queries
- [ ] Error scenario tests
- [ ] Integration tests with NSReady platform

**Review Notes:**
```
[Reviewer notes will appear here]
```

**NSReady Test References:**
- Test UUIDs: See `docs/00_Introduction_and_Terminology.md`
- Sample data: `collector_service/tests/sample_event.json`
- Test files: `tests/regression/`, `tests/performance/`

---

## Section 12: Documentation Links & References

**Paste your content here for validation:**

```
[Paste content]
```

**Validation Checklist:**
- [ ] Links to NSReady documentation
- [ ] API endpoint references
- [ ] Schema documentation links
- [ ] Tenant model references
- [ ] Data format references
- [ ] All links are valid and accessible

**Review Notes:**
```
[Reviewer notes will appear here]
```

**Key NSReady Documentation:**
- Module 0: `docs/00_Introduction_and_Terminology.md`
- Module 2: `docs/02_System_Architecture_and_DataFlow.md`
- Module 3: `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`
- Module 6: `docs/06_Parameter_Template_Manual.md` (parameter_key format)
- Module 9: `docs/09_SCADA_Integration_Manual.md` (SCADA views)
- Module 12: `docs/12_API_Developer_Manual.md` (API endpoints)
- Module 13: `docs/13_Performance_and_Monitoring_Manual.md` (performance)
- Tenant docs: `docs/TENANT_MODEL_SUMMARY.md`, `docs/TENANT_DECISION_RECORD.md`

---

## Overall Connectivity Summary

**Date Completed:** [Date]

**Validation Results:**
- [ ] Database connectivity verified
- [ ] API endpoints validated
- [ ] Tenant isolation confirmed
- [ ] Data format compatibility checked
- [ ] Performance queries optimized
- [ ] Error handling comprehensive
- [ ] Documentation links valid
- [ ] Configuration aligned

**Issues Found:**
```
[List any issues]
```

**Recommendations:**
```
[List recommendations]
```

**Sign-off:**
- [ ] Database Connectivity: ✅
- [ ] API Compatibility: ✅
- [ ] Tenant Isolation: ✅
- [ ] Data Format: ✅
- [ ] Performance: ✅
- [ ] Documentation: ✅

---

## Quick Reference: NSReady Platform Details

### Database
- **Type:** PostgreSQL with TimescaleDB extension
- **Connection:** [Configure in dashboard]
- **Schema:** See `db/migrations/`
- **Key Tables:** `customers`, `projects`, `sites`, `devices`, `ingest_events`, `parameter_templates`

### API Endpoints
- **Health:** `GET /v1/health`
- **Metrics:** `GET /metrics` (Prometheus)
- **Ingest:** `POST /v1/ingest` (write-only, not for dashboard)

### Tenant Model
- **Rule:** `tenant_id = customer_id`
- **Isolation:** Each customer = separate tenant
- **Grouping:** `parent_customer_id` for reporting only

### Data Format
- **Parameter Key:** `project:<project_uuid>:<parameter_name>`
- **Time Format:** ISO 8601 UTC
- **SCADA Views:** `v_scada_latest`, `v_scada_history`

### Documentation
- **Location:** `docs/` folder
- **Tenant Model:** `docs/TENANT_MODEL_SUMMARY.md`
- **API Reference:** `docs/12_API_Developer_Manual.md`



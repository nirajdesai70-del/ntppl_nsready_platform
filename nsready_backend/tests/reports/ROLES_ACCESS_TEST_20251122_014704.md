# Role-Based Access Control Test Report

**Date**: Sat Nov 22 01:47:04 IST 2025
**Environment**: docker
**Admin URL**: http://localhost:8000

---

## Test Configuration

- **Bearer Token**: Using `ADMIN_BEARER_TOKEN` env var (default: devtoken)
- **Role Simulation**:
  - **Engineer**: No `X-Customer-ID` header (access to all tenants)
  - **Customer**: `X-Customer-ID` header set (scoped to that customer)

**Note**: Current implementation uses bearer token + `X-Customer-ID` header for role simulation.
Future JWT implementation will extract roles from token claims.

---

## Test Results

ab46b95e2ae4   ntppl_nsready_platform-admin_tool          "uvicorn app:app --h…"   About an hour ago   Up About an hour   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp                                                                                 admin_tool
5f5a66c55c29   traefik:v2.10                              "/entrypoint.sh --ap…"   3 days ago          Up 42 hours        0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp   nsready_traefik
eb60d28f0729   ntppl_nsready_platform-collector_service   "uvicorn app:app --h…"   3 days ago          Up 42 hours        0.0.0.0:8001->8001/tcp, [::]:8001->8001/tcp                                                                                 collector_service
35c59ae87944   ntppl_nsready_platform-db                  "docker-entrypoint.s…"   3 days ago          Up 42 hours        0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp                                                                                 nsready_db
be9cf6008296   nats:2.10-alpine                           "docker-entrypoint.s…"   3 days ago          Up 42 hours        0.0.0.0:4222->4222/tcp, [::]:4222->4222/tcp, 0.0.0.0:8222->8222/tcp, [::]:8222->8222/tcp                                    nsready_nats
Admin service health: {"service":"ok"}
Test customer: Test (8cdd2387-30a1-45cc-a72c-391ec1de1e0a)

## Engineer Role Tests

**Engineer Role**: No `X-Customer-ID` header → Access to all tenants

**Test: Engineer can access /admin/customers (all customers)**
- Role: Engineer
- Endpoint: GET /admin/customers
- Expected: 200
- Actual: 200
- Result: ✅ **PASSED**

**Test: Engineer can access /admin/projects (all projects)**
- Role: Engineer
- Endpoint: GET /admin/projects
- Expected: 200
- Actual: 200
- Result: ✅ **PASSED**

**Test: Engineer can access /admin/sites (all sites)**
- Role: Engineer
- Endpoint: GET /admin/sites
- Expected: 200
- Actual: 200
- Result: ✅ **PASSED**

**Test: Engineer can access /admin/devices (all devices)**
- Role: Engineer
- Endpoint: GET /admin/devices
- Expected: 200
- Actual: 200
- Result: ✅ **PASSED**

**Test: Engineer can access /admin/parameter_templates**
- Role: Engineer
- Endpoint: GET /admin/parameter_templates
- Expected: 200
- Actual: 200
- Result: ✅ **PASSED**

**Engineer Role Summary:**
- Passed: 5
- Failed: 0

---

## Customer Role Tests

**Customer Role**: `X-Customer-ID: 8cdd2387-30a1-45cc-a72c-391ec1de1e0a` → Scoped to own customer

**Test: Customer access to /admin/customers (should be filtered or denied)**
- Role: Customer
- Endpoint: GET /admin/customers
- Expected: 200
- Actual: 200
- Result: ✅ **PASSED**

**Test: Customer can access /admin/projects (own projects only)**
- Role: Customer
- Endpoint: GET /admin/projects
- Expected: 200
- Actual: 200

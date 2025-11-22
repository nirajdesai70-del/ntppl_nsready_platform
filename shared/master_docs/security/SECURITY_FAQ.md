# Security FAQ - NSReady Platform

**Date**: 2025-11-22  
**Purpose**: Quick reference for common security questions

---

## General Security Questions

### Q: What security controls are in place?

**A**: NSReady implements comprehensive security controls:

- ✅ **Authentication**: Bearer token required for all admin endpoints
- ✅ **Authorization**: Role-based access control (Engineer vs Customer)
- ✅ **Tenant Isolation**: Complete data separation between customers
- ✅ **Input Validation**: UUID validation, required fields, data types
- ✅ **Error Handling**: Generic error messages (no information leakage)
- ✅ **Resilience**: Queue buffering, graceful degradation
- ✅ **Monitoring**: Health endpoints, metrics, logging

See `SECURITY_POSITION_NSREADY.md` for complete details.

---

### Q: Is NSReady ISO 27001 / IEC 62443 certified?

**A**: NSReady is **not currently certified**, but:

- ✅ Test suite maps to ISO 27001 and IEC 62443 controls
- ✅ Security controls are documented and tested
- ✅ Evidence trail available for audits
- ✅ Well-prepared for future certification

See `SECURITY_TEST_MAPPING_ISO_IEC.md` for detailed mapping.

---

## HTTP Status Codes

### Q: Why does the API return 422 instead of 400?

**A**: **422 (Unprocessable Entity) is the correct HTTP status** for validation errors.

**HTTP Standards**:
- **400 Bad Request**: Request is malformed (protocol error)
- **422 Unprocessable Entity**: Request is well-formed but semantically invalid (validation error)

**FastAPI/Pydantic** automatically returns 422 for:
- Missing required fields
- Invalid data types
- Pydantic validation errors

**This is correct behavior** - tests accept both 400 and 422 as valid rejection codes.

---

### Q: Why do invalid parameter keys return 200 OK?

**A**: **This is by design** for async processing.

**Architecture**:
```
API → Queue → Worker → Database (FK validation)
```

**Why**:
- API accepts and queues events (fast response)
- Worker validates parameter keys during database insert
- Database foreign key constraint ensures data integrity
- Allows queue buffering and resilience

**This is correct** - validation happens at database level (async).

---

## Tenant Isolation

### Q: How is tenant isolation enforced?

**A**: Multi-layer enforcement:

1. **Database Level**: Foreign key constraints enforce tenant boundaries
2. **API Level**: All endpoints validate tenant access before operations
3. **Application Level**: `X-Customer-ID` header scopes access
4. **Export Scripts**: Always require `--customer-id` parameter

**Validation**: See `test_tenant_isolation.sh` test suite.

---

### Q: Can customers access other customers' data?

**A**: **No** - Tenant isolation is enforced at multiple levels:

- ✅ API endpoints validate tenant access (403 Forbidden if denied)
- ✅ Database foreign keys prevent cross-tenant data access
- ✅ Export scripts require customer scoping
- ✅ SCADA views filtered by tenant

**Tested**: `test_tenant_isolation.sh`, `test_multi_customer_flow.sh`, `test_roles_access.sh`

---

## Authentication & Authorization

### Q: How does authentication work?

**A**: Bearer token authentication:

- **Token Source**: `ADMIN_BEARER_TOKEN` environment variable
- **Header**: `Authorization: Bearer <token>`
- **Validation**: All admin endpoints require valid token
- **Future**: JWT tokens with role claims (planned)

**Tested**: `test_roles_access.sh` authentication tests

---

### Q: What roles are supported?

**A**: Currently two role patterns:

1. **Engineer Role**: No `X-Customer-ID` header → Full access (all tenants)
2. **Customer Role**: `X-Customer-ID` header set → Scoped to own tenant

**Future Roles** (planned):
- Site Operator (read-only access to specific site)
- Read-only role (GET-only access)

**Tested**: `test_roles_access.sh`

---

## Error Handling

### Q: Do error messages leak sensitive information?

**A**: **No** - Error messages are sanitized:

- ✅ No SQL strings in error responses
- ✅ No stack traces exposed
- ✅ No internal table names
- ✅ No database error details
- ✅ Generic, user-friendly messages

**Validated**: `test_negative_cases.sh` security hardening tests

---

### Q: What happens with oversized payloads?

**A**: System handles gracefully:

- ✅ Large payloads (1MB+) are rejected or handled gracefully
- ✅ No server crashes
- ✅ Appropriate error status codes
- ✅ Queue buffering prevents DoS

**Tested**: `test_negative_cases.sh` oversized payload test

---

## Data Flow & Validation

### Q: When does parameter key validation happen?

**A**: **At database level** (async processing):

1. API accepts event and queues it (fast response)
2. Worker processes event from queue
3. Database foreign key constraint validates parameter_key exists
4. Invalid keys are rejected during insert

**Why async**:
- Allows queue buffering
- Provides resilience (survives database outages)
- Database FK ensures data integrity

**This is correct behavior** - tested and documented.

---

### Q: What if I send invalid data?

**A**: System rejects with appropriate status codes:

- **Missing fields**: 422 (Unprocessable Entity)
- **Invalid UUIDs**: 422 (Unprocessable Entity)
- **Invalid data types**: 422 (Unprocessable Entity)
- **Malformed JSON**: 422 or 400
- **Invalid parameter keys**: 200 (queued, validated later)

**All invalid data is rejected** - no invalid data enters database.

---

## Compliance & Audits

### Q: What evidence is available for audits?

**A**: Comprehensive evidence trail:

**Test Reports**:
- `tests/reports/ROLES_ACCESS_TEST_*.md` - Role-based access
- `tests/reports/TENANT_ISOLATION_TEST_*.md` - Tenant isolation
- `tests/reports/NEGATIVE_TEST_*.md` - Input validation
- `tests/reports/MULTI_CUSTOMER_FLOW_TEST_*.md` - Multi-tenant

**Documentation**:
- `SECURITY_TEST_MAPPING_ISO_IEC.md` - Control mapping
- `SECURITY_POSITION_NSREADY.md` - Security posture
- Service logs with tenant context
- Prometheus metrics

**Location**: All in `tests/reports/` and `master_docs/`

---

### Q: How do I prepare for an ISO/IEC audit?

**A**: Use the provided documentation:

1. **Review**: `SECURITY_TEST_MAPPING_ISO_IEC.md` - Maps tests to controls
2. **Review**: `SECURITY_POSITION_NSREADY.md` - Security posture
3. **Run Tests**: Execute test scripts to generate fresh evidence
4. **Gather Reports**: Collect test reports from `tests/reports/`
5. **Review Logs**: Check service logs for security events

**All evidence is timestamped and auditable**.

---

## Testing

### Q: Which tests should I run for security validation?

**A**: Run these test scripts:

1. **Role Access**: `./scripts/test_roles_access.sh`
   - Validates authentication and authorization
   - Tests engineer vs customer access patterns

2. **Tenant Isolation**: `./scripts/test_tenant_isolation.sh`
   - Validates data separation between tenants
   - Tests cross-tenant access denial

3. **Negative Cases**: `./scripts/test_negative_cases.sh`
   - Validates input validation
   - Tests error handling and security hardening

4. **Multi-Customer**: `./scripts/test_multi_customer_flow.sh`
   - Validates multi-tenant data flow
   - Tests tenant isolation in practice

**All tests generate detailed reports** in `tests/reports/`.

---

### Q: Why do some tests show 422 instead of 400?

**A**: **This is correct** - 422 is the proper HTTP status for validation errors.

**FastAPI/Pydantic** returns 422 for validation errors, which is:
- ✅ Correct according to HTTP standards
- ✅ Standard FastAPI behavior
- ✅ More accurate than 400 for validation errors

**Tests accept both 400 and 422** as valid rejection codes.

---

## Troubleshooting

### Q: Test shows "parameter key returned 200" - is this a failure?

**A**: **No** - This is correct behavior.

**Why**:
- Parameter validation happens at database level (async)
- API queues event and returns 200 (queued)
- Worker validates during insert
- Database FK rejects invalid keys

**This is by design** - see async processing architecture.

---

### Q: How do I verify tenant isolation is working?

**A**: Run tenant isolation tests:

```bash
# Tenant isolation test
DB_CONTAINER=nsready_db ./scripts/test_tenant_isolation.sh

# Multi-customer test
DB_CONTAINER=nsready_db ./scripts/test_multi_customer_flow.sh

# Role access test
DB_CONTAINER=nsready_db ./scripts/test_roles_access.sh
```

**All tests verify**:
- ✅ Customers cannot access other customers' data
- ✅ Cross-tenant access is denied (403)
- ✅ Data is properly isolated

---

## Best Practices

### Q: What security best practices should I follow?

**A**: 

1. **Change Default Tokens**: Set strong `ADMIN_BEARER_TOKEN` in production
2. **Enable TLS/HTTPS**: Configure at ingress/load balancer
3. **Network Isolation**: Use private networks/VPNs
4. **Monitor Access**: Review logs for security events
5. **Regular Updates**: Keep dependencies updated
6. **Run Tests**: Include security tests in CI/CD pipeline

See `SECURITY_POSITION_NSREADY.md` for deployment best practices.

---

### Q: How often should I run security tests?

**A**: 

- ✅ **In CI/CD**: Automatically on every code change
- ✅ **Before Deployments**: Run full test suite
- ✅ **After Security Changes**: Run tenant isolation tests
- ✅ **For Audits**: Run tests to generate fresh evidence

**Data flow tests**: Run when testing new integrations (not every time)

**Security tests**: Run in CI/CD and before deployments

---

## Quick Reference

### Test Scripts

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `test_roles_access.sh` | Role-based access | CI/CD, after auth changes |
| `test_tenant_isolation.sh` | Tenant isolation | CI/CD, after tenant code changes |
| `test_negative_cases.sh` | Input validation | CI/CD, after validation changes |
| `test_multi_customer_flow.sh` | Multi-tenant flow | CI/CD, integration testing |
| `test_data_flow.sh` | End-to-end flow | When testing integrations |

### Status Codes

| Code | Meaning | When Used |
|------|---------|-----------|
| 200 | Success | Valid request queued |
| 400 | Bad Request | Malformed request |
| 422 | Unprocessable Entity | Validation error (correct) |
| 401 | Unauthorized | Missing/invalid token |
| 403 | Forbidden | Access denied (tenant isolation) |
| 404 | Not Found | Resource doesn't exist |

### Documentation

| Document | Purpose |
|----------|---------|
| `SECURITY_POSITION_NSREADY.md` | Security posture statement |
| `SECURITY_TEST_MAPPING_ISO_IEC.md` | ISO/IEC control mapping |
| `SECURITY_TESTING_ADOPTION_PLAN.md` | Implementation plan |
| `SECURITY_FAQ.md` | This document |

---

## Still Have Questions?

**See Also**:
- `SECURITY_POSITION_NSREADY.md` - Complete security overview
- `SECURITY_TEST_MAPPING_ISO_IEC.md` - Compliance mapping
- `DATA_FLOW_TESTING_GUIDE.md` - Testing guide
- `TENANT_ISOLATION_TESTING_GUIDE.md` - Tenant isolation guide

**Contact**: Platform team for additional security questions

---

**Last Updated**: 2025-11-22


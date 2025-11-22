# Error-Proofing Tenant Validation - Security Hardening

**Date:** 2025-01-XX  
**Purpose:** Identify and fix potential error scenarios in tenant validation  
**Status:** 🔍 **ANALYSIS COMPLETE** - Ready for implementation

---

## Potential Error Scenarios

### 1. **Authentication Edge Cases**

| Scenario | Risk | Current Handling | Fix Required |
|----------|------|------------------|--------------|
| `X-Customer-ID` header with invalid UUID | Medium | None | ✅ Add UUID validation |
| `X-Customer-ID` header with non-existent customer | Medium | Validated in endpoints | ✅ Add explicit check |
| Multiple tenant identifiers provided (header + query) | Low | Uses header first | ✅ Log conflict, use header |
| `customer_id` in query param is empty string | Low | None | ✅ Treat as None |
| Malformed UUID in tenant identifier | Medium | DB error on query | ✅ Validate UUID format |

### 2. **Tenant Validation Edge Cases**

| Scenario | Risk | Current Handling | Fix Required |
|----------|------|------------------|--------------|
| `resource_customer_id` is None | High | None | ✅ Add NULL check |
| `resource_customer_id` is invalid UUID | Medium | DB error | ✅ Validate UUID format |
| Customer exists but is soft-deleted | Medium | None | ✅ Check customer status |
| `authenticated_tenant_id` matches but resource not found | Low | 404 error | ✅ Already handled |
| Database connection fails during validation | High | Unhandled exception | ✅ Add try/catch, log |

### 3. **FK Chain Validation Edge Cases**

| Scenario | Risk | Current Handling | Fix Required |
|----------|------|------------------|--------------|
| Project exists but customer_id FK is broken | High | None | ✅ Validate FK integrity |
| Site exists but project_id FK is broken | High | None | ✅ Validate FK integrity |
| Device exists but site_id FK is broken | High | None | ✅ Validate FK integrity |
| Circular references (shouldn't happen) | Low | None | ✅ FK constraints prevent |
| Orphaned records (FK missing) | High | Query returns empty | ✅ Explicit check |

### 4. **Error Message Leakage**

| Scenario | Risk | Current Handling | Fix Required |
|----------|------|------------------|--------------|
| Error message contains foreign customer_id | High | Partially handled | ✅ Sanitize all errors |
| Stack traces exposed in errors | High | Depends on env | ✅ Never expose in errors |
| Error reveals resource exists in other tenant | Medium | Generic errors | ✅ Generic 404/403 |
| Timing attack (different response times) | Low | None | ✅ Consistent timing |

### 5. **SQL Injection / Query Issues**

| Scenario | Risk | Current Handling | Fix Required |
|----------|------|------------------|--------------|
| SQL injection via tenant_id parameter | High | Parameterized queries | ✅ Already safe |
| Query returns unexpected NULL | Medium | None | ✅ Explicit NULL checks |
| Query timeout on large datasets | Medium | None | ✅ Add timeout |
| Race condition (customer deleted during query) | Low | Transaction isolation | ✅ Add retry logic |

### 6. **Registry Versions Edge Cases**

| Scenario | Risk | Current Handling | Fix Required |
|----------|------|------------------|--------------|
| Project exists but has no customer_id | High | FK constraint prevents | ✅ Add explicit check |
| Parameter templates not linked to project | Medium | EXISTS check handles | ✅ Already safe |
| Empty config snapshot (all queries return empty) | Low | Valid but odd | ✅ Log warning |
| Config snapshot too large (JSON size) | Medium | None | ✅ Add size limit |

---

## Error-Proofing Enhancements

### Enhancement 1: UUID Validation

**Problem:** Invalid UUIDs can cause database errors or unexpected behavior.

**Fix:**
```python
import uuid
from typing import Optional

def validate_uuid(uuid_str: Optional[str], field_name: str = "ID") -> str:
    """
    Validate and normalize UUID string.
    
    Raises:
        HTTPException: 400 if UUID is invalid
    """
    if not uuid_str:
        raise HTTPException(
            status_code=400,
            detail=f"{field_name} is required",
        )
    
    uuid_str = uuid_str.strip()
    
    try:
        # Validate UUID format
        parsed_uuid = uuid.UUID(uuid_str)
        return str(parsed_uuid)
    except (ValueError, AttributeError):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid {field_name} format: expected UUID",
        )
```

### Enhancement 2: Customer Existence Check

**Problem:** Tenant validation assumes customer exists.

**Fix:**
```python
async def validate_customer_exists(
    customer_id: str,
    session: AsyncSession,
) -> dict:
    """
    Validate customer exists and return customer info.
    
    Raises:
        HTTPException: 404 if customer not found
    """
    # Validate UUID format first
    customer_id = validate_uuid(customer_id, "Customer ID")
    
    result = await session.execute(
        text("SELECT id::text, name FROM customers WHERE id = :id"),
        {"id": customer_id}
    )
    row = result.mappings().first()
    
    if not row:
        raise HTTPException(
            status_code=404,
            detail="Customer not found",
        )
    
    return dict(row)
```

### Enhancement 3: Enhanced Tenant Validation

**Problem:** Current validation doesn't handle edge cases.

**Fix:**
```python
async def validate_tenant_access_enhanced(
    resource_customer_id: str,
    authenticated_tenant_id: Optional[str],
    session: AsyncSession,
    resource_type: str = "Resource",
) -> None:
    """
    Enhanced tenant access validation with comprehensive error handling.
    
    Raises:
        HTTPException: 400, 403, or 404 with safe error messages
    """
    # Validate resource_customer_id format
    resource_customer_id = validate_uuid(resource_customer_id, f"{resource_type} Customer ID")
    
    # Validate customer exists
    customer_info = await validate_customer_exists(resource_customer_id, session)
    
    if authenticated_tenant_id is None:
        # Engineer/admin mode - allow access to all tenants
        # Resource existence already validated above
        return
    
    # Validate authenticated_tenant_id format
    authenticated_tenant_id = validate_uuid(authenticated_tenant_id, "Authenticated Tenant ID")
    
    # Validate authenticated customer exists
    await validate_customer_exists(authenticated_tenant_id, session)
    
    # Customer mode - validate tenant access
    if authenticated_tenant_id != resource_customer_id:
        # SECURITY: Generic error message (no info leakage)
        raise HTTPException(
            status_code=403,
            detail="Access denied. Resource not available.",
        )
```

### Enhancement 4: FK Chain Validation

**Problem:** FK chain queries don't validate integrity.

**Fix:**
```python
async def validate_project_access_enhanced(
    project_id: str,
    authenticated_tenant_id: Optional[str],
    session: AsyncSession,
) -> dict:
    """
    Enhanced project access validation with FK integrity check.
    
    Returns:
        dict: Project info including customer_id
    """
    # Validate project_id format
    project_id = validate_uuid(project_id, "Project ID")
    
    result = await session.execute(
        text("""
            SELECT p.id::text, p.customer_id::text AS customer_id, p.name AS project_name,
                   c.id::text AS customer_id_validated, c.name AS customer_name
            FROM projects p
            LEFT JOIN customers c ON c.id = p.customer_id
            WHERE p.id = :id
        """),
        {"id": project_id}
    )
    row = result.mappings().first()
    
    if not row:
        raise HTTPException(
            status_code=404,
            detail="Project not found",
        )
    
    # Validate FK integrity
    if not row["customer_id_validated"]:
        # FK broken - critical error
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"CRITICAL: FK broken - Project {project_id} has invalid customer_id {row['customer_id']}")
        raise HTTPException(
            status_code=500,
            detail="Internal error: Data integrity issue. Please contact support.",
        )
    
    customer_id = row["customer_id"]
    
    # Validate tenant access
    await validate_tenant_access_enhanced(
        customer_id,
        authenticated_tenant_id,
        session,
        resource_type="Project"
    )
    
    return dict(row)
```

### Enhancement 5: Safe Error Messages

**Problem:** Error messages might leak information.

**Fix:**
```python
def format_tenant_scoped_error_safe(
    message: str,
    customer_id: Optional[str] = None,
    customer_name: Optional[str] = None,
    include_tenant_context: bool = False,
) -> str:
    """
    Format error message with tenant context, avoiding cross-tenant information leakage.
    
    Rules:
    - NEVER echo foreign customer IDs or names
    - Use generic messages for access denied
    - Only include tenant context if explicitly allowed (authenticated tenant)
    - Never expose stack traces or internal errors
    
    Args:
        message: Base error message
        customer_id: Customer ID (only include if authenticated tenant and include_tenant_context=True)
        customer_name: Customer name (only include if authenticated tenant and include_tenant_context=True)
        include_tenant_context: Whether to include tenant context (only for authenticated tenant)
        
    Returns:
        Formatted error message safe for multi-tenant environment
    """
    # Never include foreign tenant context
    if not include_tenant_context:
        return message
    
    # Only include tenant context if explicitly allowed (authenticated tenant)
    if customer_id and customer_name:
        # Sanitize customer name (limit length, remove special chars)
        safe_name = customer_name[:20].replace("\n", "").replace("\r", "")
        return f"{message} (Customer: {safe_name}...)"
    
    return message
```

### Enhancement 6: Logging for Security Audit

**Problem:** No audit trail for tenant access attempts.

**Fix:**
```python
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

async def validate_tenant_access_with_audit(
    resource_customer_id: str,
    authenticated_tenant_id: Optional[str],
    session: AsyncSession,
    resource_type: str = "Resource",
    resource_id: Optional[str] = None,
) -> None:
    """
    Validate tenant access with security audit logging.
    """
    # Validate access
    try:
        await validate_tenant_access_enhanced(
            resource_customer_id,
            authenticated_tenant_id,
            session,
            resource_type
        )
        
        # Log successful access
        if authenticated_tenant_id:
            logger.info(
                f"TENANT_ACCESS_ALLOWED: tenant={authenticated_tenant_id[:8]}..., "
                f"resource_type={resource_type}, resource_id={resource_id or 'N/A'}"
            )
        
    except HTTPException as e:
        # Log denied access (security audit)
        if authenticated_tenant_id:
            logger.warning(
                f"TENANT_ACCESS_DENIED: tenant={authenticated_tenant_id[:8]}..., "
                f"resource_type={resource_type}, resource_id={resource_id or 'N/A'}, "
                f"reason={e.status_code}"
            )
        raise
```

### Enhancement 7: Registry Versions Error Handling

**Problem:** Registry version export might fail or leak data.

**Fix:**
```python
@router.post("/{project_id}/versions/publish", response_model=PublishOut)
async def publish_version_enhanced(
    project_id: str,
    payload: PublishIn,
    session: AsyncSession = Depends(get_session),
    authenticated_tenant_id: str | None = Depends(get_authenticated_tenant),
):
    """
    Publish a registry version with enhanced error handling.
    
    CRITICAL: Only exports registry data for the project's customer (tenant isolation).
    """
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        # Validate project_id format
        project_id = validate_uuid(project_id, "Project ID")
        
        # Validate project access and get customer_id (with FK integrity check)
        project_info = await validate_project_access_enhanced(
            project_id,
            authenticated_tenant_id,
            session
        )
        customer_id = project_info["customer_id"]
        customer_name = project_info.get("customer_name", "Unknown")
        
        # Log registry version creation
        logger.info(
            f"REGISTRY_VERSION_CREATE: project={project_id[:8]}..., "
            f"customer={customer_id[:8]}..., author={payload.author}"
        )
        
        # Compute next version
        res = await session.execute(
            text("SELECT COALESCE(MAX(version), 0) AS maxv FROM registry_versions WHERE project_id = :pid"),
            {"pid": project_id},
        )
        maxv = res.scalar_one()
        next_version = int(maxv) + 1
        
        # Build full config snapshot - CRITICAL: Filter by customer_id
        # Wrap in try/catch for error handling
        try:
            cfg_customers = (await session.execute(
                text("SELECT id::text, name, metadata FROM customers WHERE id = :customer_id"),
                {"customer_id": customer_id}
            )).mappings().all()
            
            if not cfg_customers:
                # Customer not found - critical error
                logger.error(f"CRITICAL: Customer {customer_id[:8]}... not found during registry version export")
                raise HTTPException(
                    status_code=500,
                    detail="Internal error: Customer not found. Please contact support.",
                )
            
            cfg_projects = (await session.execute(
                text("SELECT id::text, customer_id::text AS customer_id, name, description FROM projects WHERE customer_id = :customer_id"),
                {"customer_id": customer_id}
            )).mappings().all()
            
            cfg_sites = (await session.execute(
                text("""
                    SELECT s.id::text, s.project_id::text AS project_id, s.name, s.location
                    FROM sites s
                    JOIN projects p ON p.id = s.project_id
                    WHERE p.customer_id = :customer_id
                """),
                {"customer_id": customer_id}
            )).mappings().all()
            
            cfg_devices = (await session.execute(
                text("""
                    SELECT d.id::text, d.site_id::text AS site_id, d.name, d.device_type, d.external_id, d.status
                    FROM devices d
                    JOIN sites s ON s.id = d.site_id
                    JOIN projects p ON p.id = s.project_id
                    WHERE p.customer_id = :customer_id
                """),
                {"customer_id": customer_id}
            )).mappings().all()
            
            cfg_params = (await session.execute(
                text("""
                    SELECT pt.id::text, pt.key, pt.name, pt.unit, pt.metadata
                    FROM parameter_templates pt
                    WHERE pt.metadata ? 'project_id'
                    AND EXISTS (
                        SELECT 1 FROM projects p
                        WHERE p.id::text = pt.metadata->>'project_id'
                        AND p.customer_id = :customer_id
                    )
                """),
                {"customer_id": customer_id}
            )).mappings().all()
            
            # Validate config snapshot is not empty (should have at least customer)
            if not cfg_customers:
                logger.warning(f"Registry version export: Empty config snapshot for customer {customer_id[:8]}...")
                raise HTTPException(
                    status_code=500,
                    detail="Internal error: Empty config snapshot. Please contact support.",
                )
            
        except HTTPException:
            raise
        except Exception as e:
            # Log error but don't expose details
            logger.error(f"Error building config snapshot: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail="Internal error: Failed to build config snapshot. Please contact support.",
            )
        
        full_config = {
            "customers": cfg_customers,
            "projects": cfg_projects,
            "sites": cfg_sites,
            "devices": cfg_devices,
            "parameter_templates": cfg_params,
        }
        
        # Validate config size (prevent DoS)
        import json
        config_json = json.dumps(full_config)
        config_size_mb = len(config_json) / (1024 * 1024)
        
        if config_size_mb > 10:  # 10MB limit
            logger.error(f"Registry version config too large: {config_size_mb:.2f}MB")
            raise HTTPException(
                status_code=413,
                detail="Config snapshot too large. Please contact support.",
            )
        
        # Insert version row
        try:
            await session.execute(
                text(
                    "INSERT INTO registry_versions(project_id, version, diff_json, author, full_config, checksum, description) "
                    "VALUES (:pid, :ver, :diff, :author, :full_config, :checksum, :description)"
                ),
                {
                    "pid": project_id,
                    "ver": next_version,
                    "diff": payload.diff_json,
                    "author": payload.author,
                    "full_config": full_config,
                    "checksum": f"v{next_version}",  # placeholder checksum
                    "description": f"Published by {payload.author}",
                },
            )
            await session.commit()
            
            logger.info(
                f"REGISTRY_VERSION_CREATED: project={project_id[:8]}..., "
                f"version=v{next_version}, customer={customer_id[:8]}..."
            )
            
        except Exception as e:
            await session.rollback()
            logger.error(f"Error creating registry version: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail="Internal error: Failed to create registry version. Please contact support.",
            )
        
        return PublishOut(status="ok", config_version=f"v{next_version}")
        
    except HTTPException:
        raise
    except Exception as e:
        # Catch-all for unexpected errors
        logger.error(f"Unexpected error in publish_version: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Internal error: Please contact support.",
        )
```

---

## Implementation Checklist

### Phase 1: Basic Validation

- [ ] Add UUID validation function
- [ ] Add customer existence check
- [ ] Enhance tenant validation with UUID checks
- [ ] Add NULL checks to all validation functions

### Phase 2: FK Integrity

- [ ] Add FK integrity checks to project access validation
- [ ] Add FK integrity checks to site access validation
- [ ] Add FK integrity checks to device access validation
- [ ] Add explicit orphaned record checks

### Phase 3: Error Handling

- [ ] Add try/catch blocks to all validation functions
- [ ] Add safe error messages (no leakage)
- [ ] Add logging for security audit trail
- [ ] Add config size validation (registry versions)

### Phase 4: Registry Versions Hardening

- [ ] Add error handling to config snapshot building
- [ ] Add empty config validation
- [ ] Add config size limit (prevent DoS)
- [ ] Add transaction rollback on errors
- [ ] Add comprehensive logging

---

## Testing Scenarios

### Test 1: Invalid UUID Format

```python
# Should return 400 Bad Request
GET /admin/customers/invalid-uuid
# Expected: 400 "Invalid Customer ID format: expected UUID"
```

### Test 2: Non-Existent Customer

```python
# Should return 404 Not Found
GET /admin/customers/00000000-0000-0000-0000-000000000000
# Expected: 404 "Customer not found"
```

### Test 3: Cross-Tenant Access Attempt

```python
# Customer A tries to access Customer B's project
# Should return 403 Forbidden
GET /admin/projects/{customer_b_project_id}
X-Customer-ID: {customer_a_id}
# Expected: 403 "Access denied. Resource not available."
```

### Test 4: Broken FK Chain

```python
# If project has invalid customer_id (shouldn't happen, but test anyway)
# Should return 500 Internal Error
# Expected: 500 "Internal error: Data integrity issue. Please contact support."
# Should also log CRITICAL error
```

### Test 5: Empty Registry Version Config

```python
# If all queries return empty (unlikely but possible)
# Should return 500 Internal Error
# Expected: 500 "Internal error: Empty config snapshot. Please contact support."
# Should log warning
```

### Test 6: Large Registry Version Config

```python
# If config snapshot > 10MB
# Should return 413 Payload Too Large
# Expected: 413 "Config snapshot too large. Please contact support."
```

---

## Security Audit Logging

### Log Events

1. **TENANT_ACCESS_ALLOWED** - Successful tenant access
2. **TENANT_ACCESS_DENIED** - Denied tenant access (security event)
3. **REGISTRY_VERSION_CREATE** - Registry version creation
4. **REGISTRY_VERSION_CREATED** - Registry version created successfully
5. **FK_INTEGRITY_ERROR** - FK chain broken (critical)
6. **CONFIG_SNAPSHOT_EMPTY** - Empty config snapshot (warning)
7. **CONFIG_SNAPSHOT_TOO_LARGE** - Config size exceeded limit

### Log Format

```json
{
  "timestamp": "2025-01-XXT12:00:00Z",
  "level": "INFO|WARNING|ERROR|CRITICAL",
  "event": "TENANT_ACCESS_ALLOWED",
  "tenant_id": "customer_id[:8]...",
  "resource_type": "Project",
  "resource_id": "project_id[:8]...",
  "status_code": 200,
  "message": "Human-readable message"
}
```

---

## Next Steps

1. **Implement UUID validation** ✅ Priority 1
2. **Enhance tenant validation** ✅ Priority 1
3. **Add FK integrity checks** ✅ Priority 2
4. **Add comprehensive error handling** ✅ Priority 2
5. **Add security audit logging** ✅ Priority 3
6. **Test all error scenarios** ✅ Priority 3

---

**Status:** 🔍 **ANALYSIS COMPLETE**  
**Priority:** 🔴 **HIGH** - Security hardening required  
**Effort:** 6-8 hours additional implementation



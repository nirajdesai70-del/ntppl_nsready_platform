# NSWare Frontend

This folder contains NSWare frontend components.

## Status

🚧 **Future Phase** - NSWare frontend is planned but not yet active.

## Components

- **`frontend_dashboard/`** - React/TypeScript dashboard (future)
  - Full industrial platform UI for multi-tenant SaaS operations
  - Multi-tenant dashboards
  - KPI engine integration
  - AI/ML capabilities
  - Enterprise-grade UI/UX design system

## Current State

NSWare components are in planning/design phase. See `../shared/master_docs/` for design specifications.

## Future Components

- Enhanced operational dashboards
- IAM integration (JWT, RBAC, MFA)
- KPI engine
- AI/ML integration
- Multi-tenant SaaS UI
- OEM customer portals

## NSReady vs NSWare Dashboard

**Critical Distinction:**

- **NSReady Operational Dashboard** (Current, Internal)
  - Location: `../nsready_backend/admin_tool/ui/` (or `templates/`)
  - Purpose: Lightweight internal UI for engineers/administrators
  - Technology: Simple HTML/JavaScript, served by FastAPI
  - Authentication: Bearer token (simple)
  - Status: Current / In design

- **NSWare Dashboard** (Future, Full SaaS Platform)
  - Location: `frontend_dashboard/` (this folder)
  - Purpose: Full industrial platform UI for multi-tenant SaaS operations
  - Technology: React/TypeScript, separate service
  - Authentication: Full stack (JWT, RBAC, MFA)
  - Status: Future / Planned

**See `../shared/master_docs/NSREADY_VS_NSWARE_DASHBOARD_CLARIFICATION.md` for full details.**

## Development Guidelines

- All NSWare UI work goes under `frontend_dashboard/`
- Use modern framework (React/TypeScript or similar)
- Full authentication stack (JWT, RBAC, MFA)
- Separate frontend service from NSReady backend
- Do not start until NSReady is stable



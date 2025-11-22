# NSReady Dashboard & UI/UX Master Specification

**Version:** 1.0  
**Document Type:** Master Reference (Dashboard/UI - NSReady v1 Data Collection Software)  
**Branding:** Neutral / No Group Nish branding  
**Scope:** Dashboard architecture, UI/UX standards, navigation, tiles, and visualization for NSReady v1 backend data collection software.

---

## 1. Executive Summary (Purpose of This Document)

This document defines the master blueprint for **NSReady v1 data collection software dashboards** and operational UI.

It aligns:
- Field telemetry ingestion (NSReady backend)
- Multi-customer/tenant isolation
- SCADA-style live dashboards
- Engineering/operator dashboards for data collection health
- Registry configuration and monitoring dashboards

And establishes:
- Standard layout structure
- Standard tile structure
- Standard data contract
- Standard theme system
- Standard UX rules
- Standard alert visualization
- Standard navigation structure
- Standard customer-group tenant model

This is the single source of truth for NSReady operational dashboard architecture.

---

## 2. Scope of This Master Document

**Included in this Master:**

1. Dashboard architecture for NSReady v1
2. UI/UX standards
3. Navigation structure
4. Dashboard tile definition
5. Data binding rules (backend → dashboard)
6. Tenant/customer isolation
7. Multi-company "Customer Group" support
8. SCADA integration visualization rules
9. Layout templates (web + mobile)
10. Operational dashboards (registry, collection health, ingestion logs, SCADA export, system health)

**Not included (covered in Backend Master):**

- Ingestion logic
- Worker/nats flows
- Database architecture
- SCADA DB integration
- YAML data contracts
- Tenant ADR
- Performance and monitoring ops

**Not included (covered in NSWare Dashboard Master - Future):**

- Process KPI specifications (steam, water, power KPIs)
- Process alert specifications
- KPI/Alert engine architecture
- Feature Store integration
- AI/ML process dashboards

**Cross-Reference:**

- **Backend Architecture:** `../NSREADY_BACKEND_MASTER.md`
- **NSWare Future Dashboards:** `../NSware Basic work/NSWARE_DASHBOARD_MASTER.md` Parts 5-10

---

## 3. Core Dashboard Philosophy (NSReady Design DNA)

NSReady dashboards follow five non-negotiable principles:

### 3.1 Real-Time but Human-Centric (Not Overloaded)

Dashboards display only:

- What the operator must act on
- What engineering must diagnose
- What management must decide

NSReady avoids:

- Overloaded charts
- Meaningless gauges
- Too many moving parts

Everything in NSReady follows the principle:

**"Minimal visual load, maximum operational clarity."**

### 3.2 Tenant-Safe and Customer-Safe by Default

Based on backend tenant model:

```
tenant_id = customer_id
parent_customer_id → group reports only
```

Dashboards must enforce:

**A. Tenant Isolation**

- A customer can never view another customer's data.
- Permissions inherited from backend access layer.

**B. Group Reporting (Optional)**

- OEMs/distributors (e.g., Customer Group) can see aggregated views.
- Individual companies see only their own data.

### 3.3 KPI-First, Chart-Second

Dashboards must always present:

```
KPIs → Alerts → Trends → Drill-down charts → Raw logs
```

Not the reverse.

This ensures:

- Latency in decision-making reduces
- Operators catch issues faster
- Engineers diagnose based on summarized signals

### 3.4 Modular, Reusable Tiles System

Every dashboard tile must follow a common contract:

- `title`
- `subtitle` (optional)
- `value`
- `status` (normal/warning/critical)
- `trend` (up/down/neutral)
- `chart` (optional)
- `actions` (optional)
- `metadata` (units, timestamp)

One tile = one independent data contract = reusable anywhere.

Tiles must be plug-and-play.

### 3.5 AI-Ready from Day Zero

Even before AI is implemented:

- Every dashboard tile must have placeholders for AI scores
- Every alert must allow "explainability"
- Every trend chart should support ML overlays

**Why?**

NSReady dashboards become:

- ML-visualization-ready without rework
- Feature-store-ready
- Prediction-integrated
- Future-proof

**Note:** Process KPIs and AI features are covered in NSWare Phase-2 (future), but the structure is AI-ready.

---

## 4. Dashboard Categories (NSReady Product Lines)

NSReady supports these operational dashboard types:

### 4.1 Registry Configuration Dashboards

Shows:

- Customer → Project → Site → Device hierarchy
- Parameter template definitions
- Registry import/export status

Target users:

- Engineers
- System administrators

### 4.2 Collection Health Dashboards (Operator)

Shows:

- Packet on-time percentage
- Missing packets
- Late packets
- Device health status
- Last packet times

Target users:

- Operators
- SCADA engineers
- Shift managers

### 4.3 Ingestion Log Dashboards (Diagnostic)

Shows:

- Event timeline
- Error logs
- Trace IDs
- Ingestion statistics

Target users:

- Data engineers
- System administrators

### 4.4 SCADA Export Monitor Dashboards

Shows:

- Latest SCADA values (`v_scada_latest`)
- Export file history
- SCADA mapping status

Target users:

- SCADA engineers
- System administrators

### 4.5 System Health Dashboards

Shows:

- Service status (`/v1/health`)
- Queue depth
- Database status
- Worker status
- Metrics (`/metrics`)

Target users:

- Engineers
- System administrators

### 4.6 Group Dashboards (Customer Group / OEM Multi-Company)

Supports:

- OEMs with multiple internal companies
- Utilities managing multiple concession areas

**Example:**

```
Customer Group
 ├── Customer Group Textool
 ├── Customer Group Texpin
 └── Customer Group [Company 3…6]
```

Dashboard must:

- Aggregate at Group level
- Drill down into each child company

This is built using:

- `customer_id` for isolation
- `parent_customer_id` for grouping

---

## 5. NSReady Theme System (Design Foundation)

The NSReady dashboards use a uniform, modern, dark-theme-first style.

**Color System:**

| Category | Color |
|----------|-------|
| Background | `#0E0E11` |
| Panel | `#1A1A1F` |
| Borders | `#2A2A32` |
| Text Primary | `#FFFFFF` |
| Text Secondary | `#A0A0A3` |
| Accent Blue | `#3D8BFF` |
| Critical Red | `#F44336` |
| Warning Yellow | `#FFC107` |
| Success Green | `#4CAF50` |

**Typography:**

- Font: Inter
- Sizes:
  - Title: 20–24
  - Tile Title: 14–16
  - KPI Value: 28–40
  - Subtext: 11–12

**Layout:**

- 12-column grid
- Modular tiles
- Responsive web + mobile

**Icons:**

- SVG-based
- Stroke 1.5–2px
- Simple geometric shapes

---

## 6. Core Dashboard Data Model

All dashboard data should follow a unified JSON contract:

```json
{
  "tenant_id": "UUID",
  "customer_id": "UUID",
  "site_id": "UUID",
  "device_id": "UUID",
  "kpis": [
    { "key": "packet_on_time_pct", "value": 96.5, "unit": "%", "status": "normal", "trend": "up" }
  ],
  "alerts": [
    { "key": "missing_packets", "level": "warning", "timestamp": "...", "message": "..." }
  ],
  "charts": [
    { "key": "ingestion_timeline_24h", "data": [...], "unit": "events" }
  ],
  "metadata": {
    "timestamp": "2025-11-18T12:10:00Z"
  }
}
```

This ensures:

- Dashboards, SCADA, and future AI all consume the same data shape
- Every tile follows the same contract
- Multi-customer isolation is enforced at data level

---

## 7. Standard Dashboard Page Types (Defined for NSReady UI)

Each dashboard instance must be one of these types:

**1) Main Operational Dashboard**

- Registry overview
- Collection health summary
- System health summary
- Quick navigation

**2) Registry Configuration Dashboard**

- Hierarchy tree
- Entity details
- Parameter templates
- Bulk import/export

**3) Collection Health Dashboard**

- Packet statistics
- Site health table
- Device health table

**4) Ingestion Log Dashboard**

- Event timeline
- Error log table
- Trace ID search

**5) SCADA Export Monitor Dashboard**

- Latest SCADA values
- Export status
- SCADA mapping

**6) System Health Dashboard**

- Service status
- Queue depth
- Database status
- Metrics snapshot

These are templates—front-end must not deviate.

---

## 8. Tile Types (Master Tile Library)

Tiles must come from the predefined library:

### 8.1 KPI Tile

- Main tile
- Large numeric display
- Status coloring

### 8.2 Alert Tile

- Color-coded severity
- Scannable message layout

### 8.3 Trend Tile

- Mini chart (sparkline)
- Up/down indicator

### 8.4 Health Tile

- Packet delay
- Missing packets
- Device uptime
- Collection health %

### 8.5 Asset Tile

- Device representation
- Registry entity representation

### 8.6 Distribution Tile

- Histogram/violin/bar

### 8.7 AI Insight Tile (Future)

- Prediction (future NSWare Phase-2)
- Confidence (future NSWare Phase-2)
- Explainability (future NSWare Phase-2)

---

## 9. Dashboard → Backend → SCADA Linkage Model

Dashboard consumes data from:

```
DB Views → API → Dashboard  
 |
ingest_events  
 |
NATS Events → Workers
```

Dashboards never call DB directly.

Dashboards must:

- Call API
- Respect tenant context
- Use unified JSON contract

Backend master document defines pulling.  
Dashboard master defines display.

**For NSReady v1:**

- Primary data sources: `v_scada_latest`, `v_scada_history` (SCADA views)
- Health endpoints: `/v1/health`, `/metrics`
- Registry: `customers`, `projects`, `sites`, `devices`, `parameter_templates`

---

---

## 2. Information Architecture (IA) Blueprint

This section defines the universal navigation and routing model for all NSReady dashboards.

The entire application must follow a clear, hierarchical, tenant-safe, predictable structure:

```
Tenant
 └── Customer (entity/company)
       └── Sites
             └── Devices
                   └── Units/KPIs/Alerts
```

This layered IA ensures:

- Perfect isolation
- Reusable UI components
- Standardised UX across industries
- Clean API access
- Straightforward data permissions

### 2.1 NSReady Navigation Layers (4-Level Structure)

The NSReady frontend uses a 4-level navigation system, identical across all deployments:

#### Level 1: Tenant (Top Level – Only for Group/OEM Use)

Shown only when:

- The OEM has multiple child companies
- The user is marked as "tenant-admin"

**Screen structure:**

- Logo (OEM or utility)
- Tenant dashboard (aggregate KPIs)
- Child customer list

**Example:**

```
Customer Group
 ├── Customer Group Textool
 ├── Customer Group Texpin
 ├── Customer Group Engineering
```

**Data source:**

- `customer_id` where `parent_customer_id IS NULL`

**Purpose:**

- High-level group/OEM analytics
- Administrator-level visibility

#### Level 2: Customer (Individual Company)

Visible to:

- Customer engineers
- Customer management
- OEM tenant managers

**Screen structure:**

- Performance KPIs for the company
- Sites overview
- Device count, uptime, distribution
- Alerts distribution

**Data source:**

- `customer_id = <child_company_uuid>`

**Notes:**

- Every dashboard must enforce `customer_id` isolation
- One company's data must never leak to another

#### Level 3: Site Dashboard (Location-Level View)

Shows detailed performance for a physical location.

**Screen structure:**

- Site-level KPIs
- Live metrics and alerts
- Device list
- Health maps
- Mini-trends

**Data source:**

- `project_id → site_id`

**Expected use:**

- On-site operators
- Maintenance engineers
- SCADA dashboards

#### Level 4: Device / Unit Dashboard (Deep Drill-Down)

Shows:

- Device KPIs
- Latest values
- Packet health
- Mini trends
- Historical charts

**Data source:**

- `device_id`

**Purpose:**

- Engineering diagnostics
- Device-level troubleshooting

### 2.2 Routing Structure (Front-End Routing Map)

The NSReady frontend must use a clean routing structure:

```
/tenant/:tenant_id
/customer/:customer_id
/site/:site_id
/device/:device_id
/operational/:customer_id/:dashboard_type
```

**Routing Rules:**

1. Tenant routing is optional
2. Customer routing is mandatory
3. Site routing always requires a valid customer context
4. Device routing must validate `customer_id + site_id + device_id`
5. Operational dashboards require engineer role (Part 6)
6. Unauthorized tenant navigation should auto-redirect to customer root

### 2.3 Navigation Components (Standardized UI Layout)

Navigation must follow a consistent left-sidebar layout:

**Left Sidebar (Fixed)**

- Tenant switcher (if applicable)
- Customer list (if tenant admin)
- Site list
- Device list (optional collapsible panel)
- **Operational section (Engineer only):**
  - Registry Configuration
  - Collection Health
  - Ingestion Logs
  - SCADA Export Monitor
  - System Health
- Common links:
  - Dashboard
  - Alerts
  - Settings

**Top Bar**

- User profile
- Time range selector
- Search
- Quick actions

**Bottom Bar (Mobile Only)**

- Home
- Alerts
- Devices
- Settings

### 2.4 Dashboard Page Types (Universal Templates)

To reduce redesign time and ensure consistent UX, NSReady defines universal dashboard templates.

#### 2.4.1 Template A: Main Operational Dashboard (Tenant/Customer)

**Sections:**

- Registry summary (device count, site count)
- Collection health summary
- System health summary
- Recent alerts

**Recommended Widgets:**

- Devices configured vs active
- Packet on-time %
- Missing packets
- System status

#### 2.4.2 Template B: Registry Configuration Dashboard

**Sections:**

- Hierarchy tree (Customer → Project → Site → Device)
- Entity details panel
- Parameter templates list
- Bulk import/export tools

#### 2.4.3 Template C: Collection Health Dashboard

**Sections:**

- Health summary KPIs
- Site health table
- Device health table

**Widgets:**

- Packet statistics
- Device uptime
- Packet health %

#### 2.4.4 Template D: Ingestion Log Dashboard

**Sections:**

- Event timeline chart
- Error log table
- Trace ID search

#### 2.4.5 Template E: SCADA Export Monitor Dashboard

**Sections:**

- Latest SCADA values table
- Export status
- SCADA mapping summary

#### 2.4.6 Template F: System Health Dashboard

**Sections:**

- Service status
- Queue depth
- Database status
- Metrics snapshot

### 2.5 Breadcrumb Navigation Standard

Breadcrumbs always follow:

```
Tenant > Customer > Site > Device
```

**Example for Customer Group:**

```
Customer Group > Customer Group Textool > Site 12 > Device 004
```

**For Operational Dashboards:**

```
Customer > Operational > [Dashboard Name]
```

**Requirements:**

- Breadcrumb must be clickable
- Must enforce tenant context
- Must handle deep links gracefully

### 2.6 Search Model (Unified Search) – NSReady Search Contract

Search must support the following entities:

- Customer
- Site
- Device
- Parameter
- Alert

**Search bar must:**

- Be tenant-aware
- Show relevant icons
- Support type-ahead
- Support deep linking

### 2.7 Role-Based Visibility

**Roles defined:**

| Role | Permissions |
|------|-------------|
| Tenant Admin | All companies + group dashboards |
| Customer Admin | Only their company + all sites |
| Site Operator | Only their site |
| Device Engineer | All devices under their site |
| Read-Only | View dashboards only |
| **Engineer** | All operational dashboards + configuration |

**Routing must enforce:**

- Role-based view
- Role-based navigation
- Role-based tile visibility

### 2.8 Multi-Device Personality Model (Industrial UI Pattern)

Devices in NSReady may have different personalities:

- Flowmeter
- Pressure gauge
- Temperature probe
- UPS
- Valve
- RTU
- PLC
- Motor
- Pump
- Steam trap
- Boiler

**Dashboard must:**

- Auto-detect device personality through metadata
- Automatically load the correct visualization template

**Example:**

```
device_type = vortex_flowmeter
→ loads Flow Dashboard Template
```

### 2.9 Data Binding Model (How Dashboard Gets Data)

Dashboard pulls data as:

```
[Backend Views] → API → Dashboard JSON → Tile Render
```

**Binding Rules:**

1. Every tile uses the same unified JSON structure
2. Every dashboard page maps to one backend view
3. Customer isolation always enforced
4. Each tile can subscribe to:
   - KPIs (collection health, system health)
   - Alerts (missing packets, errors)
   - Trends (ingestion timeline, packet health)
   - Registry data (devices, sites)

**For NSReady v1:**

- Data sources: `v_scada_latest`, `v_scada_history`, registry tables, health endpoints
- No direct database access from frontend
- All data via API layer

### 2.10 Tenant & Customer Context (Critical Rule)

**Single rule that frontend must follow:**

Tenant context always resolves through `customer_id`.

**Meaning:**

- A tenant is a company
- Parent group is for reporting & aggregation only
- UI must not treat parent group as the data boundary
- Data isolation must be enforced per company

**Example (Important):**

```
Customer Group  (parent_customer)
 ├── Customer Group Textool    → tenant
 ├── Customer Group Texpin     → tenant
```

**Dashboards must:**

- Treat Textool & Texpin as separate tenants
- Allow group-level aggregation using `parent_customer_id`
- Never mix device/site data across companies unless specifically in group dashboard view

---

## 3. Universal Tile System (UTS v1.0)

The Universal Tile System defines:

- How every dashboard tile looks
- How every tile reads data
- How every tile behaves
- How future AI modules extend tiles
- How tenant/customer safety is enforced

This ensures the entire NSReady ecosystem has:

- Consistent UI
- Reusable tile components
- Clean integration with backend APIs
- Predictable behavior across devices, industries, and sites

### 3.1 Tile Categories (NSReady Tile Taxonomy)

NSReady tiles fall under 6 universal, reusable categories:

#### 1. KPI Tiles

**Purpose:** Show a summarized key performance indicator

**Examples:**

- Devices configured vs active
- Packet on-time percentage
- Collection health metrics

#### 2. Health Tiles

**Purpose:** Indicate device/site/collection status

**Examples:**

- Packet Health %
- Latency
- Missing packets
- Battery health
- Signal strength

#### 3. Alert Tiles

**Purpose:** Show triggered alarms or warning signals

**Rendering Mode:**

- Red (critical)
- Orange (warning)
- Blue (info)
- Green (normal)

#### 4. Trend Tiles

**Purpose:** Show simple sparkline or 24-hour mini-trend

**Examples:**

- 24-hour ingestion timeline
- 12-hour packet health sparkline
- 1-week collection health trend

#### 5. Asset Tiles

**Purpose:** Represent equipment or infrastructure visually

**Examples:**

- Device tile
- Registry entity tile
- Site tile

#### 6. AI Insight Tiles (Future)

**Purpose:** Show predictions, anomalies, explanations (NSWare Phase-2)

Should be included invisibly from now:

```html
<div id="ai-insights"></div>
```

**Examples:**

- AI anomaly risk score (future)
- AI forecast for tomorrow (future)
- Explainable factors (future)

### 3.2 Tile Rendering Philosophy (NSReady UI Principles)

Every tile must follow these universal rules:

**1. Every tile is tenant-safe**

- Tiles must never show cross-customer data
- API calls must include `customer_id`
- Drill-down must inherit session tenant context

**2. Every tile has a fixed height (compact layout)**

- `s`: 1 row
- `m`: 2 rows
- `l`: 3 rows
- `xl`: 4+ rows

**3. Tiles align on a 12-column grid**

- 12-column responsive grid
- Supports desktop, tablet, mobile

**4. Each tile uses 3 zones**

```
[ Header ] → Title, icon, timestamp
[ Body ]   → KPI or chart
[ Footer ] → Status, trend, or link
```

**5. AI Compatibility**

Every tile must have invisible AI hooks:

- `ai_risk`
- `ai_factor[]`
- `ai_confidence`

These values may be empty today but must exist in tile JSON (for future NSWare Phase-2).

### 3.3 NSReady Unified Tile Contract (Backend → Frontend JSON)

This is the most important part.

Every tile must follow this universal JSON structure, regardless of KPI, alert, trend, or AI.

**JSON Contract:**

```json
{
  "id": "tile_packet_health_001",
  "type": "kpi | health | alert | trend | asset | ai",
  "title": "Packet On-Time %",
  "icon": "signal",
  "source": {
    "customer_id": "UUID",
    "site_id": "UUID",
    "device_id": "UUID",
    "parameter_key": "project:<uuid>:packet_health"
  },
  "value": 96.5,
  "unit": "%",
  "status": "normal | warning | critical | inactive",
  "trend": {
    "sparkline": [95.2, 96.1, 96.5, 96.8, 96.5],
    "direction": "up | down | flat"
  },
  "ai": {
    "enabled": false,
    "risk": null,
    "confidence": null,
    "top_factors": []
  },
  "timestamp": "2025-11-14T12:00:00Z",
  "links": {
    "drilldown": "/device/<device_id>"
  }
}
```

### 3.4 Explanation of Tile Fields

**Mandatory Fields:**

| Field | Description |
|-------|-------------|
| `id` | Unique tile identifier |
| `type` | Tile category |
| `title` | Display title |
| `source.customer_id` | Tenant/customer boundary enforcement |
| `value` | Latest KPI or measurement |
| `timestamp` | Timestamp of latest value |

**Optional/Conditional Fields:**

| Field | Purpose |
|-------|---------|
| `unit` | Measurement unit |
| `trend` | Sparkline or mini-chart data |
| `status` | For health/alerts |
| `ai` | Future AI integration hooks (NSWare Phase-2) |
| `links.drilldown` | Routing link for deeper view |

### 3.5 KPI Tile Specification (Template A)

**Layout:**

```
[ KPI Icon + Name + Timestamp ]
[ Big Number ]
[ Sparkline (optional) ]
```

**JSON Example:**

```json
{
  "type": "kpi",
  "title": "Devices Configured",
  "value": 42,
  "unit": "devices",
  "trend": { "direction": "up" }
}
```

### 3.6 Health Tile Specification (Template B)

**Layout:**

```
[ Device / Site ] 
[ Status: Green / Orange / Red ]
[ Health % ]
```

**JSON Example:**

```json
{
  "type": "health",
  "title": "Packet Health",
  "value": 98.5,
  "unit": "%",
  "status": "normal"
}
```

### 3.7 Alert Tile Specification (Template C)

**Layout:**

```
[ Alert Type ]
[ Status Color ]
[ Description ]
```

**JSON Example:**

```json
{
  "type": "alert",
  "title": "Missing Packets",
  "status": "warning",
  "value": 120,
  "unit": "packets"
}
```

### 3.8 Trend Tile Specification (Template D)

**Layout:**

```
[ KPI + Icon ]
[ Full sparkline / mini chart ]
```

**JSON Example:**

```json
{
  "type": "trend",
  "title": "24h Ingestion Timeline",
  "trend": {
    "sparkline": [1250, 1248, 1255, 1242, 1251]
  }
}
```

### 3.9 Asset Tile Specification (Template E)

**Layout:**

Visual representation of equipment or registry entity.

**JSON Example:**

```json
{
  "type": "asset",
  "title": "Device 004",
  "status": "normal"
}
```

### 3.10 AI Insight Tile Specification (Template F)

**Layout (Future NSWare Phase-2):**

```
[ AI Score ]
[ Risk Level ]
[ Contributing Factors ]
```

**JSON Example:**

```json
{
  "type": "ai",
  "title": "Anomaly Risk",
  "ai": {
    "enabled": false,
    "risk": null,
    "confidence": null,
    "top_factors": []
  }
}
```

**Note:** AI tiles are placeholders for future NSWare Phase-2. Not used in NSReady v1 operational dashboards.

### 3.11 Tile Validation Rules

**Backend Rule Set:**

- All tiles must include `customer_id`
- Device/specific tiles must include `device_id`
- KPI and trend tiles must include `parameter_key` (if applicable)
- Status must follow ENUM rules
- Timestamp must be ISO UTC: `YYYY-MM-DDTHH:MM:SSZ`

**Frontend Rule Set:**

- Unknown tile types → gracefully render generic box
- Missing values → show "No data"
- Critical alerts → animate title for accessibility
- AI tiles → hide if `ai.enabled = false`

### 3.12 Future-Proofing Hooks

Already embedded into contract:

- `ai.enabled`
- `ai.risk`
- `ai.confidence`
- `ai.top_factors[]`
- Trend sparkline
- Drilldown link

These ensure:

- No rework when AI is added in NSWare Phase 2–3
- No redesign when predictive rules are introduced
- No code duplication

---

## 4. Dashboard View Engine & JSON Contract

(NSReady Backend-Powered Rendering Model)

In NSReady, dashboards are backend-defined views, not hard-coded pages.

The backend generates a Dashboard JSON, and the frontend simply renders it using the Universal Tile System (UTS).

This keeps:

- Frontend lightweight (rendering only)
- Backend in control of what data is shown
- Tenant isolation enforced at backend level
- Easy to add new dashboards without frontend changes

### 4.1 High-Level Concept

**Flow:**

```
1. User navigates to /operational/health/:customer_id
2. Frontend requests: GET /api/dashboard/:dashboard_id?customer_id=...
3. Backend:
   - Validates customer_id (tenant check)
   - Loads dashboard definition
   - Fetches data from SCADA views / registry / health endpoints
   - Builds Dashboard JSON with tiles
4. Frontend receives Dashboard JSON
5. Frontend renders using UTS (Part 3)
```

**Key Principle:**

Dashboard JSON is the single source of truth for what appears on the screen.

### 4.2 Canonical Dashboard JSON Structure

Every NSReady dashboard must follow this structure:

```json
{
  "dashboard_id": "collection_health_customer_v1",
  "title": "Collection Health",
  "scope": {
    "customer_id": "UUID",
    "site_id": null,
    "device_id": null
  },
  "layout": {
    "grid": 12,
    "max_rows": 8
  },
  "sections": [
    {
      "id": "summary_cards",
      "title": "Health Summary",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_devices_configured", "span": 3 },
            { "tile_id": "tile_packet_on_time_pct", "span": 3 },
            { "tile_id": "tile_missing_packets", "span": 3 },
            { "tile_id": "tile_late_packets", "span": 3 }
          ]
        }
      ]
    },
    {
      "id": "site_health",
      "title": "Site Health",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_site_health_table", "span": 12 }
          ]
        }
      ]
    }
  ],
  "tiles": [
    {
      "id": "tile_devices_configured",
      "type": "kpi",
      "title": "Devices Configured vs Active",
      "value": 42,
      "unit": "devices",
      "status": "normal",
      "source": {
        "customer_id": "UUID"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    }
  ],
  "metadata": {
    "version": "1.0",
    "time_range": "1h",
    "created_at": "2025-01-XXT12:00:00Z"
  }
}
```

### 4.3 Sections, Rows, Tiles — View Hierarchy

**Structure:**

```
Dashboard
 ├── Section 1
 │    └── Row 1
 │         └── Tiles [span: 3, span: 3, span: 3, span: 3]
 ├── Section 2
 │    └── Row 1
 │         └── Tiles [span: 12]
 └── Section 3
      └── Row 1
           └── Tiles [span: 6, span: 6]
```

**Rules:**

- Sections group related content
- Rows define horizontal layout
- Tiles define individual widgets
- `span` defines column width (1-12 on 12-column grid)

### 4.4 Tenant-Aware Dashboard Generation

**Critical Rule:**

Every dashboard must include `scope.customer_id`.

**Backend Generation Logic:**

```python
def generate_dashboard(dashboard_id, customer_id, site_id=None, device_id=None):
    # 1. Validate customer_id (tenant check)
    validate_tenant_access(customer_id)
    
    # 2. Build scope
    scope = {
        "customer_id": customer_id,
        "site_id": site_id,
        "device_id": device_id
    }
    
    # 3. Load dashboard definition
    dashboard_def = load_dashboard_definition(dashboard_id)
    
    # 4. For each tile, fetch data with scope
    tiles = []
    for tile_def in dashboard_def.tiles:
        tile_data = fetch_tile_data(tile_def, scope)
        tiles.append(tile_data)
    
    # 5. Return Dashboard JSON
    return {
        "dashboard_id": dashboard_id,
        "scope": scope,
        "sections": dashboard_def.sections,
        "tiles": tiles
    }
```

**Rules:**

1. `tenant_id` MUST equal `customer_id` in NSReady v1
2. Parent customer grouping is allowed via:
   - Backend querying `parent_customer_id` and children
   - Returning aggregated tiles
3. All tile data must be filtered by `customer_id`

### 4.5 Where Dashboard Definitions Live (Config vs Code)

**NSReady v1 Approach:**

Dashboard definitions can live in:

- **Config files** (JSON/YAML) for static dashboards
- **Database tables** (future) for dynamic dashboards
- **Code** (Python/backend) for computed dashboards

**Example Static Dashboard (Config File):**

```yaml
dashboard_id: collection_health_customer_v1
title: Collection Health
sections:
  - id: summary_cards
    title: Health Summary
    rows:
      - tiles:
          - tile_id: tile_devices_configured
            span: 3
```

**Example Computed Dashboard (Code):**

```python
def generate_system_health_dashboard():
    return {
        "dashboard_id": "system_health_v1",
        "sections": [
            {
                "id": "health_summary",
                "rows": [
                    {
                        "tiles": [
                            build_service_status_tile(),
                            build_queue_depth_tile(),
                            build_db_status_tile()
                        ]
                    }
                ]
            }
        ]
    }
```

### 4.6 Dynamic Dashboard vs Static Layouts

**Static Layouts:**

- Defined in config files
- Structure fixed
- Data values change, layout doesn't

**Example:** Registry Configuration Dashboard

**Dynamic Layouts:**

- Generated by backend logic
- Structure adapts to data
- Sections/rows added/removed based on conditions

**Example:** Collection Health Dashboard (shows only sites with devices)

**NSReady v1 Default:**

Start with static layouts. Dynamic layouts can be added later if needed.

### 4.7 Dashboard → API → View Binding Contract

**API Endpoint Pattern:**

```
GET /api/dashboard/:dashboard_id?customer_id=...&site_id=...&device_id=...
```

**Response:**

Dashboard JSON (as defined in Section 4.2)

**Frontend Responsibility:**

- Call API with correct scope
- Render Dashboard JSON using UTS
- Handle errors gracefully

**Backend Responsibility:**

- Validate tenant access
- Generate Dashboard JSON
- Include all tile data in response

### 4.8 Drilldown Flow & Back Navigation

**Drilldown Example:**

1. User on Collection Health Dashboard
2. Clicks on Site Health table row (Site 12)
3. Frontend navigates to: `/operational/health/:customer_id/:site_id`
4. Backend generates new Dashboard JSON for Site-level view
5. Frontend renders Site Health Dashboard

**Back Navigation:**

- Frontend maintains navigation stack
- "Back" button returns to previous dashboard
- Breadcrumb provides navigation path

### 4.9 Versioning Strategy for Dashboards

**Version Format:**

`dashboard_id` includes version: `collection_health_customer_v1`

**Rules:**

- Minor UI tweaks → version may stay same
- Changes in KPI logic → bump minor version (1.1.0)
- Changes in layout → bump minor or major depending on impact
- Breaking changes (tiles removed, structure changed) → bump major (2.0.0)

Backend & front-end MUST be aligned on version compatibility.

### 4.10 Summary of Backend-Powered View Engine Rules

1. Backend builds dashboards, frontend renders.
2. Unified Dashboard JSON structure must be followed.
3. Tiles must adhere to Universal Tile System (UTS).
4. Tenant context is always included in the dashboard scope.
5. Layout, sections, rows are defined by backend, not hard-coded in UI.
6. Data binding is explicit — no "magic queries" from the frontend.
7. AI can add fields to tile JSON without UI breaking (future NSWare Phase-2).
8. Group reports use `parent_customer_id` only — still per tenant boundary.

---

## 5. NSReady Operational Dashboards (Data Collection Health & Configuration)

This section defines the operational dashboards for NSReady v1 data collection software.

**These dashboards are NOT customer process dashboards** (no steam efficiency, water loss, etc.).

They are strictly for:

- Registry configuration (Customers → Projects → Sites → Devices → Parameters)
- Data collection health (packets on-time, missing, late)
- Ingestion diagnostics (logs, errors, trace IDs)
- SCADA export monitoring
- System-level health (collector, NATS, workers, DB)

They all reuse the same building blocks defined in:

- **Part 1–4** (theme, layout, navigation, tile system, dashboard JSON)
- **Backend master document** (ingestion, SCADA views, health APIs, tenant model)

**Cross-Reference:**

- **Backend Architecture:** `../NSREADY_BACKEND_MASTER.md`
- **Operational Dashboard Details:** `../NSware Basic work/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`

---

### 5.1 Goals of NSReady Operational Dashboards

The NSReady operational dashboards are designed to give engineers and (optionally) customers:

**1. Configuration Clarity**

- See how registry is structured:
  - Customers → Projects → Sites → Devices → Parameter Templates
- See which things are configured and which things are still missing.

**2. Collection Health Feedback**

- Check if packets are arriving correctly:
  - On time
  - Late
  - Missing
- Per customer, per site, per device.

**3. Operational Confidence**

- Confirm that:
  - Ingestion pipeline is working end-to-end
  - SCADA exports are being produced correctly
  - System is healthy (NATS, workers, DB, queue depth)

**4. Customer-Controlled but Engineer-Governed**

- Allow customers (optionally) to:
  - Add sites
  - Add devices
  - Bulk add via copy-paste table
- Keep CSV import/export as a rare, engineer-only action, locked behind a password/role.

---

### 5.2 Operational Dashboard Types (NSReady v1)

NSReady v1 defines **six operational dashboard types**, all using the common tile system and dashboard JSON:

1. **Main Operational Dashboard** (Per Customer)
   - Summary landing page for engineers.

2. **Registry Configuration Dashboard**
   - Tree + details + parameter templates + controlled CSV tools.

3. **Collection Health Dashboard**
   - Packet on-time %, missing/late, site/device health.

4. **Ingestion Log Dashboard**
   - Event timeline + error logs + trace IDs.

5. **SCADA Export Monitor Dashboard**
   - Latest `v_scada_latest` values + export history + mapping status.

6. **System Health Dashboard**
   - `/v1/health`, `/metrics`, queue depth, worker/DB status.

Each dashboard is rendered using:

- The Universal Tile System (Part 3)
- The Dashboard JSON structure (Part 4)
- The navigation & routing model (Part 2)

---

### 5.3 Main Operational Dashboard (Per Customer)

**Route:**

```
/customer/:customer_id/operational
```

**Purpose:**

Give engineers a one-page overview of NSReady status for a specific customer.

**Typical Layout (Sections & Tiles):**

- **Section: "Registry Summary"** (row of KPI tiles)
  - KPI tile: "Projects"
  - KPI tile: "Sites"
  - KPI tile: "Devices configured"
  - KPI tile: "Parameters defined"

- **Section: "Collection Health Summary"**
  - Health tile: "Packet On-Time % (last 24h)"
  - Alert tile: "Missing Packets (last 24h)"
  - Alert tile: "Late Packets (last 24h)"
  - Trend tile: "Collection Health (last 7 days)"

- **Section: "System Health Summary"**
  - Health tile: "Service status" (`/v1/health`)
  - KPI tile: "Queue depth"
  - Health tile: "DB status"
  - Alert tile: "Recent ingestion errors"

**Example Skeleton JSON (Simplified):**

```json
{
  "dashboard_id": "operational_main_customer_v1",
  "title": "Operational Overview",
  "scope": {
    "customer_id": "UUID"
  },
  "layout": { "grid": 12, "max_rows": 6 },
  "sections": [
    { "id": "registry_summary", "title": "Registry Summary", "rows": [ ... ] },
    { "id": "collection_health", "title": "Collection Health", "rows": [ ... ] },
    { "id": "system_health", "title": "System Health", "rows": [ ... ] }
  ],
  "tiles": [ ... ],
  "metadata": { "version": "1.0", "time_range": "24h" }
}
```

---

### 5.4 Registry Configuration Dashboard

**Route:**

```
/operational/registry/:customer_id
```

**Users:**

- **Engineer:** Full registry configuration (projects, sites, devices, templates)
- **Customer Admin (optional):** Can add sites/devices, limited fields only

**Purpose:**

- View and maintain:
  - Customer → Project → Site → Device tree
  - Parameter templates (read-only or engineer-edit only)
- Provide:
  - Single-record forms
  - Bulk copy-paste creation
  - Controlled CSV import/export (engineer-only, password-protected)

**Screen Layout (Wireframe Logic):**

- **Left Panel (Asset Tiles):**
  - Asset tile: Customer & project list
  - Asset tile: Site & device tree (hierarchy)

- **Right Top Panel (Forms):**
  - Asset or KPI tile: "Selected Entity Details" (form-style tile)
  - Shows fields for selected Project / Site / Device
  - Save & validate through API

- **Right Bottom Panel (Parameter Templates):**
  - Asset tile: "Parameter Templates"
  - Table of parameter templates for current project
  - Read-only for customers, editable for engineers (future NSWare phase if needed)

**Bulk Copy–Paste Pattern (Very Important):**

A special "Bulk Add" asset tile that shows a table:

- **Columns:** Site Name, Device Name, Device Code, Device Type, etc.
- **Actions:**
  - "Add 10 rows"
  - "Paste from Excel"
  - "Apply same Device Type to all rows"
  - "Preview & Validate"
  - "Submit"

Backend receives one JSON payload:

```json
{
  "customer_id": "UUID",
  "sites": [ ... ],
  "devices": [ ... ]
}
```

This lets customers add 50–100 sites or devices at once without repeated typing.

**CSV Tools (Engineer-Only, Locked):**

In the Registry Configuration dashboard, one tile (e.g., "CSV Tools") is:

- Visible only to Engineer role
- Has:
  - "Export registry as CSV"
  - "Import registry CSV (dry-run + preview)"
- Requires:
  - Extra unlock (password/2FA, or "Unlock CSV" button)

CSV is rarely used; UI + copy-paste table are the primary tools.

---

### 5.5 Collection Health Dashboard

**Routes:**

```
/operational/health/:customer_id
/operational/health/:customer_id/:site_id   (site-specific)
```

**Users:**

- **Engineer:** Full view
- **Customer Admin (optional):** Summary view only, no deep error logs

**Purpose:**

- Understand packet behaviour for each customer and site:
  - Are devices sending data?
  - Are packets on time?
  - Which sites or devices are noisy (missing/late)?

**Key Metrics (Per Customer/Per Site):**

- `devices_configured`
- `devices_seen_recently` (at least one packet in last window)
- `packet_on_time_pct`
- `missing_packets`
- `late_packets`
- `last_packet_time` per device

**Screen Layout:**

- **Section: "Health Summary"** (KPI/Health/Alert tiles)
  - KPI tile: "Devices configured vs active"
  - Health tile: "Packet On-Time % (last 24h)"
  - Alert tile: "Missing Packets (24h)"
  - Alert tile: "Late Packets (24h)"

- **Section: "Site Health Table"** (Trend/Asset tile)
  - A tile with a table:
  - Columns: Site, Devices, On-time %, Missing, Late, Last Packet Time, Status

- **Section: "Device Health Table"**
  - When a site is selected:
  - Device, Last Packet, Gaps, Missed %, Status

**JSON Example for One KPI Tile:**

```json
{
  "id": "tile_packet_on_time_pct",
  "type": "health",
  "title": "Packet On-Time %",
  "value": 96.5,
  "unit": "%",
  "status": "normal",
  "source": { "customer_id": "UUID" },
  "timestamp": "2025-01-XXT12:00:00Z"
}
```

---

### 5.6 Ingestion Log Dashboard

**Route:**

```
/operational/logs/:customer_id
```

**Users:** Engineer only

**Purpose:**

- Diagnose ingestion issues:
  - See what events arrived when
  - See errors and which devices/parameters they involve
  - Track problematic trace IDs

**Screen Layout:**

- **Filter Bar (Top):**
  - Time range
  - Site
  - Device
  - Parameter
  - Error type

- **Section: "Event Timeline"**
  - Trend tile: events per minute/hour
  - Optionally highlight error spikes

- **Section: "Error Log Table"**
  - Alert or asset tile styled as table:
  - Time, Device, Parameter key, Error type, Message, `trace_id`
  - Row click → opens detailed modal

**Modal Sample Behaviour:**

- Shows raw `NormalizedEvent` JSON that failed or produced error
- Shows mapped DB row in `ingest_events` (if any)
- Shows any SCADA/export impact flags (future)

---

### 5.7 SCADA Export Monitor Dashboard

**Route:**

```
/operational/scada/:customer_id
```

**Users:** Engineer only

**Purpose:**

- Verify SCADA exports are correct and on time:
  - Check latest values from `v_scada_latest`
  - Check export job success/failure
  - Check device/parameter mapping status

**Screen Layout:**

- **Section: "Latest SCADA Values"**
  - Asset tile / table:
  - Device Code, Device Name, Parameter, Value, Unit, Timestamp, Quality

- **Section: "Export History"**
  - Trend or asset tile:
  - Last N exports with:
  - Time, Status (Success/Failed), File name (if applicable)

- **Section: "SCADA Mapping Status"**
  - Asset tile summarizing:
  - % of devices with `device_code` mapped
  - % of parameters with SCADA tags
  - Any missing mappings

---

### 5.8 System Health Dashboard

**Route:**

```
/operational/system/health
```

**Users:** Engineer only

**Purpose:**

- Summarize NSReady infrastructure health using:
  - `/v1/health` (collector + queue + DB)
  - `/metrics` (ingest counters, errors, queue depth gauge)

**Key Tiles:**

- Health tile: "Service Status" (`service = ok/error`)
- KPI tile: "Queue Depth" (`queue_depth`)
- Health tile: "DB Status" (`db = connected/disconnected`)
- Alert tile: "Redelivered messages" (`redelivered`)
- KPI tile: "Events queued" (`ingest_events_total{status="queued"}`)
- KPI tile: "Events success" (`ingest_events_total{status="success"}`)
- Alert tile: "Ingestion errors" (`ingest_errors_total`)

**Status Colour Rules:**

- `queue_depth` 0–5 → Green
- `queue_depth` 6–20 → Yellow
- `queue_depth` >20 → Red
- `db = disconnected` → Red

**This aligns with:**
- Backend Master Section 6.2 (Queue Depth Thresholds)
- Backend Master Section 6.1 (`/v1/health` Contract)
- Backend Master Section 6.3 (`/metrics` Prometheus Contract)

---

### 5.9 Navigation Integration (Operational Section in Sidebar)

As per Part 2, operational dashboards live under an "Operational" section in the left sidebar.

**Routes:**

```
/customer/:customer_id/operational       → Main operational overview
/operational/registry/:customer_id       → Registry Configuration
/operational/health/:customer_id         → Collection Health
/operational/logs/:customer_id           → Ingestion Logs
/operational/scada/:customer_id          → SCADA Export Monitor
/operational/system/health               → System Health (global)
```

**Sidebar Behaviour:**

- "Operational" menu visible:
  - Only for Engineer (full menu)
  - For Customer Admin:
    - Only specific items if enabled (e.g., Health Summary, limited view)

**Breadcrumb Examples:**

```
Customer Group Textool > Operational > Collection Health
Customer Group Textool > Operational > Registry
```

---

### 5.10 Role & Tenant Rules (Applied to Operational Dashboards)

Operational dashboards follow the same tenant rules as user dashboards:

- Always filter by `customer_id`
- Group dashboards use `parent_customer_id` only for aggregation
- Never mix data from two customers in one view

**Role Access Summary (Operational Dashboards):**

| Dashboard | Engineer | Customer Admin (optional) | Site Operator | Group Admin | Read-Only |
|-----------|----------|---------------------------|---------------|-------------|-----------|
| Main Operational | ✔ | ✖ or limited | ✖ | ✖ | ✖ |
| Registry Configuration | ✔ | ✖ (or restricted site/device add) | ✖ | ✖ | ✖ |
| Collection Health | ✔ | Optional summary view | ✖ | ✖ | ✖ |
| Ingestion Logs | ✔ | ✖ | ✖ | ✖ | ✖ |
| SCADA Export Monitor | ✔ | ✖ | ✖ | ✖ | ✖ |
| System Health | ✔ | ✖ | ✖ | ✖ | ✖ |

**Customer-Specific Configuration Permissions (As You Requested):**

- Engineer can enable "Customer can add sites/devices" toggle.
- When enabled:
  - Customer Admin sees:
    - "Add Site" / "Add Device" actions in Registry UI
    - Bulk copy-paste entry (but not CSV tools)
  - They cannot:
    - Change customers or projects
    - Change parameter templates
    - Touch ingestion/SCADA/system health dashboards

CSV remains engineer-only, locked behind extra steps.

---

### 5.11 Summary of Part 5 (NSReady Operational UI Layer)

Part 5 defines the NSReady v1 operational dashboard set, fully aligned with:

- Backend ingestion & SCADA
- Tenant model (`tenant_id = customer_id`)
- Data collection-only scope

**It Provides:**

- A main operational overview per customer
- Registry configuration UI (with single-record + bulk tools)
- Collection health views (packets on time, missing, late)
- Ingestion logs (events + errors + trace IDs)
- SCADA export monitor
- System health monitor

**And Respects:**

- Frontend = data entry + viewing only
- All logic, validation, and health computation in backend
- CSV = rare, engineer-only emergency/configuration tool
- Tenant isolation = enforced at every dashboard
- Future AI = hooks present but disabled for NSReady v1

This sets a clean base so that later, NSWare process dashboards (steam, water, power KPIs, AI) can sit on top without breaking or rewriting NSReady.

---

---

## 6. Tenant Isolation & Access Control (NSReady v1 UI/UX Layer)

**Scope:** NSReady v1 Data Collection Software

**Purpose:** Define how the NSReady dashboards enforce customer-safe access, engineer-privileged visibility, and optional customer-side configuration — without modifying backend architecture.

---

### 6.1 Purpose of Tenant Isolation Rules in NSReady

NSReady v1 is a multi-customer data collection platform.

The UI/UX layer must guarantee:

**A. Customer Isolation**

A customer can only see:

- Their own sites
- Their own devices
- Their own packet health
- Their own SCADA export values

**B. Engineer Master Visibility**

Engineers (internal team) can see:

- All customers
- All operational dashboards
- SCADA integration details
- Registry configuration
- Ingestion logs
- System health

**C. Controlled Customer-Side Configuration**

Customers may be allowed to:

- Add their own Sites
- Add their own Devices
- Modify device metadata

Only if this feature is enabled by the engineer.

**D. Group-Level Viewing (parent_customer_id)**

OEMs with multiple companies can see:

- Group dashboard
- Aggregated child-company metrics

But cannot:

- Modify child configurations
- Access child ingest logs
- Access system health

**This aligns with:**
- Backend Master Section 9.1 (Tenant = Customer)
- Backend Master Section 9.2 (Parent Customer = Grouping Only)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)

---

### 6.2 Core Tenant Boundary Rule (UI/UX Layer)

The entire NSReady UI is based on the simple and strict rule:

```
tenant_id = customer_id
```

**Meaning:**

- A tenant is a customer
- All dashboards filter by `customer_id`
- Parent customers are only for aggregation, not for data access boundary
- Child companies remain strict tenants

**Example — Allidhra Group Model:**

```
Allidhra Group (parent_customer_id = NULL)
 ├── Allidhra Textool (tenant)
 ├── Allidhra Texpin  (tenant)
 └── Allidhra Tech    (tenant)
```

- Allidhra Group gets group dashboard (aggregated)
- Each company gets its own dashboard
- No child company can see sibling data
- No child company can modify parent-level configurations

**This aligns with:**
- Backend Master Section 9.1 (Tenant = Customer)
- Backend Master Section 9.5 (Dashboard Routing & Access Control Rules)

---

### 6.3 NSReady Role Types (UI Access Limits)

The UI supports **6 roles**, each with different privileges.

| Role | Purpose | Access |
|------|---------|--------|
| **Engineer (Internal)** | NSReady deployment engineer | Full access to all operational dashboards, configuration, logs, SCADA integration |
| **Tenant Admin** | Parent group admin (OEM/utility) | Access aggregated dashboards for child companies (read-only) |
| **Customer Admin** | Manager of a specific customer company | Customer dashboard + site creation + device creation |
| **Site Operator** | Operator/maintenance team | Only site-level and device-level dashboards |
| **Device Engineer** | Technical user | Device-level dashboards + packet health |
| **Read-Only** | Viewer only | View dashboards, no configuration |

---

### 6.4 Role–Feature Matrix (NSReady v1)

#### Customer-Facing Dashboards

| Feature | Engineer | Customer Admin | Site Operator | Group Admin | Read-Only |
|---------|----------|----------------|---------------|-------------|-----------|
| Customer Dashboard | ✔ | ✔ | Limited | ✔ | ✔ |
| Site Dashboard | ✔ | ✔ | ✔ | ✖ | ✔ |
| Device Dashboard | ✔ | ✔ | ✔ | ✖ | ✔ |
| Packet Health | ✔ | ✔ | ✔ | ✖ | ✔ |
| Alert Viewing | ✔ | ✔ | ✔ | ✖ | ✔ |

#### Operational Dashboards (Engineer Only)

**These are never visible to customers unless explicitly allowed.**

| Operational Dashboard | Engineer | Customer Admin | Site Operator | Group Admin | Read-Only |
|----------------------|----------|----------------|---------------|-------------|-----------|
| Registry Configuration | ✔ | ✖ | ✖ | ✖ | ✖ |
| Collection Health (Full) | ✔ | Limited (optional) | ✖ | ✖ | ✖ |
| Ingestion Logs | ✔ | ✖ | ✖ | ✖ | ✖ |
| SCADA Export Monitor | ✔ | ✖ | ✖ | ✖ | ✖ |
| System Health | ✔ | ✖ | ✖ | ✖ | ✖ |

---

### 6.5 Customer-Enabled Configuration (Optional)

You clearly instructed:

**"Customers may add multiple sites and devices; common parameters remain same."**

Therefore NSReady supports **role-switchable, customer-side configuration**:

Engineers can toggle ON/OFF the following:

- Allow Customer Admin to Add Site
- Allow Customer Admin to Add Device
- Allow Customer Admin to Edit device metadata

**What Customers Can Modify (When Enabled):**

- Site name
- Device name
- Device code
- Device metadata fields

**What Customers Cannot Modify:**

- Customer-level information
- Project definitions
- Parameter templates
- SCADA export mappings
- Ingestion system settings
- Health thresholds
- Any form of backend configuration

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard - Customer Admin optional access)
- Part 5 Section 5.10 (Customer-Specific Configuration Permissions)

---

### 6.6 Temporary Access for Customer Health Checks

Your requirement:

**"Temporary access to health check is required to give customers."**

This is implemented as:

**Temporary Access Token (Engineer-Managed)**

**Format:**

```
/operational/health/:customer_id?token=<TEMP_TOKEN>
```

**Properties:**

- Valid for 4–48 hours
- Token only enables:
  - Collection health summary
  - Site/device health table
- Token does NOT allow:
  - Logs
  - SCADA export views
  - System health
  - Registry modifications

Engineers can:

- Generate token
- Remove token
- Limit token scope
- Set token validity

**This aligns with:**
- Part 5 Section 5.5 (Collection Health Dashboard - Customer Admin optional summary view)

---

### 6.7 UI Enforcement Rules (Zero Leakage Guarantee)

For every UI request, NSReady enforces:

**Rule 1: Tenant Context Must Match**

```
if auth.customer_id != route.customer_id → BLOCK
```

**Rule 2: Operational Dashboards Require Engineer**

```
if route.operational == true AND role != 'engineer' → BLOCK
```

**Rule 3: Site/Device Must Belong to Customer**

```
if site.customer_id != auth.customer_id → BLOCK
```

**Rule 4: Drilldowns Must Inherit Tenant Context**

All drilldowns must include:

- `customer_id`
- `site_id`
- `device_id`

**Rule 5: Group Dashboards Are Aggregation Only**

Group admin sees:

- Sum / average / aggregated KPIs

But cannot:

- Access ingestion logs
- Access SCADA mapping
- Modify registry

**This aligns with:**
- Part 2 Section 2.10 (Tenant & Customer Context - Critical Rule)
- Part 4 Section 4.4 (Tenant-Aware Dashboard Generation)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)

---

### 6.8 NSReady Scope Propagation (Critical)

Every Dashboard JSON returned from backend must include:

```json
"scope": {
  "customer_id": "<UUID>",
  "site_id": "<UUID or null>",
  "device_id": "<UUID or null>"
}
```

**UI Responsibilities:**

- Always include `customer_id` in API calls
- Never display tiles with mismatched `customer_id`
- If routing mismatch — redirect to login or root

**Backend Responsibilities:**

- Validate tenant context
- Return filtered, safe data
- Never mix customers in SCADA views or health metrics

**This aligns with:**
- Part 4 Section 4.2 (Canonical Dashboard JSON Structure - scope field)
- Part 4 Section 4.4 (Tenant-Aware Dashboard Generation)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)

---

### 6.9 Bulk Configuration Rights (Copy/Paste Tables)

As per your requirement:

**"Customer wants to include 100 sites… all parameters same except tag/name."**

NSReady UI supports:

**Bulk Add Table**

- Customer can paste Excel rows
- Default values auto-fill
- Only name/tag/site fields editable
- Backend validates all entries
- Errors shown inline

**Bulk Edit Table**

- Change one column across 100 rows
- Update device types
- Update metadata
- Mass enable/disable

**CSV Option (Engineer Only)**

- Locked behind password
- For heavy bulk operations
- Only Engineers can upload or download CSV

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard - Bulk Copy-Paste Pattern)
- Part 5 Section 5.4 (CSV Tools - Engineer-Only, Locked)

---

### 6.10 NSReady-Safe Permissions Summary

**Who can configure?**

- ✔ Engineer
- ✔ Customer Admin (restricted, toggle-based)
- ✖ Others

**Who can see operational dashboards?**

- ✔ Engineer
- ✖ Customers (except limited health summary via token)

**Who can see SCADA export?**

- ✔ Engineer only

**Who can view ingestion logs?**

- ✔ Engineer only

**Who can view system health?**

- ✔ Engineer only

**Who can use bulk configuration?**

- ✔ Engineer
- ✔ Customer Admin (copy/paste only)
- ✖ Others

**Who can use CSV?**

- ✔ Engineer only

---

### 6.11 Summary of Part 6 — NSReady Tenant & Role Model

This part ensures NSReady's UI/UX remains:

**SAFE**

- Strict customer isolation
- Zero leakage between tenants

**CONTROLLED**

- Engineers have full control
- Customers get only controlled access

**SIMPLE**

- Tenant = `customer_id` (backend-native)
- `parent_customer_id` only used for group dashboards

**EFFICIENT**

- Bulk addition for customers
- CSV for engineers

**FUTURE-PROOF**

- NSReady safe today
- Compatible with NSWare dashboards later

---

---

## 7. UX Mockup & Component Layout System (NSReady v1 UI Design Framework)

**Scope:** NSReady v1 – Data Collection Software

**Purpose:** Define the visual layout, UI skeleton, interaction patterns, forms, tables, and operational screens for registry configuration, communication health, SCADA export, and system diagnostics.

This part defines **HOW NSReady looks and behaves** — independent of styling (colors, fonts) already defined in Part 5.

---

### 7.1 Global Layout Shell (The Universal Page Frame)

Every NSReady screen follows the same architectural shell:

```
+---------------------------------------------------------------+
| Top Bar                                                       |
| [Product Name] [Tenant/Customer Selector] [Time Range] [User] |
+-----------------------+----------------------------------------+
| Left Sidebar          | Main Content Area                      |
| (Navigation Tree)     | Sections → Rows → Tiles/Forms/Tables   |
+-----------------------+----------------------------------------+
```

---

#### 7.1.1 Top Bar (Static Across All Screens)

**Contents:**

- Product name / logo (neutral)
- Tenant/Customer selector (visible to Engineers, Group Admin)
- **Time range selector**
  - Last 1h, 24h, 7d
  - Custom ranges
- **User menu**
  - Profile
  - Role
  - Logout

**Behavior:**

- Time range applies to current dashboard context
- Always visible

---

#### 7.1.2 Left Sidebar (Role-Aware Navigation)

Always present, collapsible on tablet/mobile.

**Sections:**

**A. Main (For All Roles)**

- Customer Dashboard
- Sites
- Devices
- Alerts

**B. Operational (Engineer Only)**

- Registry Configuration
- Collection Health
- Ingestion Logs
- SCADA Export Monitor
- System Health

**C. Settings**

- User roles (future)
- Feature toggles (future)

**This aligns with:**
- Part 2 Section 2.3 (Navigation Components)
- Part 5 Section 5.9 (Navigation Integration)

---

#### 7.1.3 Main Content Area

Always structured as:

```
Section
  Row
    Tile / Form / Table
```

**Examples:**

- Section: "Collection Health Summary"
  - Row: 4 KPI tiles
- Section: "Site Health Table"
- Section: "Ingestion Timeline Chart"

**This aligns with:**
- Part 4 Section 4.3 (Sections, Rows, Tiles — View Hierarchy)

---

### 7.2 NSReady Operational Screen Wireframes (Exact UI Layout)

These are the **5 operational dashboards** NSReady v1 must provide.

They use same tile system and dashboard JSON, but content is specific to data collection software.

---

#### 7.2.1 Operational Home (Engineer Landing Page)

**Route:** `/operational/:customer_id/home`

**Purpose:**

A quick diagnostic summary for Engineers.

**Wireframe:**

```
[ Section: Operational Summary ]
  [ KPI: Devices Configured ]   [ KPI: On-Time Packets % ]
  [ Alert: Missing Packets ]    [ Alert: Late Packets ]

[ Section: Site Health ]
  [ Table: Site Name | On-Time % | Missing | Last Packet | Status ]

[ Section: System Health ]
  [ Health: Service ] [ KPI: Queue Depth ] [ Health: DB Status ]
```

**Data Source:**

- `/v1/health`
- Rollup views
- Registry tables

**This aligns with:**
- Part 5 Section 5.3 (Main Operational Dashboard)
- Backend Master Section 6.1 (`/v1/health` Contract)

---

#### 7.2.2 Registry Configuration Screen

**Route:** `/operational/registry/:customer_id`

**Users:** Engineer, Customer Admin (restricted)

**Purpose:**

Configure the data collection hierarchy:

- Customer → Project → Site → Device
- Parameter key mappings
- Device metadata
- Bulk operations

**Wireframe:**

```
+-----------------------------+-----------------------------------+
| Hierarchy Tree              | Entity Detail Panel               |
| - Customer                  | [Dynamic form:                    |
|   - Project A               |   Device/Site fields ]            |
|     - Site 1                |                                   |
|       - Device 001          | Parameter Templates               |
|       - Device 002          | [Table: parameter_name, unit...]  |
|     - Site 2                |                                   |
+-----------------------------+-----------------------------------+
| Bulk Add Panel (Optional)                                       |
| - Paste Excel table / Add rows / Preview / Submit               |
+-----------------------------------------------------------------+
| CSV Tools (Engineer Only - Password Locked)                     |
| - Download registry CSV                                         |
| - Upload registry CSV                                           |
+-----------------------------------------------------------------+
```

**Key Interactions:**

- Tree-driven navigation
- Selecting a node loads details on the right
- Customer Admin:
  - Cannot modify projects
  - Can add Sites (if allowed)
  - Can add Devices (if allowed)

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard)
- Part 6 Section 6.5 (Customer-Enabled Configuration)

---

#### 7.2.3 Collection Health Dashboard

**Route:** `/operational/health/:customer_id`

**Purpose:**

Monitor if packets are coming on time, and identify missing/late/idle devices.

**Wireframe:**

```
[ Section: Summary ]
  [ KPI: Devices Configured ] [ KPI: Devices Active ]
  [ Health: On-Time % ]       [ Alert: Missing / Late ]

[ Section: Site Health ]
  [ Table: 
     Site | Devices | On-Time % | Missing | Late | Last Packet | Status ]

[ Section: Device Health (optional site-filtered) ]
  [ Table:
     Device | Last Packet | Gap (min) | Missing | Status ]
```

**Temp Customer Access Token View:**

Same screen but only Summary + Read-only tables.

**This aligns with:**
- Part 5 Section 5.5 (Collection Health Dashboard)
- Part 6 Section 6.6 (Temporary Access for Customer Health Checks)

---

#### 7.2.4 Ingestion Logs Screen (Engineer Only)

**Route:** `/operational/logs/:customer_id`

**Purpose:**

Debug ingestion issues using full timeline and structured logs.

**Wireframe:**

```
[ Filters: time_range, site, device, parameter, error_type ]

[ Event Timeline Chart ]  ← sparkline with markers for errors

[ Error Log Table ]
  Time | Device | Site | Error Type | Message | Trace ID
  (Click row → Modal)
```

**Modal: Detailed Event View**

- Full `NormalizedEvent` JSON
- DB row (`ingest_events`)
- Trace chain (future AI-ready)

**This aligns with:**
- Part 5 Section 5.6 (Ingestion Log Dashboard)
- Backend Master Section 5.3 (NormalizedEvent Contract)

---

#### 7.2.5 SCADA Export Monitor (Engineer Only)

**Route:** `/operational/scada/:customer_id`

**Wireframe:**

```
[ Latest SCADA Values ]
  v_scada_latest → Table: Device | Parameter | Value | Timestamp | Quality

[ Export History ]
  Last N Export Runs:
    Time | Duration | Status | File Name | Link (if applicable)

[ SCADA Mapping Summary ]
  Device → device_code mapping
  Parameter → parameter_key mapping
```

**This aligns with:**
- Part 5 Section 5.7 (SCADA Export Monitor Dashboard)
- Backend Master Section 8.2.1 (`v_scada_latest` View)

---

#### 7.2.6 System Health Dashboard (Engineer Only)

**Route:** `/operational/system/health`

**Wireframe:**

```
[ Section: Real-Time Health ]
  [ Health: Service Status ]
  [ KPI: Queue Depth ]
  [ Health: DB Status ]
  [ Alert: Redelivered Messages ]

[ Section: Metrics Snapshot ]
  [ KPI: Events Queued ]
  [ KPI: Events Success ]
  [ Alert: Ingestion Errors ]
  [ Health: Queue Depth Gauge ]

[ Section: JSON View ]
  Raw /v1/health JSON (collapsible)
```

**This aligns with:**
- Part 5 Section 5.8 (System Health Dashboard)
- Backend Master Section 6.1 (`/v1/health` Contract)
- Backend Master Section 6.3 (`/metrics` Prometheus Contract)

---

### 7.3 Customer-Facing Dashboards (NSReady v1)

These are the simplified dashboards customers can see:

#### 7.3.1 Customer Dashboard

- Device count
- Last packet time
- Missing packets
- Packet health summary

#### 7.3.2 Site Dashboard

- Site-level packet health
- Device list
- Health summary

#### 7.3.3 Device Dashboard

- Last packet
- Status
- Mini 24h trend
- Device metadata

**This aligns with:**
- Part 6 Section 6.4 (Role–Feature Matrix - Customer-Facing Dashboards)

---

### 7.4 Data Entry Interfaces (Critical for NSReady)

NSReady UI is a **data entry + health monitoring tool**, not a hard-coded KPI system.

This section defines all the front-end patterns.

---

#### 7.4.1 Single Item Add/Edit Form

**For Site/Device:**

- Auto-populated common fields
- Only differences edited (name, tag, device code)
- Inline validation
- Save & Continue

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard - Forms)

---

#### 7.4.2 Bulk Add (Copy–Paste Grid)

**Your Requirement:**

**"Customer wants to add 100 sites… only name/tag changes. Common parameters are same."**

**UI Behavior:**

- Paste Excel → instantly converts to table
- All rows editable
- "Duplicate row" button
- "Edit one column across all rows"
- Preview before submitting

**Backend Receives:**

```json
{
  "customer_id": "...",
  "sites": [...],
  "devices": [...]
}
```

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard - Bulk Copy-Paste Pattern)
- Part 6 Section 6.9 (Bulk Configuration Rights)

---

#### 7.4.3 CSV Upload/Download (Engineer Only)

**Must be:**

- Password protected
- Hidden under "Advanced Tools"
- ONLY for large migrations

**This aligns with:**
- Part 5 Section 5.4 (CSV Tools - Engineer-Only, Locked)
- Part 6 Section 6.10 (NSReady-Safe Permissions Summary)

---

### 7.5 Validation & Error Reporting UX

**Inline Field Validation**

- Required fields
- Wrong UUID formats
- Duplicate device codes
- Invalid characters

**Global Notification Bar**

- Success: "10 devices added successfully"
- Error: "3 rows contain invalid values"

**Error → Jump to Health**

- "View in Collection Health"
- "View in Ingestion Logs"

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard - Validation)

---

### 7.6 Responsive Behavior (Web + Tablet + Optional Mobile)

**Desktop**

- Full grid
- Navigation sidebar
- Operational dashboards fully visible

**Tablet**

- Sidebar collapsible
- Grids stack
- Tables scroll horizontally

**Mobile (Optional Minimal Version)**

- Home
- Alerts
- Site-level summary
- Device-level summary

**Operational dashboards can remain desktop-first.**

**This aligns with:**
- Part 1 Section 5 (Theme System - Layout: 12-column grid, responsive web + mobile)

---

### 7.7 Summary of Part 7

Part 7 delivers a complete UX framework for NSReady v1:

**Dashboard Structure**

- Unified global layout shell
- Standard navigation
- Breadcrumbs
- Device/site drilldown

**Screen Definitions**

- Registry Configuration
- Collection Health
- Ingestion Logs
- SCADA Export Monitor
- System Health

**Data Entry**

- Single forms
- Bulk copy/paste
- Controlled CSV

**UI/UX Principles**

- Tenant safety
- Role-based visibility
- API-driven rendering
- Clear validation
- Consistent layout

**Future-Proof Hooks**

- AI placeholders present but inactive
- Same tile system usable in NSWare Phase-2

---

---

## 8. Performance & Caching Model (NSReady v1 Dashboard Layer)

**Purpose:**

To define how the NSReady operational dashboards should fetch, cache, refresh, and render backend data without overloading:

- The data collection pipeline
- The SCADA export system
- The database
- Or the user's browser

This part ensures fast dashboards, low backend load, per-customer isolation, and predictable refresh behaviour across all NSReady UI screens.

**Scope:**

This section applies **ONLY to NSReady v1**:

- Registry configuration dashboard
- Collection health dashboard
- Ingestion logs
- SCADA export monitor
- System health dashboard
- Device/Site live health tiles
- Customer-level operational views

It does **NOT cover** NSWare process KPIs, AI/ML scoring, or future feature-store heavy workloads.

Minimal NSWare placeholders are included **ONLY where forward compatibility is mandatory**.

**Cross-Reference:**

- **Backend Master Section 7.9:** Time-Series Modeling Strategy (Rollups over Raw)
- **Backend Master Section 7.10:** Database Golden Rules (Never query ingest_events directly for large time ranges)
- **Backend Master Section 6.2:** Queue Depth Thresholds

---

### 8.1 Core Performance Principles (NSReady v1)

The NSReady dashboard layer follows **six strict performance principles**:

**1. Use Lightweight Endpoints, Never Direct DB Queries**

All dashboard data must be retrieved through controlled backend APIs:

```
/api/dashboard/:dashboard_id
/api/operational/...
/api/scada/...
/v1/health
/metrics
```

Dashboards never hit the database directly.

Dashboards never use raw SQL.

Dashboards never use WebSocket streaming in v1.

**2. Use Pre-Aggregated SCADA & Ingestion Views Whenever Possible**

Prefer:

- `v_scada_latest` → latest values
- `v_scada_history` → historical SCADA time-series
- `operational_site_health` → per-site aggregation
- `operational_device_health` → per-device aggregation
- `ingest_events_count_windowed` → ingestion summary

Avoid direct reads of `ingest_events` except:

- For ingestion logs
- With strict time filters
- Via structured API endpoints

**3. Every Request Must Be Tenant-Scoped**

All queries include:

```
customer_id
project_id (optional)
site_id (optional)
device_id (optional)
```

Prevents cross-tenant load.

Prevents high-cardinality "global" queries.

**4. Dashboards Must Be Inexpensive to Refresh**

Most dashboards must be safe to refresh every 10–30 seconds without causing database strain.

**5. Default Time Windows Must Be Constrained**

To prevent large result sets:

| Dashboard Type | Default Time Range |
|----------------|-------------------|
| System Health | last 10–30 seconds |
| Collection Health | last 1 hour |
| Ingestion Logs | last 1–24 hours |
| SCADA Export | last 1 export cycle |

Longer ranges must require user selection.

**6. Large Datasets Must Use Rollups**

No dashboard should return > 2000 data points per tile.

If the query output is too large:

- Backend down-samples
- Backend returns error with recommended narrower time range

**This aligns with:**
- Backend Master Section 7.9 (Time-Series Modeling Strategy - Rollups over Raw)
- Backend Master Section 7.10 (Database Golden Rules - Never query ingest_events directly for large time ranges)

---

### 8.2 Dashboard Refresh Model

Each NSReady dashboard type has a recommended refresh cadence based on its function.

| Dashboard | Frequency | Why |
|-----------|-----------|-----|
| System Health | 5–10 sec | Live workers, queue depth, DB connectivity |
| Collection Health | 10–20 sec | Packet on-time %, missing/late windows |
| Site/Device Health List | 20–30 sec | Device heartbeat isn't sub-second |
| Ingestion Logs | Manual or 30–60 sec | Debug view, not real-time |
| SCADA Export Monitor | 30–60 sec | Exports typically run every 10–60 sec |
| Registry Config | Manual | Static registry (no polling) |

**Rule:**

No NSReady dashboard may refresh faster than every 5 seconds.

**Reason:**

Protection against:

- NATS saturation
- Worker backlog
- DB pressure
- Browser memory buildup

**This aligns with:**
- Backend Master Section 6.2 (Queue Depth Thresholds)
- Part 5 Section 5.8 (System Health Dashboard)

---

### 8.3 API Call Patterns & Backend Load Strategy

#### 8.3.1 Primary Rule

**One API call per dashboard = 1 Dashboard JSON**

All dashboards must be served using:

```
GET /api/dashboard/:dashboard_id?customer_id=...&scope...
```

Backend returns:

```
sections[]
tiles[]
metadata{}
```

#### 8.3.2 Supplemental API Calls Allowed

Only when required:

- `/api/ingestion/logs?time_range=...`
- `/api/scada/latest?customer_id=...`
- `/api/health?customer_id=...`
- `/api/registry/...`

**Prohibited:**

Calling 20–100 APIs per dashboard (N+1 patterns).

#### 8.3.3 All API Calls Must Be Tenant-Scoped

Every endpoint must internally inject:

```
WHERE customer_id = <tenant>
```

Backend must hard-enforce this.

Frontend may not override it.

**This aligns with:**
- Part 4 Section 4.7 (Dashboard → API → View Binding Contract)
- Part 6 Section 6.7 (UI Enforcement Rules - Tenant Context Must Match)

---

### 8.4 Data Source Priority (NSReady v1)

Different tile types require different data sources.

This table standardizes which backend source each tile must use.

| Tile Type | Preferred Data Source | Why |
|-----------|----------------------|-----|
| KPI Tile | Pre-aggregated view (cached) | Good for "Configured vs Active", overall % |
| Health Tile | Health endpoints (`/v1/health`, `operational_xxx`) | Real-time connectivity info |
| Alert Tile | Alert lists from ingestion/health APIs | Missing/late events, failures |
| Trend Tile | Rollup views (`scada`, `ingest_events_count_windowed`) | Avoid raw data volume |
| Asset Tile | Registry (sites, devices, projects) | Static metadata |
| Distribution Tile | Backend aggregated stats | No heavy client-side maths |
| AI Tile | Disabled in NSReady v1 | Placeholder only |

#### 8.4.1 When Raw Data (ingest_events) MAY Be Used

**ONLY** via ingestion log endpoint, and **ONLY** with:

- Strict time window
- Pagination
- Ordering limits

**Examples:**

```
/api/ingestion/logs?customer_id=...&time_range=1h&limit=500
```

#### 8.4.2 When Raw Data MAY NOT Be Used

- Live dashboards
- Trend tiles
- Collection health summary
- SCADA health monitoring
- Registry screens

**This aligns with:**
- Part 3 Section 3.5-3.10 (Tile Specifications)
- Backend Master Section 7.9 (Time-Series Modeling Strategy)

---

### 8.5 Response Size Limits (Strict NSReady v1 Rule)

These protect the backend from accidental overload.

| Item | Hard Limit |
|------|-----------|
| Max tile points | 2000 |
| Max event logs fetched | 500 per request |
| Max device list | 500 devices per screen |
| Max site list | 200 sites |
| Max SCADA rows | 500 per view |
| Max dashboard tiles per page | 50 |

Backend must enforce these limits automatically.

**This aligns with:**
- Backend Master Section 7.10 (Database Golden Rules - Performance constraints)

---

### 8.6 Caching Model (Backend & Frontend)

#### 8.6.1 Backend Cache Layers

Backend may use:

- In-memory dashboard cache (per tenant)
- Redis or in-process TTL cache
- JSON snapshot caching
- SCADA view caching for 1–5 seconds

**Cache Key:**

```
dashboard:<customer_id>:<dashboard_id>:<scope_hash>
```

#### 8.6.2 Backend Cache Duration

Recommended durations:

| Dashboard | Duration |
|-----------|----------|
| System Health | 1–2 sec |
| Collection Health | 2–5 sec |
| Ingestion Logs | 5–10 sec |
| SCADA Export | 10–30 sec |
| Registry | 60–300 sec |

#### 8.6.3 Frontend Cache (Browser)

Frontend should use "stale-while-revalidate" for:

- Dashboard JSON
- Tile content
- SCADA view
- Health API
- Device/site/registry lists

#### 8.6.4 Degraded Mode

If backend is slow or returns 500:

- Show cached values
- Show timestamp of cache
- Show banner "Data delayed"
- DO NOT blank the dashboard

**This aligns with:**
- Part 4 Section 4.4 (Tenant-Aware Dashboard Generation)
- Part 6 Section 6.8 (NSReady Scope Propagation)

---

### 8.7 Tenant-Aware Performance Safety (Very Important)

Tenant isolation applies to performance too.

**Rules:**

**1. No Cross-Tenant Caching**

Every tenant's cache must be isolated.

**2. Large Tenants Must Not Slow Small Tenants**

Heavy dashboards for one customer must never affect others.

**3. Per-Tenant Rate Limiting**

Examples:

- Max 5 dashboard refreshes per second per tenant
- Max 10 ingestion log queries per minute

**4. Parent Group Dashboards Always Run Aggregated Queries**

But each child customer query is still scoped independently.

**This aligns with:**
- Part 6 Section 6.7 (UI Enforcement Rules - Zero Leakage Guarantee)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)

---

### 8.8 Browser Performance Constraints

Rules for frontend rendering:

1. **Max DOM nodes per dashboard:** 1500
2. **Max visible tiles at once:** 20–30
3. **Charts cleaned on unmount**
4. **Memory budget:** < 200 MB
5. **Mobile simplified render path**

**This aligns with:**
- Part 7 Section 7.6 (Responsive Behavior)

---

### 8.9 Graceful Degradation Rules

Dashboards must remain stable when:

**1. `/v1/health` is Slow**

- Show "System health delayed"
- Avoid spinner lock
- Use cached data

**2. NATS Queue Depth Spikes**

- Mark health tile as yellow or red
- Reduce refresh frequency temporarily
- Show "System under load" warning

**3. SCADA Export Fails**

- Use last successful export timestamp
- Display red alert tile with reason
- Provide retry button (engineer only)

**4. Database High Load**

Backend should:

- Deny large queries
- Return error with "Use smaller time range"
- Fallback to rollups

**This aligns with:**
- Backend Master Section 6.2 (Queue Depth Thresholds - 0-5/6-20/>20)
- Part 5 Section 5.8 (System Health Dashboard - Queue depth status)

---

### 8.10 Future NSWare Phase-2 Alignment (Minimal Placeholders)

Part 8 is NSReady-focused. NSWare future references are strictly limited:

**Placeholders Only:**

- AI tiles follow same caching rules as KPI/Health tiles
- KPI/alert engine will use same dashboard JSON pattern
- Feature store tiles will reuse same per-tenant cache boundaries

**Zero NSWare complexity is added here.**

**This aligns with:**
- Part 1 Section 3.5 (AI-Ready from Day Zero - Placeholders only)
- Part 3 Section 3.10 (AI Insight Tile - Future NSWare Phase-2)

---

### 8.11 Part 8 Summary

Part 8 establishes:

- Performance rules for NSReady dashboards
- API call architecture (1 call per dashboard)
- Polling cadences per dashboard type
- Strict backend load protections
- Strict tenant isolation in performance
- Caching standards (backend + frontend)
- Fail-safe graceful degradation rules
- Future-proof compatibility with NSWare Phase-2

This lets NSReady dashboards remain:

- Safe
- Fast
- Scalable
- Multi-tenant
- Predictable
- AI-ready (structure only)

---

---

## 9. Feature Store Integration Layer (NSReady v1 – Future-Proof Hooks Only)

(Compatible with NSReady v1 — no heavy NSWare KPIs, no AI logic)

---

### 9.1 Purpose of Part 9

NSReady v1 does **NOT include**:

- Process KPIs
- Machine learning
- Model registry
- Prediction scoring
- AI insights

**HOWEVER:**

We must still plan the dashboard and API contract so that NSReady v1 does **not require rework** when NSWare Phase-2 is added later.

**Part 9 defines:**

- Minimal future-proof fields
- Contract extensions
- Data placeholders
- Safe integration boundaries
- UI/UX structures that support evolution without redesign

This ensures that NSReady v1 dashboards can later "grow into" NSWare AI and KPI dashboards without breaking anything.

**Cross-Reference:**

- **Backend Master Section 7.7:** Feature Tables (AI/ML Future)
- **Backend Master Section 9.6:** Tenant Context for Future NSWare AI/ML Layer
- **Part 1 Section 3.5:** AI-Ready from Day Zero (Placeholders only)
- **Part 3 Section 3.10:** AI Insight Tile (Future NSWare Phase-2)

---

### 9.2 Design Principles for NSReady Feature Integration (Future Hooks)

**P1 — No AI Logic in NSReady v1**

- NSReady v1 must **NOT compute** features, predictions, or ML scores.
- NSReady v1 does **NOT run ANY model**.

**P2 — The Dashboard Must Accept AI Fields Even If Empty**

To future-proof:

```json
"ai": {
  "enabled": false,
  "risk": null,
  "confidence": null,
  "top_factors": []
}
```

**P3 — Tile Contract Must Already Support AI Fields**

This prevents redesign of tiles in NSWare Phase-2.

**P4 — Only Operational KPIs (Packet Health etc.) in NSReady v1**

Part 9 must **NOT introduce** process KPIs.

**P5 — NSReady Backend Remains Clean and Unaffected**

Backend will simply pass empty/disabled AI fields during NSReady v1.

**This aligns with:**
- Part 1 Section 3.5 (AI-Ready from Day Zero - Placeholders only)
- Part 3 Section 3.2 (Tile Rendering Philosophy - AI Compatibility)

---

### 9.3 What NSReady Needs Today (Minimum Hooks)

NSReady dashboards already include:

- Timestamp
- Value
- Trend
- Status
- Tenant context

But we add **two future-proof fields** immediately:

**Field A: ai block (disabled)**

```json
"ai": {
  "enabled": false
}
```

**Field B: derived block (future KPIs)**

```json
"derived": null
```

These should **ALWAYS be present** in tile JSON.

If not needed, they remain `null` or `disabled`.

No UI renders them in NSReady v1.

**This aligns with:**
- Part 3 Section 3.3 (NSReady Unified Tile Contract)
- Part 3 Section 3.12 (Future-Proofing Hooks)

---

### 9.4 Tile Extensions for Future Compatibility (NSReady-Safe)

Every NSReady tile supports:

**A. AI Placeholder**

```json
"ai": {
  "enabled": false,
  "risk": null,
  "confidence": null,
  "top_factors": []
}
```

**B. Derived/Computed Values Placeholder**

For NSWare Phase-2 KPIs (flow, pressure, etc.):

```json
"derived": {
  "value": null,
  "unit": null,
  "window": null
}
```

**C. Multi-Source Tile Future Hook**

```json
"source_extras": {}
```

**This aligns with:**
- Part 3 Section 3.3 (NSReady Unified Tile Contract - AI block)
- Part 3 Section 3.12 (Future-Proofing Hooks)

---

### 9.5 Dashboard JSON Extensions (NSReady-Safe)

Dashboard JSON includes:

```json
"metadata": {
  "version": "1.0",
  "generated_at": "2025-11-18T12:10:00Z",
  "ai_ready": true,
  "derived_ready": true
}
```

**Rules:**

- `ai_ready = true` simply signals future compatibility
- Does not activate any AI logic
- Does not load ML models
- Does not change backend behaviour

**This aligns with:**
- Part 4 Section 4.2 (Canonical Dashboard JSON Structure)
- Part 4 Section 4.10 (Summary of Backend-Powered View Engine Rules)

---

### 9.6 Backend Role in Part 9 (NSReady v1)

The NSReady backend must:

**1. Include AI + Derived Blocks in Tile Responses**

Even if empty.

**2. NEVER Compute or Call Any Model**

- No NATS messages
- No model registry
- No vector store
- No ML inference

**3. Expose Clean, Stable API Shape**

So NSWare future layers can plug-in predict/feature-store outputs later.

**This aligns with:**
- Backend Master Section 7.7 (Feature Tables - AI/ML Future - NOT implemented in NSReady v1)
- Backend Master Section 9.6 (Tenant Context for Future NSWare AI/ML Layer)

---

### 9.7 Tenant Isolation Rules (Future-Proof)

Even in NSWare Phase-2:

- AI predictions are tenant-specific
- Aggregated KPIs must never mix across tenants
- Parent → child grouping allowed only at reporting layer

Thus, in NSReady v1 we **MUST enforce**:

```
tile.scope.customer_id = <tenant>
dashboard.scope.customer_id = <tenant>
api.customer_id = <tenant>
```

No exceptions.

This prevents massive rework when AI/Feature Store comes later.

**This aligns with:**
- Part 6 Section 6.2 (Core Tenant Boundary Rule)
- Part 6 Section 6.7 (UI Enforcement Rules - Zero Leakage Guarantee)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)

---

### 9.8 NSReady → NSWare Compatibility Requirements

| Requirement | NSReady v1 Status | NSWare Phase-2 Impact |
|-------------|-------------------|----------------------|
| Tile JSON supports AI fields | Enabled (empty) | Used |
| Dashboard JSON supports AI metadata | Enabled | Used |
| Tenant scoping | Required | Required |
| Derived KPI placeholder | Enabled | Used |
| Multi-source placeholder | Enabled | Used |
| Feature-store API endpoints | Not required in v1 | Added in v2 |
| AI explanation drawer UI | Not rendered | Activated in v2 |

**This aligns with:**
- Part 3 Section 3.12 (Future-Proofing Hooks)
- Part 4 Section 4.10 (Summary of Backend-Powered View Engine Rules)

---

### 9.9 UI/UX Requirements for Future AI Compatibility

Even though NSReady v1 doesn't show AI:

The design **MUST still include** the slots.

**Requirement #1 — AI Region Reserved in Tile**

```html
<div class="ai-area" style="display:none"></div>
```

**Requirement #2 — Explainability Drawer Reserved**

Even if not shown:

```html
<div id="explain-drawer" style="display:none"></div>
```

**Requirement #3 — Chart Overlays Support Future AI Bands**

Trend charts must include:

```json
"ai_overlay": []
```

Even if empty.

**This aligns with:**
- Part 7 Section 7.7 (Summary of Part 7 - Future-Proof Hooks)
- Part 3 Section 3.12 (Future-Proofing Hooks)

---

### 9.10 Future Feature Store Integration Path (Informational Only)

**Not part of NSReady v1**, but these endpoints will come:

```
GET /api/ai/features/:device_id
GET /api/ai/predictions/:device_id
GET /api/ai/explain/:alert_id
```

Dashboards must not depend on them today.

**This aligns with:**
- Backend Master Section 7.7 (Feature Tables - AI/ML Future)
- Backend Master Section 9.6 (Tenant Context for Future NSWare AI/ML Layer)

---

### 9.11 Summary of NSReady Part 9

Part 9 ensures:

- NSReady v1 remains clean, not mixed with NSWare logic
- Tile format, Dashboard JSON, API contract already support NSWare Phase-2
- No rework required when features like AI or model scoring are added later
- Tenant safety is maintained even in future advanced features
- The dashboard contract is backwards compatible for 10+ years

**NSReady Today:**

- Only operational health
- Only ingestion metrics
- Only SCADA latest/history
- No process KPIs
- No AI logic

**But the structure is ready for NSWare tomorrow.**

---

---

## 10. UI Rendering Rules, Error Handling & Explainability (NSReady v1 Final Layer)

**Scope of Part 10:**

This section defines how the NSReady frontend must render tiles, dashboards, graphs, errors, and validation results, with strict NSReady v1 constraints:

- **NO process KPIs**
- **NO NSWare KPI/alert engine**
- **NO AI predictions**
- **NO ML explainability**

But the UI must still include safe placeholders (invisible) so that NSWare v2 can plug-in explainability, AI indicators, and deeper diagnostics later without redesign.

---

### 10.1 Purpose of Part 10

Part 10 ensures:

**1. NSReady Dashboards Always Render Safely**

Regardless of missing data, empty fields, worker delays, or backend timeouts.

**2. No Operational Screen Breaks**

Even if `/v1/health`, `/metrics`, or SCADA views temporarily fail.

**3. All Tiles Adhere to Strict Visual and Behavioral Rules**

So dashboards behave predictably and consistently.

**4. Explainability Regions Exist — But Remain Invisible**

Until NSWare Phase-2 activates them.

**5. Debug & Traceability Hooks**

(`trace_id`, ingestion path indicators) are properly displayed for engineers.

**This aligns with:**
- Part 3 Section 3.11 (Tile Validation Rules)
- Part 8 Section 8.9 (Graceful Degradation Rules)

---

### 10.2 Global UI Rendering Rules (Applies to All Dashboards)

**Rule 1 — Tiles Must Be Rendered Even If Data Is Missing**

If backend misses a value:

- Tile renders "No Data"
- State becomes "inactive"
- Tile border shows greyed-out style
- Timestamp slot reads "--"

**Rule 2 — UI Never Crashes Due to Missing or Malformed Fields**

Frontend must protect itself from:

- Missing fields
- Null fields
- Wrong data types
- Missing timestamps
- Empty tile list

**Rule 3 — UI NEVER Recomputes KPI Logic**

Frontend never:

- Calculates percentages
- Calculates packet health
- Calculates missing/late packet thresholds
- Calculates any metadata

All logic comes from backend tile JSON.

**Rule 4 — Timestamps Always Displayed in Operator-Friendly Way**

- Local timezone for operators
- UTC on hover
- ISO format when copying

**Rule 5 — Tile Width/Height Strictly Follows the Grid**

- 12-column layout
- `span` controls width
- Tile height controlled by type (`s`, `m`, `l`, `xl`)

**This aligns with:**
- Part 3 Section 3.2 (Tile Rendering Philosophy)
- Part 4 Section 4.3 (Sections, Rows, Tiles — View Hierarchy)

---

### 10.3 Error Handling (NSReady v1)

When an API call fails:

**UI Must Show One of Three Safe States**

**A) Transient Error**

(API timeout, slow DB)

"Data delayed. Retrying…"

- Soft yellow banner
- Auto-retry after 5–10s

**B) Hard Error**

(API returns error)

"Backend unavailable. Last good data shown."

- Red banner
- Tiles show cached values
- Timestamp shows "stale"

**C) Partial Failure**

(Some tiles loaded, others failed)

- Failed tiles show "No Data"
- Successful tiles remain visible

**UI Never Hides Entire Dashboard Unless Completely Unreachable**

**This aligns with:**
- Part 8 Section 8.6.4 (Degraded Mode)
- Part 8 Section 8.9 (Graceful Degradation Rules)

---

### 10.4 Ingestion Traceability Rendering (NSReady-Only Feature)

The UI must support traceability for debugging data flow:

Every tile may include:

```json
"debug": {
  "trace_id": "...",
  "event_count": 12,
  "source": "ingest_events / worker"
}
```

**Frontend Behavior:**

- Show a subtle "trace" icon for engineers
- Clicking it reveals:
  - `trace_id`
  - `event_count`
  - Ingestion path
  - Worker id (if provided)

Only visible when user role = Engineer.

**This aligns with:**
- Backend Master Section 5.3 (NormalizedEvent - trace_id)
- Part 5 Section 5.6 (Ingestion Log Dashboard - trace_id display)
- Part 6 Section 6.3 (NSReady Role Types - Engineer access)

---

### 10.5 SCADA View Rendering Rules

**SCADA Tables (Latest + History)**

**SCADA Latest Grid**

- Always sorted by device
- Columns:
  - Device
  - Parameter
  - Value
  - Timestamp
  - Quality

**SCADA History Trend**

- Limited to operator-selected time ranges
- Always pull from SCADA view, not raw `ingest_events`

**Fallback Rules**

If SCADA views fail:

- UI shows: "SCADA view temporarily unavailable. Using cached values."
- UI must continue rendering cached last-known values

**This aligns with:**
- Part 5 Section 5.7 (SCADA Export Monitor Dashboard)
- Backend Master Section 8.2.1 (`v_scada_latest` View)
- Backend Master Section 8.2.2 (`v_scada_history` View)

---

### 10.6 NSReady Explainability Hooks (Hidden Now, Active Later)

NSReady v1 does **NOT implement** explainability.

But the UI must reserve space.

**Two Hidden UI Regions Per Tile**

**A) Explainability Drawer Placeholder**

```html
<div id="explainability-drawer" style="display:none"></div>
```

**B) AI Factors Placeholder**

```json
"ai": {
  "enabled": false,
  "top_factors": []
}
```

**Frontend Behavior in NSReady v1:**

- Never show these sections
- Never attempt to parse AI fields
- Never load AI icons or overlays

This prevents redesign in NSWare v2.

**This aligns with:**
- Part 9 Section 9.9 (UI/UX Requirements for Future AI Compatibility)
- Part 3 Section 3.10 (AI Insight Tile - Future NSWare Phase-2)

---

### 10.7 Operational UX Patterns (Error, Logs, Warnings)

**Pattern 1 — Warning Badge on Tile**

Used when:

- Worker delays
- Queue depth high
- SCADA view outdated

**Pattern 2 — Timeline Markers**

Trend tiles highlight:

- Ingestion gaps
- Error spikes
- Missing packets

**Pattern 3 — Modal Error Detail**

Engineer clicks alert → modal opens showing:

- Timestamp
- Device
- Event details
- Trace ID
- Raw `NormalizedEvent` (read-only)

**Pattern 4 — On-Dashboard Quick Actions (Engineer-Only)**

Buttons:

- "View Device Logs"
- "Refresh"
- "Open SCADA Latest"
- "Open Registry"

**This aligns with:**
- Part 5 Section 5.6 (Ingestion Log Dashboard - Modal behavior)
- Part 6 Section 6.3 (NSReady Role Types - Engineer access)

---

### 10.8 Operational Behavior in Degraded Mode

If background services partially fail:

**A) Collector-Service Down**

- Red icon
- System Health tile status = critical
- All tiles show stale tag and last pulled timestamp

**B) Worker Down**

- Queue depth tile becomes warning
- Tile footnote: "Worker inactive. Messages pending."

**C) NATS Down**

- Entire dashboard banner red: "Ingestion Paused — NATS unreachable"

**D) Postgres Slow**

- Warning banner: "Database slow. Some values delayed."

**E) SCADA Export Failing**

- SCADA tile turns warning/critical
- Row in export history tile marked red

**This aligns with:**
- Part 8 Section 8.9 (Graceful Degradation Rules)
- Backend Master Section 6.2 (Queue Depth Thresholds)
- Part 5 Section 5.8 (System Health Dashboard)

---

### 10.9 Rendering Rules for Bulk Data

Bulk data includes:

- SCADA tables
- Registry lists
- Device lists
- Error logs

**Rules:**

1. **Virtual scrolling** for >200 rows
2. **Server-side pagination** for >1000 rows
3. **CSV export** only for engineer
4. **Copy-paste from table** must be supported
5. **Click-to-filter:**
   - Click device → filter logs for device
   - Click parameter → filter SCADA table

**This aligns with:**
- Part 5 Section 5.4 (Registry Configuration Dashboard - Bulk Add Table)
- Part 7 Section 7.4.2 (Bulk Add - Copy-Paste Grid)

---

### 10.10 Final Summary — Part 10

Part 10 ensures:

- NSReady dashboards never break
- Engineer debugging is fully supported
- Tenant isolation is preserved in ALL states
- All NSReady operational dashboards behave consistently
- Future NSWare AI/ML upgrades will **NOT require UI redesign**

**NSReady v1 UI Layer is now fully documented from Part 1 through Part 10.**

---

## Complete NSReady Dashboard Master — Final Summary

**Document Status:** ✅ **COMPLETE** (Parts 1-10)

**Scope:** NSReady v1 Data Collection Software — Dashboard & UI/UX Master Specification

**Purpose:** This document defines the complete dashboard architecture, UI/UX standards, navigation, tiles, operational dashboards, tenant isolation, performance, and rendering rules for NSReady v1 data collection software.

**Key Achievements:**

✅ **Parts 1-4:** Common Foundation (Theme, Navigation, Tile System, Dashboard JSON)  
✅ **Part 5:** NSReady Operational Dashboards (Registry, Health, Logs, SCADA, System)  
✅ **Part 6:** Tenant Isolation & Access Control (Role-based, Customer-enabled config)  
✅ **Part 7:** UX Mockup & Component Layout System (Wireframes, Forms, Bulk Entry)  
✅ **Part 8:** Performance & Caching Model (Refresh cadences, API patterns, Caching)  
✅ **Part 9:** Feature Store Integration Layer (Future-proof hooks for NSWare Phase-2)  
✅ **Part 10:** UI Rendering Rules & Error Handling (Safe rendering, Traceability, Degraded mode)

**NSReady v1 Dashboard Capabilities:**

- ✅ Registry Configuration (Customer → Project → Site → Device)
- ✅ Collection Health Monitoring (Packet on-time %, Missing/Late packets)
- ✅ Ingestion Logs (Event timeline, Error logs, Trace IDs)
- ✅ SCADA Export Monitor (Latest values, Export history, Mapping status)
- ✅ System Health (Service status, Queue depth, DB status, Metrics)
- ✅ Tenant Isolation (Strict customer boundary enforcement)
- ✅ Role-Based Access (Engineer, Customer Admin, Site Operator, etc.)
- ✅ Bulk Configuration (Copy-paste tables, CSV tools engineer-only)
- ✅ Performance Optimized (Rollups over raw, Caching, Rate limiting)
- ✅ Future-Proof (AI placeholders, NSWare Phase-2 compatible)

**Separation of Concerns:**

- ✅ **NSReady v1:** Data collection, operational health, registry configuration
- ✅ **NSWare Phase-2 (Future):** Process KPIs, AI/ML scoring, Feature Store (NOT in this document)

**Cross-References to Backend Master:**

- ✅ Backend Master Section 4: Registry & Parameter Templates
- ✅ Backend Master Section 5: Ingestion Engine
- ✅ Backend Master Section 6: Health Monitoring & Queue Depth
- ✅ Backend Master Section 7: Database Architecture
- ✅ Backend Master Section 8: SCADA Integration
- ✅ Backend Master Section 9: Tenant Model

**Related Documents:**

- **NSReady Backend Master:** `../NSREADY_BACKEND_MASTER.md`
- **NSWare Dashboard Master (Future):** `../NSware Basic work/NSWARE_DASHBOARD_MASTER.md`
- **NSReady Operational Dashboards (Detailed):** `../NSware Basic work/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`

---

**Status:** ✅ **NSREADY_DASHBOARD_MASTER.md is COMPLETE** (All 10 Parts)

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Scope:** NSReady v1 Data Collection Software — Dashboard & UI/UX Layer

---

**Next Steps:**

This master document is ready for:
- Frontend development team implementation
- UI/UX design team wireframe creation
- Backend API team dashboard JSON contract implementation
- Quality assurance team test case development
- Documentation team user guide creation

**For NSWare Phase-2 (Future):**

See `NSWARE_DASHBOARD_MASTER.md` for process KPIs, AI/ML dashboards, and Feature Store integration specifications.


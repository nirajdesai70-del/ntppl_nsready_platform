# NSWare Dashboard & UI/UX Master Specification

**Version:** 1.0  
**Document Type:** Master Reference (Dashboard/UI)  
**Branding:** Neutral / No Group Nish branding  
**Scope:** Dashboard architecture, UI/UX standards, navigation, tiles, KPI/alert specification, data binding, tenant isolation, and AI-readiness design for NSWare platform.

---

## 1. Executive Summary (Purpose of This Document)

This document defines the master blueprint for all current and future NSWare dashboards, mobile UIs, and visualization layers.

It aligns:

- Field telemetry ingestion (NSReady backend)
- Multi-customer/tenant isolation
- SCADA-style live dashboards
- Engineering/operator dashboards
- OEM / multi-company reporting dashboards
- AI-ready future visual layers

And establishes:

- Standard layout structure
- Standard tile structure
- Standard data contract
- Standard theme system
- Standard UX rules
- Standard alert visualization
- Standard navigation structure
- Standard customer-group tenant model

This is the single source of truth for NSWare dashboard architecture.

---

## 2. Scope of This Master Document

**Included in this Master:**

1. Dashboard architecture
2. UI/UX standards
3. Navigation structure
4. Dashboard tile definition
5. KPI/alert specification
6. Data binding rules (backend → dashboard)
7. Tenant/customer isolation
8. Multi-company "Customer Group" support
9. SCADA integration visualization rules
10. AI/ML-ready visual placeholders
11. Layout templates (web + mobile)

**Not included (covered in Backend Master):**

- Ingestion logic
- Worker/nats flows
- Database architecture
- SCADA DB integration
- YAML data contracts
- Tenant ADR
- Performance and monitoring ops

---

## 3. Core Dashboard Philosophy (NSWare Design DNA)

NSWare dashboards follow five non-negotiable principles:

### 3.1 Real-Time but Human-Centric (Not Overloaded)

Dashboards display only:

- What the operator must act on
- What engineering must diagnose
- What management must decide

NSWare avoids:

- Overloaded charts
- Meaningless gauges
- Too many moving parts

Everything in NSWare follows the principle:

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

NSWare dashboards become:

- ML-visualization-ready without rework
- Feature-store-ready
- Prediction-integrated
- Future-proof

---

## 4. Dashboard Categories (NSWare Product Lines)

NSWare supports multiple dashboard types:

### 4.1 Live Telemetry Dashboards (Operator)

Shows:

- Real-time values
- Alarms
- Health status
- Device-level KPIs
- Packet health visuals

Target users:

- Operators
- SCADA engineers
- Shift managers

### 4.2 Engineering Dashboards (Diagnostic)

Shows:

- Time-series charts
- Windowed statistics
- Packet delay/jitter graphs
- Device-reset patterns
- Alert frequency distribution

Target users:

- Electrical engineers
- Mechanical engineers
- Instrumentation & control engineers
- Data engineers

### 4.3 Management Dashboards (Summary-Level)

Shows:

- Daily/weekly usage
- Customer performance
- Group-level aggregation
- Location comparisons
- SLA adherence

Target users:

- OEM leadership
- Utility managers
- Plant directors

### 4.4 Group Dashboards (Customer Group / OEM Multi-Company)

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

### 4.5 AI/ML Dashboards (Future Phase)

Supports:

- Predictions
- Anomaly detection
- Model score timelines
- Explainability (top contributing factors)

Even now, visual placeholders must exist.

---

## 5. NSWare Theme System (Design Foundation)

The NSWare dashboards use a uniform, modern, dark-theme-first style.

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
    { "key": "voltage", "value": 231.5, "unit": "V", "status": "normal", "trend": "up" }
  ],
  "alerts": [
    { "key": "over_voltage", "level": "critical", "timestamp": "...", "message": "..." }
  ],
  "charts": [
    { "key": "voltage_24h", "data": [...], "unit": "V" }
  ],
  "metadata": {
    "timestamp": "2025-11-18T12:10:00Z"
  }
}
```

This ensures:

- Dashboards, SCADA, and AI all consume the same data shape
- Every tile follows the same contract
- Multi-customer isolation is enforced at data level

---

## 7. Standard Dashboard Page Types (Defined for NSWare UI)

Each dashboard instance must be one of these 5 types:

**1) Main Dashboard**

- KPIs
- Alerts
- Live tiles
- Quick view

**2) Device/Unit Dashboard**

- Detailed device KPIs
- Trend charts
- Live metrics

**3) Site Dashboard**

- All devices in a site
- Heatmaps
- Distribution graphs

**4) Customer/OEM Dashboard**

- Aggregated views
- Comparison across subsidiaries

**5) AI Insights Dashboard (Future)**

- Prediction
- Score trends
- Explainability

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

### 8.5 Distribution Tile

- Histogram/violin/bar

### 8.6 AI Insight Tile (Future)

- Prediction
- Confidence
- Explainability

---

## 9. Dashboard → Backend → SCADA → AI Linkage Model

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

---

---

## 2. Information Architecture (IA) Blueprint

This section defines the universal navigation and routing model for all NSWare dashboards.

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

### 2.1 NSWare Navigation Layers (4-Level Structure)

The NSWare frontend uses a 4-level navigation system, identical across all deployments:

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
- Heatmaps (flow, temp, pressure)
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
- AI insights (future)
- Packet health
- Mini trends
- Historical charts

**Data source:**

- `device_id`

**Purpose:**

- Engineering diagnostics
- Device-level troubleshooting

### 2.2 Routing Structure (Front-End Routing Map)

The NSWare frontend must use a clean routing structure:

```
/tenant/:tenant_id
/customer/:customer_id
/site/:site_id
/device/:device_id
/unit/:unit_id   (optional future)
/kpi/:kpi_key    (optional future)
```

**Routing Rules:**

1. Tenant routing is optional
2. Customer routing is mandatory
3. Site routing always requires a valid customer context
4. Device routing must validate `customer_id + site_id + device_id`
5. Unauthorized tenant navigation should auto-redirect to customer root

### 2.3 Navigation Components (Standardized UI Layout)

Navigation must follow a consistent left-sidebar layout:

**Left Sidebar (Fixed)**

- Tenant switcher (if applicable)
- Customer list (if tenant admin)
- Site list
- Device list (optional collapsible panel)
- Common links:
  - Dashboard
  - Alerts
  - Trends
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

To reduce redesign time and ensure consistent UX, NSWare defines 5 universal dashboard templates.

#### 2.4.1 Template A: Main Dashboard (Tenant/Customer)

**Sections:**

- High-level KPIs
- Alerts
- Trend cards
- Comparison views

**Recommended Widgets:**

- Usage KPIs
- Outage KPIs
- Pressure KPIs
- Temperature KPIs
- Alerts overview

#### 2.4.2 Template B: Site Overview Dashboard

**Sections:**

- Site KPIs
- Device list
- Health map
- Mini trends

**Widgets:**

- Flow/pressure/temperature overview
- Device uptime
- Packet health

#### 2.4.3 Template C: Device Dashboard

**Sections:**

- Device KPIs
- Alerts
- Live metrics
- Trends
- Logs

#### 2.4.4 Template D: AI Insights Dashboard (Future)

**Sections:**

- Predictions
- Explainability
- Top contributing factors
- Score timeline

**Placeholder Implementation:**

Dashboards MUST include invisible `<div id="ai-insights">` region for future expansion.

### 2.5 Breadcrumb Navigation Standard

Breadcrumbs always follow:

```
Tenant > Customer > Site > Device
```

**Example for Customer Group:**

```
Customer Group > Customer Group Textool > Site 12 > Device 004
```

**Requirements:**

- Breadcrumb must be clickable
- Must enforce tenant context
- Must handle deep links gracefully

### 2.6 Search Model (Unified Search) – NSWare Search Contract

Search must support the following entities:

- Customer
- Site
- Device
- Parameter
- KPI
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

**Routing must enforce:**

- Role-based view
- Role-based navigation
- Role-based tile visibility

### 2.8 Multi-Device Personality Model (Industrial UI Pattern)

Devices in NSWare may have different personalities:

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
   - KPIs
   - Alerts
   - Trends
   - AI predictions (future)

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

---

## 3. Universal Tile System (UTS v1.0)

The Universal Tile System defines:

- How every dashboard tile looks
- How every tile reads data
- How every tile behaves
- How future AI modules extend tiles
- How tenant/customer safety is enforced

This ensures the entire NSWare ecosystem has:

- Consistent UI
- Reusable tile components
- Clean integration with backend APIs
- Predictable behavior across devices, industries, and sites

### 3.1 Tile Categories (NSWare Tile Taxonomy)

NSWare tiles fall under 6 universal, reusable categories:

#### 1. KPI Tiles

**Purpose:** Show a summarized key performance indicator

**Examples:**

- Flow rate
- Pressure
- Temperature
- Steam consumption
- Energy usage

#### 2. Health Tiles

**Purpose:** Indicate device/site status

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

- 24-hour flow curve
- 12-hour pressure sparkline
- 1-week KPI trend

#### 5. Asset Tiles

**Purpose:** Represent equipment or infrastructure visually

**Examples:**

- Device tile
- Valve tile
- Pump tile
- Flowmeter tile
- Boiler tile

#### 6. AI Insight Tiles (Future)

**Purpose:** Show predictions, anomalies, explanations

Should be included invisibly from now:

```html
<div id="ai-insights"></div>
```

**Examples:**

- AI anomaly risk score
- AI forecast for tomorrow
- Explainable factors ("Top 3 contributing behaviors")

### 3.2 Tile Rendering Philosophy (NSWare UI Principles)

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

These values may be empty today but must exist in tile JSON.

### 3.3 NSWare Unified Tile Contract (Backend → Frontend JSON)

This is the most important part.

Every tile must follow this universal JSON structure, regardless of KPI, alert, trend, or AI.

**JSON Contract:**

```json
{
  "id": "tile_voltage_001",
  "type": "kpi | health | alert | trend | asset | ai",
  "title": "Voltage",
  "icon": "bolt",
  "source": {
    "customer_id": "UUID",
    "site_id": "UUID",
    "device_id": "UUID",
    "parameter_key": "project:<uuid>:voltage"
  },
  "value": 230.5,
  "unit": "V",
  "status": "normal | warning | critical | inactive",
  "trend": {
    "sparkline": [228, 229, 231, 230, 230.5],
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
| `ai` | Future AI integration hooks |
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
  "title": "Flow Rate",
  "value": 112.4,
  "unit": "kg/h",
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
  "title": "High Pressure",
  "status": "critical",
  "value": 14.2,
  "unit": "bar"
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
  "title": "24h Flow Trend",
  "trend": {
    "sparkline": [120,118,117,119,121,122]
  }
}
```

### 3.9 Asset Tile Specification (Template E)

**Layout:**

Visual representation of equipment.

**JSON Example:**

```json
{
  "type": "asset",
  "title": "Valve 03",
  "status": "normal"
}
```

### 3.10 AI Insight Tile Specification (Template F)

**Layout:**

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
    "enabled": true,
    "risk": 0.72,
    "confidence": 0.93,
    "top_factors": ["Flow variance", "Pressure drop"]
  }
}
```

### 3.11 Tile Validation Rules

**Backend Rule Set:**

- All tiles must include `customer_id`
- Device/specific tiles must include `device_id`
- KPI and trend tiles must include `parameter_key`
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

---

## 4. Dashboard View Engine & JSON Contract

(NSWare Backend-Powered Rendering Model)

In NSWare, dashboards are backend-defined views, not hard-coded pages.

The backend generates a Dashboard JSON, and the frontend simply renders it using the Universal Tile System (UTS).

This keeps:

- Logic centralized
- Behavior consistent
- AI integration trivial
- Multi-customer configurations manageable

### 4.1 High-Level Concept

**Dashboard generation flow:**

```
User opens /customer/:customer_id/dashboard
         ↓
NSWare Backend receives request (with tenant context)
         ↓
Backend loads dashboard definition for that context
         ↓
Backend gathers data (views, APIs, SCADA, AI)
         ↓
Backend assembles Dashboard JSON:
    sections[] → rows[] → tiles[]
         ↓
Frontend receives JSON and renders tiles
```

**Key rule:**

Dashboard JSON is the single source of truth for what appears on the screen.

### 4.2 Canonical Dashboard JSON Structure

This is the master contract between NSWare backend and NSWare frontend.

```json
{
  "dashboard_id": "customer_main_v1",
  "title": "Customer Overview",
  "scope": {
    "tenant_id": "UUID",
    "customer_id": "UUID",
    "site_id": null,
    "device_id": null
  },
  "layout": {
    "grid": 12,
    "max_rows": 6
  },
  "sections": [
    {
      "id": "kpi_bar",
      "title": "Key KPIs",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_kpi_flow", "span": 3 },
            { "tile_id": "tile_kpi_pressure", "span": 3 },
            { "tile_id": "tile_kpi_energy", "span": 3 },
            { "tile_id": "tile_kpi_uptime", "span": 3 }
          ]
        }
      ]
    },
    {
      "id": "alerts",
      "title": "Active Alerts",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_alert_list", "span": 12 }
          ]
        }
      ]
    }
  ],
  "tiles": [
    {
      "id": "tile_kpi_flow",
      "type": "kpi",
      "title": "Flow Rate",
      "source": {
        "customer_id": "UUID",
        "site_id": null,
        "device_id": null,
        "parameter_key": "project:<uuid>:flow"
      },
      "value": 114.6,
      "unit": "kg/h",
      "status": "normal",
      "trend": { "direction": "up" },
      "timestamp": "2025-11-14T12:00:00Z"
    }
    // ... rest of tiles referenced in sections
  ],
  "metadata": {
    "generated_at": "2025-11-14T12:01:00Z",
    "version": "1.0.0"
  }
}
```

### 4.3 Sections, Rows, Tiles — View Hierarchy

Frontend only needs to understand 3 layout primitives:

1. **Section** → A logical block / panel with title
2. **Row** → A horizontal arrangement of tiles
3. **Tile** → A unit from Universal Tile System (UTS)

**Example:**

```json
"sections": [
  {
    "id": "kpi_bar",
    "title": "Key KPIs",
    "rows": [
      {
        "tiles": [
          { "tile_id": "tile_kpi_flow", "span": 3 },
          { "tile_id": "tile_kpi_pressure", "span": 3 },
          { "tile_id": "tile_kpi_energy", "span": 3 },
          { "tile_id": "tile_kpi_uptime", "span": 3 }
        ]
      }
    ]
  }
]
```

**Frontend behaviour:**

- For each section:
  - Render section title
  - For each row:
    - Use 12-column grid
    - Allocate columns according to span for each tile

**Backend behaviour:**

- Choose which tiles belong where
- Choose layout and spans
- Guarantee tile IDs exist in the tiles array

### 4.4 Tenant-Aware Dashboard Generation

All dashboards must be generated using:

```json
"scope": {
  "tenant_id": "<customer_id>",
  "customer_id": "<customer_id>",
  "site_id": null | "<site_id>",
  "device_id": null | "<device_id>"
}
```

**Rules:**

1. `tenant_id` MUST equal `customer_id` in NSReady v1
2. Group dashboards (for OEM / holding company) are generated by:
   - Backend querying `parent_customer_id` and children
   - But still fully enforcing isolation of non-child customers
3. Access control:
   - Backend uses auth context to determine allowed scope
   - Frontend does not enforce security; it only renders JSON

### 4.5 Where Dashboard Definitions Live (Config vs Code)

To avoid hard-coding dashboards, NSWare supports config-driven dashboard definitions.

**Possible storage options:**

- YAML/JSON files in repo (e.g. `/dashboards/customer_main.yaml`)
- DB tables (e.g. `dashboard_definitions`)
- Hybrid (DB + git sync)

**Recommended v1 path:**

- Store dashboard definitions as JSON/YAML in config directory
- Load them on server start
- Attach dynamic data via view engine

### 4.6 Dynamic Dashboard vs Static Layouts

**Static parts:**

- Section structure
- Tile positions
- Page titles
- Routes

**Dynamic parts:**

- KPI values
- Alert content
- Trend data
- AI scores

**Backend separates:**

- Layout skeleton (from config)
- Data binding + values (from DB/views/AI/store)

This gives:

- Fast UI iteration
- Consistent behaviour
- Clean separation of what is "editable" vs what is "calculated"

### 4.7 Dashboard → API → View Binding Contract

For each dashboard page, backend must define:

1. Dashboard ID
2. View/Endpoint used to fetch data
3. Data transformation rules
4. Tile mapping rules

**Example mapping:**

| Dashboard ID | Backend View | Notes |
|--------------|--------------|-------|
| `customer_main_v1` | `vw_customer_kpi_summary` | Pre-aggregated KPIs |
| `site_main_v1` | `vw_site_metrics` | Site-level metrics |
| `device_main_v1` | `vw_device_metrics` | Raw + rollup data |

**Important Rule:**

Backend must expose only cleaned, ready-to-render JSON.  
Frontend must NOT compute business rules.

### 4.8 Drilldown Flow & Back Navigation

Each tile may provide:

```json
"links": {
  "drilldown": "/device/<device_id>"
}
```

**Frontend Rules:**

- Clicking KPI tile sends user to target dashboard (e.g., device view)
- Breadcrumb preserves path:

```
Customer > Site > Device
```

**Backend Rules:**

- Drilldown target must be a known, registered dashboard ID
- Backend can supply direct `dashboard_id` for patterns like:

```json
"links": {
  "dashboard_id": "device_main_v1",
  "scope": { "device_id": "…" }
}
```

### 4.9 Versioning Strategy for Dashboards

All dashboards must carry a version field:

```json
"metadata": {
  "version": "1.0.0"
}
```

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
7. AI can add fields to tile JSON without UI breaking.
8. Group reports use `parent_customer_id` only — still per tenant boundary.

---

---

---

## 5. KPI & Alert Model (NSWare KPI Engine v1.0)

> ⚠️ **NSWare Phase-2 – Process KPI & Alert Engine (Future Implementation)**  
> 
> **This section defines the NSWare process KPI & alert model** (steam efficiency, water loss, power consumption, etc.)  
> **It is NOT part of NSReady v1 data collection software.**  
> 
> **NSReady v1** only guarantees:
> - Clean telemetry ingestion (`ingest_events`)
> - Registry structure (customers → projects → sites → devices)
> - Tenant isolation (`tenant_id = customer_id`)
> - Operational health views (`/v1/health`, queue depth, packet health)
> 
> **NSWare KPI/alert logic** (process KPIs, threshold-based alerts, AI scoring) will be implemented as a **separate, future layer** on top of the NSReady foundation.
> 
> **For NSReady v1 operational dashboards** (registry configuration, collection health, ingestion logs, SCADA export), see `master_docs/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`.

---

This part defines how every KPI and alert will behave in **NSWare customer-facing dashboards** (future Phase-2).

It is the common language between:
- **Backend**: parameter templates, computed KPIs, rollups
- **Frontend**: tiles & dashboards (Parts 1–4)
- **Future AI**: scoring, anomaly flags, risk indicators

This model is **process-facing, not system-health-facing**:
- **Process KPIs** → flow, pressure, energy, uptime, efficiency
- **Process alerts** → high/low limits, rate-of-change, stability, etc.
- **NSReady ingest/queue health** is covered in backend/operational docs and `PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`, not here.

---

### 5.1 Goals of the NSWare KPI Model

The KPI/Alert model must:

**1. Be consistent across industries**

- Same structure whether it's water, steam, chemicals, or power.
- Only the names and units change.

**2. Be tenant-safe and customer-specific**

- One customer's KPI definitions and limits must not affect another's.
- KPI configs are scoped per customer or per project.

**3. Be derived from backend data contracts**

- KPIs are computed from:
  - parameter templates (parameter_key)
  - rollups (1m/5m/hourly)
  - registry context (device/site/project/customer)

**4. Be AI-upgradeable without rework**

- Today: KPI and alert logic may be deterministic (thresholds, comparisons).
- Tomorrow: AI can add risk, recommendation, or anomaly flags into the same structure.

---

### 5.2 KPI Object – Canonical Frontend Contract

Every KPI shown on NSWare dashboards must follow a standard JSON object, independent of industry.

```json
{
  "kpi_key": "kpi.flow.rate",
  "title": "Flow Rate",
  "scope": {
    "customer_id": "UUID",
    "project_id": "UUID",
    "site_id": "UUID",
    "device_id": "UUID"
  },
  "value": 112.4,
  "unit": "kg/h",
  "state": "normal | warning | critical | inactive",
  "baseline": {
    "value": 105.0,
    "window": "7d"
  },
  "limits": {
    "min": 0,
    "max": 200,
    "warning_low": 70,
    "warning_high": 160,
    "critical_low": 50,
    "critical_high": 180
  },
  "trend": {
    "direction": "up | down | flat",
    "change_pct": 3.2,
    "period": "1h"
  },
  "ai": {
    "enabled": false,
    "risk": null,
    "confidence": null,
    "top_factors": []
  },
  "timestamp": "2025-11-18T12:10:00Z",
  "source": {
    "type": "computed | raw | aggregated",
    "parameter_keys": [
      "project:<uuid>:flow",
      "project:<uuid>:pressure"
    ]
  }
}
```

**Key points:**

- `kpi_key` is KPI-level identity (e.g., `kpi.flow.rate`), not the raw `parameter_key`.
- `scope` always includes `customer_id` (tenant boundary).
- `limits` are where customer-specific tuning lives (per customer or project).
- `ai` block is reserved for future AI use, but is present from Day 1.

---

### 5.3 KPI Categories (Process-Facing, Not System-Facing)

To keep NSWare generic, we define KPI categories (not fixed names):

**1. Flow / Throughput KPIs**

- Examples: `kpi.flow.rate`, `kpi.production.rate`, `kpi.volume.throughput`

**2. Pressure / Head / Level KPIs**

- Examples: `kpi.pressure.line`, `kpi.level.tank`

**3. Temperature / Quality KPIs**

- Examples: `kpi.temperature.supply`, `kpi.quality.metric`

**4. Energy / Efficiency KPIs**

- Examples: `kpi.energy.consumption`, `kpi.efficiency.overall`

**5. Uptime / Availability KPIs**

- Examples: `kpi.uptime.device`, `kpi.availability.site`

**6. Custom Domain KPIs**

- Placeholders for domain-specific KPIs (e.g., `kpi.waste.ratio`, `kpi.yield.rate`)

**Important:**

- KPI engine is agnostic to industry.
- A steam-house, water plant, or chemical reactor simply maps its own "meaning" into these categories.

---

### 5.4 KPI State Model

The `state` field is a visual summarization of KPI condition for tiles:

**Possible values:**

- `normal`
- `warning`
- `critical`
- `inactive` (KPI disabled / not applicable / no data)

**How state is derived (high-level):**

- Backend combines:
  - latest value
  - limits
  - quality flags
  - optional AI risk
- Frontend only renders, never re-computes state.

**Example mapping:**

- If `value > critical_high` → `state = "critical"`
- Else if `value > warning_high` → `state = "warning"`
- Else if no data in last N minutes → `state = "inactive"`
- Else → `state = "normal"`

**Rule:**

Exact logic lives in backend KPI computation layer.

UI should assume state is already correct.

---

### 5.5 Alert Object – Canonical Frontend Contract

Alerts are events generated when KPI or conditions cross thresholds.

An alert is not a KPI; it references a KPI or condition.

```json
{
  "alert_id": "uuid-alert-001",
  "alert_key": "alert.flow.high",
  "title": "High Flow",
  "scope": {
    "customer_id": "UUID",
    "project_id": "UUID",
    "site_id": "UUID",
    "device_id": "UUID"
  },
  "level": "info | warning | critical",
  "state": "active | acknowledged | resolved | suppressed",
  "message": "Flow rate above high warning threshold",
  "kpi_key": "kpi.flow.rate",
  "value": 180.2,
  "unit": "kg/h",
  "threshold": {
    "type": "high | low | roc | windowed",
    "value": 160.0
  },
  "timestamps": {
    "raised_at": "2025-11-18T12:05:00Z",
    "acknowledged_at": null,
    "resolved_at": null
  },
  "ai": {
    "enabled": false,
    "root_cause": null,
    "suggested_action": null
  }
}
```

**Key fields:**

- `alert_key` – static identity (e.g. `alert.flow.high`, `alert.pressure.low`)
- `level` – severity (info/warning/critical)
- `state` – lifecycle control for operator (see next section)
- `kpi_key` – link back to KPI
- `scope.customer_id` – tenant boundary
- `timestamps` – alert lifecycle tracking

---

### 5.6 Alert Lifecycle & Reset / Acknowledge Model

NSWare follows a simple, SCADA-like alert lifecycle.

**States:**

1. **active**
   - Condition currently violated (e.g., above high threshold).

2. **acknowledged**
   - Operator has seen the alert.
   - Visual emphasization reduced, but still present.

3. **resolved**
   - Condition no longer violated.
   - Alert stays in history, but not in active panel.

4. **suppressed** (optional future)
   - Alerts temporarily muted for known conditions/maintenance.

**Operator interactions (via UI):**

- **Acknowledge:**
  - Frontend sends `PATCH /alerts/:alert_id { "state": "acknowledged" }` (or similar).
  - Only allowed for correct roles.

- **View History:**
  - Frontend filters: `state = active` or `state IN (resolved, acknowledged)`.

**Rule:**

Backend defines the lifecycle transitions;

frontend only exposes buttons and updates state via API.

---

### 5.7 KPI ↔ Alert Relationship

One KPI can have:
- Multiple alert types (low, high, rate-of-change, windowed condition).
- Different thresholds per site or customer.

**Example:**

- `kpi.flow.rate` could have:
  - `alert.flow.high`
  - `alert.flow.very_high`
  - `alert.flow.instability` (based on variance)

**Front-end usage:**

- **Main KPI tile:**
  - Shows value, state (normal/warning/critical).

- **Alert list tile:**
  - Shows rows for active alerts linked to that KPI.

- **Tile drill-down can show:**
  - KPI time series
  - Alert overlay on graph
  - Alert timeline (when raised/ack/resolved)

---

### 5.8 Tenant-Scoped KPI Profiles (Per Customer)

The same KPI key may be interpreted differently for different customers.

**Example:**

- **Customer A:**
  - `kpi.flow.rate` critical above 200 kg/h

- **Customer B:**
  - `kpi.flow.rate` critical above 350 kg/h

**To support this:**

- Backend maintains per-customer KPI profile, containing:
  - enabled KPIs
  - KPI display name
  - units (if overridden)
  - thresholds (warning/critical)
  - alert enable/disable flags

**UI Behavior:**

- Always reads ready-to-render KPI object with correct thresholds and state.
- Does not recalculate, only displays.

**Design Decision:**

- Profiles live in backend, not in frontend.
- Frontend is 100% driven by KPI object and Alert object contracts.

---

### 5.9 How This Connects to Parameter Templates & NSReady

Even though KPI keys are abstract (e.g., `kpi.flow.rate`), they are always grounded in NSReady data:

- A KPI is backed by:
  - one or more `parameter_keys` from NSReady registry, and/or
  - one or more rollup views (continuous aggregates)

**Example:**

```json
"source": {
  "type": "computed",
  "parameter_keys": [
    "project:8212caa2-...:flow",
    "project:8212caa2-...:pressure"
  ]
}
```

**High-level mapping:**

- **NSReady v1 (Current - Data Collection Layer):**
  - `parameter_templates` define raw measurements.
  - `ingest_events` stores raw time-series.
  - SCADA views expose latest/history data.
  - Operational health endpoints (`/v1/health`, `/metrics`).

- **NSWare Phase-2 (Future - Process KPI Layer):**
  - KPI engine defines KPI dictionary (`kpi_key` → formula).
  - Alerts refer to KPI dictionary entries.
  - Dashboards only see KPI & alert objects, not raw formulas.
  - KPI computation reads from NSReady `ingest_events` and rollups.

**Implementation Timeline:**

- **NSReady v1** (Current): ✅ Data collection foundation exists
  - Registry, ingestion, storage, SCADA views, operational health
  
- **NSWare Phase-2** (Future): ⏳ KPI/Alert engine to be implemented
  - KPI dictionary, KPI profiles, alert lifecycle storage
  - Process KPI computation engine
  - Alert generation and management
  - Customer-facing process dashboards

**Separation of Concerns:**

- **NSReady operational dashboards** (current): Registry config, packet health, ingestion logs, SCADA export → See `PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`
- **NSWare process dashboards** (future): Steam efficiency, water loss, power consumption, process KPIs → This Part 5

---

### 5.10 Summary – KPI & Alert Model

**Part 5 defines the architecture contract for NSWare Phase-2 (future process KPI & alert engine).**

**What Part 5 Defines:**

- **A canonical KPI object**, with:
  - `kpi_key`, scope, value, unit, state, limits, trend, AI hooks.

- **A canonical Alert object**, with:
  - `alert_key`, level, state, message, timestamps, KPI linkage.

- **A simple alert lifecycle** (active → acknowledged → resolved (+ future suppressed)).

- **A clear separation:**
  - Backend computes KPI, state, and alerts.
  - Frontend displays and updates lifecycle (ack/reset).

- **Tenant isolation at KPI level:**
  - Every KPI and alert is tied to `customer_id`.

- **Future AI-compatible design:**
  - AI risk, confidence, and explanation fields already included in KPI & Alert objects.

**What Part 5 Is NOT:**

- ❌ Not part of NSReady v1 (data collection software)
- ❌ Not about operational health (queue depth, packet health)
- ❌ Not about registry configuration or ingestion monitoring

**What Part 5 IS:**

- ✅ Architecture blueprint for NSWare Phase-2 process KPI engine
- ✅ Contract for how process KPIs (steam, water, power) will be defined
- ✅ Design for customer-facing process dashboards (future)
- ✅ Foundation for AI/ML integration in process analytics

**Relationship to NSReady:**

This keeps NSWare:
- Consistent across industries
- Safe across tenants
- Aligned with NSReady backend & parameter contracts
- Ready for future AI/ML integration
- **Built on top of** NSReady data collection foundation

**For NSReady v1 operational dashboards**, see `PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`.

---

---

## 6. Tenant Isolation & Access Control (UI/UX Layer)

This section defines how the NSWare dashboard must enforce tenant isolation, customer-specific access, engineer-only sections, and temporary controlled privileges without changing backend design.

This is a **UI/UX + API-interaction layer**, built on top of the tenant model already formalized in:
- `NSREADY_BACKEND_MASTER.md` Section 9 (Tenant Model & Multi-Customer Isolation)
- `docs/TENANT_MODEL_SUMMARY.md` (Core Rule: `tenant_id = customer_id`)
- `docs/TENANT_DECISION_RECORD.md` (ADR-003)

---

### 6.1 Purpose of Tenant Isolation Rules

The dashboard must guarantee **four outcomes**:

**A. Each customer sees only their own data**

- No mixing of Projects/Sites/Devices belonging to another customer.
- No access to other tenants even by mistake.

**B. Engineers have elevated access**

- Can see and configure NSReady operational dashboards.
- Can access metadata, registry checks, packet timelines, SCADA export monitors.
- Customers cannot.

**C. Optional controlled access for customers**

- Customer may be allowed to add Sites or Devices if enabled.
- Customer may view health summary only (not system internals).
- Temporary access tokens can be granted by engineer.

**D. Customer Groups (parent_customer_id)**

- Can only access aggregated dashboards for subsidiaries.
- Cannot modify registry entries of child companies.

---

### 6.2 Tenant Boundary (UI Rule)

Everything in the UI flows from one universal rule:

```
frontend.tenant_id = backend.customer_id
```

This is the UI version of the backend rule.

**What this means in practice:**

| UI Section | Tenant Boundary | Behavior |
|------------|----------------|----------|
| Customer Dashboards | `customer_id` | Shows KPIs/alerts for that customer only |
| Site Dashboard | `site_id + customer_id` | Prevents cross-customer drill-down |
| Device Dashboard | `device_id + customer_id` | Ensures device belongs to customer |
| Operational Dashboards | `engineer role only` | Never visible to customers |
| Group Dashboards | `parent_customer_id` | Aggregated view only |

---

### 6.3 Role Definitions (UI side)

The dashboard supports **5 roles**:

| Role | Description | Access |
|------|-------------|--------|
| **Engineer** | Company-level admin | All dashboards, all configuration |
| **Customer Admin** | Customer's manager | Customer dashboards + limited site creation |
| **Site Operator** | Operator of single site | Site dashboard + device pages |
| **Read-Only** | Viewer | Cannot modify anything |
| **Group Admin** | OEM/distributor | Group dashboards only |

---

### 6.4 Role–Feature Matrix

This tells exactly what each role can and cannot see.

#### Customer-Facing Dashboards (Parts 1–4 KPIs)

| Feature | Engineer | Customer Admin | Site Operator | Group Admin | Read Only |
|---------|----------|----------------|---------------|-------------|-----------|
| Customer Main Dashboard | ✔ | ✔ | Limited | ✔ (group-level) | ✔ |
| Site Dashboard | ✔ | ✔ | ✔ | ✖ | ✔ |
| Device Dashboard | ✔ | ✔ | ✔ | ✖ | ✔ |
| KPI Drilldown | ✔ | ✔ | ✔ | ✔ (group summary) | ✔ |
| Alert Acknowledge | ✔ | ✔ | ✔ | ✖ | ✖ |

#### NSReady Operational Dashboards

| Operational Dashboard | Engineer | Customer Admin | Site Operator | Group Admin | Read Only |
|----------------------|----------|----------------|---------------|-------------|-----------|
| Registry Configuration | ✔ | ✖ | ✖ | ✖ | ✖ |
| Collection Health | ✔ | optional (limited view) | ✖ | ✖ | ✖ |
| Ingestion Logs | ✔ | ✖ | ✖ | ✖ | ✖ |
| SCADA Export Monitor | ✔ | ✖ | ✖ | ✖ | ✖ |
| System Health Dashboard | ✔ | ✖ | ✖ | ✖ | ✖ |

**Customer Admin Optional Access:**

Can view Collection Health (Summary Only) if enabled by engineer.

---

### 6.5 Customer-Enabled Configuration (Carefully Controlled)

**You clarified:**

"Customers may add multiple sites and multiple devices; common parameters remain same, only named values change."

The UI must support:

**A. Customer-Allowed Site Creation (Optional Toggle)**

- Engineer toggles: "Allow customer to add Site"
- Customer Admin can:
  - Create Site
  - Create Devices under that Site
  - Copy–Paste templates for mass addition (100 sites easily)

**B. Customer-Allowed Device Configuration**

- Customer Admin can:
  - Add devices
  - Rename devices
  - Set device metadata (location, tags)

**C. Customer cannot modify:**

- Customer record
- Project record
- Parameter Templates (engineer only)
- SCADA export settings
- Data collection engine settings
- Packet thresholds
- Ingestion logic
- System health settings

---

### 6.6 Temporary Access Tokens for Customers

**Your requirement:**

"Temporary access to health check is required to give customers; engineer controls activation."

**Solution:**

- Engineer generates temporary access token:
  - Valid for 24 hours (configurable)
  - Only works for Collection Health Dashboard Summary
  - Does not expose ingestion logs, SCADA export monitor, or DB status

**Token Format Example:**

```
/operational/health/:customer_id?token=XYZ123
```

**Token Expiry:**

- Automatically disables
- Logged for audit
- Engineer can revoke manually

---

### 6.7 Frontend Enforcement Formula

For every page load, UI must evaluate:

```
if (!auth.customer_id == route.customer_id) → BLOCK
if (feature == 'operational_dashboard' && role != engineer) → BLOCK
if (feature == 'customer_config_site_add' && !engineer.enabled_toggle) → BLOCK
if (token.present) → apply temporary rules
```

**ZERO business logic on the frontend.**

All rules also validated by backend APIs.

---

### 6.8 "Customer Groups / OEM Model" (Supported UI Behavior)

Customers with subsidiaries (e.g., OEMs) get:

**Group Dashboard (Parent Customer)**

- Aggregated KPIs from all children
- Summary alerts
- Rollups (total flow, total uptime, total consumption)

**Child Dashboard (Tenant)**

- Standard dashboard (customer-specific)
- Cannot see siblings
- Cannot modify group-level settings

**Rule:**

Parent is **NOT** tenant boundary.

Child is **ALWAYS** tenant.

This aligns with `NSREADY_BACKEND_MASTER.md` Section 9.2 (Customer Hierarchy).

---

### 6.9 Tenant Isolation in Tiles, KPIs, Alerts (Strict Rules)

Every tile, KPI, and alert must include:

```json
"scope": {
  "customer_id": "UUID"
}
```

This prevents accidental leakage.

**UI never loads:**

- Tiles with mismatched `customer_id`
- Alerts for another customer
- KPIs tied to other tenants

**Backend double-checks everything.**

This aligns with:
- Part 3 (Universal Tile System) — tiles include scope
- Part 4 (Dashboard JSON) — dashboard scope includes `customer_id`
- Part 5 (KPI & Alert Model) — KPI/Alert objects include scope

---

### 6.10 Tenant Isolation for Future AI & Explainability

When Phase 2 ML & anomaly detection arrives:

- Every model score includes `tenant_id`/`customer_id`
- No cross-customer training sets
- No shared baselines
- No mixing prediction features
- No shared vector memories
- AI explanations must be scoped per tenant

The UI must reserve space for:

- `alert.ai.explanations[]`
- `kpi.ai.risk`
- `kpi.ai.confidence`

All tenant-scoped.

This aligns with:
- Part 5 Section 5.2 (KPI Object AI hooks)
- Part 5 Section 5.5 (Alert Object AI hooks)
- `NSREADY_BACKEND_MASTER.md` Section 9.6 (Tenant Context for Future NSWare AI/ML Layer)

---

### 6.11 Summary of Part 6

Part 6 establishes the **UI/UX isolation framework** for NSWare dashboards:

- ✅ **Tenant = customer_id** (aligns with backend rule)
- ✅ **Parent = reporting layer only** (not tenant boundary)
- ✅ **Engineer = full access** (operational dashboards)
- ✅ **Customer = limited config** (sites/devices if enabled)
- ✅ **Operator = site-level only** (restricted scope)
- ✅ **Group admin = aggregate view only** (read-only rollups)
- ✅ **Temporary access tokens allowed** (health summary only)
- ✅ **Every KPI / Alert / Tile is tenant-scoped**
- ✅ **AI future-proofing is included**

This keeps NSWare:

- **Safe** (no cross-tenant leakage)
- **Industry neutral** (generic role model)
- **Multi-customer manageable** (scales to many tenants)
- **Ready for future AI features** (tenant-scoped ML)
- **Strictly aligned with backend tenant model** (no conflicts)

**Cross-References:**

- Backend Tenant Model: `NSREADY_BACKEND_MASTER.md` Section 9
- Tenant Summary: `docs/TENANT_MODEL_SUMMARY.md`
- KPI/Alert Scope: Part 5 Sections 5.2, 5.5
- Tile Scope: Part 3 Section 3.6
- Dashboard Scope: Part 4 Section 4.3

---

---

## 7. UX Mockup & Component Layout System

(Wireframe-level spec for NSReady + NSWare dashboards)

This part describes the visual skeleton of the UI — the common layout, key screens, and control patterns for:
- **NSReady Operational UI** (configuration + health)
- **NSWare Process Dashboards** (customer-facing KPIs)

It stays at **wireframe/structure level**, not colors or fonts (those are in Part 1 Section 5), and assumes:
- Frontend is a **data entry + viewing tool**
- All persistence happens via **API calls to NSReady backend**
- **CSV is optional, controlled, and password-protected for engineers only**

---

### 7.1 Global Layout Shell (All Screens)

Every NSWare/NSReady screen follows a shared shell:

```
+-------------------------------------------------------+
| Top Bar                                               |
| [Logo/Name]  [Tenant/Customer Selector]  [Time Range] |
| [User Menu]  [Settings]                              |
+---------------------+---------------------------------+
| Left Sidebar        | Main Content (Tiles/Forms)      |
| - Navigation        |                                 |
|   - Home            |  [Section header]               |
|   - Dashboards      |  [Rows of tiles or forms]       |
|   - Operational     |                                 |
|   - Settings        |                                 |
+---------------------+---------------------------------+
```

#### Top Bar (Global)

- **Left:** Product name / logo (generic)
- **Center:** Context selectors
  - Tenant/Customer (if engineer or group admin)
  - Time range (Last 1h, 24h, 7d, custom)
- **Right:** User menu (role, logout), Settings

#### Left Sidebar (Role-aware)

**Main Sections:**

- **Dashboards**
  - Customer main
  - Site list
  - Device list

- **Operational** (Engineer only)
  - Registry
  - Collection Health
  - Ingestion Logs
  - SCADA Export
  - System Health

- **Settings**
  - User/role management (future)
  - Feature toggles (future)

#### Main Content Area

- Uses **Sections → Rows → Tiles/Forms** as defined in **Parts 3 & 4**
- For configuration pages, the "tiles" are often form blocks or tables

**This layout aligns with:**
- Part 2 Section 2.3 (Navigation Components)
- Part 1 Section 5 (Theme System)
- Part 4 Section 4.4 (View Hierarchy)

---

### 7.2 NSReady Operational Screens (Wireframe)

We define **five key NSReady operational screens**. These reuse the same shell and tile system, but content is focused on **data collection software health and configuration**, not process KPIs.

For complete specifications, see `master_docs/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`.

---

#### 7.2.1 Operational Home (Engineer Landing)

**Route:** `/operational/:customer_id/home`

**Purpose:** One-page summary of NSReady status for a customer.

**Wireframe:**

- **Top:** "Operational Overview – [Customer Name]"
- **Row 1** (4 KPI tiles):
  - Devices Configured vs Active
  - Packet On-Time %
  - Missing Packets (last 24h)
  - Late Packets (last 24h)
- **Row 2** (2 tiles):
  - Site Health table (Status per site)
  - System Health summary (Service, Queue, DB)
- **Row 3:**
  - "Open Issues / Errors (last 24h)" (alert list)

**Actions:**

- Each tile's drilldown heads to the relevant operational screen:
  - Site Health → `/operational/health/:customer_id`
  - System Health → `/operational/system/health`
  - Errors → `/operational/logs/:customer_id`

**Uses:**
- Part 3 (Universal Tile System)
- Part 4 (Dashboard JSON structure)
- Part 6 Section 6.4 (Role-based access - Engineer only)

---

#### 7.2.2 Registry Configuration Screen

**Route:** `/operational/registry/:customer_id`

**Users:** Engineer (config), Customer Admin (read-only or restricted site/device add)

**Wireframe Layout:**

**Left Column (Hierarchy):**

- **Tree view:**
  - Customer
  - Projects
  - Sites
  - Devices

**Right Column (Details + Forms):**

- **Top panel:** Selected Node Details
  - Shows fields based on type (Project/Site/Device)
- **Middle panel:** Parameter Templates (read-only list)
  - Table: `parameter_name`, `unit`, `type`, `key`
- **Bottom panel:** Actions (role-dependent)
  - **Engineer:**
    - Add Project/Site/Device
    - Bulk add (table + copy/paste)
    - CSV upload/download (password-protected)
  - **Customer Admin:**
    - Optional: Add Site / Device via protected forms
    - No access to CSV upload/download

**Copy–Paste Bulk Pattern:**

- A table with N rows and columns:
  - Site name, Device name, Device code, etc.
- "Add 10 rows" button
- Allow user to copy rows from Excel → paste into grid
- All common parameters auto-populated; user changes only name/tag/site fields

**Uses:**
- Part 6 Section 6.5 (Customer-Enabled Configuration)
- Part 6 Section 6.4 (Role-based access)
- Part 7 Section 7.4 (Data Entry Patterns)

---

#### 7.2.3 Collection Health Screen

**Route:**
- Engineer: `/operational/health/:customer_id`
- Temp token (customer view): `/operational/health/:customer_id?token=XYZ`

**Wireframe Layout:**

**Row 1:** KPI/Health tiles:
- Devices Configured vs Active (KPI)
- Packet On-Time % (Health)
- Missing Packets (Alert)
- Late Packets (Alert)

**Row 2:** Site Health table:
- Columns: Site, Devices, On-Time %, Missing, Late, Last Packet Time, Status

**Row 3:** Device Health table (for selected Site):
- Columns: Device, Last Packet, Gaps, Status

**Behavior:**

- Engineer sees full details.
- Customer (with temporary token or limited permission) sees only aggregated KPIs and tables, no deep error logs.

**Uses:**
- Part 6 Section 6.6 (Temporary Access Tokens)
- Part 3 (Tile System - KPI, Health, Alert tiles)
- Part 6 Section 6.4 (Role-based access)

---

#### 7.2.4 Ingestion Logs Screen

**Route:** `/operational/logs/:customer_id`

**Users:** Engineer only

**Wireframe Layout:**

**Top:** Filter bar
- Time range
- Site (dropdown)
- Device (dropdown)
- Parameter (dropdown)
- Error type

**Main Panel:**

- **Upper half:** Event Timeline Chart (trend tile)
  - Events over time
  - Highlighted error points
- **Lower half:** Error Log Table
  - Columns: Time, Device, Parameter, Error Type, Message, Trace ID
  - Click row → opens detailed modal

**Modal:**

- Shows complete NormalizedEvent payload (read-only)
- Shows how it was stored in `ingest_events`
- Trace chain for future AI debugging

**Uses:**
- Part 3 (Trend Tile for timeline)
- Part 6 Section 6.4 (Engineer-only access)
- Backend Master Section 5.3 (NormalizedEvent contract)

---

#### 7.2.5 SCADA Export Monitor Screen

**Route:** `/operational/scada/:customer_id`

**Users:** Engineer only

**Wireframe Layout:**

**Row 1:**
- **Left:** "Latest SCADA Values" table (from `v_scada_latest`)
- **Right:** "Export Status" (last N exports, success/fail)

**Row 2:**
- "SCADA Mapping Summary":
  - Device → `device_code` mapping status
  - Parameter → `parameter_key` mapping status

**Row 3:**
- Optional: "Test Export Now" button (engineer only, triggers safe export)

**Uses:**
- Backend Master Section 8 (SCADA Integration)
- Part 6 Section 6.4 (Engineer-only access)
- Database views: `v_scada_latest`

---

#### 7.2.6 System Health Screen

**Route:** `/operational/system/health`

**Users:** Engineer only

**Wireframe Layout:**

**Row 1:**
- Service Status (health tile)
- Queue Depth (KPI)
- DB Status (health tile)
- Redelivered Messages (alert)

**Row 2:**
- Events queued (KPI)
- Events success (KPI)
- Events errors (alert)
- Queue Depth (gauge)

**Row 3:**
- Raw JSON view of `/v1/health`
- Selected metrics from `/metrics` (text/log view or mini-chart)

**Uses:**
- Backend Master Section 6 (Health Monitoring)
- Part 3 (Health, KPI, Alert tiles)
- Backend APIs: `/v1/health`, `/metrics`

---

### 7.3 Customer-Facing NSWare Dashboards (Structural Recap)

For completeness, **NSWare customer dashboards** continue to use:
- Same shell (Top bar + Sidebar + Main content)
- Same tile system
- Same Dashboard JSON structure
- But with **process KPIs**, not operational metrics.

**Examples:**

- **Customer Main:** Steam/water/power KPIs (Phase 2 - future)
- **Site View:** Process performance, consumption KPIs
- **Device View:** Device-specific KPIs, trends

**This stays consistent with Parts 1–4; Part 5 and 6 just added the operational branch.**

**For NSWare Phase-2 process KPIs**, see Part 5 (KPI & Alert Model - future).

---

### 7.4 Data Entry & Bulk Configuration Patterns

This section formalizes the front-end patterns we need for **configuration related to the data collection software**.

---

#### 7.4.1 Single Record Form (Site / Device)

**Appears on right panel** when node selected in registry tree.

**Basic fields:**

- **Site:** Name, Location, Description
- **Device:** Name, Code, Type, Site, Notes

**Validation:**

- Required fields highlighted
- Errors shown inline

**Save modes:**

- "Save & Close"
- "Save & Add Another" (for operator efficiency)

**Uses:**
- Part 6 Section 6.5 (Customer-Enabled Configuration)
- Part 7 Section 7.5 (Validation Patterns)

---

#### 7.4.2 Bulk Copy–Paste Table (100+ Sites/Devices)

**Key requirement from you:**

"Customer wants to include 100 sites, all device configuration same except tag/name/site."

**Pattern:**

- Engineer or allowed Customer Admin opens Bulk Add panel.
- UI shows an empty table with columns:
  - Site Name
  - Device Name
  - Device Code
  - Device Type
  - Any other per-row fields

**Features:**

1. "Add N rows" button
2. Copy from Excel → Paste directly into table
3. Default values (for common parameters) auto-populated
4. Edit single column across all selected rows (e.g., device type)
5. Preview before submit
6. Submit sends a single JSON payload to backend:

```json
{
  "customer_id": "...",
  "sites": [...],
  "devices": [...]
}
```

**Backend:**

- Applies same registry import logic as `import_registry.sh`, but via API
- Enforces uniqueness, validation, and FK rules

**Uses:**
- Part 6 Section 6.5 (Customer-Enabled Configuration)
- Backend Master Section 4 (Registry & Parameter Templates)
- API endpoint: Registry import API (future)

---

#### 7.4.3 CSV Upload/Download (Engineer-Only Tool)

We keep CSV import/export as a **controlled configuration tool**, NOT the primary editing mechanism.

**Location:**

- Registry Configuration Screen → Bottom Actions Panel

**UI Rules:**

- CSV actions are:
  - **Hidden by default**
  - **Shown only when:**
    - User = Engineer
    - Additional security: "Unlock CSV Tools" (password or 2FA)
- **Options:**
  - Download current registry as CSV
  - Upload modified CSV (with dry-run and diff preview)

**Purpose:**

- Engineer can perform bulk operations safely
- Customers still work via UI forms + copy-paste tables

**This aligns with your requirement:**

"CSV remains rare, locked for authorized engineer."

**Uses:**
- Part 6 Section 6.4 (Role-based access - Engineer only)
- Part 6 Section 6.3 (Role Definitions)

---

### 7.5 Validation, Errors & Feedback Patterns

---

#### 7.5.1 Inline Field Validation

For any form (Site, Device, Bulk table):

- **Instant feedback on:**
  - Duplicate `device_code`
  - Invalid characters
  - Missing required fields
- **Summary error bar** at top of form

---

#### 7.5.2 Global Notification Panel

**Success messages:**

- "Site created successfully"
- "10 devices added successfully"

**Error messages:**

- "3 rows failed due to missing fields"
- "Parameter key invalid—see details"

---

#### 7.5.3 Operational Health Linking

From error messages, provide:

- "View in Collection Health" link
- "View in Ingestion Logs" link

So the engineer can jump from config → health.

**Uses:**
- Part 7 Section 7.2.3 (Collection Health Screen)
- Part 7 Section 7.2.4 (Ingestion Logs Screen)

---

### 7.6 Responsive Behaviour (Web + Tablet, Optional Mobile)

**Desktop:**

- Full sidebar + top bar + 3-section main content
- Most tiles and tables visible

**Tablet:**

- Collapsible sidebar
- Some tiles stack vertically
- Table columns reduce via priorities

**Mobile (optional emphasis later):**

- Bottom navigation bar for core items:
  - Dashboards
  - Operational
  - Alerts
  - Settings
- Light versions of:
  - Site summary
  - Device health
  - Key alerts

**Operational/config screens can be desktop-first for now.**

**This aligns with:**
- Part 2 Section 2.8 (Multi-Device Personality Model)
- Part 1 Section 5 (Theme System - responsive grid)

---

### 7.7 Summary of Part 7

Part 7 delivers the **wireframe-level UX spec** for:

1. **Global shell:** top bar, sidebar, main content
2. **NSReady operational screens:** registry, health, logs, SCADA export, system health
3. **Customer-facing dashboards:** structurally consistent with earlier parts
4. **Data entry patterns:** single forms + bulk copy-paste + controlled CSV
5. **Error/validation UX:** inline + global notifications
6. **Tenant context:** baked into all routing and scope
7. **Future AI hooks:** space reserved in tiles and modals

**This keeps front-end exactly as you wanted:**

- ✅ Primarily **data entry and health viewing**
- ✅ All persistence via **API**
- ✅ **CSV as rare, controlled, engineer-only backup tool**
- ✅ Operational dashboards tightly tied to the data collection engine, not process KPIs

**Cross-References:**

- **Part 1 Section 5:** Theme System (colors, typography)
- **Part 2 Section 2.3:** Navigation Components
- **Part 3:** Universal Tile System
- **Part 4:** Dashboard JSON structure
- **Part 6:** Tenant Isolation & Access Control
- **PART5_NSREADY_OPERATIONAL_DASHBOARDS.md:** Complete operational dashboard specs
- **Backend Master Section 6:** Health Monitoring APIs
- **Backend Master Section 8:** SCADA Integration

---

---

## 8. Performance & Caching Model (NSWare Dashboard Layer)

This section defines how NSWare dashboards should use the NSReady/NSWare backend in a performant way, without overloading:
- The ingestion pipeline
- The database
- Or the browser/front-end

It focuses on:
- API call patterns
- Polling intervals
- Use of rollup views vs raw data
- Per-tenant caching
- Chart/time-range limits
- Degraded/readonly behaviour

**All rules here assume the backend architecture defined in `NSREADY_BACKEND_MASTER.md` is already in place** (NATS + Worker + Timescale + rollups).

---

### 8.1 Principles for Dashboard Performance

NSWare dashboards follow these **performance principles**:

**1. Read from rollups, not the raw firehose**

- Raw table `ingest_events` is for ingestion and diagnostics.
- Dashboards should primarily read from:
  - `v_scada_latest` (current values)
  - Rollup/aggregate views (1-minute, 5-minute, hourly)
- Only short, tight debug views may read near-raw data (and always with strong time filters).

**2. Per-tenant performance isolation**

- All queries and caches are scoped by `customer_id`.
- One noisy tenant must not affect others.

**3. Time-bounded queries by default**

- **Default time ranges:**
  - Last 1 hour (live ops)
  - Last 24 hours (shift view)
  - Last 7 days (management view)
- Anything longer must hit rollups, not raw.

**4. Backend decides shape, frontend renders**

- Backend returns pre-shaped JSON (dashboard + tiles).
- Frontend does minimal aggregation/transformation.

**5. Predictable, capped API usage**

- Every page type has a defined polling interval.
- No uncontrolled polling loops.

**This aligns with:**
- Backend Master Section 7.9 (Time-Series Modeling Strategy)
- Backend Master Section 7.6 (SCADA Views - read-only, rollup-based)
- Part 4 Section 4.3 (Backend-Powered View Engine)

---

### 8.2 Page-Type Based Data Refresh Strategy

Different dashboards have different refresh needs:

| Page Type | Typical User | Refresh Pattern |
|-----------|--------------|-----------------|
| Live Telemetry (Operator) | Control room, shift | 5–10 seconds polling |
| Site Dashboard | Site engineer | 15–60 seconds polling |
| Device Dashboard | Diagnostics | Manual refresh + 30–60 s |
| Management Overview | Management | Manual / 5–15 minutes |
| Operational Health (NSReady) | Internal engineer | 10–30 seconds polling |
| AI Insights (Future) | Analyst/engineer | Manual / on demand |

**Rules:**

- No dashboard should poll faster than every 5 seconds.
- Management views should default to manual or slow refresh.
- Mobile views should be explicit refresh, not auto-poll, unless configured.

**This aligns with:**
- Part 7 Section 7.2 (NSReady Operational Screens)
- Part 7 Section 7.6 (Responsive Behaviour)
- Part 2 Section 2.4 (Dashboard Page Types)

---

### 8.3 API Call Patterns (Per Page Load)

Every dashboard page should aim to use **one main API call**:

```
GET /api/dashboard/:dashboard_id?customer_id=...&scope=...
```

The response is the **Dashboard JSON defined in Part 4**, including:
- `sections[]`
- `tiles[]`
- `metadata`

**Supplementary calls** (allowed, but controlled):

- `GET /api/device/:device_id/metrics?...` — only for deep drill-down
- `GET /api/alerts?customer_id=...&time_range=...` — for alert lists
- `GET /api/health?customer_id=...` — for tenant-specific health

**Rules:**

1. Use Dashboard JSON as the primary orchestration call.
2. Avoid N+1 patterns (`/api/device` called for each tile).
3. If extra data is needed, group it into list APIs (e.g., `/api/devices?site_id=...`).

**This aligns with:**
- Part 4 Section 4.3 (Dashboard JSON structure)
- Part 4 Section 4.8 (API Binding Contract)
- Backend Master Section 6 (Health API)

---

### 8.4 Caching Strategy (Client + Server)

---

#### 8.4.1 Client-Side Caching

On the browser/UI side:

- **Cache Dashboard JSON per route + tenant:**
  - Key pattern: `dashboard:<tenant_id>:<dashboard_id>:<scope_hash>`
- **Cache lifetime:**
  - Live pages: 5–10 seconds
  - Management pages: 1–5 minutes
- **Use:**
  - Stale-while-revalidate: show cached, refetch in background.

---

#### 8.4.2 Server-Side Caching (Optional NSWare Layer)

On the API layer (NSWare):

- **Cache pre-computed Dashboard JSON** for expensive views:
  - Group dashboards
  - Multi-site summaries
- **Invalidate when:**
  - Underlying rollup views are refreshed
  - Registry changes (new site/device) occur

**Rules:**

- Never cache across tenants. Scope caches by `customer_id`.
- For live telemetry, prefer short-lived caches or direct DB access.

**This aligns with:**
- Part 6 Section 6.9 (Tenant Isolation in Tiles, KPIs, Alerts)
- Part 6 Section 6.7 (Frontend Enforcement Formula)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)

---

### 8.5 Data Sources per Tile Type

Each tile type should use the **lightest possible data source**:

| Tile Type | Preferred Source |
|-----------|-----------------|
| KPI Tile | Rollup views (`vw_customer_kpi_summary`, etc.) |
| Health Tile | Health views (`vw_site_health`, `vw_device_health`) |
| Alert Tile | Alert tables / views (`vw_alerts_recent`) |
| Trend Tile | Rollups (1m/5m/hourly), not raw `ingest_events` |
| Asset Tile | Registry tables (`devices`, `sites`) |
| AI Insight | AI scoring API / `inference_log` (future) |

**Golden rule:**

- Only debug / NSReady internal tools touch near-raw data.
- Customer dashboards must stay on top of rollups/aggregates.

**This aligns with:**
- Part 3 Section 3.1 (Tile Categories)
- Part 3 Section 3.6 (Tile Data Binding)
- Backend Master Section 7.9 (Time-Series Modeling Strategy)
- Backend Master Section 7.6 (SCADA Views)

---

### 8.6 Chart & Time-Range Guardrails

To avoid performance surprises, NSWare dashboards must implement:

**1. Point limits per chart**

- **Max points:**
  - Desktop: 1,000–2,000 points per chart
  - Mobile: 200–500 points per chart
- If a query would return more, backend must:
  - Aggregate further (e.g., group by 5m instead of 1m)
  - Or reject with a polite error (e.g., "Use a shorter time range")

**2. Time-range presets**

- **Suggested presets:**
  - Last 15 minutes
  - Last 1 hour
  - Last 6 hours
  - Last 24 hours
  - Last 7 days
- Longer ranges (30/90 days) must hit rollups, never raw.

**3. Default behaviour**

- Live dashboards: default to 1 hour range
- Management dashboards: default to 24 hours or 7 days

**This aligns with:**
- Part 2 Section 2.3 (Navigation Components - Time range selector)
- Part 7 Section 7.1 (Global Layout Shell - Time range in top bar)
- Backend Master Section 7.9 (Retention Rule - dashboards use rollups)

---

### 8.7 Tenant-Aware Aggregation & Caching

All aggregation and caching must be **tenant-scoped**:

- Separate cache keys per `customer_id`
- Queries always include `customer_id`
- Group dashboards use:
  - a safe list of children: `SELECT id FROM customers WHERE parent_customer_id = :group_id OR id = :group_id`
  - but still cached separately from a single-tenant view

**Why:**

- Prevents cross-customer leakage
- Localizes performance issues to a single tenant
- Makes it easier to debug per-tenant load

**This aligns with:**
- Part 6 Section 6.2 (Tenant Boundary - UI Rule)
- Part 6 Section 6.8 (Customer Groups / OEM Model)
- Backend Master Section 9.4 (Tenant Boundary Enforcement)
- Backend Master Section 9.5 (Dashboard Routing & Access Control Rules)

---

### 8.8 Handling Slow or Degraded Backends

Dashboards must degrade gracefully when:
- `/v1/health` is slow or failing
- `/metrics` is slow
- SCADA views are temporarily unavailable

**UI behaviour:**

- Show "data delayed" banners or icons
- Keep last good data visible with a timestamp
- Avoid spinning loaders for more than a few seconds

**Backend behaviour:**

- **Timeouts:**
  - API calls should have sensible timeouts (e.g., 3–5s per call)
- **Retry strategy:**
  - Limited retries (1–2), then fail with clear error
- **Fallback:**
  - Use older cached data if available

**This aligns with:**
- Backend Master Section 6 (Health, Monitoring & Operational Observability)
- Backend Master Section 6.1 (Health API - `/v1/health`)
- Backend Master Section 6.3 (Metrics API - `/metrics`)
- Part 7 Section 7.2.6 (System Health Screen)

---

### 8.9 Relationship to NSReady Performance Manual

This dashboard performance model is built on top of the **NSReady backend performance rules** in:
- `NSREADY_BACKEND_MASTER.md` Sections 6 & 7
- Module 13 – Performance and Monitoring Manual

**Key alignments:**

- Queue depth thresholds (0–5/6–20/21–100/>100)
- Use of rollup views
- Raw table (`ingest_events`) treated as ingest/diagnostic, not dashboard-primary
- Tenant-scope used for isolation and safe caching

**NSWare dashboards are consumers of that performance model, not owners of it.**

**This aligns with:**
- Backend Master Section 6.2 (Queue Depth - Global Canonical Thresholds)
- Backend Master Section 7.9 (Time-Series Modeling Strategy)
- Backend Master Section 7.5 (Data Contract - dashboards use rollups)

---

### 8.10 Summary – Performance & Caching Model

Part 8 establishes:

- ✅ **Per-page refresh patterns** (5s–15min depending on page type)
- ✅ **Per-tenant caching rules** (never cache across tenants)
- ✅ **Per-tile data source preferences** (rollups over raw data)
- ✅ **Time-range and point limits** (1h–7d defaults, 1k–2k points max)
- ✅ **Degraded-mode behaviours** (stale-while-revalidate, graceful failures)

**So that:**

- ✅ NSReady ingestion remains safe and stable
- ✅ NSWare dashboards stay responsive and predictable
- ✅ Multi-tenant deployments don't impact each other
- ✅ Future AI/ML layers can reuse the same contracts without rework

**This keeps the dashboard layer thin and predictable, sitting cleanly on top of the NSReady backend architecture you've already stabilized.**

**Cross-References:**

- **Part 4:** Dashboard JSON structure (API orchestration)
- **Part 6:** Tenant Isolation (cache scoping)
- **Part 7:** Page types (refresh patterns)
- **Backend Master Section 6:** Health & Monitoring APIs
- **Backend Master Section 7:** Database Architecture & Rollups
- **Backend Master Section 9:** Tenant Model (isolation rules)

---

---

## 9. Feature Store Integration Layer (NSWare v2.0 Ready)

(Dashboards + AI/ML + Feature Store Contract)

This part defines how NSWare dashboards interact with AI/ML features, baseline statistics, predictions, and explainability outputs, using a clean separation between:
- **NSReady (v1)** → ingestion + storage + SCADA views
- **NSWare (v2)** → feature store + models + prediction/explainability outputs
- **NSWare Dashboard (v2)** → consumption of AI-ready data

Even though NSWare's AI layer is **future-phase**, the dashboard design must be **AI-ready today**.

Part 9 establishes the data contracts, view-models, and feature flows that make this possible.

---

### 9.1 Objectives of the Feature Store Integration Layer

The Feature Store Integration Layer exists to ensure:

**1. Consistency across all dashboards**

Every tile, KPI, alert, trend chart, and AI insight is built on the same contract.

**2. Predictable AI data consumption**

Dashboards must never directly query ML models—they always use a well-defined backend API.

**3. Strict tenant isolation**

Feature store, models, predictions, and explainability must always be scoped to:

```
tenant_id = customer_id
```

**4. Zero rework when AI/ML is added**

Even if NSWare AI comes later, the dashboards stay unchanged because placeholders + contracts already exist.

**5. Strong alignment with NSReady storage**

All features derive from:
- Raw data (`ingest_events`)
- Rollups (1m, 5m, hourly)
- Registry (customer, site, device)
- SCADA views

**This aligns with:**
- Backend Master Section 7.7 (Feature Tables - AI/ML Future)
- Backend Master Section 9.6 (Tenant Context for Future NSWare AI/ML Layer)
- Part 3 Section 3.10 (AI Insight Tile)
- Part 5 Section 5.2 (KPI Object AI hooks)

---

### 9.2 What the Feature Store Contains (Future NSWare v2)

This describes what NSWare's Feature Store will contain (future layer).

Dashboards must expect these fields, even if they are empty today.

---

#### 9.2.1 Online Feature Store (for live dashboards)

Low-latency features computed from:
- Latest rollups
- Device health
- Packet delays
- Moving windows (5m, 30m)

**Example fields:**

| Feature Name | Description |
|--------------|-------------|
| `voltage_mean_5m` | Smoothed KPI for stable display |
| `pressure_std_15m` | Used for anomaly detection |
| `packet_gap_seconds` | Device health metric |
| `ai_risk_score` | Model-based anomaly score |
| `ai_confidence` | Prediction confidence |
| `ai_factors[]` | Top contributors (explainability) |

**This aligns with:**
- Backend Master Section 7.7.1 (feature_store_online)
- Part 8 Section 8.5 (Data Sources per Tile Type)

---

#### 9.2.2 Offline Feature Store (for model training)

Contains historical:
- Trends
- Seasonal patterns
- Baseline KPIs
- Event frequency distributions

**Dashboards never query offline store, only the API does.**

**This aligns with:**
- Backend Master Section 7.7.2 (feature_store_offline)

---

#### 9.2.3 AI Inference Log (Explainability)

Each model call produces:

- `model_name`
- `timestamp`
- `tenant_id`
- `device_id`
- `feature_vector`
- `prediction`
- `risk_score`
- `confidence`
- `top_contributing_factors[]`

**Dashboards will render:**

- AI risk score
- Explainability bar
- Top contributing factors

Using **UTS AI Insight Tile** (Part 3 Section 3.1.6).

**This aligns with:**
- Backend Master Section 7.7.3 (inference_log)
- Part 3 Section 3.10 (AI Insight Tile)

---

### 9.3 Dashboard Consumption Flow (AI + Feature Store)

**Dashboards do not compute features.**

**Dashboards do not call models.**

Dashboards consume **precomputed features** from the backend:

```
Feature Store → NSWare API → Dashboard JSON → UTS Tiles
```

**API endpoints (future NSWare layer):**

- `GET /api/ai/features/:device_id?customer_id=...`
- `GET /api/ai/predictions/:device_id?customer_id=...`
- `GET /api/ai/explain/:device_id?customer_id=...`

**Dashboard responsibilities:**

- Render values provided by backend
- Never compute statistics client-side
- Respect tenant isolation
- Display predictions only when `ai.enabled = true`

**This aligns with:**
- Part 4 Section 4.3 (Backend-Powered View Engine)
- Part 4 Section 4.8 (API Binding Contract)
- Part 8 Section 8.3 (API Call Patterns)

---

### 9.4 Feature Store → Dashboard JSON Contract

Part 4 defines the Dashboard JSON.

Part 3 defines the UTS Tile Format.

Part 9 adds **AI + Feature Store extensions**.

---

#### 9.4.1 UTS AI Tile Contract

Already defined in Part 3:

```json
{
  "type": "ai",
  "title": "Anomaly Risk",
  "ai": {
    "enabled": true,
    "risk": 0.72,
    "confidence": 0.93,
    "top_factors": ["Flow variance", "Pressure drop"]
  }
}
```

**This aligns with:**
- Part 3 Section 3.10 (AI Insight Tile)
- Part 5 Section 5.2 (KPI Object - AI block)

---

#### 9.4.2 UTS KPI / Health Tile with Feature Store Enhancements

Tiles may now carry feature-store-enriched fields:

```json
{
  "id": "tile_voltage",
  "type": "kpi",
  "title": "Voltage (Stabilized)",
  "value": 228.8,
  "unit": "V",
  "stabilized_value": 228.11,
  "rolling_mean_5m": 227.9,
  "status": "normal",
  "ai": {
    "enabled": false
  }
}
```

**This aligns with:**
- Part 3 Section 3.2 (Tile Rendering Philosophy)
- Part 5 Section 5.2 (KPI Object)

---

#### 9.4.3 Feature Store Extensions Are Optional

If empty:

```json
"ai": {
  "enabled": false
}
```

Dashboard simply hides the AI components.

**This aligns with:**
- Part 3 Section 3.7 (AI Compatibility)
- Part 5 Section 5.2 (KPI Object - AI block)

---

### 9.5 Tenant Isolation Rules (AI & Feature Store)

These are **strict and non-negotiable**:

**Rule 1 — AI features must always include tenant context**

```
tenant_id = customer_id
```

**Rule 2 — No cross-tenant model training or scoring**

Models run per tenant or per device class within a tenant.

**Rule 3 — All API calls to Feature Store require customer_id**

**Rule 4 — Group dashboards may show aggregated predictions**

…but each child company's inference must be isolated.

**Rule 5 — Explainability outputs must never reveal cross-tenant data**

**Example:**

- ❌ "Industry average risk score" — forbidden
- ✔ "Your baseline risk score (7-day)" — allowed

**This aligns with:**
- Part 6 Section 6.2 (Tenant Boundary - UI Rule)
- Part 6 Section 6.9 (Tenant Isolation in Tiles, KPIs, Alerts)
- Part 6 Section 6.10 (Tenant Isolation for Future AI & Explainability)
- Backend Master Section 9.6 (Tenant Context for Future NSWare AI/ML Layer)

---

### 9.6 Dashboard UI Patterns for AI/Feature Store

---

#### Pattern A – AI Insight Tile (UTS type: ai)

Used on device dashboards / unit dashboards.

**Displays:**

- AI score
- Risk colour bar
- Confidence indicator
- Top contributing factors

**This aligns with:**
- Part 3 Section 3.1.6 (AI Insight Tiles)
- Part 7 Section 7.2.3 (Device Dashboard)

---

#### Pattern B – AI Overlay on Trend Charts

Trend charts may include:

- AI anomaly bands
- Forecast overlay
- Drift warnings

**Example:**

- Blue = historical
- Green = predicted
- Red band = risk zone

**This aligns with:**
- Part 3 Section 3.1.4 (Trend Tiles)
- Part 5 Section 5.9 (How This Connects to Parameter Templates & NSReady)

---

#### Pattern C – AI Summary Card

At customer or site level:

- % devices at risk
- Top 5 problematic devices
- Anomalies last 24h

**This aligns with:**
- Part 2 Section 2.4.1 (Template A: Main Dashboard)
- Part 7 Section 7.2.1 (Operational Home)

---

#### Pattern D – Explainability Drawer

When an AI insight tile is clicked:

A drawer opens with:

- Feature vector
- Model used
- Timestamp
- Factor contributions
- Drill-down link

**This aligns with:**
- Part 7 Section 7.5.3 (Operational Health Linking)
- Part 3 Section 3.7 (AI Compatibility)

---

### 9.7 Performance Constraints (AI-Ready)

**Constraint 1 — No live-model calls on dashboard load**

Dashboards only read stored inference results.

**Constraint 2 — Feature queries must be bounded**

Default API queries MUST enforce:

- Device scope
- Tenant scope
- Time range
- Rollup tier

**Constraint 3 — Cache predictions for stability**

Predictions should refresh:

- At model frequency (e.g., every 15m / hourly)
- Not on every dashboard refresh

**Constraint 4 — Large tenant → restrict live insights**

Where customers have 5,000+ devices:

- Limit AI tiles to subsets (e.g., highest risk)
- Offer backend pagination

**This aligns with:**
- Part 8 Section 8.3 (API Call Patterns)
- Part 8 Section 8.4 (Caching Strategy)
- Part 8 Section 8.7 (Tenant-Aware Aggregation & Caching)

---

### 9.8 Future Roadmap (NSWare AI v2.x)

**Phase 2.0: Feature Computation Engine**

- Rolling mean, rolling std
- Packet delay classification
- KPI normalization
- SCADA-derived derived features

**Phase 2.1: Model Registry**

- Store and version models per tenant

**Phase 2.2: Online Inference Router**

- Fast scoring endpoint
- Per-tenant isolation built in

**Phase 2.3: Operator Explainability**

- Top contributing factors
- Predicted causes
- Recommend corrective action

**Phase 2.4: Tenant-Level AI Dashboards**

- Risk maps
- AI health scoring
- Fleet-wide alerts

**This aligns with:**
- Backend Master Section 7.7 (Feature Tables - AI/ML Future)
- Backend Master Section 9.6 (Tenant Context for Future NSWare AI/ML Layer)
- Backend Master Section 10.7 (Future NSWare Integration Plan)

---

### 9.9 Summary — Feature Store Integration Layer

Part 9 defines the **full AI-ready architecture** for NSWare dashboards:

- ✅ **Dashboard JSON contract extended** with AI/feature fields
- ✅ **Universal Tile System supports AI** without redesign
- ✅ **Tenant isolation strictly preserved** (no cross-tenant leakage)
- ✅ **Clear distinction** between NSReady (v1) ingestion and NSWare (v2) AI
- ✅ **Dashboards consume stored predictions**, not models
- ✅ **AI overlay, explainability, and scoring** integrated cleanly
- ✅ **Roadmap ensures future growth** without breaking contracts

**This keeps the dashboard layer:**

- **Unified** (same contract for all tiles)
- **Consistent** (same patterns across dashboards)
- **Future-proof** (AI-ready from day zero)
- **AI-ready from day zero** (placeholders and contracts exist)

**Cross-References:**

- **Part 3:** Universal Tile System (AI Insight Tiles)
- **Part 4:** Dashboard JSON structure (AI extensions)
- **Part 5:** KPI & Alert Model (AI hooks)
- **Part 6:** Tenant Isolation (AI tenant-scoping)
- **Part 8:** Performance & Caching (AI performance constraints)
- **Backend Master Section 7.7:** Feature Tables (AI/ML Future)
- **Backend Master Section 9.6:** Tenant Context for Future NSWare AI/ML Layer

---

---

## 10. AI/ML Display & Explainability – UI/UX Master Rules

This part describes how AI/ML outputs are rendered in the UI, how explainability is shown to operators/engineers, and how tenant safety and NSReady constraints are respected.

It uses the same **Tile Engine (Part 3)** and **Dashboard JSON (Part 4)** and the **Feature Store layer (Part 9)**.

It does **not define any model logic or training**. It defines only UI/UX and contracts.

---

### 10.1 Goals of AI/ML Display in NSWare

NSWare AI/ML visualizations have **four primary goals**:

**1. Augment, not replace, human judgment**

- AI should highlight risk and patterns, not silently override SCADA logic or engineering judgment.

**2. Remain fully tenant-safe**

- All AI outputs are strictly scoped to one tenant (`tenant_id = customer_id`).
- No cross-customer comparisons unless explicitly configured at group level.

**3. Be explainable and traceable**

- Every AI score should have an explanation path and a `trace_id` / `model_version` link.

**4. Avoid UI rework when models evolve**

- UI uses stable contracts (`tile.ai`, `ai.factors[]`, etc.), so models can be swapped/upgraded without redesign.

**This aligns with:**
- Part 9 Section 9.1 (Objectives of Feature Store Integration Layer)
- Part 6 Section 6.10 (Tenant Isolation for Future AI & Explainability)
- Part 5 Section 5.2 (KPI Object - AI hooks)

---

### 10.2 AI Rendering Levels (Where AI Appears)

AI appears in **three levels** of NSWare UI:

**Level 1 – Device/Unit Page (Micro-level)**

- AI tiles show per-device risk/score
- Typical use: "Is this device behaving normally right now?"
- Controlled via **UTS AI Tile** and KPI tiles with `ai.*` fields.

**Level 2 – Site/Customer Page (Meso-level)**

- AI summary tiles show counts and ratios:
  - % devices at risk
  - Number of anomalies in last 24h
  - Top 5 risky devices/sites
- Controlled via **AI Summary Tiles** (KPI type with AI tags).

**Level 3 – Group/OEM Page (Macro-level)**

- AI aggregation across child companies (group view):
  - Total at-risk sites per company
  - Comparison between subsidiaries
- Must still respect tenant rules:
  - OEM can see aggregated, per-child AI signals
  - Child company cannot see group-level AI

**This aligns with:**
- Part 2 Section 2.1 (4-Level Navigation Layers)
- Part 6 Section 6.8 (Customer Groups / OEM Model)
- Part 9 Section 9.5 (Tenant Isolation Rules)

---

### 10.3 UTS AI Fields – Final Contract (Reused from Part 3 & 9)

To avoid rework, all AI display is driven by **three main fields**:

```json
"ai": {
  "enabled": true | false,
  "risk": 0.0,          // 0.0–1.0 normalized risk
  "confidence": 0.0,    // 0.0–1.0 model confidence
  "top_factors": [      // ordered list, most important first
    "Flow variance high vs 7-day baseline",
    "Frequent short outages"
  ]
}
```

**UI Rules:**

- If `ai.enabled = false` → AI components hidden, tile still works as normal KPI/health tile.
- If `ai.enabled = true` → AI overlay or dedicated AI tile is shown.
- `risk` & `confidence` drive colors and badges.
- `top_factors` drives explainability sections.

**This aligns with:**
- Part 3 Section 3.10 (AI Insight Tiles)
- Part 5 Section 5.2 (KPI Object - AI block)
- Part 9 Section 9.4 (Feature Store → Dashboard JSON Contract)

---

### 10.4 Risk Colour & Badge Mapping (Canonical)

All AI tiles and AI-enhanced KPIs use the same risk colour code:

| Risk Value (ai.risk) | Colour | Text Badge |
|---------------------|--------|------------|
| 0.00 – 0.33 | Green | "Low Risk" |
| 0.34 – 0.66 | Amber | "Medium Risk" |
| 0.67 – 1.00 | Red | "High Risk" |

**UI behaviour:**

- **Green** → subtle highlight, no urgent action
- **Amber** → flagged, but not screaming; suggests "monitor"
- **Red** → strong highlight; should draw operator attention immediately

**Confidence drives indicator style:**

- Confidence <0.5 → show a lighter "Uncertain" style
- Confidence ≥0.5 → normal rendering
- Confidence ≥0.8 → strong rendering (solid badge, crisp colour)

**This aligns with:**
- Part 1 Section 5 (Theme System - colors)
- Part 3 Section 3.4 (Alert Tiles - color coding)

---

### 10.5 AI Tile Types (Display Patterns)

AI logic can be surfaced through **three primary tile patterns**, using UTS.

---

#### 10.5.1 AI Insight Tile (UTS type: "ai")

This is the **core AI visualization tile**.

**Layout:**

```
[ Title: "Anomaly Risk" + Badge: Low/Medium/High ]
[ Big Score (0.72) + Confidence (93%) ]
[ Top contributing factors list ]
[ Link: "View details" → opens explainability drawer ]
```

**JSON Example:**

```json
{
  "id": "tile_ai_anomaly_device_001",
  "type": "ai",
  "title": "Anomaly Risk",
  "source": {
    "customer_id": "UUID",
    "site_id": "UUID",
    "device_id": "UUID"
  },
  "ai": {
    "enabled": true,
    "risk": 0.72,
    "confidence": 0.93,
    "top_factors": [
      "Flow variance vs 7-day baseline",
      "Packet gaps in last 2 hours"
    ]
  },
  "timestamp": "2025-11-18T12:00:00Z",
  "links": {
    "drilldown": "/device/<device_id>/ai"
  }
}
```

**This aligns with:**
- Part 3 Section 3.1.6 (AI Insight Tiles)
- Part 9 Section 9.6 (Pattern A – AI Insight Tile)

---

#### 10.5.2 KPI Tile with AI Overlay (UTS type: "kpi" + ai.*)

Uses a standard KPI tile (big number) with a **subtle AI overlay**.

**Example:**

```json
{
  "id": "tile_pressure",
  "type": "kpi",
  "title": "Line Pressure",
  "value": 13.8,
  "unit": "bar",
  "status": "normal",
  "ai": {
    "enabled": true,
    "risk": 0.41,
    "confidence": 0.78,
    "top_factors": [
      "Fluctuations vs 24h baseline",
      "Approaching configured high limit"
    ]
  }
}
```

**UI Behaviour:**

- KPI panel remains main focus.
- Small AI risk badge in top-right (e.g., "Medium AI Risk").
- Hover/click can open AI Explainability Drawer.

**This aligns with:**
- Part 3 Section 3.1.1 (KPI Tiles)
- Part 9 Section 9.4.2 (UTS KPI / Health Tile with Feature Store Enhancements)

---

#### 10.5.3 AI Summary Tile (UTS type: "kpi" used as group summary)

Used on **Customer or Site page**.

**Example:**

```json
{
  "id": "tile_ai_summary_customer",
  "type": "kpi",
  "title": "Devices at AI Risk (24h)",
  "value": 7,
  "unit": "devices",
  "status": "warning",
  "ai": {
    "enabled": true,
    "risk": 0.58,
    "confidence": 0.9,
    "top_factors": [
      "High variance in energy usage",
      "Frequent start/stop cycles"
    ]
  }
}
```

**This aligns with:**
- Part 9 Section 9.6 (Pattern C – AI Summary Card)
- Part 2 Section 2.4.1 (Template A: Main Dashboard)

---

### 10.6 Explainability UI Patterns

NSWare must provide **intuitive, operator-friendly explainability**.

---

#### 10.6.1 Explainability Drawer (Per Device / Per Event)

**Trigger:** Clicking an AI tile or AI badge.

**Drawer Contents (typical):**

- Model name + version (e.g., `anomaly_detector_v1.3.2`)
- Timestamp
- Device identity (`device_code`, location)
- Raw risk & confidence values
- **Feature contribution list:**
  - Top 3–5 factors with simple descriptions
  - Simple bars: longer = more influence
  - Link to event timeline chart (24h view, marked anomalies)

**Example Layout:**

```
[ Anomaly Risk: High (0.82, 91% confidence) ]
[ Model: anomaly_detector_v1.3.2 ]
[ Device: Flowmeter 004 @ Site 12 ]

Top contributing factors:

1. Flow variance vs 7-day baseline         [██████████]
2. Frequent packet gaps (last 3 hours)     [███████   ]
3. Unusual night-time activity pattern     [█████     ]

[ Button: View 24h trend ]
```

**This aligns with:**
- Part 9 Section 9.6 (Pattern D – Explainability Drawer)
- Part 7 Section 7.5.3 (Operational Health Linking)

---

#### 10.6.2 AI-Enhanced Trend Chart

Used when an engineer opens the device trend view.

**Visuals:**

- Normal 24h/7d KPI line
- **Overlaid red markers** where AI flagged anomalies
- **Hovering on marker** shows:
  - Risk value
  - Confidence
  - Short factor list

**Purpose:**

- Help engineers see when AI sees risk, not just "yes/no".

**This aligns with:**
- Part 9 Section 9.6 (Pattern B – AI Overlay on Trend Charts)
- Part 3 Section 3.1.4 (Trend Tiles)

---

#### 10.6.3 Early Warning vs Confirmed Issue

AI must clearly differentiate:

- **"Early Warning"** (suggests watching)
- **"Confirmed Issue"** (requires action)

**UI representation:**

- **Early Warning:** Amber banner, text like "Check in next shift if pattern persists."
- **Confirmed Issue:** Red banner, text like "Investigate now—pattern matches known failure modes."

These states are decided by **backend logic** (models + thresholds), but UI must render them clearly.

**This aligns with:**
- Part 5 Section 5.4 (KPI State Model)
- Part 5 Section 5.5 (Alert Object)

---

### 10.7 Human-in-the-Loop & Feedback Hooks (Future)

To keep AI usable and trustworthy:

---

#### 10.7.1 Operator Feedback Buttons

For AI tiles, provide quick feedback clicks:

- ✅ "Looks correct"
- ❌ "Looks wrong"

**Backend logs these into:**

- `feedback_log` (NSWare future table)
- Used for model retraining, bias checks, and tuning.

**UI behaviour:**

- Simple 2-button row under AI tile
- Single click, no heavy forms

**This aligns with:**
- Part 9 Section 9.8 (Future Roadmap - Phase 2.3)
- Backend Master Section 7.7.3 (inference_log)

---

#### 10.7.2 "Explain More" & "Explain Less"

For advanced users:

- Allow toggling verbosity:
  - Collapse to top 1–2 factors
  - Expand to full factor list

Helps different roles (operator vs data engineer).

---

### 10.8 Safety & UX Guardrails for AI Display

AI in NSWare must **not confuse or overwhelm operators**.

**Hard Rules:**

1. **AI never replaces core SCADA alarms**
   - Existing alarm logic remains primary.
   - AI augments, not replaces.

2. **Uncertain AI output must be visually clear**
   - Low confidence → show grey "uncertain" state.

3. **No cross-tenant comparison text**
   - Never show: "You are worse than other tenants."
   - Only show tenant-local baselines.

4. **No hard-coded "magic numbers" in UI**
   - Risk thresholds, baselines must come from backend.
   - UI only renders categories and labels.

5. **AI tiles must degrade gracefully**
   - If AI service off or error:
     - Hide AI tiles or show "AI Insights unavailable"
     - Never break whole dashboard.

**This aligns with:**
- Part 6 Section 6.10 (Tenant Isolation for Future AI & Explainability)
- Part 9 Section 9.5 (Tenant Isolation Rules)
- Part 8 Section 8.8 (Handling Slow or Degraded Backends)

---

### 10.9 Accessibility & Clarity Requirements

AI components must respect **standard accessibility practices**:

- Colour-blind friendly palettes
- Risk conveyed with icons and text, not colour alone
- Tooltips for acronyms and technical terms
- Keyboard navigable explainability drawers
- Clear timestamps in local + UTC modes (if configured)

**This aligns with:**
- Part 1 Section 5 (Theme System)
- Part 7 Section 7.6 (Responsive Behaviour)

---

### 10.10 Summary – AI/ML Display & Explainability in NSWare

Part 10 completes the **NSWare Dashboard Master** by specifying:

- ✅ **Where AI appears:** Device, Site, Customer, Group
- ✅ **How AI appears:** UTS AI tiles, KPI overlays, explainability drawers
- ✅ **How AI remains safe:** Tenant-isolated, SCADA-friendly, human-in-the-loop
- ✅ **How AI integrates:** via Feature Store APIs and stored predictions, not model calls from UI
- ✅ **How AI is future-proof:** Contract-driven, not tightly tied to any one model

**With Parts 1–10, NSWare's dashboard layer is now:**

- ✅ **Architecturally aligned** with NSReady backend
- ✅ **Tenant-aware and safe** for multi-customer OEM/utility use
- ✅ **Ready to plug into future AI/ML services** with no UI redesign
- ✅ **Clear for frontend, backend, and AI engineers** to collaborate without stepping on each other

**Cross-References:**

- **Part 1:** Foundation Layer (Theme System)
- **Part 2:** Information Architecture & Navigation
- **Part 3:** Universal Tile System (AI Insight Tiles)
- **Part 4:** Dashboard JSON & Rendering Model
- **Part 5:** KPI & Alert Model (AI hooks)
- **Part 6:** Tenant Isolation & Access Control (AI tenant-scoping)
- **Part 7:** UX Mockup & Component Layout
- **Part 8:** Performance & Caching Model (AI constraints)
- **Part 9:** Feature Store Integration Layer
- **Backend Master Section 7.7:** Feature Tables (AI/ML Future)
- **Backend Master Section 9.6:** Tenant Context for Future NSWare AI/ML Layer

---

**Status:** Part 10/10 Complete ✅  
**NSWARE_DASHBOARD_MASTER.md is now COMPLETE**

---

**Master Document Summary:**

The NSWare Dashboard Master Document (Parts 1–10) defines the complete architecture for:

- ✅ **NSWare customer-facing dashboards** (process KPIs - future Phase-2)
- ✅ **NSReady operational dashboards** (data collection health - current v1)
- ✅ **Universal Tile System (UTS v1.0)** — unified tile contract
- ✅ **Backend-powered Dashboard JSON** — backend-generated views
- ✅ **Tenant isolation & access control** — multi-customer safety
- ✅ **Performance & caching** — scalable, responsive dashboards
- ✅ **Feature Store integration** — AI-ready architecture
- ✅ **AI/ML display & explainability** — future-proof AI visualization

**Related Documents:**

- **NSReady Backend Master:** `master_docs/NSREADY_BACKEND_MASTER.md`
- **NSReady Operational Dashboards:** `master_docs/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`
- **Tenant Model Summary:** `docs/TENANT_MODEL_SUMMARY.md`


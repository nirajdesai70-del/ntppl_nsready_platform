# NSReady Operational Dashboards (NSReady v1 Data Collection UI)

> **Scope:** NSReady v1 Operational UI  
> **Status:** Current Implementation (Not Future)  
> **Related:** See `NSWARE_DASHBOARD_MASTER.md` Part 5 for NSWare Phase-2 process KPIs (future)

---

> **Scope of NSReady Operational UI**  

> This document describes **NSReady operational dashboards** for reviewing and validating  

> the **data collection software itself**:

> - Registry configuration (Customers → Projects → Sites → Devices → Parameters)  

> - Packet timing behaviour (on-time / late / missing)  

> - Ingestion & SCADA export health  

> 

> **Architecture Note:**  

> Part 5 uses the **same Universal Tile System (Part 3)** and **Dashboard JSON structure (Part 4)**  

> as NSWare customer dashboards, but with **operational content** instead of process KPIs.  

> This ensures consistency while keeping operational tools separate from customer dashboards.

---

## 5.1 Goals of NSReady Operational UI

The NSReady operational UI has **three primary goals**:

1. **Configuration Clarity**  

   - Visualize registry structure (Customers → Projects → Sites → Devices → Parameters)

   - Show expected reporting intervals and SCADA mapping fields

2. **Collection Health Feedback**  

   - Show packet behaviour: Are packets coming? On time? Missing? Late?

   - Display last packet time per device/site

3. **Operational Confidence**  

   - Verify configuration correctness

   - Verify ingestion end-to-end

   - Verify SCADA exports production

**Scope Separation:**

- **NSReady Operational UI (Part 5)**: Data collection health & configuration review
- **NSWare Customer Dashboards (Parts 1-4)**: Process KPIs (steam efficiency, water loss, etc.)

---

## 5.2 NSReady Operational Dashboard Types

NSReady operational UI consists of **five** dashboard types, all using the **same UTS + Dashboard JSON architecture**:

1. **Registry Configuration Dashboard**

   - Customers, Projects, Sites, Devices, Parameter Templates

2. **Collection Health Dashboard** (Per Customer / Site / Device)

   - Expected vs Received packets, Late vs Missing behaviour

3. **Ingestion Log Dashboard**

   - Event timeline, Trace IDs, Error markers

4. **SCADA Export Monitor Dashboard**

   - Latest SCADA values, Export file history

5. **System Health Dashboard**

   - `/v1/health` view, Queue depth, Worker/DB status

All dashboards use:
- **Universal Tile System** (Part 3)
- **Dashboard JSON structure** (Part 4)
- **Navigation hierarchy** (Part 2)
- **Theme system** (Part 1 Section 5)

---

## 5.3 Dashboard 1: Registry Configuration Dashboard

**Purpose:** Visualize and edit the registry structure.

**Dashboard JSON Structure:**

```json
{
  "dashboard_id": "registry_config_customer_v1",
  "title": "Registry Configuration",
  "scope": {
    "customer_id": "UUID"
  },
  "layout": {
    "grid": 12,
    "max_rows": 10
  },
  "sections": [
    {
      "id": "customer_list",
      "title": "Customers",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_customer_list", "span": 12 }
          ]
        }
      ]
    },
    {
      "id": "hierarchy_tree",
      "title": "Project → Site → Device Hierarchy",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_hierarchy_tree", "span": 6 },
            { "tile_id": "tile_entity_details", "span": 6 }
          ]
        }
      ]
    },
    {
      "id": "parameter_templates",
      "title": "Parameter Templates",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_parameter_browser", "span": 12 }
          ]
        }
      ]
    }
  ],
  "tiles": [
    {
      "id": "tile_customer_list",
      "type": "asset",
      "title": "Customer List",
      "source": {
        "customer_id": "UUID"
      },
      "status": "normal",
      "links": {
        "drilldown": "/customer/:customer_id"
      }
    },
    {
      "id": "tile_hierarchy_tree",
      "type": "asset",
      "title": "Hierarchy Tree",
      "source": {
        "customer_id": "UUID"
      },
      "status": "normal"
    },
    {
      "id": "tile_entity_details",
      "type": "kpi",
      "title": "Entity Details",
      "value": null,
      "status": "normal"
    },
    {
      "id": "tile_parameter_browser",
      "type": "asset",
      "title": "Parameter Templates",
      "source": {
        "customer_id": "UUID",
        "project_id": "UUID"
      },
      "status": "normal"
    }
  ],
  "metadata": {
    "version": "1.0",
    "created_at": "2025-01-XXT00:00:00Z"
  }
}
```

**Tile Types Used:**

- **Asset Tile**: Customer list, Hierarchy tree, Parameter browser
- **KPI Tile**: Entity details (when node selected)

**Navigation:**

- Route: `/operational/registry/:customer_id`
- Uses Part 2 navigation hierarchy (Customer → Site → Device)

---

## 5.4 Dashboard 2: Collection Health Dashboard

**Purpose:** Show packet behaviour and ingestion health (NOT process KPIs).

**Dashboard JSON Structure:**

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
    },
    {
      "id": "device_health",
      "title": "Device Health",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_device_health_table", "span": 12 }
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
    },
    {
      "id": "tile_packet_on_time_pct",
      "type": "health",
      "title": "Packet On-Time %",
      "value": 96.5,
      "unit": "%",
      "status": "normal",
      "source": {
        "customer_id": "UUID"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_missing_packets",
      "type": "alert",
      "title": "Missing Packets",
      "value": 120,
      "unit": "packets",
      "status": "warning",
      "source": {
        "customer_id": "UUID"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_late_packets",
      "type": "alert",
      "title": "Late Packets",
      "value": 30,
      "unit": "packets",
      "status": "warning",
      "source": {
        "customer_id": "UUID"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_site_health_table",
      "type": "trend",
      "title": "Site Health Table",
      "source": {
        "customer_id": "UUID"
      },
      "status": "normal"
    },
    {
      "id": "tile_device_health_table",
      "type": "trend",
      "title": "Device Health Table",
      "source": {
        "customer_id": "UUID",
        "site_id": "UUID"
      },
      "status": "normal"
    }
  ],
  "metadata": {
    "version": "1.0",
    "time_range": "1h",
    "created_at": "2025-01-XXT12:00:00Z"
  }
}
```

**Tile Types Used:**

- **KPI Tile**: Device counts
- **Health Tile**: Packet On-Time %
- **Alert Tile**: Missing/Late packets
- **Trend Tile**: Site/Device health tables (with sparklines)

**Data Model (per customer):**

- `expected_packets` = device_count × configured_interval × time_window
- `received_packets` = count from `ingest_events`
- `missing_packets` = expected - received
- `late_packets` = arrival after 2× configured interval
- `devices_configured` = count from `devices` table
- `devices_seen_recently` = devices with at least one packet in window
- `devices_silent` = configured but no recent data

**Navigation:**

- Route: `/operational/health/:customer_id`
- Drill-down: `/operational/health/:customer_id/:site_id`
- Drill-down: `/operational/health/:customer_id/:site_id/:device_id`

---

## 5.5 Dashboard 3: Ingestion Log Dashboard

**Purpose:** Show event timeline and error tracking for debugging.

**Dashboard JSON Structure:**

```json
{
  "dashboard_id": "ingestion_log_customer_v1",
  "title": "Ingestion Log",
  "scope": {
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
      "id": "event_stream",
      "title": "Event Stream",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_event_timeline", "span": 12 }
          ]
        }
      ]
    },
    {
      "id": "error_log",
      "title": "Error Log",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_error_list", "span": 12 }
          ]
        }
      ]
    }
  ],
  "tiles": [
    {
      "id": "tile_event_timeline",
      "type": "trend",
      "title": "Event Timeline",
      "trend": {
        "sparkline": [],
        "direction": "up"
      },
      "source": {
        "customer_id": "UUID",
        "device_id": "UUID"
      },
      "status": "normal",
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_error_list",
      "type": "alert",
      "title": "Error List",
      "value": 5,
      "unit": "errors",
      "status": "warning",
      "source": {
        "customer_id": "UUID"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    }
  ],
  "metadata": {
    "version": "1.0",
    "filters": {
      "time_range": "1h",
      "error_type": null
    },
    "created_at": "2025-01-XXT12:00:00Z"
  }
}
```

**Tile Types Used:**

- **Trend Tile**: Event timeline with sparkline
- **Alert Tile**: Error list with counts

**Navigation:**

- Route: `/operational/logs/:customer_id`
- Filters: `customer`, `site`, `device`, `parameter_key`, `time_range`

---

## 5.6 Dashboard 4: SCADA Export Monitor Dashboard

**Purpose:** Show SCADA export status and latest values.

**Dashboard JSON Structure:**

```json
{
  "dashboard_id": "scada_export_customer_v1",
  "title": "SCADA Export Monitor",
  "scope": {
    "customer_id": "UUID",
    "site_id": null
  },
  "layout": {
    "grid": 12,
    "max_rows": 6
  },
  "sections": [
    {
      "id": "latest_values",
      "title": "Latest SCADA Values",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_scada_latest_grid", "span": 12 }
          ]
        }
      ]
    },
    {
      "id": "export_status",
      "title": "Export Status",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_export_history", "span": 12 }
          ]
        }
      ]
    }
  ],
  "tiles": [
    {
      "id": "tile_scada_latest_grid",
      "type": "asset",
      "title": "SCADA Latest Values",
      "source": {
        "customer_id": "UUID",
        "view": "v_scada_latest"
      },
      "status": "normal",
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_export_history",
      "type": "trend",
      "title": "Export History",
      "source": {
        "customer_id": "UUID"
      },
      "status": "normal",
      "timestamp": "2025-01-XXT12:00:00Z"
    }
  ],
  "metadata": {
    "version": "1.0",
    "data_source": "v_scada_latest",
    "created_at": "2025-01-XXT12:00:00Z"
  }
}
```

**Tile Types Used:**

- **Asset Tile**: SCADA latest values grid
- **Trend Tile**: Export history timeline

**Data Source:**

- `v_scada_latest` (read-only)

**Navigation:**

- Route: `/operational/scada/:customer_id`
- Optional: `/operational/scada/:customer_id/:site_id`

---

## 5.7 Dashboard 5: System Health Dashboard

**Purpose:** Show system health metrics (`/v1/health` and `/metrics`).

**Dashboard JSON Structure:**

```json
{
  "dashboard_id": "system_health_v1",
  "title": "System Health",
  "scope": {
    "customer_id": null,
    "site_id": null,
    "device_id": null
  },
  "layout": {
    "grid": 12,
    "max_rows": 4
  },
  "sections": [
    {
      "id": "health_summary",
      "title": "Health Summary",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_service_status", "span": 3 },
            { "tile_id": "tile_queue_depth", "span": 3 },
            { "tile_id": "tile_db_status", "span": 3 },
            { "tile_id": "tile_redelivered", "span": 3 }
          ]
        }
      ]
    },
    {
      "id": "metrics_snapshot",
      "title": "Metrics Snapshot",
      "rows": [
        {
          "tiles": [
            { "tile_id": "tile_ingest_queued", "span": 3 },
            { "tile_id": "tile_ingest_success", "span": 3 },
            { "tile_id": "tile_ingest_errors", "span": 3 },
            { "tile_id": "tile_queue_depth_gauge", "span": 3 }
          ]
        }
      ]
    }
  ],
  "tiles": [
    {
      "id": "tile_service_status",
      "type": "health",
      "title": "Service Status",
      "value": 1,
      "unit": null,
      "status": "normal",
      "source": {
        "endpoint": "/v1/health"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_queue_depth",
      "type": "kpi",
      "title": "Queue Depth",
      "value": 0,
      "unit": "messages",
      "status": "normal",
      "source": {
        "endpoint": "/v1/health"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_db_status",
      "type": "health",
      "title": "DB Status",
      "value": 1,
      "unit": null,
      "status": "normal",
      "source": {
        "endpoint": "/v1/health"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_redelivered",
      "type": "alert",
      "title": "Redelivered",
      "value": 0,
      "unit": "messages",
      "status": "normal",
      "source": {
        "endpoint": "/v1/health"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_ingest_queued",
      "type": "kpi",
      "title": "Events Queued",
      "value": 1250,
      "unit": "events",
      "status": "normal",
      "source": {
        "endpoint": "/metrics",
        "metric": "ingest_events_total{status=\"queued\"}"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_ingest_success",
      "type": "kpi",
      "title": "Events Success",
      "value": 1248,
      "unit": "events",
      "status": "normal",
      "source": {
        "endpoint": "/metrics",
        "metric": "ingest_events_total{status=\"success\"}"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_ingest_errors",
      "type": "alert",
      "title": "Events Errors",
      "value": 2,
      "unit": "errors",
      "status": "warning",
      "source": {
        "endpoint": "/metrics",
        "metric": "ingest_errors_total"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    },
    {
      "id": "tile_queue_depth_gauge",
      "type": "health",
      "title": "Queue Depth Gauge",
      "value": 0,
      "unit": "messages",
      "status": "normal",
      "source": {
        "endpoint": "/metrics",
        "metric": "ingest_queue_depth"
      },
      "timestamp": "2025-01-XXT12:00:00Z"
    }
  ],
  "metadata": {
    "version": "1.0",
    "endpoints": ["/v1/health", "/metrics"],
    "created_at": "2025-01-XXT12:00:00Z"
  }
}
```

**Tile Types Used:**

- **Health Tile**: Service status, DB status, Queue depth gauge
- **KPI Tile**: Queue depth, Events queued/success
- **Alert Tile**: Redelivered, Events errors

**Status Rules:**

- Green: `queue_depth 0-5`, `db=connected`
- Yellow: `queue_depth 6-20`
- Red: `queue_depth >20` or `db=disconnected`

**Navigation:**

- Route: `/operational/system/health`

---

## 5.8 Navigation Integration (Part 2 Patterns)

**NSReady Operational UI Navigation:**

All operational dashboards use the **same navigation hierarchy** as NSWare dashboards (Part 2):

```
/customer/:customer_id/operational
  ├── /registry
  ├── /health
  ├── /logs
  ├── /scada
  └── /system/health
```

**Breadcrumbs:**

```
Customer > Operational > [Dashboard Name]
```

**Example:**

```
Customer Group Textool > Operational > Collection Health
```

**Navigation Components:**

- Uses Part 2 left sidebar (Customer → Site → Device)
- Uses Part 2 top bar (user profile, time range selector)
- Uses Part 2 breadcrumb navigation

---

## 5.9 Theme System Integration (Part 1 Section 5)

**NSReady Operational UI Theme:**

All operational dashboards use the **same theme system** as NSWare dashboards (Part 1 Section 5):

- **Colors**: Same palette (Background `#0E0E11`, Panel `#1A1A1F`, etc.)
- **Typography**: Same font (Inter), same sizes
- **Layout**: Same 12-column grid
- **Icons**: Same SVG-based icons

**Result:**

- Visual consistency across all UI
- NSReady operational UI looks like part of same ecosystem

---

## 5.10 Tenant & Customer Isolation (Same Rules)

**NSReady Operational UI Isolation:**

All operational dashboards enforce the **same tenant isolation rules** as NSWare dashboards:

- `tenant_id = customer_id` (Part 2 Section 2.10)
- Never mix different `customer_id`s in one view
- Group-level reports use `parent_customer_id` (explicit group dashboards)

**Routing Rules:**

- `/operational/registry/:customer_id` → Filters by `customer_id`
- `/operational/health/:customer_id` → Filters by `customer_id`
- `/operational/logs/:customer_id` → Filters by `customer_id`
- `/operational/scada/:customer_id` → Filters by `customer_id`

---

## 5.11 Summary: NSReady Operational Dashboards

**What Part 5 Defines:**

- **5 operational dashboards** using UTS + Dashboard JSON
- **Same architecture** as NSWare customer dashboards (Parts 1-4)
- **Same navigation** as NSWare dashboards (Part 2)
- **Same theme** as NSWare dashboards (Part 1 Section 5)
- **Same isolation rules** as NSWare dashboards (Part 2 Section 2.10)

**Key Difference:**

- **Content/Purpose**: Operational (data collection health) vs Customer (process KPIs)
- **Architecture**: Same (UTS + Dashboard JSON)

**Result:**

- Consistent architecture across all UI
- Single rendering engine for both operational and customer dashboards
- Visual consistency across all UI
- Maintainable single set of patterns

---

**Status:** NSReady Operational UI Specification Complete ✅  
**Location:** `master_docs/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md`  

**Cross-Reference:**
- **For NSWare Phase-2 process KPIs** (steam efficiency, water loss, power consumption, etc.), see `NSWARE_DASHBOARD_MASTER.md` Part 5 (KPI & Alert Model)
- **For backend architecture**, see `NSREADY_BACKEND_MASTER.md`

**Separation:**
- **This document** = NSReady v1 operational UI (current)
- **NSWare Part 5** = Process KPI engine (future Phase-2)



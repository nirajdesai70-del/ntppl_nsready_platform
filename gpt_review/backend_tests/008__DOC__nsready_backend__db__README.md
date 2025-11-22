### Database Schema (PostgreSQL 15 + TimescaleDB)

This folder defines the base schema for registry (customers/projects/sites/devices/parameters) and telemetry (ingest events, measurements, gaps, errors).

Tables:
- customers(id, name, metadata, created_at)
- projects(id, customer_id, name, description, created_at)
- sites(id, project_id, name, location, created_at)
- devices(id, site_id, name, device_type, external_id, status, created_at)
- parameter_templates(id, key, name, unit, metadata, created_at)
- registry_versions(id, created_at, checksum, description)
- tokens(id, device_id, token_hash, expires_at, created_at)
- ingest_events(time, device_id, parameter_key, value, quality, source, event_id, attributes, created_at)
- measurements(time, device_id, parameter_key, agg_interval, value_avg, value_min, value_max, value_count, created_at)
- missing_intervals(id, device_id, parameter_key, start_time, end_time, reason, created_at)
- error_logs(id, time, source, level, message, context)

Views:
- v_scada_latest: latest value per device/parameter from `ingest_events`
- v_scada_history: flat projection of `ingest_events`

TimescaleDB:
- `ingest_events` is a hypertable on column `time`
- Compression enabled after 7 days, retention policy of 90 days

Indexes:
- `ingest_events(device_id, parameter_key, time DESC)`
- unique `ingest_events(event_id)` (nullable-aware) for idempotency
- supporting indexes on foreign keys and time columns

### Migrations
Files in `db/migrations/` are copied into `/docker-entrypoint-initdb.d` and applied alphabetically when the database is initialized for the first time.

Order:
1. `001-init.sql` enables TimescaleDB and uuid-ossp
2. `100_core_registry.sql` creates registry tables
3. `110_telemetry.sql` creates telemetry tables and indexes
4. `120_timescale_hypertables.sql` defines hypertables and policies
5. `130_views.sql` defines views

Re-running migrations:
- The official Postgres entrypoint only runs `/docker-entrypoint-initdb.d` scripts on first init.
- To re-apply from scratch, remove the data volume and start again.

Reset:
```bash
docker compose down
docker volume rm nsready_db_data
docker compose up --build
```

### Manual Checks / Smoke Tests
Connect:
```bash
docker compose exec db psql -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\"
```

Verify extensions:
```sql
SELECT extname FROM pg_extension WHERE extname IN ('timescaledb','uuid-ossp');
```

Check hypertables:
```sql
SELECT hypertable_name, compression_enabled FROM timescaledb_information.hypertables;
```

Check latest view:
```sql
SELECT * FROM v_scada_latest LIMIT 10;
```

Insert a sample device chain and telemetry:
```sql
INSERT INTO customers(name) VALUES ('Acme') RETURNING id;
-- use returned id in subsequent inserts as needed...
```



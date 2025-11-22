-- Drop unique index that doesn't include partition column (required for hypertable)
-- TimescaleDB requires unique indexes to include the partition column
DROP INDEX IF EXISTS uq_ingest_event_id;

-- Create hypertables and policies
SELECT create_hypertable('ingest_events', by_range('time'), if_not_exists => TRUE);

-- Recreate unique index with time column included (required for hypertables)
CREATE UNIQUE INDEX IF NOT EXISTS uq_ingest_event_id
  ON ingest_events (time, event_id)
  WHERE event_id IS NOT NULL;

-- Optionally hypertable for measurements if desired
-- SELECT create_hypertable('measurements', by_range('time'), if_not_exists => TRUE);

-- Enable compression on ingest_events and set policies
ALTER TABLE ingest_events SET (
  timescaledb.compress = true,
  timescaledb.compress_segmentby = 'device_id,parameter_key'
);

-- Compress chunks older than 7 days
SELECT add_compression_policy('ingest_events', INTERVAL '7 days', if_not_exists => TRUE);

-- Retain raw data for 90 days
SELECT add_retention_policy('ingest_events', INTERVAL '90 days', if_not_exists => TRUE);



-- Telemetry: ingest_events (hypertable), measurements (optional), missing_intervals, error_logs
CREATE TABLE IF NOT EXISTS ingest_events (
    time TIMESTAMPTZ NOT NULL,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    parameter_key TEXT NOT NULL REFERENCES parameter_templates(key) ON DELETE RESTRICT,
    value DOUBLE PRECISION,
    quality SMALLINT NOT NULL DEFAULT 0,
    source TEXT,
    event_id TEXT, -- optional idempotency key from source
    attributes JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (time, device_id, parameter_key)
);

-- Optional summarized measurements table (not necessarily hypertable)
CREATE TABLE IF NOT EXISTS measurements (
    time TIMESTAMPTZ NOT NULL,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    parameter_key TEXT NOT NULL REFERENCES parameter_templates(key) ON DELETE RESTRICT,
    agg_interval TEXT NOT NULL, -- e.g. '1m', '5m', '1h'
    value_avg DOUBLE PRECISION,
    value_min DOUBLE PRECISION,
    value_max DOUBLE PRECISION,
    value_count BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS missing_intervals (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    parameter_key TEXT NOT NULL REFERENCES parameter_templates(key) ON DELETE RESTRICT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS error_logs (
    id BIGSERIAL PRIMARY KEY,
    time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source TEXT,
    level TEXT,
    message TEXT NOT NULL,
    context JSONB DEFAULT '{}'::jsonb
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ingest_events_device_param_time_desc
  ON ingest_events (device_id, parameter_key, time DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ingest_event_id
  ON ingest_events (event_id)
  WHERE event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_measurements_device_param_time
  ON measurements (device_id, parameter_key, time);

CREATE INDEX IF NOT EXISTS idx_missing_intervals_device_param
  ON missing_intervals (device_id, parameter_key, start_time, end_time);

CREATE INDEX IF NOT EXISTS idx_error_logs_time
  ON error_logs (time);



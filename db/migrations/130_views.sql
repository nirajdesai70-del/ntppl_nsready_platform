-- Latest value per device/parameter
CREATE OR REPLACE VIEW v_scada_latest AS
WITH ranked AS (
  SELECT
    device_id,
    parameter_key,
    time,
    value,
    quality,
    ROW_NUMBER() OVER (PARTITION BY device_id, parameter_key ORDER BY time DESC) AS rn
  FROM ingest_events
)
SELECT device_id, parameter_key, time, value, quality
FROM ranked
WHERE rn = 1;

-- History projection for convenience
CREATE OR REPLACE VIEW v_scada_history AS
SELECT
  time, device_id, parameter_key, value, quality, source
FROM ingest_events;



-- Setup read-only user for SCADA database access
-- Usage: Run this script on your NSREADY database to create a dedicated SCADA user
-- 
-- To execute:
-- kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -f /path/to/setup_scada_readonly_user.sql
-- Or copy and paste into psql session

-- Create read-only user (change password as needed)
CREATE USER scada_reader WITH PASSWORD 'CHANGE_THIS_PASSWORD';

-- Grant connection to database
GRANT CONNECT ON DATABASE nsready TO scada_reader;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO scada_reader;

-- Grant SELECT on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO scada_reader;

-- Grant SELECT on all existing sequences (if any)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO scada_reader;

-- Set default privileges for future tables/views
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO scada_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO scada_reader;

-- Grant SELECT on views (explicitly for SCADA views)
GRANT SELECT ON v_scada_latest TO scada_reader;
GRANT SELECT ON v_scada_history TO scada_reader;

-- Optional: Create a materialized view for better performance
-- Uncomment if you want to use materialized views
/*
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_scada_latest_readable AS
SELECT 
    c.name AS customer_name,
    p.name AS project_name,
    s.name AS site_name,
    d.name AS device_name,
    d.external_id AS device_code,
    d.device_type,
    pt.name AS parameter_name,
    pt.key AS parameter_key,
    pt.unit AS parameter_unit,
    v.time AS timestamp,
    v.value,
    v.quality
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
JOIN sites s ON s.id = d.site_id
JOIN projects p ON p.id = s.project_id
JOIN customers c ON c.id = p.customer_id;

CREATE INDEX idx_mv_scada_latest_time ON mv_scada_latest_readable(timestamp DESC);
CREATE INDEX idx_mv_scada_latest_device ON mv_scada_latest_readable(device_name);

GRANT SELECT ON mv_scada_latest_readable TO scada_reader;
*/

-- Verify permissions
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'scada_reader'
ORDER BY table_name, privilege_type;

-- Display connection info
SELECT 
    'User created: scada_reader' AS info,
    'Password: CHANGE_THIS_PASSWORD' AS password_note,
    'Connection string: postgresql://scada_reader:CHANGE_THIS_PASSWORD@<host>:5432/nsready' AS connection_string;








-- Enable TimescaleDB extension and uuid-ossp on first database init
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Migrations are copied into /docker-entrypoint-initdb.d as separate files
-- and executed alphabetically by the Postgres entrypoint on first init.
-- No further action needed here.



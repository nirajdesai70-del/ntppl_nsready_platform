FROM timescale/timescaledb:2.16.1-pg15

# Copy initialization script(s) and migrations (executed alphabetically on first init)
COPY init.sql /docker-entrypoint-initdb.d/001-init.sql
COPY migrations/*.sql /docker-entrypoint-initdb.d/



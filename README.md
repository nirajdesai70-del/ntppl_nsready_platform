## NTPPL NS-Ready Data Collection and Configuration Platform (Tier-1 – Local)

This repository contains a minimal, production-ready Docker scaffold for a local Tier-1 deployment with:
- **admin_tool** (FastAPI, port 8000)
- **collector_service** (FastAPI, port 8001)
- **PostgreSQL 15 with TimescaleDB**
- **NATS** message queue

Phase-1 focuses on the operational environment only (no business logic yet).

### Prerequisites
- Docker Desktop for macOS
- `docker-compose` CLI available (Docker Desktop provides this)

### Project Structure
```
ntppl_nsready_platform/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── Makefile
├── admin_tool/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── collector_service/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
└── db/
    ├── init.sql
    ├── migrations/
    │   └── (placeholder)
    └── Dockerfile
```

### Environment Variables
Copy the example file and adjust as needed:
```bash
cp .env.example .env
```

`.env.example` contains:
```bash
APP_ENV=development
POSTGRES_DB=nsready_db
POSTGRES_USER=nsready_user
POSTGRES_PASSWORD=nsready_password
POSTGRES_HOST=db
POSTGRES_PORT=5432
NATS_URL=nats://nats:4222
```

### Build and Run
Using Makefile:
```bash
make up
```
Or directly:
```bash
docker-compose up --build
```

This will start:
- `admin_tool` on `http://localhost:8000`
- `collector_service` on `http://localhost:8001`
- `Postgres` on `localhost:5432` (TimescaleDB extension enabled)
- `NATS` on `nats://localhost:4222` with monitoring on `http://localhost:8222`

### Health Checks
Test the services:
```bash
curl http://localhost:8000/health
curl http://localhost:8001/health
```
Expected response:
```json
{ "service": "ok" }
```

### Tear Down
```bash
make down
```
Or:
```bash
docker-compose down
```

### Notes
- Database data persists in the named volume `nsready_db_data`.
- Both apps are built with Python 3.11 and served by Uvicorn.
- `collector_service` will use `NATS_URL` and both services can use the DB env vars in future phases.



# مرساة — Clinic Management Platform

A secure, Arabic-first clinic management platform for a psychiatric clinic.

## Repository layout

```
Marsa/
├── backend/        # FastAPI + PostgreSQL API server
├── app/            # Flutter doctor tablet app (Huawei MatePad primary)
├── web/            # Next.js receptionist PWA + public website
├── docs/           # Architecture, schema, decisions
├── docker-compose.yml   # Local dev: PostgreSQL + Redis
└── README.md
```

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Python | 3.12+ | Backend |
| uv | latest | Python package manager (`pip install uv`) |
| Flutter | 3.x | Doctor app |
| Node.js | 20 LTS | Web frontends |
| Docker Desktop | latest | Local DB + Redis |
| PostgreSQL client | any | Optional, for direct DB inspection |

## Quick start (local development)

### 1. Start infrastructure

```powershell
docker compose up -d
```

This starts PostgreSQL 16 on port 5432 and Redis 7 on port 6379.

### 2. Start the backend API

```powershell
cd backend
cp .env.example .env          # then fill in your values
uv sync
uv run alembic upgrade head   # run migrations
uv run uvicorn app.main:app --reload --port 8000
```

API docs available at: http://localhost:8000/docs

### 3. Run backend tests

```powershell
cd backend
uv run pytest -v
```

### 4. Run the Flutter app

```powershell
cd app
flutter pub get
flutter run                   # connects to a running device or emulator
```

## Environment variables

See `backend/.env.example` for all required configuration. Never commit `.env` files.

## Documentation

- [Architecture & plan](docs/architecture.md)
- [Database schema](docs/schema.md)
- [Permissions matrix](docs/permissions.md)
- [Device testing guide](app/DEVICE_TEST.md)

## Development vs. production

- **Development**: Docker Compose for infrastructure, `--reload` server, synthetic data only
- **Production**: Separate environment, separate secrets, separate database — see `docs/deployment.md`

> ⚠️ Never use real patient data in development or testing environments.

## Language

Primary: Arabic (RTL). English support is architecturally ready. All code, comments, and documentation are in English.

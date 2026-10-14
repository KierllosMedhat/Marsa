# مرساة (Marsa) Backend

FastAPI + PostgreSQL + Redis backend for the مرساة psychiatric clinic management system.

## Setup

```bash
# Sync dependencies
uv sync

# Run migrations
uv run alembic upgrade head

# Run tests
uv run pytest

# Run dev server
uv run uvicorn app.main:app --reload
```

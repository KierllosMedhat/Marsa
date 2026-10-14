from datetime import datetime, timezone
from fastapi import APIRouter, Depends
import redis.asyncio as aioredis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.redis_client import get_redis

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check(
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """Health check endpoint verifying database and Redis connectivity. No auth required."""
    db_ok = False
    redis_ok = False

    # Check database
    try:
        res = await db.execute(text("SELECT 1"))
        db_ok = res.scalar() == 1
    except Exception:
        db_ok = False

    # Check Redis
    try:
        redis_ok = bool(await redis.ping())
    except Exception:
        redis_ok = False

    overall_status = "ok" if db_ok and redis_ok else ("degraded" if db_ok else "down")

    return {
        "status": overall_status,
        "db": db_ok,
        "redis": redis_ok,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

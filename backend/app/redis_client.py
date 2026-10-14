from typing import AsyncGenerator
import redis.asyncio as aioredis
from app.config import get_settings

_redis_pool = None


def get_redis_pool():
    global _redis_pool
    if _redis_pool is None:
        settings = get_settings()
        _redis_pool = aioredis.ConnectionPool.from_url(
            settings.redis_url,
            decode_responses=True,
        )
    return _redis_pool


async def get_redis_client() -> aioredis.Redis:
    """Return an async Redis client from the connection pool."""
    pool = get_redis_pool()
    return aioredis.Redis(connection_pool=pool)


async def get_redis() -> AsyncGenerator[aioredis.Redis, None]:
    """FastAPI dependency for obtaining a Redis client."""
    client = await get_redis_client()
    try:
        yield client
    finally:
        await client.aclose()


async def close_redis_pool():
    """Close the global Redis connection pool."""
    global _redis_pool
    if _redis_pool is not None:
        await _redis_pool.disconnect()
        _redis_pool = None

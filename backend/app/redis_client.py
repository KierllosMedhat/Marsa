from typing import Any, AsyncGenerator
import redis.asyncio as aioredis
from app.config import get_settings

_redis_pool = None


class InMemoryRedis:
    """In-memory Redis fallback when no external Redis server is running."""

    def __init__(self):
        self._store: dict[str, str] = {}

    async def get(self, key: str) -> str | None:
        return self._store.get(key)

    async def set(self, key: str, value: str) -> bool:
        self._store[key] = str(value)
        return True

    async def setex(self, key: str, time: int, value: str) -> bool:
        self._store[key] = str(value)
        return True

    async def delete(self, *keys: str) -> int:
        count = 0
        for k in keys:
            if k in self._store:
                del self._store[k]
                count += 1
        return count

    async def aclose(self):
        pass


_in_memory_instance = InMemoryRedis()


def get_redis_pool():
    global _redis_pool
    if _redis_pool is None:
        settings = get_settings()
        try:
            _redis_pool = aioredis.ConnectionPool.from_url(
                settings.redis_url,
                decode_responses=True,
            )
        except Exception:
            _redis_pool = None
    return _redis_pool


async def get_redis_client() -> Any:
    """Return an async Redis client or in-memory fallback."""
    pool = get_redis_pool()
    if pool is not None:
        try:
            client = aioredis.Redis(connection_pool=pool)
            await client.ping()
            return client
        except Exception:
            pass
    return _in_memory_instance


async def get_redis() -> AsyncGenerator[Any, None]:
    """FastAPI dependency for obtaining a Redis client."""
    client = await get_redis_client()
    try:
        yield client
    finally:
        if hasattr(client, "aclose") and not isinstance(client, InMemoryRedis):
            try:
                await client.aclose()
            except Exception:
                pass


async def close_redis_pool():
    """Close the global Redis connection pool."""
    global _redis_pool
    if _redis_pool is not None:
        try:
            await _redis_pool.disconnect()
        except Exception:
            pass
        _redis_pool = None

import hashlib
import json
import logging
from typing import Any, Optional

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger(__name__)


class CacheService:
    """Redis-backed caching service for search results and frequently accessed data."""

    def __init__(self):
        self._redis: Optional[aioredis.Redis] = None
        self._prefix = "apex:cache:"

    async def connect(self):
        """Connect to Redis (idempotent)."""
        if self._redis is not None:
            return
        try:
            self._redis = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=3,
                socket_timeout=3,
            )
            await self._redis.ping()
            logger.info("Cache service connected to Redis")
        except Exception as e:
            logger.warning(f"Cache service Redis unavailable: {e}")
            self._redis = None

    async def close(self):
        """Close Redis connection."""
        if self._redis is not None:
            try:
                await self._redis.aclose()
            except Exception:
                pass
            self._redis = None

    def _key(self, key: str) -> str:
        """Prefix a key."""
        if key.startswith(self._prefix):
            return key
        return f"{self._prefix}{key}"

    async def get(self, key: str) -> Optional[str]:
        """Get cached value by key."""
        if self._redis is None:
            return None
        try:
            return await self._redis.get(self._key(key))
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None

    async def set(self, key: str, value: str, ttl: int = 300):
        """Set cached value with TTL in seconds (default 5 min)."""
        if self._redis is None:
            return
        try:
            await self._redis.set(self._key(key), value, ex=ttl)
        except Exception as e:
            logger.error(f"Cache set error: {e}")

    async def delete(self, key: str):
        """Delete cached value."""
        if self._redis is None:
            return
        try:
            await self._redis.delete(self._key(key))
        except Exception as e:
            logger.error(f"Cache delete error: {e}")

    async def delete_pattern(self, pattern: str):
        """Delete all keys matching pattern (e.g. 'apex:cache:search:*')."""
        if self._redis is None:
            return
        try:
            full_pattern = self._key(pattern) if not pattern.startswith(self._prefix) else pattern
            cursor = 0
            while True:
                cursor, keys = await self._redis.scan(cursor=cursor, match=full_pattern, count=200)
                if keys:
                    await self._redis.delete(*keys)
                if cursor == 0:
                    break
        except Exception as e:
            logger.error(f"Cache delete_pattern error: {e}")

    async def invalidate_property(self, property_id: str):
        """Invalidate all caches related to a property."""
        await self.delete(f"property:{property_id}")
        await self.delete_pattern("search:*")

    async def invalidate_search(self):
        """Invalidate all search-related caches."""
        await self.delete_pattern("search:*")


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------
cache_service = CacheService()


# ---------------------------------------------------------------------------
# Key generation
# ---------------------------------------------------------------------------
def make_search_cache_key(**filters) -> str:
    """Generate deterministic cache key from search filters using MD5 hash."""
    canonical = json.dumps(filters, sort_keys=True, default=str)
    h = hashlib.md5(canonical.encode()).hexdigest()
    return f"search:{h}"


# ---------------------------------------------------------------------------
# High-level helpers
# ---------------------------------------------------------------------------
async def cache_search_results(query_hash: str, results: list, ttl: int = 300):
    """Cache search results by query hash."""
    await cache_service.set(f"search:{query_hash}", json.dumps(results, default=str), ttl=ttl)


async def get_cached_search(query_hash: str) -> Optional[list]:
    """Get cached search results."""
    raw = await cache_service.get(f"search:{query_hash}")
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return None


async def cache_property(property_id: str, property_data: dict, ttl: int = 600):
    """Cache property details (10 min TTL)."""
    await cache_service.set(
        f"property:{property_id}",
        json.dumps(property_data, default=str),
        ttl=ttl,
    )


async def get_cached_property(property_id: str) -> Optional[dict]:
    """Get cached property."""
    raw = await cache_service.get(f"property:{property_id}")
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return None

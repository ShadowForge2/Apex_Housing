import time
import logging
from typing import Optional
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
import redis.asyncio as redis

from app.config import settings

logger = logging.getLogger(__name__)

# Default limits by endpoint category (requests per window_seconds)
RATE_LIMITS = {
    "auth": {"max_requests": 10, "window_seconds": 60},
    "payment": {"max_requests": 20, "window_seconds": 60},
    "booking": {"max_requests": 30, "window_seconds": 60},
    "escrow": {"max_requests": 30, "window_seconds": 60},
    "search": {"max_requests": 60, "window_seconds": 60},
    "upload": {"max_requests": 10, "window_seconds": 60},
    "default": {"max_requests": 100, "window_seconds": 60},
}

# Per-user authenticated limits (higher than anonymous)
AUTHENTICATED_MULTIPLIER = 5

# Path prefix -> rate limit category mapping
PATH_CATEGORIES = {
    "/api/v1/auth/": "auth",
    "/api/v1/payments/": "payment",
    "/api/v1/bookings/": "booking",
    "/api/v1/escrow/": "escrow",
    "/api/v1/search/": "search",
    "/api/v1/favorites/": "default",
    "/api/v1/reviews/": "default",
    "/api/v1/disputes/": "default",
    "/api/v1/messages/": "default",
}


_global_rate_limiter: Optional["RateLimitMiddleware"] = None


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Redis-backed sliding window rate limiter.
    Handles 1M+ concurrent users via Redis atomic operations.
    """

    def __init__(self, app, redis_url: str = None):
        super().__init__(app)
        self.redis_url = redis_url or settings.REDIS_URL
        self._redis: Optional[redis.Redis] = None
        global _global_rate_limiter
        _global_rate_limiter = self

    async def close(self):
        if self._redis is not None:
            await self._redis.aclose()
            self._redis = None

    async def _get_redis(self) -> Optional[redis.Redis]:
        if self._redis is None:
            try:
                self._redis = redis.from_url(
                    self.redis_url,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=2,
                    socket_timeout=2,
                )
            except Exception as e:
                logger.error(f"Redis connection failed: {e}")
                return None
        return self._redis

    def _get_category(self, path: str) -> str:
        for prefix, category in PATH_CATEGORIES.items():
            if path.startswith(prefix):
                return category
        return "default"

    def _get_rate_limit(self, category: str, is_authenticated: bool) -> dict:
        limits = RATE_LIMITS.get(category, RATE_LIMITS["default"])
        if is_authenticated:
            return {
                "max_requests": limits["max_requests"] * AUTHENTICATED_MULTIPLIER,
                "window_seconds": limits["window_seconds"],
            }
        return limits

    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health check and docs
        if request.url.path in ("/health", "/docs", "/redoc", "/openapi.json"):
            return await call_next(request)

        # Skip if Redis is down (fail open)
        r = await self._get_redis()
        if r is None:
            return await call_next(request)

        # Identify the user (by token or IP)
        user_id = self._extract_user_id(request)
        category = self._get_category(request.url.path)
        limits = self._get_rate_limit(category, user_id.startswith("user:"))

        # Sliding window rate limit key
        key = f"rl:{category}:{user_id}"
        window = limits["window_seconds"]
        max_requests = limits["max_requests"]

        now = time.time()
        window_start = now - window

        try:
            pipe = r.pipeline()
            # Remove expired entries
            pipe.zremrangebyscore(key, 0, window_start)
            # Count current window requests
            pipe.zcard(key)
            # Add current request
            pipe.zadd(key, {f"{now}": now})
            # Set expiry on key
            pipe.expire(key, window)
            results = await pipe.execute()

            current_count = results[1]

            if current_count >= max_requests:
                retry_after = int(window - (now - (now - window)))
                return JSONResponse(
                    status_code=429,
                    content={
                        "success": False,
                        "message": "Rate limit exceeded. Please try again later.",
                    },
                    headers={
                        "Retry-After": str(retry_after),
                        "X-RateLimit-Limit": str(max_requests),
                        "X-RateLimit-Remaining": "0",
                        "X-RateLimit-Reset": str(int(now + retry_after)),
                    },
                )

            response = await call_next(request)
            remaining = max_requests - current_count - 1
            response.headers["X-RateLimit-Limit"] = str(max_requests)
            response.headers["X-RateLimit-Remaining"] = str(max(0, remaining))
            response.headers["X-RateLimit-Reset"] = str(int(now + window))
            return response

        except Exception as e:
            logger.error(f"Rate limit error: {e}")
            # Fail open — let request through
            return await call_next(request)

    def _extract_user_id(self, request: Request) -> str:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
            try:
                from app.auth.service import decode_token
                payload = decode_token(token)
                return f"user:{payload.get('sub', 'unknown')}"
            except Exception:
                pass
        # Fall back to IP address
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            ip = forwarded.split(",")[0].strip()
        else:
            ip = request.client.host if request.client else "unknown"
        return f"ip:{ip}"

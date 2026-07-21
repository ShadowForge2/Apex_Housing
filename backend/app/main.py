import sys
if sys.platform == "win32":
    import asyncio
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging

from app.config import settings
from app.common.exceptions import AppException

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")
    from app.services.sentry_service import init_sentry
    init_sentry()
    from app.events.handlers import register_all_handlers
    await register_all_handlers()

    # Verify Redis connectivity on startup
    try:
        import redis.asyncio as aioredis
        _redis = aioredis.from_url(settings.REDIS_URL, socket_connect_timeout=3)
        await _redis.ping()
        await _redis.aclose()
        logger.info("Redis connection verified")
    except Exception as e:
        logger.warning(f"Redis unavailable (rate limiting disabled): {e}")

    # Connect cache service
    from app.services.cache import cache_service
    await cache_service.connect()

    yield

    # Shutdown: close cache service and rate limiter Redis
    from app.services.cache import cache_service
    await cache_service.close()

    from app.middleware.rate_limit import _global_rate_limiter
    if _global_rate_limiter:
        await _global_rate_limiter.close()
    logger.info("Shutting down...")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="APEX Housing - Landlord-Tenant Marketplace Platform with Escrow Protection",
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json" if settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset", "Retry-After", "X-Request-ID"],
)

from app.middleware.api_logging import APILoggingMiddleware
app.add_middleware(APILoggingMiddleware)

if settings.RATE_LIMIT_ENABLED:
    from app.middleware.rate_limit import RateLimitMiddleware
    app.add_middleware(RateLimitMiddleware)

@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "message": exc.message, "errors": exc.errors},
    )

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    try:
        from app.services.sentry_service import capture_exception
        capture_exception(exc)
    except Exception:
        pass
    return JSONResponse(
        status_code=500,
        content={"success": False, "message": "Internal server error"},
    )

from app.health import router as health_router
from app.auth.router import router as auth_router
from app.users.router import router as users_router
from app.properties.router import router as properties_router
from app.bookings.router import router as bookings_router
from app.escrow.router import router as escrow_router
from app.payments.router import router as payments_router
from app.messages.router import router as messages_router
from app.notifications.router import router as notifications_router
from app.reviews.router import router as reviews_router
from app.documents.router import router as documents_router
from app.disputes.router import router as disputes_router
from app.search.router import router as search_router
from app.maps.router import router as maps_router
from app.admin.router import router as admin_router
from app.commission.router import router as admin_commission_router
from app.analytics.router import router as admin_analytics_router
from app.favorites.router import router as favorites_router
from app.payments.webhook_router import router as webhook_router
from app.reports.router import router as reports_router
from app.amenities.router import router as amenities_router
from app.agents.router import router as agents_router
from app.landlords.router import router as landlords_router
from app.sharing.router import router as sharing_router

app.include_router(health_router)

# --- Sharing (public pages, no API prefix) ---
app.include_router(sharing_router)

# --- Webhooks (no API_V1_PREFIX — Paystack hits these directly) ---
app.include_router(webhook_router)

# --- Shared (both user app and admin app) ---
app.include_router(auth_router, prefix=settings.API_V1_PREFIX)

# --- User App routes ---
app.include_router(users_router, prefix=settings.API_V1_PREFIX)
app.include_router(properties_router, prefix=settings.API_V1_PREFIX)
app.include_router(bookings_router, prefix=settings.API_V1_PREFIX)
app.include_router(escrow_router, prefix=settings.API_V1_PREFIX)
app.include_router(payments_router, prefix=settings.API_V1_PREFIX)
app.include_router(messages_router, prefix=settings.API_V1_PREFIX)
app.include_router(notifications_router, prefix=settings.API_V1_PREFIX)
app.include_router(reviews_router, prefix=settings.API_V1_PREFIX)
app.include_router(documents_router, prefix=settings.API_V1_PREFIX)
app.include_router(disputes_router, prefix=settings.API_V1_PREFIX)
app.include_router(search_router, prefix=settings.API_V1_PREFIX)
app.include_router(maps_router, prefix=settings.API_V1_PREFIX)
app.include_router(favorites_router, prefix=settings.API_V1_PREFIX)
app.include_router(reports_router, prefix=settings.API_V1_PREFIX)
app.include_router(amenities_router, prefix=settings.API_V1_PREFIX)
app.include_router(agents_router, prefix=settings.API_V1_PREFIX)
app.include_router(landlords_router, prefix=settings.API_V1_PREFIX)

# --- Admin App routes ---
app.include_router(admin_router, prefix=settings.API_V1_PREFIX)
app.include_router(admin_commission_router, prefix=settings.API_V1_PREFIX)
app.include_router(admin_analytics_router, prefix=settings.API_V1_PREFIX)

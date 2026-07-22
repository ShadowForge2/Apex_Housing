import logging
import asyncio
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.otp_tasks.cleanup_expired_otps")
def cleanup_expired_otps():
    """Delete expired and used OTP codes to keep the database clean."""
    logger.info("Cleaning up expired OTP codes")

    async def _cleanup():
        from datetime import datetime, timedelta, timezone
        from sqlalchemy import delete
        from app.database import async_session
        from app.auth.models import OTPCode

        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        async with async_session() as db:
            result = await db.execute(
                delete(OTPCode).where(
                    (OTPCode.expires_at < datetime.now(timezone.utc)) |
                    ((OTPCode.is_used == True) & (OTPCode.created_at < cutoff))
                )
            )
            await db.commit()
            logger.info(f"Deleted {result.rowcount} expired/used OTP codes")

    _run_async(_cleanup())

import logging
import asyncio
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.escrow_tasks.check_expired_escrows")
def check_expired_escrows():
    """Check for escrows whose 30-hour hold timer has expired and auto-release."""
    logger.info("Checking for expired escrow timers")

    async def _check():
        from app.database import async_session
        from app.escrow.service import EscrowService

        async with async_session() as db:
            service = EscrowService(db)
            released = await service.auto_release_expired()
            logger.info(f"Auto-released {len(released)} expired escrows")

    _run_async(_check())


@celery_app.task(name="app.tasks.escrow_tasks.auto_release_escrow")
def auto_release_escrow(escrow_id: str):
    """Automatically release escrow funds after 30 hours if no dispute."""
    logger.info(f"Auto-releasing escrow {escrow_id}")

    async def _release():
        from uuid import UUID
        from app.database import async_session
        from app.escrow.service import EscrowService

        async with async_session() as db:
            service = EscrowService(db)
            await service.release_funds(UUID(escrow_id))
            logger.info(f"Escrow {escrow_id} auto-released successfully")

    _run_async(_release())


@celery_app.task(name="app.tasks.escrow_tasks.start_escrow_timer")
def start_escrow_timer(escrow_id: str):
    """Start the 30-hour timer after move-in confirmation."""
    logger.info(f"Starting 30-hour timer for escrow {escrow_id}")

    async def _start():
        from uuid import UUID
        from app.database import async_session
        from app.escrow.service import EscrowService

        async with async_session() as db:
            service = EscrowService(db)
            escrow = await service.get_escrow(UUID(escrow_id))
            logger.info(f"Timer started for escrow {escrow_id}, expires at {escrow.hold_expires_at}")

    _run_async(_start())


@celery_app.task(name="app.tasks.escrow_tasks.send_escrow_expiry_reminders")
def send_escrow_expiry_reminders():
    """Send reminders to tenants for escrows expiring within 2 hours (Fix #6)."""
    logger.info("Checking for escrows expiring soon")

    async def _check():
        from app.database import async_session
        from app.escrow.service import EscrowService

        async with async_session() as db:
            service = EscrowService(db)
            count = await service.send_expiring_soon_reminders()
            logger.info(f"Sent {count} escrow expiry reminders")

    _run_async(_check())

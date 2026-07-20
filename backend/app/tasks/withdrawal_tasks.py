import logging
import asyncio
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.withdrawal_tasks.process_scheduled_withdrawals")
def process_scheduled_withdrawals():
    """
    Process all withdrawals that are scheduled for now or earlier.
    Runs every 15 minutes during business hours.
    Only processes on business days.
    """
    logger.info("Checking for scheduled withdrawals to process")

    async def _process():
        from app.database import async_session
        from app.payments.service import PaymentService
        from app.common.business_days import is_business_day

        now = __import__("datetime").datetime.utcnow()
        if not is_business_day(now):
            logger.info("Not a business day, skipping withdrawal processing")
            return

        async with async_session() as db:
            service = PaymentService(db)
            processed = await service.process_pending_withdrawals()
            if processed:
                logger.info(f"Processed {len(processed)} scheduled withdrawals")
            else:
                logger.debug("No scheduled withdrawals to process")

    _run_async(_process())


@celery_app.task(name="app.tasks.withdrawal_tasks.refund_expired_withdrawals")
def refund_expired_withdrawals():
    """
    Auto-refund withdrawals that have been pending/scheduled for more than 48 hours.
    Runs every hour.
    """
    logger.info("Checking for expired withdrawals to refund")

    async def _refund():
        from app.database import async_session
        from app.payments.service import PaymentService

        async with async_session() as db:
            service = PaymentService(db)
            refunded = await service.auto_refund_expired_withdrawals()
            if refunded:
                logger.info(f"Auto-refunded {len(refunded)} expired withdrawals")
            else:
                logger.debug("No expired withdrawals to refund")

    _run_async(_refund())

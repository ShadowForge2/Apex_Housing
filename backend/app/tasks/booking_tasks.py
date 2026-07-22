import logging
import asyncio
from uuid import uuid4
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.booking_tasks.expire_pending_bookings")
def expire_pending_bookings():
    """Expire bookings that haven't been confirmed within 48 hours."""
    logger.info("Expiring stale bookings")

    async def _expire():
        from datetime import datetime, timedelta, timezone
        from sqlalchemy import select
        from app.database import async_session
        from app.bookings.models import Booking, BookingStatusHistory
        from app.common.enums import BookingStatus
        from app.users.models import User
        from app.notifications.service import NotificationService

        cutoff = datetime.now(timezone.utc) - timedelta(hours=48)
        async with async_session() as db:
            result = await db.execute(
                select(Booking).where(
                    Booking.status == BookingStatus.PENDING,
                    Booking.created_at <= cutoff,
                )
            )
            stale = result.scalars().all()
            service = NotificationService(db)
            for booking in stale:
                booking.status = BookingStatus.EXPIRED
                history = BookingStatusHistory(
                    id=uuid4(), booking_id=booking.id,
                    status=BookingStatus.EXPIRED, notes="Auto-expired after 48h",
                )
                db.add(history)

                await service.send_notification(
                    user_id=booking.tenant_id,
                    title="Booking Expired",
                    message="Your booking has expired because it was not confirmed within 48 hours.",
                    reference_type="booking", reference_id=booking.id,
                )

                from app.properties.models import PropertyAvailability
                avail_result = await db.execute(
                    select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
                )
                avail = avail_result.scalar_one_or_none()
                if avail:
                    avail.is_available = True

            await db.commit()
            logger.info(f"Expired {len(stale)} stale bookings")

    _run_async(_expire())


@celery_app.task(name="app.tasks.booking_tasks.process_booking_expiration")
def process_booking_expiration(booking_id: str):
    logger.info(f"Processing expiration for booking {booking_id}")

    async def _process():
        from uuid import UUID
        from sqlalchemy import select
        from app.database import async_session
        from app.bookings.models import Booking, BookingStatusHistory
        from app.common.enums import BookingStatus
        from app.notifications.service import NotificationService
        from app.properties.models import PropertyAvailability

        async with async_session() as db:
            result = await db.execute(select(Booking).where(Booking.id == UUID(booking_id)))
            booking = result.scalar_one_or_none()
            if not booking or booking.status != BookingStatus.PENDING:
                return

            booking.status = BookingStatus.EXPIRED
            history = BookingStatusHistory(
                id=uuid4(), booking_id=booking.id,
                status=BookingStatus.EXPIRED, notes="Manually expired",
            )
            db.add(history)
            await db.commit()

            service = NotificationService(db)
            await service.send_notification(
                user_id=booking.tenant_id,
                title="Booking Expired",
                message="Your booking has expired.",
                reference_type="booking", reference_id=booking.id,
            )

    _run_async(_process())

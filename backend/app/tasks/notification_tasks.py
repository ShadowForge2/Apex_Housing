import logging
import asyncio
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.notification_tasks.send_push_notification")
def send_push_notification(user_id: str, title: str, message: str, data: dict = None):
    logger.info(f"Sending push to {user_id}: {title}")

    async def _send():
        from uuid import UUID
        from app.database import async_session
        from app.notifications.service import NotificationService

        async with async_session() as db:
            service = NotificationService(db)
            await service._send_push(UUID(user_id), title, message, data=data or {})

    _run_async(_send())


@celery_app.task(name="app.tasks.notification_tasks.send_email_notification")
def send_email_notification(user_id: str, subject: str, html: str):
    logger.info(f"Sending email to user {user_id}: {subject}")

    async def _send():
        from uuid import UUID
        from app.database import async_session
        from app.notifications.service import NotificationService

        async with async_session() as db:
            service = NotificationService(db)
            await service._send_email(UUID(user_id), subject, html)

    _run_async(_send())


@celery_app.task(name="app.tasks.notification_tasks.send_rent_reminders")
def send_rent_reminders():
    """Send daily rent due reminders to tenants."""
    logger.info("Sending rent reminders")

    async def _send():
        from datetime import datetime, timedelta, timezone
        from sqlalchemy import select
        from app.database import async_session
        from app.bookings.models import Booking
        from app.common.enums import BookingStatus
        from app.users.models import User
        from app.notifications.service import NotificationService

        async with async_session() as db:
            upcoming = datetime.now(timezone.utc) + timedelta(days=7)
            result = await db.execute(
                select(Booking).where(
                    Booking.status.in_([BookingStatus.ACTIVE, BookingStatus.CONFIRMED]),
                )
            )
            bookings = result.scalars().all()
            service = NotificationService(db)
            for booking in bookings:
                user_result = await db.execute(select(User).where(User.id == booking.tenant_id))
                user = user_result.scalar_one_or_none()
                if user:
                    await service.send_notification(
                        user_id=booking.tenant_id,
                        title="Rent Reminder",
                        message="Your rent payment is due soon. Please ensure timely payment.",
                        reference_type="booking", reference_id=booking.id,
                    )
            logger.info(f"Sent {len(bookings)} rent reminders")

    _run_async(_send())


@celery_app.task(name="app.tasks.notification_tasks.send_lease_expiry_reminders")
def send_lease_expiry_reminders():
    """Send lease expiry reminders 30 days before expiry."""
    logger.info("Sending lease expiry reminders")

    async def _send():
        from datetime import datetime, timedelta, timezone
        from sqlalchemy import select
        from app.database import async_session
        from app.bookings.models import Booking
        from app.common.enums import BookingStatus
        from app.notifications.service import NotificationService

        async with async_session() as db:
            now = datetime.now(timezone.utc)
            thirty_days = now + timedelta(days=30)
            result = await db.execute(
                select(Booking).where(
                    Booking.status == BookingStatus.ACTIVE,
                    Booking.lease_end_date <= thirty_days,
                    Booking.lease_end_date >= now,
                )
            )
            bookings = result.scalars().all()
            service = NotificationService(db)
            for booking in bookings:
                await service.send_notification(
                    user_id=booking.tenant_id,
                    title="Lease Expiring Soon",
                    message=f"Your lease expires on {booking.lease_end_date.strftime('%B %d, %Y')}. Please renew or plan accordingly.",
                    reference_type="booking", reference_id=booking.id,
                )
            logger.info(f"Sent {len(bookings)} lease expiry reminders")

    _run_async(_send())

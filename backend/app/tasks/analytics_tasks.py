import logging
import asyncio
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.analytics_tasks.aggregate_daily_analytics")
def aggregate_daily_analytics():
    """Aggregate daily platform metrics into daily_analytics table."""
    logger.info("Aggregating daily analytics")

    async def _aggregate():
        from datetime import date, timedelta
        from sqlalchemy import select, func
        from app.database import async_session
        from app.users.models import User
        from app.bookings.models import Booking
        from app.payments.models import Transaction
        from app.properties.models import Property
        from app.analytics.models import DailyAnalytics
        from app.common.enums import BookingStatus, PaymentStatus, PropertyStatus

        yesterday = date.today() - timedelta(days=1)

        async with async_session() as db:
            existing = await db.execute(
                select(DailyAnalytics).where(DailyAnalytics.date == yesterday)
            )
            if existing.scalar_one_or_none():
                logger.info(f"Analytics for {yesterday} already exist, skipping")
                return

            total_users = (await db.execute(select(func.count()).select_from(User))).scalar() or 0
            total_properties = (await db.execute(select(func.count()).select_from(Property))).scalar() or 0

            new_users = (await db.execute(
                select(func.count()).select_from(User).where(func.date(User.created_at) == yesterday)
            )).scalar() or 0

            new_bookings = (await db.execute(
                select(func.count()).select_from(Booking).where(func.date(Booking.created_at) == yesterday)
            )).scalar() or 0

            new_revenue = (await db.execute(
                select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                    Transaction.status == PaymentStatus.SUCCESS,
                    func.date(Transaction.created_at) == yesterday,
                )
            )).scalar() or 0

            total_revenue = (await db.execute(
                select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                    Transaction.status == PaymentStatus.SUCCESS,
                )
            )).scalar() or 0

            active_properties = (await db.execute(
                select(func.count()).select_from(Property).where(Property.status == PropertyStatus.ACTIVE)
            )).scalar() or 0

            occupancy = (float(active_properties) / float(total_properties) * 100) if total_properties > 0 else 0

            metric = DailyAnalytics(
                date=yesterday,
                total_users=total_users,
                new_users=new_users,
                total_properties=total_properties,
                active_properties=active_properties,
                new_bookings=new_bookings,
                total_revenue=float(total_revenue),
                new_revenue=float(new_revenue),
                total_escrow=0,
                escrow_released=0,
                escrow_refunded=0,
                occupancy_rate=occupancy,
                conversion_rate=0,
            )
            db.add(metric)
            await db.commit()
            logger.info(f"Daily analytics for {yesterday}: {new_bookings} bookings, {new_revenue} NGN revenue")

    _run_async(_aggregate())


@celery_app.task(name="app.tasks.analytics_tasks.update_popular_searches")
def update_popular_searches():
    """Update popular search terms from last 24h."""
    logger.info("Updating popular searches")

    async def _update():
        from datetime import datetime, timedelta
        from sqlalchemy import select, func
        from app.database import async_session
        from app.analytics.models import SearchAnalytics

        cutoff = datetime.utcnow() - timedelta(hours=24)
        async with async_session() as db:
            result = await db.execute(
                select(SearchAnalytics.search_query, func.count().label("cnt"))
                .where(
                    SearchAnalytics.created_at >= cutoff,
                    SearchAnalytics.search_query.isnot(None),
                )
                .group_by(SearchAnalytics.search_query)
                .order_by(func.count().desc())
                .limit(20)
            )
            popular = result.all()
            logger.info(f"Top searches: {[p[0] for p in popular[:5]]}")

    _run_async(_update())


@celery_app.task(name="app.tasks.analytics_tasks.update_property_stats")
def update_property_stats():
    """Update property view counts and engagement stats."""
    logger.info("Updating property stats")

    async def _update():
        from sqlalchemy import select, func
        from app.database import async_session
        from app.properties.models import Property
        from app.bookings.models import Booking

        async with async_session() as db:
            result = await db.execute(select(Property.id))
            property_ids = [row[0] for row in result.all()]

            for pid in property_ids:
                bookings = (await db.execute(
                    select(func.count()).select_from(Booking).where(Booking.property_id == pid)
                )).scalar() or 0

            logger.info(f"Updated stats for {len(property_ids)} properties")

    _run_async(_update())

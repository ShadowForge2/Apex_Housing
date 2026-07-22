from datetime import datetime, timedelta, timezone
from decimal import Decimal
from calendar import month_abbr
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, extract

from app.users.models import Landlord
from app.properties.models import Property, PropertyPricing, PropertyAvailability
from app.bookings.models import Booking
from app.common.enums import BookingStatus


class LandlordAnalyticsService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_landlord(self, user_id: UUID) -> Landlord | None:
        result = await self.db.execute(
            select(Landlord).where(Landlord.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_summary(self, landlord: Landlord) -> dict:
        now = datetime.now(timezone.utc)
        current_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        prev_month_start = (current_month_start - timedelta(days=1)).replace(day=1)

        total_revenue_result = await self.db.execute(
            select(func.coalesce(func.sum(Booking.total_amount), 0.0)).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
            )
        )
        total_revenue = float(total_revenue_result.scalar())

        current_month_result = await self.db.execute(
            select(func.coalesce(func.sum(Booking.total_amount), 0.0)).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
                Booking.created_at >= current_month_start,
            )
        )
        current_month_revenue = float(current_month_result.scalar())

        prev_month_result = await self.db.execute(
            select(func.coalesce(func.sum(Booking.total_amount), 0.0)).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
                Booking.created_at >= prev_month_start,
                Booking.created_at < current_month_start,
            )
        )
        prev_month_revenue = float(prev_month_result.scalar())

        months_with_revenue_result = await self.db.execute(
            select(func.count(func.distinct(
                func.date_trunc('month', Booking.created_at)
            ))).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
            )
        )
        months_with_revenue = max(months_with_revenue_result.scalar() or 1, 1)
        avg_monthly = total_revenue / months_with_revenue

        total_properties_result = await self.db.execute(
            select(func.count()).select_from(Property).where(Property.landlord_id == landlord.id)
        )
        total_properties = total_properties_result.scalar()

        active_bookings_result = await self.db.execute(
            select(func.count()).select_from(Booking).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.CONFIRMED, BookingStatus.ACTIVE]),
            )
        )
        active_bookings = active_bookings_result.scalar()
        occupancy_rate = round((active_bookings / total_properties * 100)) if total_properties > 0 else 0

        if prev_month_revenue > 0:
            growth = round(((current_month_revenue - prev_month_revenue) / prev_month_revenue) * 100)
        else:
            growth = 100 if current_month_revenue > 0 else 0

        return {
            "totalRevenue": total_revenue,
            "avgMonthly": round(avg_monthly),
            "occupancyRate": occupancy_rate,
            "growthPercent": growth,
        }

    async def get_revenue_chart(self, landlord: Landlord) -> dict:
        now = datetime.now(timezone.utc)
        months = []
        for i in range(11, -1, -1):
            d = now - timedelta(days=i * 30)
            months.append({
                "year": d.year,
                "month": d.month,
                "label": month_abbr[d.month],
            })

        monthly_revenue = []
        for m in months:
            start = datetime(m["year"], m["month"], 1)
            if m["month"] == 12:
                end = datetime(m["year"] + 1, 1, 1)
            else:
                end = datetime(m["year"], m["month"] + 1, 1)

            result = await self.db.execute(
                select(func.coalesce(func.sum(Booking.total_amount), 0.0)).where(
                    Booking.landlord_id == landlord.id,
                    Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
                    Booking.created_at >= start,
                    Booking.created_at < end,
                )
            )
            revenue = float(result.scalar())
            monthly_revenue.append({
                "label": m["label"],
                "month": m["label"],
                "amount": round(revenue),
            })

        return {"monthlyRevenue": monthly_revenue}

    async def get_property_analytics(self, landlord: Landlord) -> dict:
        props_result = await self.db.execute(
            select(Property, PropertyPricing, PropertyAvailability).outerjoin(
                PropertyPricing, PropertyPricing.property_id == Property.id
            ).outerjoin(
                PropertyAvailability, PropertyAvailability.property_id == Property.id
            ).where(Property.landlord_id == landlord.id)
        )
        rows = props_result.all()

        properties = []
        for prop, pricing, availability in rows:
            active_booking_result = await self.db.execute(
                select(func.count()).select_from(Booking).where(
                    Booking.property_id == prop.id,
                    Booking.status.in_([BookingStatus.CONFIRMED, BookingStatus.ACTIVE]),
                )
            )
            active_bookings = active_booking_result.scalar()

            completed_revenue_result = await self.db.execute(
                select(func.coalesce(func.sum(Booking.total_amount), 0.0)).where(
                    Booking.property_id == prop.id,
                    Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
                )
            )
            revenue = float(completed_revenue_result.scalar())

            is_booked = availability.is_booked if availability else False
            status = "occupied" if is_booked or active_bookings > 0 else "vacant"
            occupancy = 100 if status == "occupied" else 0

            rent = float(pricing.rent_amount) if pricing else 0

            properties.append({
                "name": prop.title,
                "type": prop.property_type.lower(),
                "revenue": f"₦{revenue:,.0f} total",
                "revenueRaw": round(revenue),
                "status": status,
                "occupancy": occupancy,
                "views": 0,
                "inquiries": 0,
            })

        return {"properties": properties}

    async def get_occupancy(self, landlord: Landlord) -> dict:
        total_result = await self.db.execute(
            select(func.count()).select_from(Property).where(Property.landlord_id == landlord.id)
        )
        total_properties = total_result.scalar()

        booked_result = await self.db.execute(
            select(func.count()).select_from(PropertyAvailability).join(
                Property, Property.id == PropertyAvailability.property_id
            ).where(
                Property.landlord_id == landlord.id,
                PropertyAvailability.is_booked == True,
            )
        )
        booked_count = booked_result.scalar()
        occupied = booked_count
        vacant = total_properties - occupied
        avg_occupancy = round((occupied / total_properties * 100)) if total_properties > 0 else 0

        return {
            "avgOccupancy": avg_occupancy,
            "occupiedUnits": f"{occupied} units",
            "vacantUnits": f"{vacant} units",
            "totalProperties": f"{total_properties} properties",
        }

    async def get_insights(self, landlord: Landlord) -> dict:
        insights = []

        props_result = await self.db.execute(
            select(Property, PropertyPricing).outerjoin(
                PropertyPricing, PropertyPricing.property_id == Property.id
            ).where(Property.landlord_id == landlord.id)
        )
        props = props_result.all()

        if not props:
            return {"insights": []}

        total_properties = len(props)

        active_bookings_result = await self.db.execute(
            select(func.count()).select_from(Booking).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.CONFIRMED, BookingStatus.ACTIVE]),
            )
        )
        active_bookings = active_bookings_result.scalar()

        if active_bookings > 0:
            insights.append({
                "title": f"{active_bookings} Active Booking{'s' if active_bookings != 1 else ''}",
                "subtitle": f"You have {active_bookings} active booking{'s' if active_bookings != 1 else ''} across your {total_properties} properties.",
                "icon": "home_work",
                "color": "primary",
            })

        total_revenue_result = await self.db.execute(
            select(func.coalesce(func.sum(Booking.total_amount), 0.0)).where(
                Booking.landlord_id == landlord.id,
                Booking.status.in_([BookingStatus.COMPLETED, BookingStatus.ACTIVE]),
            )
        )
        total_revenue = float(total_revenue_result.scalar())

        if total_revenue > 0:
            insights.append({
                "title": f"₦{total_revenue:,.0f} Total Revenue",
                "subtitle": f"Your properties have generated ₦{total_revenue:,.0f} in total booking revenue.",
                "icon": "trending_up",
                "color": "success",
            })

        occupancy_result = await self.db.execute(
            select(func.count()).select_from(PropertyAvailability).join(
                Property, Property.id == PropertyAvailability.property_id
            ).where(
                Property.landlord_id == landlord.id,
                PropertyAvailability.is_booked == True,
            )
        )
        occupied_count = occupancy_result.scalar()
        if total_properties > 0:
            occupancy_pct = round((occupied_count / total_properties) * 100)
            if occupancy_pct < 50:
                insights.append({
                    "title": f"Occupancy at {occupancy_pct}%",
                    "subtitle": f"Only {occupied_count} of {total_properties} units are occupied. Consider adjusting pricing or listing on more channels.",
                    "icon": "speed",
                    "color": "warning",
                })
            else:
                insights.append({
                    "title": f"Occupancy at {occupancy_pct}%",
                    "subtitle": f"{occupied_count} of {total_properties} units are occupied. Strong occupancy rate!",
                    "icon": "speed",
                    "color": "success",
                })

        completed_result = await self.db.execute(
            select(func.count()).select_from(Booking).where(
                Booking.landlord_id == landlord.id,
                Booking.status == BookingStatus.COMPLETED,
            )
        )
        completed_bookings = completed_result.scalar()
        if completed_bookings > 0:
            insights.append({
                "title": f"{completed_bookings} Completed Booking{'s' if completed_bookings != 1 else ''}",
                "subtitle": f"{completed_bookings} bookings have been successfully completed on your properties.",
                "icon": "check_circle",
                "color": "success",
            })

        if total_properties > 0 and occupied_count == 0 and total_revenue == 0:
            insights.append({
                "title": "Get Your First Booking",
                "subtitle": "Your properties are live but haven't received bookings yet. Ensure your listings have quality photos and competitive pricing.",
                "icon": "lightbulb",
                "color": "primary",
            })

        return {"insights": insights}

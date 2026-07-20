from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, date

from app.analytics.models import DailyAnalytics, UserActivity, SearchAnalytics

class AnalyticsService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def record_activity(self, user_id: UUID, action: str, resource_type: str, resource_id: UUID = None, metadata: dict = None, ip_address: str = None, user_agent: str = None) -> UserActivity:
        activity = UserActivity(
            id=uuid4(), user_id=user_id,
            action=action, resource_type=resource_type,
            resource_id=resource_id, metadata_json=metadata,
            ip_address=ip_address, user_agent=user_agent,
        )
        self.db.add(activity)
        await self.db.commit()
        return activity

    async def record_search(self, query: str, filters: dict = None, results_count: int = 0, user_id: UUID = None) -> SearchAnalytics:
        search = SearchAnalytics(
            id=uuid4(), search_query=query,
            filters_json=filters, results_count=results_count,
            user_id=user_id,
        )
        self.db.add(search)
        await self.db.commit()
        return search

    async def get_overview(self) -> dict:
        analytics_result = await self.db.execute(
            select(DailyAnalytics).order_by(DailyAnalytics.date.desc()).limit(30)
        )
        recent = analytics_result.scalars().all()

        if not recent:
            return {
                "total_users": 0, "total_properties": 0,
                "total_bookings": 0, "total_revenue": 0,
                "occupancy_rate": 0, "recent_trend": [],
            }

        latest = recent[0]
        return {
            "total_users": latest.total_users,
            "total_properties": latest.total_properties,
            "total_bookings": latest.total_bookings,
            "total_revenue": latest.total_revenue,
            "occupancy_rate": float(latest.occupancy_rate),
            "recent_trend": recent,
        }

    async def get_activity_log(self, user_id: UUID = None, page: int = 1, page_size: int = 20) -> dict:
        query = select(UserActivity)
        if user_id:
            query = query.where(UserActivity.user_id == user_id)

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.order_by(UserActivity.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        activities = result.scalars().all()
        return {"total": total, "activities": activities, "page": page, "page_size": page_size}

    async def get_search_analytics(self, page: int = 1, page_size: int = 20) -> dict:
        query = select(SearchAnalytics)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.order_by(SearchAnalytics.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        searches = result.scalars().all()
        return {"total": total, "searches": searches, "page": page, "page_size": page_size}

    async def get_property_analytics(self, property_id: UUID) -> dict:
        activity_result = await self.db.execute(
            select(func.count()).select_from(UserActivity).where(
                UserActivity.resource_type == "property",
                UserActivity.resource_id == property_id,
            )
        )
        view_count = activity_result.scalar()

        search_result = await self.db.execute(
            select(func.count()).select_from(SearchAnalytics).where(
                SearchAnalytics.filters_json["property_id"].as_string() == str(property_id)
            )
        )
        search_count = search_result.scalar() or 0

        return {
            "property_id": property_id,
            "view_count": view_count,
            "search_mentions": search_count,
        }

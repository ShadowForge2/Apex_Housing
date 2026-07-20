from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user, get_admin
from app.analytics.service import AnalyticsService
from app.users.models import User
from app.common.response import SuccessResponse

router = APIRouter(prefix="/admin/analytics", tags=["Admin - Analytics"])

@router.get("/overview", response_model=SuccessResponse)
async def get_overview(user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AnalyticsService(db)
    overview = await service.get_overview()
    return SuccessResponse(data=overview)

@router.get("/activity", response_model=SuccessResponse)
async def get_activity(user_id: UUID = None, page: int = 1, page_size: int = 20, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AnalyticsService(db)
    activity = await service.get_activity_log(user_id=user_id, page=page, page_size=page_size)
    return SuccessResponse(data=activity)

@router.get("/searches", response_model=SuccessResponse)
async def get_search_analytics(page: int = 1, page_size: int = 20, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AnalyticsService(db)
    searches = await service.get_search_analytics(page=page, page_size=page_size)
    return SuccessResponse(data=searches)

@router.get("/property/{property_id}", response_model=SuccessResponse)
async def get_property_analytics(property_id: UUID, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AnalyticsService(db)
    analytics = await service.get_property_analytics(property_id)
    return SuccessResponse(data=analytics)

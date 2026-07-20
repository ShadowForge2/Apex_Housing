from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import UUID

from app.database import get_db
from app.dependencies import get_landlord
from app.users.models import User, Landlord, Profile
from app.properties.models import Property
from app.bookings.models import Booking
from app.payments.models import Wallet
from app.common.response import SuccessResponse
from app.common.enums import BookingStatus
from app.landlords.analytics_service import LandlordAnalyticsService

router = APIRouter(prefix="/landlords", tags=["Landlords"])

@router.get("/dashboard/stats", response_model=SuccessResponse)
async def landlord_dashboard(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    landlord_result = await db.execute(
        select(Landlord).where(Landlord.user_id == user.id)
    )
    landlord = landlord_result.scalar_one_or_none()

    if not landlord:
        return SuccessResponse(data={
            "total_properties": 0,
            "active_properties": 0,
            "total_bookings": 0,
            "active_bookings": 0,
            "completed_bookings": 0,
            "total_earned": 0.0,
            "wallet_balance": 0.0,
            "wallet_pending": 0.0,
        })

    property_count_result = await db.execute(
        select(func.count()).select_from(Property).where(Property.landlord_id == landlord.id)
    )
    total_properties = property_count_result.scalar()

    active_result = await db.execute(
        select(func.count()).select_from(Property).where(
            Property.landlord_id == landlord.id,
            Property.status == "ACTIVE",
        )
    )
    active_properties = active_result.scalar()

    bookings_result = await db.execute(
        select(func.count()).select_from(Booking).where(Booking.landlord_id == landlord.id)
    )
    total_bookings = bookings_result.scalar()

    active_bookings_result = await db.execute(
        select(func.count()).select_from(Booking).where(
            Booking.landlord_id == landlord.id,
            Booking.status.in_([BookingStatus.CONFIRMED, BookingStatus.ACTIVE]),
        )
    )
    active_bookings = active_bookings_result.scalar()

    completed_bookings_result = await db.execute(
        select(func.count()).select_from(Booking).where(
            Booking.landlord_id == landlord.id,
            Booking.status == BookingStatus.COMPLETED,
        )
    )
    completed_bookings = completed_bookings_result.scalar()

    wallet_result = await db.execute(
        select(Wallet).where(Wallet.user_id == user.id)
    )
    wallet = wallet_result.scalar_one_or_none()

    return SuccessResponse(data={
        "total_properties": total_properties,
        "active_properties": active_properties,
        "total_bookings": total_bookings,
        "active_bookings": active_bookings,
        "completed_bookings": completed_bookings,
        "total_earned": float(landlord.total_earned),
        "wallet_balance": float(wallet.balance) if wallet else 0.0,
        "wallet_pending": float(wallet.pending_balance) if wallet else 0.0,
    })


@router.get("/analytics/summary", response_model=SuccessResponse)
async def landlord_analytics_summary(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = LandlordAnalyticsService(db)
    landlord = await service.get_landlord(user.id)
    if not landlord:
        return SuccessResponse(data={"totalRevenue": 0, "avgMonthly": 0, "occupancyRate": 0, "growthPercent": 0})
    data = await service.get_summary(landlord)
    return SuccessResponse(data=data)


@router.get("/analytics/revenue", response_model=SuccessResponse)
async def landlord_analytics_revenue(
    period: str = Query("monthly", description="Revenue period"),
    user: User = Depends(get_landlord),
    db: AsyncSession = Depends(get_db),
):
    service = LandlordAnalyticsService(db)
    landlord = await service.get_landlord(user.id)
    if not landlord:
        return SuccessResponse(data={"monthlyRevenue": []})
    data = await service.get_revenue_chart(landlord)
    return SuccessResponse(data=data)


@router.get("/analytics/properties", response_model=SuccessResponse)
async def landlord_analytics_properties(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = LandlordAnalyticsService(db)
    landlord = await service.get_landlord(user.id)
    if not landlord:
        return SuccessResponse(data={"properties": []})
    data = await service.get_property_analytics(landlord)
    return SuccessResponse(data=data)


@router.get("/analytics/occupancy", response_model=SuccessResponse)
async def landlord_analytics_occupancy(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = LandlordAnalyticsService(db)
    landlord = await service.get_landlord(user.id)
    if not landlord:
        return SuccessResponse(data={"avgOccupancy": 0, "occupiedUnits": "0 units", "vacantUnits": "0 units", "totalProperties": "0 properties"})
    data = await service.get_occupancy(landlord)
    return SuccessResponse(data=data)


@router.get("/analytics/insights", response_model=SuccessResponse)
async def landlord_analytics_insights(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = LandlordAnalyticsService(db)
    landlord = await service.get_landlord(user.id)
    if not landlord:
        return SuccessResponse(data={"insights": []})
    data = await service.get_insights(landlord)
    return SuccessResponse(data=data)

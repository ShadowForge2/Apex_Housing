from fastapi import APIRouter, Depends
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

router = APIRouter(prefix="/landlords", tags=["Landlords"])

@router.get("/dashboard/stats", response_model=SuccessResponse)
async def landlord_dashboard(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    landlord_result = await db.execute(
        select(Landlord).where(Landlord.user_id == user.id)
    )
    landlord = landlord_result.scalar_one_or_none()

    property_count_result = await db.execute(
        select(func.count()).select_from(Property).where(Property.landlord_id == landlord.id if landlord else Property.landlord_id == None)
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
        select(func.count()).select_from(Booking).where(Booking.landlord_id == landlord.id if landlord else Booking.landlord_id == None)
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

    total_earned = float(landlord.total_earned) if landlord else 0.0

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
        "total_earned": total_earned,
        "wallet_balance": float(wallet.balance) if wallet else 0.0,
        "wallet_pending": float(wallet.pending_balance) if wallet else 0.0,
    })

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user, get_tenant, get_landlord
from app.bookings.service import BookingService
from app.bookings.schemas import BookingCreate, BookingStatusUpdate, ViewingScheduleCreate
from app.users.models import User
from app.common.enums import UserRole
from app.common.response import SuccessResponse

router = APIRouter(prefix="/bookings", tags=["Bookings"])

@router.post("/", response_model=SuccessResponse)
async def create_booking(body: BookingCreate, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="KYC verification required to make a booking. Please verify your identity first.")
    service = BookingService(db)
    booking = await service.create_booking(user.id, body)
    return SuccessResponse(message="Booking created, escrow pending payment", data={"id": str(booking.id), "reference": booking.booking_reference})

@router.get("/", response_model=SuccessResponse)
async def list_bookings(page: int = 1, page_size: int = 20, status: str = None, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = BookingService(db)
    if user.role == UserRole.TENANT:
        bookings = await service.list_bookings(page=page, page_size=page_size, tenant_id=user.id, status=status)
    elif user.role == UserRole.LANDLORD:
        bookings = await service.list_bookings(page=page, page_size=page_size, landlord_id=user.id, status=status)
    else:
        bookings = await service.list_bookings(page=page, page_size=page_size, status=status)
    return SuccessResponse(data=bookings)

@router.post("/viewing", response_model=SuccessResponse)
async def schedule_viewing(body: ViewingScheduleCreate, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    service = BookingService(db)
    schedule = await service.schedule_viewing(body, user.id)
    return SuccessResponse(message="Viewing scheduled", data=schedule)

@router.get("/{booking_id}/history", response_model=SuccessResponse)
async def get_booking_status_history(booking_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.bookings.models import BookingStatusHistory
    from sqlalchemy import func as sql_func

    booking_result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = booking_result.scalar_one_or_none()
    if not booking:
        from app.common.exceptions import NotFound
        raise NotFound("Booking not found")

    query = select(BookingStatusHistory).where(BookingStatusHistory.booking_id == booking_id)
    count_result = await db.execute(select(sql_func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.order_by(BookingStatusHistory.created_at)
    result = await db.execute(query)
    history = result.scalars().all()
    return SuccessResponse(data={"total": total, "history": history})

@router.get("/{booking_id}", response_model=SuccessResponse)
async def get_booking(booking_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = BookingService(db)
    booking = await service.get_booking(booking_id)
    return SuccessResponse(data=booking)

@router.post("/{booking_id}/confirm", response_model=SuccessResponse)
async def confirm_booking(booking_id: UUID, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    service = BookingService(db)
    booking = await service.confirm_booking(booking_id, user.id)
    return SuccessResponse(message="Payment verified, booking confirmed, chat unlocked", data={"id": str(booking.id), "status": booking.status.value})

@router.put("/{booking_id}/status", response_model=SuccessResponse)
async def update_booking_status(booking_id: UUID, body: BookingStatusUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = BookingService(db)
    booking = await service.update_booking_status(booking_id, user.id, body)
    return SuccessResponse(message="Booking status updated", data=booking)

@router.post("/{booking_id}/cancel", response_model=SuccessResponse)
async def cancel_booking(booking_id: UUID, reason: str = "", user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = BookingService(db)
    booking = await service.cancel_booking(booking_id, user.id, reason)
    return SuccessResponse(message="Booking cancelled", data=booking)

@router.get("/viewings", response_model=SuccessResponse)
async def list_viewings(page: int = 1, page_size: int = 20, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.bookings.models import ViewingSchedule
    from sqlalchemy import func as sql_func
    from app.common.enums import UserRole
    from app.properties.models import Property

    query = select(ViewingSchedule)
    if user.role == UserRole.TENANT:
        query = query.where(ViewingSchedule.tenant_id == user.id)
    elif user.role == UserRole.LANDLORD:
        query = query.join(Property, ViewingSchedule.property_id == Property.id).where(Property.landlord_id == user.id)

    count_result = await db.execute(select(sql_func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    query = query.offset((page - 1) * page_size).limit(page_size).order_by(ViewingSchedule.scheduled_date.desc())
    result = await db.execute(query)
    viewings = result.scalars().all()
    return SuccessResponse(data={"total": total, "viewings": viewings, "page": page, "page_size": page_size})

@router.delete("/viewings/{viewing_id}", response_model=SuccessResponse)
async def cancel_viewing(viewing_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.bookings.models import ViewingSchedule
    from sqlalchemy import update as sa_update

    result = await db.execute(select(ViewingSchedule).where(ViewingSchedule.id == viewing_id))
    viewing = result.scalar_one_or_none()
    if not viewing:
        from app.common.exceptions import NotFound
        raise NotFound("Viewing not found")
    if viewing.tenant_id != user.id:
        from app.common.exceptions import Forbidden
        raise Forbidden("Only the tenant can cancel a viewing")

    await db.execute(
        sa_update(ViewingSchedule)
        .where(ViewingSchedule.id == viewing_id)
        .values(is_completed=True)
    )
    await db.commit()
    return SuccessResponse(message="Viewing cancelled", data={"viewing_id": str(viewing_id)})

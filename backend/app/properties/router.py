from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user, get_landlord
from app.properties.service import PropertyService
from app.properties.schemas import PropertyCreate, PropertyUpdate, PropertyListResponse
from app.properties.config import get_labels_for_property_type, LABEL_DISPLAY_NAMES
from app.users.models import User
from app.common.response import SuccessResponse
from app.services.storage import supabase_storage

router = APIRouter(prefix="/properties", tags=["Properties"])

@router.post("/", response_model=SuccessResponse)
async def create_property(body: PropertyCreate, user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="KYC verification required to list a property. Please verify your identity first.")
    service = PropertyService(db)
    prop = await service.create_property(user.id, body)
    return SuccessResponse(message="Property created", data={"id": str(prop.id), "slug": prop.slug})

@router.get("/", response_model=SuccessResponse)
async def list_properties(
    page: int = 1, page_size: int = 20, status: str = None,
    landlord_id: UUID = None, city: str = None, property_type: str = None,
    min_price: float = None, max_price: float = None,
    db: AsyncSession = Depends(get_db),
):
    service = PropertyService(db)
    props = await service.list_properties(
        page=page, page_size=page_size, status=status,
        landlord_id=landlord_id, city=city, property_type=property_type,
        min_price=min_price, max_price=max_price,
    )
    return SuccessResponse(data=props)

@router.get("/labels/{property_type}", response_model=SuccessResponse)
async def get_image_labels(property_type: str):
    labels = get_labels_for_property_type(property_type)
    label_list = [
        {"value": l, "display": LABEL_DISPLAY_NAMES.get(l, l.replace("_", " ").title())}
        for l in labels
    ]
    return SuccessResponse(data={"property_type": property_type, "labels": label_list})

@router.get("/{property_id}", response_model=SuccessResponse)
async def get_property(property_id: UUID, db: AsyncSession = Depends(get_db)):
    service = PropertyService(db)
    prop = await service.get_property(property_id)
    return SuccessResponse(data=prop)

@router.get("/slug/{slug}", response_model=SuccessResponse)
async def get_property_by_slug(slug: str, db: AsyncSession = Depends(get_db)):
    service = PropertyService(db)
    prop = await service.get_property_by_slug(slug)
    return SuccessResponse(data=prop)

@router.put("/{property_id}", response_model=SuccessResponse)
async def update_property(property_id: UUID, body: PropertyUpdate, user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = PropertyService(db)
    is_admin = user.role.value == "admin"
    prop = await service.update_property(property_id, user.id, body, is_admin=is_admin)
    return SuccessResponse(message="Property updated", data=prop)

@router.delete("/{property_id}")
async def delete_property(property_id: UUID, user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = PropertyService(db)
    is_admin = user.role.value == "admin"
    await service.delete_property(property_id, user.id, is_admin=is_admin)
    return SuccessResponse(message="Property deleted")


@router.post("/{property_id}/images", response_model=SuccessResponse)
async def upload_property_image(
    property_id: UUID,
    file: UploadFile = File(...),
    label: str = Query(..., description="Image label (e.g. front, kitchen, bedroom_1)"),
    sort_order: int = 0,
    user: User = Depends(get_landlord),
    db: AsyncSession = Depends(get_db),
):
    service = PropertyService(db)
    prop = await service.get_property(property_id)
    if prop.landlord_id != user.id:
        raise HTTPException(status_code=403, detail="Not your property")

    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large. Max 10MB.")

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    valid_labels = get_labels_for_property_type(prop.property_type)
    if label not in valid_labels:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid label '{label}' for {prop.property_type}. Valid: {', '.join(valid_labels)}"
        )

    try:
        result = await supabase_storage.upload_property_image(
            file_bytes=content,
            property_id=str(property_id),
            file_name=file.filename or "image",
            content_type=file.content_type,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

    from app.properties.models import PropertyImage
    from uuid import uuid4
    image = PropertyImage(
        id=uuid4(), property_id=property_id,
        url=result["url"], label=label,
        sort_order=sort_order,
        is_primary=(label == "front"),
    )
    db.add(image)
    await db.commit()
    return SuccessResponse(message=f"Image uploaded with label: {LABEL_DISPLAY_NAMES.get(label, label)}", data={"url": result["url"], "label": label})


@router.post("/{property_id}/videos", response_model=SuccessResponse)
async def upload_property_video(
    property_id: UUID,
    file: UploadFile = File(...),
    user: User = Depends(get_landlord),
    db: AsyncSession = Depends(get_db),
):
    service = PropertyService(db)
    prop = await service.get_property(property_id)
    if prop.landlord_id != user.id:
        raise HTTPException(status_code=403, detail="Not your property")

    content = await file.read()
    if len(content) > 50 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Video too large. Max 50MB.")

    if not file.content_type or not file.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="File must be a video")

    try:
        result = await supabase_storage.upload_file(
            file_bytes=content,
            file_name=file.filename or "video",
            content_type=file.content_type,
            folder=f"properties/{property_id}/videos",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

    from app.properties.models import PropertyVideo
    from uuid import uuid4
    video = PropertyVideo(
        id=uuid4(), property_id=property_id,
        url=result["url"], label="main",
    )
    db.add(video)
    await db.commit()
    return SuccessResponse(message="Video uploaded", data={"url": result["url"]})


@router.delete("/{property_id}/images/{image_id}", response_model=SuccessResponse)
async def delete_property_image(
    property_id: UUID, image_id: UUID,
    user: User = Depends(get_landlord),
    db: AsyncSession = Depends(get_db),
):
    from app.properties.models import PropertyImage, PropertyAvailability

    service = PropertyService(db)
    prop = await service.get_property(property_id)
    if prop.landlord_id != user.id:
        raise HTTPException(status_code=403, detail="Not your property")

    avail_result = await db.execute(
        select(PropertyAvailability).where(PropertyAvailability.property_id == property_id)
    )
    avail = avail_result.scalar_one_or_none()
    if avail and avail.is_booked:
        raise HTTPException(status_code=400, detail="Cannot modify images during an active booking")

    img_result = await db.execute(
        select(PropertyImage).where(PropertyImage.id == image_id, PropertyImage.property_id == property_id)
    )
    image = img_result.scalar_one_or_none()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")

    await db.delete(image)
    await db.commit()
    return SuccessResponse(message="Image deleted")


@router.delete("/{property_id}/videos/{video_id}", response_model=SuccessResponse)
async def delete_property_video(
    property_id: UUID, video_id: UUID,
    user: User = Depends(get_landlord),
    db: AsyncSession = Depends(get_db),
):
    from app.properties.models import PropertyVideo, PropertyAvailability

    service = PropertyService(db)
    prop = await service.get_property(property_id)
    if prop.landlord_id != user.id:
        raise HTTPException(status_code=403, detail="Not your property")

    avail_result = await db.execute(
        select(PropertyAvailability).where(PropertyAvailability.property_id == property_id)
    )
    avail = avail_result.scalar_one_or_none()
    if avail and avail.is_booked:
        raise HTTPException(status_code=400, detail="Cannot modify videos during an active booking")

    vid_result = await db.execute(
        select(PropertyVideo).where(PropertyVideo.id == video_id, PropertyVideo.property_id == property_id)
    )
    video = vid_result.scalar_one_or_none()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    await db.delete(video)
    await db.commit()
    return SuccessResponse(message="Video deleted")


@router.get("/{property_id}/availability", response_model=SuccessResponse)
async def get_property_availability(property_id: UUID, db: AsyncSession = Depends(get_db)):
    from app.properties.models import PropertyAvailability
    from app.bookings.models import Booking
    from app.common.enums import BookingStatus
    from datetime import date as date_type

    service = PropertyService(db)
    prop = await service.get_property(property_id)
    avail_result = await db.execute(
        select(PropertyAvailability).where(PropertyAvailability.property_id == property_id)
    )
    availability = avail_result.scalar_one_or_none()

    bookings_result = await db.execute(
        select(Booking).where(
            Booking.property_id == property_id,
            Booking.status.in_([BookingStatus.CONFIRMED, BookingStatus.ACTIVE]),
            Booking.move_in_date.isnot(None),
        )
    )
    booked_dates = []
    for b in bookings_result.scalars().all():
        if b.move_in_date:
            booked_dates.append(str(b.move_in_date))

    return SuccessResponse(data={
        "property_id": str(property_id),
        "is_available": availability.is_available if availability else False,
        "available_from": str(availability.available_from) if availability and availability.available_from else None,
        "available_until": str(availability.available_until) if availability and availability.available_until else None,
        "plan_type": availability.plan_type if availability else None,
        "is_booked": availability.is_booked if availability else False,
        "minimum_stay_days": availability.minimum_stay_days if availability else None,
        "maximum_stay_days": availability.maximum_stay_days if availability else None,
        "booked_dates": booked_dates,
    })

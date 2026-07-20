from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.dependencies import get_current_user
from app.properties.models import Amenity
from app.common.response import SuccessResponse

router = APIRouter(prefix="/amenities", tags=["Amenities"])

VALID_CATEGORIES = {"basic", "comfort", "safety", "entertainment", "outdoor", "kitchen", "bathroom", "laundry", "tech", "accessibility"}

@router.get("/", response_model=SuccessResponse)
async def list_amenities(category: str = None, db: AsyncSession = Depends(get_db)):
    query = select(Amenity).order_by(Amenity.category, Amenity.name)
    if category:
        query = query.where(Amenity.category == category)
    result = await db.execute(query)
    amenities = result.scalars().all()
    return SuccessResponse(data={
        "total": len(amenities),
        "amenities": amenities,
    })

@router.post("/", response_model=SuccessResponse)
async def create_amenity(name: str, category: str = "basic", icon: str = None, db: AsyncSession = Depends(get_db)):
    if category not in VALID_CATEGORIES:
        raise Exception(f"Invalid category. Must be one of: {', '.join(sorted(VALID_CATEGORIES))}")
    existing = await db.execute(select(Amenity).where(Amenity.name == name))
    if existing.scalar_one_or_none():
        from app.common.exceptions import BadRequest
        raise BadRequest(f"Amenity '{name}' already exists")
    from uuid import uuid4
    amenity = Amenity(id=uuid4(), name=name, category=category, icon=icon)
    db.add(amenity)
    await db.commit()
    return SuccessResponse(message="Amenity created", data=amenity)

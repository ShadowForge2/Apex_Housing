from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from uuid import UUID
from pydantic import BaseModel

from app.database import get_db
from app.dependencies import get_current_user
from app.users.models import User, Agent, Profile
from app.properties.models import Property, PropertyImage, PropertyLocation, PropertyPricing, PropertyAvailability, PropertyFeature, PropertyAmenity, Amenity
from app.common.response import SuccessResponse
from app.common.exceptions import NotFound

router = APIRouter(prefix="/agents", tags=["Agents"])

class AgentProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    agency_name: str | None
    license_number: str | None
    total_properties: int
    total_commission: float
    first_name: str | None = None
    last_name: str | None = None
    profile_picture: str | None = None
    bio: str | None = None

    class Config:
        from_attributes = True

@router.get("/{agent_user_id}", response_model=SuccessResponse)
async def get_agent_profile(agent_user_id: UUID, db: AsyncSession = Depends(get_db)):
    agent_result = await db.execute(
        select(Agent).where(Agent.user_id == agent_user_id)
    )
    agent = agent_result.scalar_one_or_none()
    if not agent:
        raise NotFound("Agent not found")

    profile_result = await db.execute(
        select(Profile).where(Profile.user_id == agent_user_id)
    )
    profile = profile_result.scalar_one_or_none()

    user_result = await db.execute(
        select(User).where(User.id == agent_user_id)
    )
    user = user_result.scalar_one_or_none()

    data = {
        "id": agent.id,
        "user_id": agent.user_id,
        "agency_name": agent.agency_name,
        "license_number": agent.license_number,
        "total_properties": agent.total_properties,
        "total_commission": float(agent.total_commission),
        "first_name": profile.first_name if profile else None,
        "last_name": profile.last_name if profile else None,
        "profile_picture": profile.profile_picture if profile else None,
        "bio": profile.bio if profile else None,
        "email": user.email if user else None,
        "is_verified": user.is_verified if user else False,
    }
    return SuccessResponse(data=data)


@router.get("/{agent_user_id}/properties", response_model=SuccessResponse)
async def get_agent_properties(
    agent_user_id: UUID, page: int = 1, page_size: int = 20,
    status: str = None, db: AsyncSession = Depends(get_db),
):
    agent_result = await db.execute(
        select(Agent).where(Agent.user_id == agent_user_id)
    )
    agent = agent_result.scalar_one_or_none()
    if not agent:
        raise NotFound("Agent not found")

    query = (
        select(Property)
        .options(
            selectinload(Property.images),
            selectinload(Property.location),
            selectinload(Property.pricing),
            selectinload(Property.availability),
            selectinload(Property.features),
            selectinload(Property.amenities),
        )
        .where(Property.agent_id == agent.id)
    )
    if status:
        query = query.where(Property.status == status)

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    query = query.offset((page - 1) * page_size).limit(page_size).order_by(Property.created_at.desc())
    result = await db.execute(query)
    properties = result.scalars().unique().all()

    return SuccessResponse(data={
        "total": total,
        "properties": properties,
        "page": page,
        "page_size": page_size,
    })

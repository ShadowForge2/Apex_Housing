from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.common.enums import ReviewTargetType

class ReviewCreate(BaseModel):
    target_user_id: Optional[UUID] = None
    property_id: Optional[UUID] = None
    booking_id: Optional[UUID] = None
    target_type: ReviewTargetType
    rating: int = Field(ge=1, le=5)
    title: str = Field(min_length=3, max_length=200)
    content: str = Field(min_length=10)
    is_anonymous: bool = False
    image_urls: List[str] = []

class ReviewUpdate(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5)
    title: Optional[str] = None
    content: Optional[str] = None

class ReviewResponseModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    reviewer_id: UUID
    target_user_id: Optional[UUID] = None
    property_id: Optional[UUID] = None
    target_type: ReviewTargetType
    rating: int
    title: str
    content: str
    is_anonymous: bool
    is_verified: bool
    helpful_count: int
    created_at: datetime

class ReviewListResponse(BaseModel):
    total: int
    average_rating: float
    reviews: List[ReviewResponseModel]

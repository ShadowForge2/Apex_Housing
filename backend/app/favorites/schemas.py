from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class FavoriteCreate(BaseModel):
    property_id: UUID
    note: Optional[str] = Field(None, max_length=500)


class FavoriteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    property_id: UUID
    note: Optional[str] = None
    created_at: datetime


class FavoriteListResponse(BaseModel):
    total: int
    favorites: List[FavoriteResponse]


class WishListCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)


class WishListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    name: str
    description: Optional[str] = None
    created_at: datetime
    item_count: int = 0


class WishListItemCreate(BaseModel):
    property_id: UUID
    note: Optional[str] = Field(None, max_length=500)


class WishListItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    wishlist_id: UUID
    property_id: UUID
    note: Optional[str] = None
    created_at: datetime


class WishListDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    description: Optional[str] = None
    created_at: datetime
    items: List[WishListItemResponse] = []

from pydantic import BaseModel, ConfigDict, Field, computed_field
from typing import Optional, List, Any
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from app.common.enums import get_tenant_price, get_agent_net_price


PRICE_RANGES = {
    "budget": {"min": 0, "max": 100000, "label": "Under 100k"},
    "mid": {"min": 100000, "max": 300000, "label": "100k - 300k"},
    "standard": {"min": 300000, "max": 500000, "label": "300k - 500k"},
    "premium": {"min": 500000, "max": 1000000, "label": "500k - 1M"},
    "luxury": {"min": 1000000, "max": None, "label": "Above 1M"},
}


class SearchFilters(BaseModel):
    q: Optional[str] = Field(None, description="Instant search text (title, description, tags)")
    state: Optional[str] = Field(None, description="State filter (e.g. Lagos)")
    city: Optional[str] = Field(None, description="City filter (e.g. Ikeja)")
    area: Optional[str] = Field(None, description="Area/neighborhood filter (e.g. Lekki Phase 1)")
    price_range: Optional[str] = Field(None, description="Preset: budget, mid, standard, premium, luxury")
    min_price: Optional[float] = Field(None, description="Custom min price")
    max_price: Optional[float] = Field(None, description="Custom max price")
    property_type: Optional[str] = Field(None, description="Property type string (e.g. apartment)")
    amenity_ids: Optional[List[UUID]] = Field(None, description="Required amenities")
    agent_tags: Optional[str] = Field(None, description="Search in agent tags (e.g. near church)")
    latitude: Optional[float] = Field(None, description="User latitude for distance calc")
    longitude: Optional[float] = Field(None, description="User longitude for distance calc")
    radius_km: Optional[float] = Field(50.0, description="Search radius in km when lat/lng provided")
    sort_by: str = Field("newest", description="Sort: distance, price_low, price_high, newest, popular")
    page: int = Field(1, ge=1)
    page_size: int = Field(20, ge=1, le=50)


class PropertySearchResult(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    title: str
    slug: str
    description: str
    property_type: str
    agent_tags: Optional[str] = None
    front_image: Optional[str] = None
    rent_amount: Optional[float] = None
    security_deposit: Optional[float] = None
    currency: str = "NGN"
    city: Optional[str] = None
    state: Optional[str] = None
    neighborhood: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_km: Optional[float] = None
    is_available: bool = True
    created_at: datetime

    @computed_field
    @property
    def tenant_price(self) -> Optional[int]:
        """Price shown to tenant: rent + 5% markup, rounded to whole number."""
        if self.rent_amount is None:
            return None
        return get_tenant_price(Decimal(str(self.rent_amount)))

    @computed_field
    @property
    def agent_net_price(self) -> Optional[int]:
        """Price agent receives: rent - 5% markdown, rounded to whole number."""
        if self.rent_amount is None:
            return None
        return get_agent_net_price(Decimal(str(self.rent_amount)))


class SearchResponse(BaseModel):
    total: int
    properties: List[PropertySearchResult]
    page: int
    page_size: int
    filters_applied: dict
    fallback_used: bool = False
    fallback_message: Optional[str] = None


class LocationHierarchy(BaseModel):
    states: List[str]
    cities_by_state: dict = Field(default_factory=dict)
    areas_by_city: dict = Field(default_factory=dict)


class SavedSearchCreate(BaseModel):
    name: str
    filters_json: dict = Field(default_factory=dict)
    notify_new_matches: bool = False


class SavedSearchResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    name: str
    filters_json: Optional[dict] = None
    notify_new_matches: bool
    created_at: datetime


class PopularSearchResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    query_text: str
    result_count: int

from pydantic import BaseModel, ConfigDict, Field, computed_field
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date
from decimal import Decimal
from app.common.enums import PropertyStatus, PlanType, get_tenant_price, get_agent_net_price


class AmenityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    icon: Optional[str] = None
    category: str


class PropertyImageCreate(BaseModel):
    url: str
    label: str = Field(description="Image label (e.g. front, kitchen, bedroom_1)")
    is_primary: bool = False
    sort_order: int = 0


class PropertyImageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    url: str
    label: str
    is_primary: bool
    sort_order: int


class PropertyLocationCreate(BaseModel):
    address: str
    city: str
    state: str
    country: str = "Nigeria"
    zip_code: Optional[str] = None
    latitude: float = 0.0
    longitude: float = 0.0
    neighborhood: Optional[str] = None


class PropertyLocationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    zip_code: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    neighborhood: Optional[str] = None


class PropertyFeatureCreate(BaseModel):
    feature_name: str
    feature_value: Optional[str] = None


class PropertyFeatureResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    feature_name: str
    feature_value: Optional[str] = None


class PropertyPricingCreate(BaseModel):
    rent_amount: Decimal
    security_deposit: Decimal
    service_fee: Decimal = Decimal("0")
    currency: str = "NGN"


class PropertyPricingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    rent_amount: float
    security_deposit: float
    service_fee: float
    currency: str

    @computed_field
    @property
    def tenant_price(self) -> int:
        """Price shown to tenant: rent + 5% markup, rounded to whole number."""
        return get_tenant_price(Decimal(str(self.rent_amount)))

    @computed_field
    @property
    def agent_net_price(self) -> int:
        """Price agent receives: rent - 5% markdown, rounded to whole number."""
        return get_agent_net_price(Decimal(str(self.rent_amount)))


class PropertyAvailabilityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    is_available: bool
    available_from: Optional[date] = None
    available_until: Optional[date] = None
    plan_type: Optional[str] = None
    is_booked: bool = False
    minimum_stay_days: Optional[int] = None
    maximum_stay_days: Optional[int] = None


class PropertyCreate(BaseModel):
    property_type: str = Field(description="Property type string: apartment, house, etc.")
    title: str = Field(min_length=5, max_length=200)
    description: str = Field(min_length=20)
    agent_id: Optional[UUID] = None
    agent_tags: Optional[str] = Field(None, description="Comma-separated tags: near church, quiet area, newly built, etc.")
    agent_terms: Optional[str] = Field(None, description="Agent's terms and conditions for this property listing")
    agent_signature_data: Optional[str] = Field(None, description="Base64 encoded signature image. Optional if agent has a stored signature.")
    agent_signed_at: Optional[datetime] = Field(None, description="Timestamp when agent signed")
    location: PropertyLocationCreate
    pricing: PropertyPricingCreate
    images: List[PropertyImageCreate] = Field(default_factory=list, max_length=5, description="Property images. Must include 'front' label if provided.")
    video_url: Optional[str] = Field(None, description="Video URL")
    features: List[PropertyFeatureCreate] = []
    amenity_ids: List[UUID] = []
    available_from: Optional[date] = Field(None, description="Start of availability window")
    available_until: Optional[date] = Field(None, description="End of availability window")
    plan_type: Optional[str] = Field(None, description="MONTHLY, YEARLY, or FLEXIBLE")
    minimum_stay_days: Optional[int] = Field(None, ge=1)
    maximum_stay_days: Optional[int] = Field(None, ge=1)


class PropertyLocationUpdate(BaseModel):
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    neighborhood: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class PropertyPricingUpdate(BaseModel):
    rent_amount: Optional[Decimal] = None
    security_deposit: Optional[Decimal] = None
    service_fee: Optional[Decimal] = None


class PropertyUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    property_type: Optional[str] = None
    agent_tags: Optional[str] = None
    status: Optional[PropertyStatus] = None
    location: Optional[PropertyLocationUpdate] = None
    pricing: Optional[PropertyPricingUpdate] = None


class PropertyResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    landlord_id: UUID
    agent_id: Optional[UUID] = None
    title: str
    slug: str
    description: Optional[str] = None
    property_type: str
    status: PropertyStatus
    agent_tags: Optional[str] = None
    agent_terms: Optional[str] = None
    agent_signed_at: Optional[datetime] = None
    images: List[PropertyImageResponse] = []
    videos: List[dict] = []
    location: Optional[PropertyLocationResponse] = None
    pricing: Optional[PropertyPricingResponse] = None
    availability: Optional[PropertyAvailabilityResponse] = None
    features: List[PropertyFeatureResponse] = []
    amenities: List[AmenityResponse] = []
    created_at: datetime


class PropertyListResponse(BaseModel):
    total: int
    properties: List[PropertyResponse]
    page: int
    page_size: int

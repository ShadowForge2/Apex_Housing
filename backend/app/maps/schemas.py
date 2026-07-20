from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime

class MapPinCreate(BaseModel):
    property_id: UUID
    pin_type: str = "property"
    latitude: float
    longitude: float
    label: Optional[str] = None
    metadata_json: Optional[dict] = None

class MapPinResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    property_id: UUID
    pin_type: str
    latitude: float
    longitude: float
    label: Optional[str] = None
    metadata_json: Optional[dict] = None
    is_active: bool
    created_at: datetime


class RadiusSearchRequest(BaseModel):
    latitude: float
    longitude: float
    radius_km: float = 5.0
    property_type: Optional[str] = None

class LocationVerifyRequest(BaseModel):
    latitude: float
    longitude: float
    expected_address: str

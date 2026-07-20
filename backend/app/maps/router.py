from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional

from app.database import get_db
from app.dependencies import get_current_user
from app.maps.service import MapService
from app.maps.schemas import MapPinCreate, RadiusSearchRequest, LocationVerifyRequest
from app.services.maps import geocoding_service
from app.users.models import User
from app.common.response import SuccessResponse

router = APIRouter(prefix="/maps", tags=["Maps"])

class ReverseGeocodeRequest(BaseModel):
    latitude: float
    longitude: float

class ForwardGeocodeRequest(BaseModel):
    address: str
    country: str = "NG"

class ValidateLocationRequest(BaseModel):
    latitude: float
    longitude: float

class NearbyPlacesRequest(BaseModel):
    latitude: float
    longitude: float
    radius_km: float = 5.0
    place_type: Optional[str] = None
    keyword: Optional[str] = None

@router.post("/pins", response_model=SuccessResponse)
async def create_pin(body: MapPinCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = MapService(db)
    pin = await service.create_pin(user.id, body)
    return SuccessResponse(message="Pin created", data=pin)

@router.get("/pins", response_model=SuccessResponse)
async def get_pins(
    min_lat: Optional[float] = Query(None),
    max_lat: Optional[float] = Query(None),
    min_lng: Optional[float] = Query(None),
    max_lng: Optional[float] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    service = MapService(db)
    bounds = None
    if all(v is not None for v in [min_lat, max_lat, min_lng, max_lng]):
        bounds = {"min_lat": min_lat, "max_lat": max_lat, "min_lng": min_lng, "max_lng": max_lng}
    pins = await service.get_pins(bounds=bounds)
    return SuccessResponse(data=pins)

@router.post("/radius-search", response_model=SuccessResponse)
async def radius_search(body: RadiusSearchRequest, db: AsyncSession = Depends(get_db)):
    service = MapService(db)
    results = await service.radius_search(body)
    return SuccessResponse(data=results)

@router.post("/verify-location", response_model=SuccessResponse)
async def verify_location(body: LocationVerifyRequest, db: AsyncSession = Depends(get_db)):
    service = MapService(db)
    result = await service.verify_location(body.latitude, body.longitude, body.expected_address)
    return SuccessResponse(data=result)

@router.post("/reverse-geocode", response_model=SuccessResponse)
async def reverse_geocode(body: ReverseGeocodeRequest):
    result = await geocoding_service.reverse_geocode(body.latitude, body.longitude)
    return SuccessResponse(data=result)

@router.post("/geocode", response_model=SuccessResponse)
async def forward_geocode(body: ForwardGeocodeRequest):
    result = await geocoding_service.forward_geocode(body.address, body.country)
    return SuccessResponse(data=result)

@router.post("/validate-location", response_model=SuccessResponse)
async def validate_location(body: ValidateLocationRequest):
    is_valid = geocoding_service.validate_nigeria_bounds(body.latitude, body.longitude)
    return SuccessResponse(data={"valid": is_valid, "latitude": body.latitude, "longitude": body.longitude})

@router.post("/nearby-places", response_model=SuccessResponse)
async def nearby_places(body: NearbyPlacesRequest):
    places = await geocoding_service.search_nearby_places(
        lat=body.latitude,
        lng=body.longitude,
        radius_meters=int(body.radius_km * 1000),
        place_type=body.place_type,
        keyword=body.keyword,
    )
    return SuccessResponse(data={"places": places, "count": len(places)})

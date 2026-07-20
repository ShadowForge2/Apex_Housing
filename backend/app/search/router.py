from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from typing import Optional, List

from app.database import get_db
from app.dependencies import get_current_user_id
from app.search.service import SearchService
from app.search.schemas import SearchFilters, SavedSearchCreate
from app.common.response import SuccessResponse

router = APIRouter(prefix="/search", tags=["Search"])


@router.get("/properties", response_model=SuccessResponse)
async def search_properties(
    q: Optional[str] = Query(None, description="Search text"),
    state: Optional[str] = Query(None, description="State"),
    city: Optional[str] = Query(None, description="City"),
    area: Optional[str] = Query(None, description="Area/neighborhood"),
    price_range: Optional[str] = Query(None, description="Preset: budget, mid, standard, premium, luxury"),
    min_price: Optional[float] = Query(None, description="Min price"),
    max_price: Optional[float] = Query(None, description="Max price"),
    property_type: Optional[str] = Query(None, description="Property type string"),
    agent_tags: Optional[str] = Query(None, description="Search agent tags"),
    amenity_ids: Optional[List[UUID]] = Query(None, description="Required amenities"),
    latitude: Optional[float] = Query(None, description="User latitude"),
    longitude: Optional[float] = Query(None, description="User longitude"),
    radius_km: Optional[float] = Query(50.0, description="Search radius in km"),
    sort_by: str = Query("newest", description="Sort: distance, price_low, price_high, newest"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    filters = SearchFilters(
        q=q, state=state, city=city, area=area,
        price_range=price_range, min_price=min_price, max_price=max_price,
        property_type=property_type,
        agent_tags=agent_tags, amenity_ids=amenity_ids,
        latitude=latitude, longitude=longitude,
        radius_km=radius_km,
        sort_by=sort_by, page=page, page_size=page_size,
    )
    service = SearchService(db)
    results = await service.search_properties(filters, user_id)
    return SuccessResponse(data=results)


@router.get("/locations", response_model=SuccessResponse)
async def get_locations(db: AsyncSession = Depends(get_db)):
    service = SearchService(db)
    hierarchy = await service.get_location_hierarchy()
    return SuccessResponse(data=hierarchy)


@router.get("/price-ranges", response_model=SuccessResponse)
async def get_price_ranges():
    from app.search.schemas import PRICE_RANGES
    ranges = [
        {"key": k, "label": v["label"], "min": v["min"], "max": v["max"]}
        for k, v in PRICE_RANGES.items()
    ]
    return SuccessResponse(data=ranges)


@router.post("/saved", response_model=SuccessResponse)
async def save_search(body: SavedSearchCreate, user_id: UUID = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    service = SearchService(db)
    saved = await service.save_search(user_id, body)
    return SuccessResponse(message="Search saved", data=saved)


@router.get("/saved", response_model=SuccessResponse)
async def get_saved_searches(user_id: UUID = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    service = SearchService(db)
    searches = await service.get_saved_searches(user_id)
    return SuccessResponse(data=searches)


@router.get("/popular", response_model=SuccessResponse)
async def get_popular(limit: int = 10, db: AsyncSession = Depends(get_db)):
    service = SearchService(db)
    popular = await service.get_popular_searches(limit)
    return SuccessResponse(data=popular)

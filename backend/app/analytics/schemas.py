from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Any
from uuid import UUID
from datetime import date, datetime

class DailyAnalyticsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    date: date
    total_users: int
    new_users: int
    total_properties: int
    active_properties: int
    total_bookings: int
    new_bookings: int
    total_revenue: float
    new_revenue: float
    occupancy_rate: float
    popular_areas: Optional[Any] = None
    conversion_rate: float

class UserActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    action: str
    resource_type: str
    resource_id: Optional[UUID] = None
    created_at: datetime

class SearchAnalyticsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    search_query: str
    results_count: int
    user_id: Optional[UUID] = None
    created_at: datetime

class AnalyticsOverviewResponse(BaseModel):
    total_users: int
    total_properties: int
    total_bookings: int
    total_revenue: float
    occupancy_rate: float
    recent_trend: List[DailyAnalyticsResponse]

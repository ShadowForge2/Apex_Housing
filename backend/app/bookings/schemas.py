from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date, time
from app.common.enums import BookingStatus

class BookingCreate(BaseModel):
    property_id: UUID
    viewing_date: Optional[date] = None
    viewing_time: Optional[time] = None
    viewing_notes: Optional[str] = None
    move_in_date: Optional[date] = None
    notes: Optional[str] = None
    terms_agreed: bool = Field(description="Must be true — tenant explicitly agrees to agent terms + platform terms")
    signature_data: Optional[str] = Field(None, description="Base64 encoded signature image. Optional if user has a stored signature.")

class ViewingScheduleCreate(BaseModel):
    booking_id: UUID
    property_id: UUID
    scheduled_date: date
    scheduled_time: time
    duration_minutes: int = 30
    notes: Optional[str] = None

class ViewingScheduleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    scheduled_date: date
    scheduled_time: time
    duration_minutes: int
    notes: Optional[str] = None
    is_completed: bool
    completed_at: Optional[datetime] = None

class BookingStatusUpdate(BaseModel):
    status: BookingStatus
    notes: Optional[str] = None
    cancellation_reason: Optional[str] = None

class BookingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    property_id: UUID
    tenant_id: UUID
    landlord_id: UUID
    agent_id: Optional[UUID] = None
    status: BookingStatus
    booking_reference: str
    viewing_date: Optional[date] = None
    viewing_time: Optional[time] = None
    move_in_date: Optional[date] = None
    lease_start_date: Optional[date] = None
    total_amount: float
    security_deposit: float
    service_fee: float
    notes: Optional[str] = None
    cancellation_reason: Optional[str] = None
    cancelled_at: Optional[datetime] = None
    tenant_terms_agreed: bool = False
    tenant_terms_agreed_at: Optional[datetime] = None
    created_at: datetime

class BookingListResponse(BaseModel):
    total: int
    bookings: List[BookingResponse]

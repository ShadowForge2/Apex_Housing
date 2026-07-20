from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.common.enums import DisputeStatus, DisputeResolution

class DisputeCreate(BaseModel):
    escrow_id: UUID
    booking_id: UUID
    category: str = Field(description="rent_condition, damage, fraud, payment_issue, other")
    title: str = Field(min_length=5, max_length=200)
    description: str = Field(min_length=20)
    evidence_urls: List[str] = []

class DisputeUpdate(BaseModel):
    status: Optional[DisputeStatus] = None
    resolution: Optional[DisputeResolution] = None
    resolution_notes: Optional[str] = None

class DisputeMessageCreate(BaseModel):
    content: str = Field(min_length=1)
    is_admin_note: bool = False

class DisputeMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    dispute_id: UUID
    sender_id: UUID
    content: str
    is_admin_note: bool
    created_at: datetime

class DisputeEvidenceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    dispute_id: UUID
    uploaded_by: UUID
    evidence_type: str
    file_url: str
    description: Optional[str] = None
    uploaded_at: datetime

class DisputeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    escrow_id: UUID
    booking_id: UUID
    tenant_id: UUID
    landlord_id: UUID
    reported_by: UUID
    status: DisputeStatus
    category: str
    title: str
    description: str
    resolution: Optional[DisputeResolution] = None
    resolution_notes: Optional[str] = None
    resolved_at: Optional[datetime] = None
    evidence: List[DisputeEvidenceResponse] = []
    messages: List[DisputeMessageResponse] = []
    created_at: datetime
    updated_at: datetime

class DisputeListResponse(BaseModel):
    total: int
    disputes: List[DisputeResponse]

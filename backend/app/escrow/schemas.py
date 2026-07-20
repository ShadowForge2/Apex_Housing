from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.common.enums import EscrowStatus, EscrowEvent

class EscrowTransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    tenant_id: UUID
    landlord_id: UUID
    agent_id: Optional[UUID] = None
    property_id: UUID
    status: EscrowStatus
    amount: float
    security_deposit: float
    service_fee: float
    agent_commission: float
    platform_fee: float
    currency: str
    payment_reference: str
    escrow_reference: str
    hold_started_at: Optional[datetime] = None
    hold_released_at: Optional[datetime] = None
    hold_expires_at: Optional[datetime] = None
    move_in_confirmed_at: Optional[datetime] = None
    dispute_opened_at: Optional[datetime] = None
    resolution: Optional[str] = None
    resolution_at: Optional[datetime] = None
    resolution_notes: Optional[str] = None
    created_at: datetime

class EscrowStatusUpdate(BaseModel):
    status: EscrowStatus
    notes: Optional[str] = None

class EscrowMoveInConfirm(BaseModel):
    confirmed: bool = True
    notes: Optional[str] = None

class AdminDecisionRequest(BaseModel):
    decision: str = Field(description="'release' or 'refund'")
    notes: Optional[str] = None

class EscrowDisputeRequest(BaseModel):
    reason: str
    description: str
    evidence_urls: List[str] = []

class EscrowStatusHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    escrow_id: UUID
    status: EscrowStatus
    event_type: EscrowEvent
    notes: Optional[str] = None
    created_at: datetime

class EscrowListResponse(BaseModel):
    total: int
    escrows: List[EscrowTransactionResponse]

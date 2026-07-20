from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime

class CommissionRuleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    description: Optional[str] = None
    role_type: str
    percentage: float
    min_amount: Optional[float] = None
    max_amount: Optional[float] = None
    is_active: bool
    created_at: datetime

class CommissionLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    commission_rule_id: UUID
    booking_id: UUID
    escrow_id: UUID
    agent_id: Optional[UUID] = None
    landlord_id: Optional[UUID] = None
    base_amount: float
    commission_rate: float
    commission_amount: float
    platform_share: float
    recipient_share: float
    status: str
    processed_at: Optional[datetime] = None
    created_at: datetime

class PlatformRevenueResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    period_start: datetime
    period_end: datetime
    total_bookings: int
    total_revenue: float
    total_commission: float
    total_escrow_processed: float
    total_refunds: float
    created_at: datetime

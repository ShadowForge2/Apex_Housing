from pydantic import BaseModel, ConfigDict, Field, EmailStr
from typing import Optional, List
from uuid import UUID
from datetime import datetime

class AdminActionRequest(BaseModel):
    action: str
    target_type: str
    target_id: UUID
    details: dict = Field(default_factory=dict)

class AdminActionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    admin_id: UUID
    action: str
    target_type: str
    target_id: UUID
    details_json: Optional[dict] = None
    created_at: datetime

class AuditLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: Optional[UUID] = None
    action: str
    resource_type: str
    resource_id: Optional[UUID] = None
    old_value: Optional[dict] = None
    new_value: Optional[dict] = None
    ip_address: Optional[str] = None
    created_at: datetime

class FraudAlertResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: Optional[UUID] = None
    alert_type: str
    severity: str
    description: str
    evidence_json: Optional[dict] = None
    status: str
    assigned_to: Optional[UUID] = None
    resolved_at: Optional[datetime] = None
    created_at: datetime

class FraudAlertUpdate(BaseModel):
    status: Optional[str] = None
    assigned_to: Optional[UUID] = None

class PropertyApprovalRequest(BaseModel):
    property_id: UUID
    approved: bool
    rejection_reason: Optional[str] = None

class KYCApprovalRequest(BaseModel):
    document_id: UUID
    approved: bool
    rejection_reason: Optional[str] = None

class AdminInviteRequest(BaseModel):
    email: EmailStr
    role: str = "ADMIN"

class AdminRoleChangeRequest(BaseModel):
    user_id: UUID
    role: str

class AdminDashboardResponse(BaseModel):
    total_users: int
    total_landlords: int
    total_tenants: int
    pending_properties: int
    pending_kyc: int
    open_disputes: int
    total_revenue: float
    recent_signups: int
    active_escrows: int

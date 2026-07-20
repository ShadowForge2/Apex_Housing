from pydantic import BaseModel, ConfigDict, EmailStr, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date
from app.common.enums import UserRole

class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    profile_picture: Optional[str] = None
    bio: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None

class ProfileUpdateRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    profile_picture: Optional[str] = None
    phone_number: Optional[str] = None
    bio: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    role: UserRole
    is_super_admin: bool = False
    is_active: bool
    is_verified: bool
    profile: Optional[ProfileResponse] = None
    created_at: datetime

class LandlordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    total_properties: int
    total_earned: float

class TenantResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    total_bookings: int
    total_spent: float

class VerificationDocumentUpload(BaseModel):
    document_type: str
    document_url: str
    document_number: Optional[str] = None
    expiry_date: Optional[date] = None

class VerificationDocumentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    document_type: str
    document_url: str
    document_number: Optional[str] = None
    status: str
    created_at: datetime

class UserListResponse(BaseModel):
    total: int
    users: List[UserResponse]


class SignatureSaveRequest(BaseModel):
    signature_data: str = Field(description="Base64 encoded signature image")
    label: Optional[str] = Field(None, description="Optional label for this signature")


class SignatureResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    signature_data: str
    is_active: bool
    label: Optional[str] = None
    created_at: datetime


class SignatureStatusResponse(BaseModel):
    has_signature: bool
    signature_data: Optional[str] = None
    signature_created_at: Optional[datetime] = None


class SignatureListResponse(BaseModel):
    total: int
    signatures: List[SignatureResponse]


class SignatureCheckResponse(BaseModel):
    has_signature: bool
    requires_signature: bool
    for_action: str
    signature_data: Optional[str] = None
    signature_created_at: Optional[datetime] = None

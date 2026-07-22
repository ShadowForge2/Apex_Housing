from pydantic import BaseModel, ConfigDict, EmailStr, Field
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.common.enums import UserRole

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    role: UserRole
    first_name: str
    last_name: str

    model_config = {"json_schema_extra": {
        "examples": [{"role": "tenant"}, {"role": "landlord"}]
    }}

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str = Field(min_length=8)

class VerifyOTPRequest(BaseModel):
    email: Optional[EmailStr] = None
    code: str = Field(min_length=6, max_length=6)
    purpose: str = "verify"

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8)

class SendOtpRequest(BaseModel):
    email: EmailStr
    purpose: str = "verify"

class LogoutRequest(BaseModel):
    refresh_token: str

class AdminRequestAccessRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)

class AuthResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    role: UserRole
    is_verified: bool
    message: str

from fastapi import APIRouter, Depends, Request, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth.schemas import (
    RegisterRequest, LoginRequest, TokenResponse, RefreshTokenRequest,
    PasswordResetRequest, PasswordResetConfirm, VerifyOTPRequest,
    ChangePasswordRequest, LogoutRequest, AuthResponse, SendOtpRequest,
    AdminRequestAccessRequest,
)
from app.auth.service import AuthService, generate_otp
from app.auth.models import OTPCode
from app.common.response import SuccessResponse
from app.services.email import email_service
from app.services.google_oauth import google_oauth_service
from app.config import settings
from uuid import uuid4
from datetime import datetime, timedelta, timezone
import hashlib


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=SuccessResponse)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    tokens = await service.register(
        email=body.email, password=body.password,
        role=body.role, first_name=body.first_name, last_name=body.last_name,
    )

    if tokens.get("redirect_to_login"):
        return SuccessResponse(message="Account already exists. Please login.", data=tokens)

    from sqlalchemy import select as sa_select
    from app.users.models import User as UserModel
    user_result = await db.execute(sa_select(UserModel).where(UserModel.email == body.email))
    user = user_result.scalar_one_or_none()

    otp = generate_otp()
    otp_record = OTPCode(
        id=uuid4(), user_id=user.id if user else None,
        code=hashlib.sha256(otp.encode()).hexdigest(),
        purpose="verify", is_used=False, expires_at=_utcnow() + timedelta(minutes=10),
    )
    db.add(otp_record)
    await db.commit()
    await email_service.send_otp(to=body.email, otp=otp, purpose="verification")
    return SuccessResponse(message="Registration successful. Verification OTP sent to email.", data=tokens)

@router.post("/admin/request-access", response_model=SuccessResponse)
async def admin_request_access(body: AdminRequestAccessRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    tokens = await service.request_admin_access(email=body.email, password=body.password)
    return SuccessResponse(message="OTP sent to your email. Verify to activate your account.", data=tokens)

@router.post("/login", response_model=SuccessResponse)
async def login(body: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    from app.users.models import User as UserModel
    from sqlalchemy import select as sa_select

    service = AuthService(db)
    ip = request.client.host if request.client else ""
    ua = request.headers.get("user-agent", "")

    if body.client_type in ("admin", "user"):
        result = await db.execute(sa_select(UserModel).where(UserModel.email == body.email))
        user = result.scalar_one_or_none()
        if user:
            is_admin = user.role.value == "ADMIN"
            if body.client_type == "admin" and not is_admin:
                raise HTTPException(status_code=403, detail="Admin login required. Please login with your admin account.")
            if body.client_type == "user" and is_admin:
                raise HTTPException(status_code=403, detail="Admin account detected. Please login with the admin app.")

    tokens = await service.login(email=body.email, password=body.password, ip_address=ip, user_agent=ua)
    return SuccessResponse(message="Login successful", data=tokens)

@router.post("/refresh", response_model=SuccessResponse)
async def refresh_token(body: RefreshTokenRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    tokens = await service.refresh_tokens(body.refresh_token)
    return SuccessResponse(message="Token refreshed", data=tokens)

@router.post("/logout")
async def logout(body: LogoutRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    await service.logout(body.refresh_token)
    return SuccessResponse(message="Logged out successfully")

@router.post("/send-otp", response_model=SuccessResponse)
async def send_otp(body: SendOtpRequest, db: AsyncSession = Depends(get_db)):
    from sqlalchemy import select as sa_select
    from sqlalchemy import func as sa_func
    from app.users.models import User as UserModel

    user_result = await db.execute(sa_select(UserModel).where(UserModel.email == body.email))
    user = user_result.scalar_one_or_none()
    if not user:
        return SuccessResponse(message="If this email is registered, an OTP has been sent.")

    recent_otps = await db.execute(
        sa_select(sa_func.count()).select_from(OTPCode).where(
            OTPCode.user_id == user.id,
            OTPCode.created_at > _utcnow() - timedelta(minutes=5),
        )
    )
    if recent_otps.scalar() >= 3:
        raise HTTPException(status_code=429, detail="Too many OTP requests. Wait 5 minutes before trying again.")

    otp = generate_otp()
    otp_record = OTPCode(
        id=uuid4(), user_id=user.id,
        code=hashlib.sha256(otp.encode()).hexdigest(),
        purpose=body.purpose, is_used=False, expires_at=_utcnow() + timedelta(minutes=10),
    )
    db.add(otp_record)
    await db.commit()
    await email_service.send_otp(to=body.email, otp=otp, purpose=body.purpose)
    return SuccessResponse(message=f"OTP sent to {body.email}")

@router.post("/password-reset/request", response_model=SuccessResponse)
async def request_password_reset(body: PasswordResetRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    await service.request_password_reset(body.email)
    return SuccessResponse(message="Password reset OTP sent to your email")

@router.post("/password-reset/confirm", response_model=SuccessResponse)
async def confirm_password_reset(body: PasswordResetConfirm, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    await service.reset_password(token=body.token, new_password=body.new_password)
    return SuccessResponse(message="Password reset successful")

@router.post("/verify-otp", response_model=SuccessResponse)
async def verify_otp(body: VerifyOTPRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    await service.verify_otp(email=body.email, code=body.code, purpose=body.purpose)
    return SuccessResponse(message="OTP verified successfully")

@router.get("/google/login")
async def google_login():
    url = google_oauth_service.get_authorization_url()
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url)

@router.get("/google/callback")
async def google_callback(code: str = None, state: str = None, db: AsyncSession = Depends(get_db)):
    if not code:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=400, content={"error": "No authorization code"})

    token_data = await google_oauth_service.exchange_code(code)
    if "access_token" not in token_data:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=400, content={"error": "Failed to exchange code"})

    user_info = await google_oauth_service.get_user_info(token_data["access_token"])
    if not user_info.get("email"):
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=400, content={"error": "Failed to get user info"})

    from sqlalchemy import select
    from app.users.models import User, Profile, Tenant
    from app.auth.service import create_access_token, create_refresh_token, hash_password
    from app.auth.models import UserSession
    from app.common.enums import UserRole
    from fastapi.responses import RedirectResponse

    email = user_info["email"]
    result = await db.execute(select(User).where(User.email == email))
    existing_user = result.scalar_one_or_none()

    if existing_user:
        access_token = create_access_token(existing_user.id, existing_user.role)
        refresh_token = create_refresh_token(existing_user.id)
        session = UserSession(
            id=uuid4(), user_id=existing_user.id, refresh_token=refresh_token,
            is_active=True,
            expires_at=_utcnow() + timedelta(days=7),
        )
        db.add(session)
        await db.commit()
        redirect_url = f"{settings.FRONTEND_URL}/auth/callback?access_token={access_token}&refresh_token={refresh_token}"
        return RedirectResponse(redirect_url)

    role = UserRole.TENANT
    new_user = User(
        id=uuid4(), email=email,
        password_hash=hash_password(uuid4().hex),
        role=role, is_active=True, is_verified=True,
    )
    db.add(new_user)

    profile = Profile(
        id=uuid4(), user_id=new_user.id,
        first_name=user_info.get("given_name", ""),
        last_name=user_info.get("family_name", ""),
        profile_picture=user_info.get("picture"),
    )
    db.add(profile)

    tenant = Tenant(id=uuid4(), user_id=new_user.id)
    db.add(tenant)
    await db.commit()

    access_token = create_access_token(new_user.id, new_user.role)
    refresh_token = create_refresh_token(new_user.id)
    session = UserSession(
        id=uuid4(), user_id=new_user.id, refresh_token=refresh_token,
        is_active=True,
        expires_at=_utcnow() + timedelta(days=7),
    )
    db.add(session)
    await db.commit()

    redirect_url = f"{settings.FRONTEND_URL}/auth/callback?access_token={access_token}&refresh_token={refresh_token}&new_user=true"
    return RedirectResponse(redirect_url)

@router.post("/google/verify-id-token")
async def google_verify_id_token(body: dict, request: Request, db: AsyncSession = Depends(get_db)):
    """Accept a Google ID token from a mobile client, create/find user, return app tokens."""
    id_token = body.get("id_token")
    if not id_token:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=400, content={"success": False, "message": "id_token is required"})

    user_info = await google_oauth_service.verify_id_token(id_token)
    if not user_info.get("email"):
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=401, content={"success": False, "message": "Invalid Google ID token"})

    from sqlalchemy import select
    from app.users.models import User, Profile, Tenant
    from app.auth.service import create_access_token, create_refresh_token, hash_password
    from app.auth.models import UserSession
    from app.common.enums import UserRole

    email = user_info["email"]
    result = await db.execute(select(User).where(User.email == email))
    existing_user = result.scalar_one_or_none()

    ip = request.client.host if request.client else ""
    ua = request.headers.get("user-agent", "")

    if existing_user:
        access_token = create_access_token(existing_user.id, existing_user.role)
        refresh_token = create_refresh_token(existing_user.id)
        session = UserSession(
            id=uuid4(), user_id=existing_user.id, refresh_token=refresh_token,
            is_active=True, ip_address=ip, user_agent=ua,
            expires_at=_utcnow() + timedelta(days=7),
        )
        db.add(session)
        await db.commit()
        return SuccessResponse(message="Login successful", data={
            "access_token": access_token,
            "refresh_token": refresh_token,
            "user": {
                "id": str(existing_user.id),
                "email": existing_user.email,
                "role": existing_user.role.value if existing_user.role else "TENANT",
            },
            "new_user": False,
        })

    role = UserRole.TENANT
    new_user = User(
        id=uuid4(), email=email,
        password_hash=hash_password(uuid4().hex),
        role=role, is_active=True, is_verified=True,
    )
    db.add(new_user)

    profile = Profile(
        id=uuid4(), user_id=new_user.id,
        first_name=user_info.get("first_name", ""),
        last_name=user_info.get("last_name", ""),
        profile_picture=user_info.get("avatar_url"),
    )
    db.add(profile)

    tenant = Tenant(id=uuid4(), user_id=new_user.id)
    db.add(tenant)
    await db.commit()

    access_token = create_access_token(new_user.id, new_user.role)
    refresh_token = create_refresh_token(new_user.id)
    session = UserSession(
        id=uuid4(), user_id=new_user.id, refresh_token=refresh_token,
        is_active=True, ip_address=ip, user_agent=ua,
        expires_at=_utcnow() + timedelta(days=7),
    )
    db.add(session)
    await db.commit()

    return SuccessResponse(message="Account created and login successful", data={
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user": {
            "id": str(new_user.id),
            "email": new_user.email,
            "role": new_user.role.value if new_user.role else "TENANT",
        },
        "new_user": True,
    })


@router.get("/apple/login")
async def apple_login():
    return SuccessResponse(
        message="Apple Sign-In coming soon",
        data={"status": "coming_soon", "provider": "apple"},
    )

@router.post("/apple/callback")
async def apple_callback():
    return SuccessResponse(
        message="Apple Sign-In coming soon",
        data={"status": "coming_soon", "provider": "apple"},
    )

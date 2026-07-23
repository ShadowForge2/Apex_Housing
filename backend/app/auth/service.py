from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import uuid4, UUID
import secrets
import hashlib
import logging

logger = logging.getLogger(__name__)

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from passlib.context import CryptContext
from jose import jwt, JWTError

from app.config import settings
from app.auth.models import UserSession, OTPCode
from app.users.models import User, Profile, Landlord, Tenant
from app.common.enums import UserRole
from app.common.exceptions import BadRequest, Unauthorized, NotFound, Conflict, Forbidden
from app.services.email import email_service


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(user_id: UUID, role: str) -> str:
    expire = _utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "role": role,
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def create_refresh_token(user_id: UUID) -> str:
    expire = _utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "exp": expire,
        "type": "refresh",
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        raise Unauthorized("Invalid or expired token")

def generate_otp(length: int = 6) -> str:
    return "".join([str(secrets.randbelow(10)) for _ in range(length)])


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(self, email: str, password: str = "", role: UserRole = UserRole.TENANT, first_name: str = "", last_name: str = "") -> dict:
        existing = await self.db.execute(select(User).where(User.email == email))
        existing_user = existing.scalar_one_or_none()

        if existing_user:
            if existing_user.is_verified:
                return {"redirect_to_login": True, "message": "Account already exists. Please login."}
            existing_user.password_hash = hash_password(password)
            await self.db.commit()
            await self.db.refresh(existing_user)
            access_token = create_access_token(existing_user.id, existing_user.role)
            refresh_token = create_refresh_token(existing_user.id)
            return {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                "user_id": str(existing_user.id),
                "role": str(existing_user.role),
                "first_name": first_name,
                "last_name": last_name,
                "resend_otp": True,
            }

        is_super_admin = False
        if role == UserRole.ADMIN:
            admin_count = await self.db.execute(select(func.count()).select_from(User).where(User.role == UserRole.ADMIN.value))
            if admin_count.scalar() > 0:
                raise Forbidden("Cannot self-register as admin. Contact a super admin.")
            is_super_admin = True

        user = User(
            id=uuid4(),
            email=email,
            password_hash=hash_password(password),
            role=role,
            is_super_admin=is_super_admin,
            is_active=True,
            is_verified=False,
        )
        self.db.add(user)

        profile = Profile(
            id=uuid4(),
            user_id=user.id,
            first_name=first_name,
            last_name=last_name,
        )
        self.db.add(profile)

        if role == UserRole.LANDLORD:
            landlord = Landlord(id=uuid4(), user_id=user.id)
            self.db.add(landlord)
        elif role == UserRole.TENANT:
            tenant = Tenant(id=uuid4(), user_id=user.id)
            self.db.add(tenant)

        await self.db.commit()
        await self.db.refresh(user)

        access_token = create_access_token(user.id, user.role)
        refresh_token = create_refresh_token(user.id)

        session = UserSession(
            id=uuid4(),
            user_id=user.id,
            refresh_token=refresh_token,
            is_active=True,
            expires_at=_utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        self.db.add(session)
        await self.db.commit()

        await email_service.send_welcome(to=email, name=first_name)

        profile_result = await self.db.execute(select(Profile).where(Profile.user_id == user.id))
        profile = profile_result.scalar_one_or_none()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user_id": str(user.id),
            "role": user.role,
            "first_name": profile.first_name if profile else "",
            "last_name": profile.last_name if profile else "",
            "is_super_admin": user.is_super_admin,
        }

    async def login(self, email: str, password: str, ip_address: str = "", user_agent: str = "") -> dict:
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user or not verify_password(password, user.password_hash):
            raise Unauthorized("Invalid email or password")
        if not user.is_active:
            raise Unauthorized("Account is deactivated")

        access_token = create_access_token(user.id, user.role)
        refresh_token = create_refresh_token(user.id)

        session = UserSession(
            id=uuid4(),
            user_id=user.id,
            refresh_token=refresh_token,
            user_agent=user_agent,
            ip_address=ip_address,
            is_active=True,
            expires_at=_utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        self.db.add(session)

        await self.db.commit()

        profile_result = await self.db.execute(select(Profile).where(Profile.user_id == user.id))
        profile = profile_result.scalar_one_or_none()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user_id": str(user.id),
            "role": user.role,
            "first_name": profile.first_name if profile else "",
            "last_name": profile.last_name if profile else "",
            "is_super_admin": user.is_super_admin,
        }

    async def refresh_tokens(self, refresh_token: str) -> dict:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise BadRequest("Invalid token type")

        user_id = UUID(payload["sub"])
        result = await self.db.execute(
            select(UserSession).where(
                UserSession.refresh_token == refresh_token,
                UserSession.is_active == True,
                UserSession.user_id == user_id,
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise Unauthorized("Invalid or expired refresh token")

        session.is_active = False

        user_result = await self.db.execute(select(User).where(User.id == user_id))
        user = user_result.scalar_one_or_none()
        if not user or not user.is_active:
            raise Unauthorized("User not found or deactivated")

        new_access = create_access_token(user.id, user.role)
        new_refresh = create_refresh_token(user.id)

        new_session = UserSession(
            id=uuid4(),
            user_id=user.id,
            refresh_token=new_refresh,
            is_active=True,
            expires_at=_utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        self.db.add(new_session)
        await self.db.commit()

        return {
            "access_token": new_access,
            "refresh_token": new_refresh,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        }

    async def logout(self, refresh_token: str) -> None:
        result = await self.db.execute(
            select(UserSession).where(UserSession.refresh_token == refresh_token)
        )
        session = result.scalar_one_or_none()
        if session:
            session.is_active = False
            await self.db.commit()

    async def request_password_reset(self, email: str) -> None:
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user:
            return

        otp = generate_otp()
        otp_record = OTPCode(
            id=uuid4(),
            user_id=user.id,
            code=hashlib.sha256(otp.encode()).hexdigest(),
            purpose="reset",
            is_used=False,
            expires_at=_utcnow() + timedelta(minutes=10),
        )
        self.db.add(otp_record)
        await self.db.commit()

        await email_service.send_otp(to=email, otp=otp, purpose="password reset")

    async def reset_password(self, token: str, new_password: str) -> None:
        result = await self.db.execute(
            select(OTPCode).where(
                OTPCode.code == hashlib.sha256(token.encode()).hexdigest(),
                OTPCode.purpose == "reset",
                OTPCode.is_used == False,
                OTPCode.expires_at > _utcnow(),
            )
        )
        otp_record = result.scalar_one_or_none()
        if not otp_record:
            raise BadRequest("Invalid or expired reset token")

        user_result = await self.db.execute(select(User).where(User.id == otp_record.user_id))
        user = user_result.scalar_one_or_none()
        if not user:
            raise BadRequest("User not found")
        user.password_hash = hash_password(new_password)
        otp_record.is_used = True
        await self.db.commit()

    async def verify_otp(self, email: str = None, code: str = "", purpose: str = "verify") -> bool:
        code_hash = hashlib.sha256(code.encode()).hexdigest()
        query = select(OTPCode).where(
            OTPCode.code == code_hash,
            OTPCode.purpose == purpose,
            OTPCode.is_used == False,
            OTPCode.expires_at > _utcnow(),
        )

        # Scope OTP to the specific user if email is provided
        if email:
            user_result = await self.db.execute(select(User).where(User.email == email))
            user = user_result.scalar_one_or_none()
            if user:
                query = query.where(OTPCode.user_id == user.id)
            else:
                raise BadRequest("Invalid or expired OTP")

        result = await self.db.execute(query)
        otp_record = result.scalar_one_or_none()
        if not otp_record:
            raise BadRequest("Invalid or expired OTP")

        otp_record.is_used = True

        if purpose == "verify" and email and user:
            user.is_verified = True

        await self.db.commit()
        return True

    async def get_current_user(self, user_id: UUID) -> User:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")
        if not user.is_active:
            raise Unauthorized("Account is deactivated")
        return user

    async def request_admin_access(self, email: str, password: str) -> dict:
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("No invitation found for this email. Contact the super admin.")
        if user.role != UserRole.ADMIN:
            raise BadRequest("This email is not registered as an admin.")
        if user.is_verified:
            raise Conflict("Account already activated. Please login.")

        user.password_hash = hash_password(password)
        user.is_active = True
        await self.db.commit()

        otp = generate_otp()
        otp_record = OTPCode(
            id=uuid4(),
            user_id=user.id,
            code=hashlib.sha256(otp.encode()).hexdigest(),
            purpose="verify",
            is_used=False,
            expires_at=_utcnow() + timedelta(minutes=10),
        )
        self.db.add(otp_record)
        await self.db.commit()
        await email_service.send_otp(to=email, otp=otp, purpose="verification")

        try:
            from app.messages.models import Conversation, ConversationParticipant
            from app.common.enums import UserRole as UR
            from uuid import uuid4 as _uuid
            from sqlalchemy import select as sa_select

            conv_result = await self.db.execute(
                sa_select(Conversation).where(Conversation.conversation_type == "admin_group")
            )
            conv = conv_result.scalar_one_or_none()
            if conv:
                existing = await self.db.execute(
                    sa_select(ConversationParticipant).where(
                        ConversationParticipant.conversation_id == conv.id,
                        ConversationParticipant.user_id == user.id,
                    )
                )
                if not existing.scalar_one_or_none():
                    participant = ConversationParticipant(
                        id=_uuid(), conversation_id=conv.id,
                        user_id=user.id, unread_count=0,
                    )
                    self.db.add(participant)
                    await self.db.commit()
        except Exception as e:
            logger.error(f"Failed to add admin {user.id} to group chat: {e}")

        access_token = create_access_token(user.id, user.role)
        refresh_token = create_refresh_token(user.id)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user_id": str(user.id),
            "role": str(user.role),
            "is_super_admin": user.is_super_admin,
        }

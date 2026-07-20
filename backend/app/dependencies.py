from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.auth.service import decode_token
from app.users.models import User
from app.common.enums import UserRole
from app.common.exceptions import Unauthorized, Forbidden


async def _extract_bearer(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    if not auth.startswith("Bearer "):
        raise Unauthorized("Missing or invalid authorization header")
    return auth[7:]


async def get_current_user_id(token: str = Depends(_extract_bearer)) -> UUID:
    payload = decode_token(token)
    if payload.get("type") != "access":
        raise Unauthorized("Invalid token type")
    return UUID(payload["sub"])


async def get_current_user(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> User:
    from sqlalchemy import select
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise Unauthorized("User not found")
    if not user.is_active:
        raise Unauthorized("Account is deactivated")
    return user


class RoleChecker:
    def __init__(self, allowed_roles: list[UserRole]):
        self.allowed_roles = allowed_roles

    def __call__(self, user: User = Depends(get_current_user)) -> User:
        if user.role not in self.allowed_roles:
            raise Forbidden("You don't have permission to access this resource")
        return user


get_tenant = RoleChecker([UserRole.TENANT])
get_landlord = RoleChecker([UserRole.LANDLORD, UserRole.ADMIN])
get_admin = RoleChecker([UserRole.ADMIN])
get_landlord_or_agent = get_landlord
get_any_user = RoleChecker([UserRole.TENANT, UserRole.LANDLORD, UserRole.ADMIN])


async def get_super_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.ADMIN or not user.is_super_admin:
        raise Forbidden("Super admin access required")
    return user


async def get_verified_user(user: User = Depends(get_current_user)) -> User:
    if not user.is_verified:
        raise Forbidden("Identity verification required. Please complete KYC to access this feature.")
    return user


async def get_verified_tenant(user: User = Depends(get_verified_user)) -> User:
    if user.role != UserRole.TENANT:
        raise Forbidden("Tenant access required")
    return user


async def get_verified_landlord(user: User = Depends(get_verified_user)) -> User:
    if user.role not in (UserRole.LANDLORD, UserRole.ADMIN):
        raise Forbidden("Landlord access required")
    return user

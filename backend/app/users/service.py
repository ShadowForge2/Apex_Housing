from uuid import UUID
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional, List

from app.users.models import User, Profile, Landlord, Tenant, VerificationDocument
from app.users.schemas import (
    ProfileUpdateRequest, ProfileResponse, UserResponse, LandlordResponse,
    TenantResponse, VerificationDocumentUpload,
)
from app.common.enums import UserRole
from app.common.exceptions import NotFound, BadRequest, Forbidden

class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_user(self, user_id: UUID) -> User:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")
        return user

    async def get_user_profile(self, user_id: UUID) -> dict:
        user = await self.get_user(user_id)
        profile_result = await self.db.execute(select(Profile).where(Profile.user_id == user_id))
        profile = profile_result.scalar_one_or_none()
        
        response = {
            "id": user.id,
            "email": user.email,
            "role": user.role,
            "is_active": user.is_active,
            "is_verified": user.is_verified,
            "created_at": user.created_at,
            "profile": None,
        }
        
        if profile:
            response["profile"] = {
                "id": profile.id,
                "user_id": profile.user_id,
                "first_name": profile.first_name,
                "last_name": profile.last_name,
                "profile_picture": profile.profile_picture,
                "phone_number": profile.phone_number,
                "bio": profile.bio,
                "date_of_birth": profile.date_of_birth,
                "gender": profile.gender,
            }
        
        if user.role == UserRole.LANDLORD:
            ll_result = await self.db.execute(select(Landlord).where(Landlord.user_id == user_id))
            ll = ll_result.scalar_one_or_none()
            if ll:
                response["landlord"] = {
                    "id": ll.id,
                    "total_properties": ll.total_properties, "total_earned": ll.total_earned,
                }
        elif user.role == UserRole.TENANT:
            tn_result = await self.db.execute(select(Tenant).where(Tenant.user_id == user_id))
            tn = tn_result.scalar_one_or_none()
            if tn:
                response["tenant"] = {
                    "id": tn.id,
                    "total_bookings": tn.total_bookings, "total_spent": tn.total_spent,
                }
        
        return response

    async def update_profile(self, user_id: UUID, data: ProfileUpdateRequest) -> dict:
        result = await self.db.execute(select(Profile).where(Profile.user_id == user_id))
        profile = result.scalar_one_or_none()
        if not profile:
            raise NotFound("Profile not found")
        
        update_data = data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(profile, key, value)
        
        await self.db.commit()
        await self.db.refresh(profile)
        return {"id": profile.id, "user_id": profile.user_id, **update_data}

    async def list_users(self, page: int = 1, page_size: int = 20, role: str = None) -> dict:
        query = select(User)
        count_query = select(User)
        
        if role:
            query = query.where(User.role == role)
            count_query = count_query.where(User.role == role)
        
        total_result = await self.db.execute(select(count_query.subquery().count()))
        total = total_result.scalar()
        
        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        users = result.scalars().all()
        
        return {"total": total, "users": users, "page": page, "page_size": page_size}

    async def upload_verification_document(self, user_id: UUID, data: VerificationDocumentUpload) -> VerificationDocument:
        doc = VerificationDocument(
            user_id=user_id,
            document_type=data.document_type,
            document_url=data.document_url,
            document_number=data.document_number,
            expiry_date=data.expiry_date,
            status="pending",
        )
        self.db.add(doc)
        await self.db.commit()
        await self.db.refresh(doc)
        return doc

    async def switch_role(self, user_id: UUID, new_role: UserRole) -> dict:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")

        old_role = user.role
        if old_role == new_role:
            return {"message": f"Already a {new_role.value}", "role": new_role.value}

        if new_role == UserRole.ADMIN:
            raise Forbidden("Cannot switch to admin role")

        user.role = new_role

        if new_role == UserRole.LANDLORD:
            existing = await self.db.execute(select(Landlord).where(Landlord.user_id == user_id))
            if not existing.scalar_one_or_none():
                self.db.add(Landlord(user_id=user_id))

        elif new_role == UserRole.TENANT:
            existing = await self.db.execute(select(Tenant).where(Tenant.user_id == user_id))
            if not existing.scalar_one_or_none():
                self.db.add(Tenant(user_id=user_id))

        await self.db.commit()
        return {"message": f"Role switched from {old_role.value} to {new_role.value}", "role": new_role.value}

    async def submit_kyc(self, user_id: UUID, document_type: str, document_url: str, selfie_url: str = None, needs_review: bool = False) -> dict:
        existing = await self.db.execute(
            select(VerificationDocument).where(
                VerificationDocument.user_id == user_id,
                VerificationDocument.status.in_(["pending", "approved"]),
            )
        )
        if existing.scalar_one_or_none():
            return {"status": "already_submitted", "message": "KYC already submitted or approved"}

        if needs_review:
            status = "pending"
            message = "Document submitted for review. We'll verify it shortly."
        else:
            status = "approved"
            message = "KYC verified successfully"

        doc = VerificationDocument(
            user_id=user_id,
            document_type=document_type,
            document_url=document_url,
            status=status,
            reviewed_at=datetime.utcnow() if not needs_review else None,
        )
        self.db.add(doc)

        user_result = await self.db.execute(select(User).where(User.id == user_id))
        user = user_result.scalar_one_or_none()
        if user and not needs_review:
            user.is_verified = True

        await self.db.commit()
        return {"status": status, "message": message, "document_id": str(doc.id)}

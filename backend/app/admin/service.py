from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timezone

from app.admin.models import AdminAction, AuditLog, FraudAlert, PlatformSetting
from app.admin.schemas import AdminActionRequest, FraudAlertUpdate
from app.users.models import User, Profile, Landlord, Tenant, VerificationDocument
from app.properties.models import Property
from app.disputes.models import Dispute
from app.escrow.models import EscrowTransaction
from app.bookings.models import Booking
from app.commission.models import PlatformRevenue
from app.common.enums import EscrowStatus, PropertyStatus, UserRole, BookingStatus
from app.common.exceptions import NotFound, BadRequest, Forbidden, Conflict
from app.events.bus import event_bus
from app.events.types import AdminActionEvent
from app.auth.service import create_access_token, create_refresh_token, hash_password

class AdminService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_setting(self, key: str, default: str = "0") -> str:
        result = await self.db.execute(select(PlatformSetting).where(PlatformSetting.key == key))
        row = result.scalar_one_or_none()
        return row.value if row else default

    async def get_setting_float(self, key: str, default: float = 0.0) -> float:
        val = await self.get_setting(key, str(default))
        try:
            return float(val)
        except (ValueError, TypeError):
            return default

    async def record_action(self, admin_id: UUID, data: AdminActionRequest) -> AdminAction:
        action = AdminAction(
            id=uuid4(), admin_id=admin_id,
            action=data.action,
            target_type=data.target_type,
            target_id=data.target_id,
            details_json=data.details,
        )
        self.db.add(action)
        await self.db.commit()
        await self.db.refresh(action)

        await event_bus.emit("admin.action", AdminActionEvent(
            admin_id=admin_id,
            action=data.action,
            target_type=data.target_type,
            target_id=data.target_id,
            details=data.details,
        ))
        return action

    async def approve_property(self, admin_id: UUID, property_id: UUID, approved: bool, rejection_reason: str = None) -> Property:
        result = await self.db.execute(select(Property).where(Property.id == property_id))
        prop = result.scalar_one_or_none()
        if not prop:
            raise NotFound("Property not found")

        old_status = prop.status

        if approved:
            prop.status = PropertyStatus.ACTIVE.value
        else:
            prop.status = PropertyStatus.DRAFT.value

        await self.record_action(admin_id, AdminActionRequest(
            action="approve_property" if approved else "reject_property",
            target_type="property", target_id=property_id,
            details={"reason": rejection_reason} if rejection_reason else {},
        ))
        await self.db.commit()
        await self.db.refresh(prop)

        # Emit status changed event — triggers in-app notification to landlord
        old_status_val = old_status.value if hasattr(old_status, "value") else str(old_status)
        new_status_val = prop.status.value if hasattr(prop.status, "value") else str(prop.status)
        await event_bus.emit("property.status_changed", PropertyStatusChangedEvent(
            property_id=property_id, old_status=old_status_val,
            new_status=new_status_val, triggered_by=admin_id,
        ))

        # Send email notification to landlord
        try:
            from app.services.email import email_service
            from app.users.models import User
            user_result = await self.db.execute(select(User).where(User.id == prop.landlord_id))
            landlord = user_result.scalar_one_or_none()
            if landlord:
                if approved:
                    await email_service.send_property_approved(landlord.email, prop.title)
                else:
                    await email_service.send_property_rejected(landlord.email, prop.title, rejection_reason or "")
        except Exception as e:
            logger.warning(f"Failed to send property approval email: {e}")

        return prop

    async def approve_kyc(self, admin_id: UUID, document_id: UUID, approved: bool, rejection_reason: str = None) -> VerificationDocument:
        result = await self.db.execute(select(VerificationDocument).where(VerificationDocument.id == document_id))
        doc = result.scalar_one_or_none()
        if not doc:
            raise NotFound("Document not found")

        doc.status = "approved" if approved else "rejected"
        doc.reviewed_by = admin_id
        doc.rejection_reason = rejection_reason

        if approved:
            user_result = await self.db.execute(select(User).where(User.id == doc.user_id))
            user = user_result.scalar_one_or_none()
            if user:
                user.is_verified = True

        await self.record_action(admin_id, AdminActionRequest(
            action="approve_kyc" if approved else "reject_kyc",
            target_type="verification_document", target_id=document_id,
            details={"reason": rejection_reason} if rejection_reason else {},
        ))
        await self.db.commit()

        try:
            user_result2 = await self.db.execute(select(User).where(User.id == doc.user_id))
            target_user = user_result2.scalar_one_or_none()
            if target_user:
                from app.services.email import email_service
                if approved:
                    await email_service.send_kyc_approved(target_user.email)
                else:
                    await email_service.send_kyc_rejected(target_user.email, rejection_reason or "")
        except Exception:
            pass

        return doc

    async def get_dashboard(self) -> dict:
        from datetime import timedelta, date
        from sqlalchemy import extract

        total_users = (await self.db.execute(select(func.count()).select_from(User))).scalar() or 0
        total_landlords = (await self.db.execute(select(func.count()).select_from(User).where(User.role == UserRole.LANDLORD.value))).scalar() or 0
        total_tenants = (await self.db.execute(select(func.count()).select_from(User).where(User.role == UserRole.TENANT.value))).scalar() or 0
        total_properties = (await self.db.execute(select(func.count()).select_from(Property))).scalar() or 0
        pending_properties = (await self.db.execute(select(func.count()).select_from(Property).where(Property.status == PropertyStatus.PENDING_APPROVAL.value))).scalar() or 0
        pending_kyc = (await self.db.execute(select(func.count()).select_from(VerificationDocument).where(VerificationDocument.status == "pending"))).scalar() or 0
        total_bookings = (await self.db.execute(select(func.count()).select_from(Booking))).scalar() or 0
        active_bookings = (await self.db.execute(select(func.count()).select_from(Booking).where(Booking.status == BookingStatus.ACTIVE.value))).scalar() or 0
        open_disputes = (await self.db.execute(select(func.count()).select_from(Dispute).where(Dispute.status == "open"))).scalar() or 0
        active_escrows_count = (await self.db.execute(select(func.count()).select_from(EscrowTransaction).where(EscrowTransaction.status.in_([EscrowStatus.FUNDS_HELD.value, EscrowStatus.TIMER_RUNNING.value])))).scalar() or 0

        revenue_result = await self.db.execute(select(func.coalesce(func.sum(PlatformRevenue.total_revenue), 0)))
        total_revenue = float(revenue_result.scalar() or 0)

        revenue_by_month_result = await self.db.execute(
            select(
                PlatformRevenue.period_start,
                func.coalesce(func.sum(PlatformRevenue.total_revenue), 0).label("revenue"),
            )
            .where(PlatformRevenue.period_start >= date.today() - timedelta(days=180))
            .group_by(PlatformRevenue.period_start)
            .order_by(PlatformRevenue.period_start)
        )
        monthly_revenue = []
        for row in revenue_by_month_result.all():
            monthly_revenue.append({
                "month": row.period_start.strftime("%b"),
                "revenue": float(row.revenue),
            })

        recent_signups_result = await self.db.execute(
            select(User).order_by(User.created_at.desc()).limit(10)
        )
        recent_signups_users = recent_signups_result.scalars().all()
        recent_signups_list = [
            {"id": str(u.id), "email": u.email, "role": str(u.role), "created_at": str(u.created_at)}
            for u in recent_signups_users
        ]

        active_escrows_result = await self.db.execute(
            select(EscrowTransaction).where(
                EscrowTransaction.status.in_([EscrowStatus.FUNDS_HELD.value, EscrowStatus.TIMER_RUNNING.value])
            ).order_by(EscrowTransaction.created_at.desc()).limit(10)
        )
        active_escrows_list = [
            {
                "id": str(e.id),
                "booking_id": str(e.booking_id),
                "tenant_id": str(e.tenant_id),
                "landlord_id": str(e.landlord_id),
                "amount": str(e.amount),
                "status": e.status.value if hasattr(e.status, 'value') else str(e.status),
                "created_at": str(e.created_at),
            }
            for e in active_escrows_result.scalars().all()
        ]

        try:
            activity_result = await self.db.execute(
                select(AuditLog)
                .order_by(AuditLog.created_at.desc())
                .limit(10)
            )
            activity_logs = activity_result.scalars().all()
            recent_activity = [
                {
                    "id": str(a.id),
                    "action": a.action,
                    "resource_type": a.resource_type,
                    "resource_id": str(a.resource_id) if a.resource_id else None,
                    "created_at": str(a.created_at),
                }
                for a in activity_logs
            ]
        except Exception:
            recent_activity = []

        return {
            "total_users": total_users,
            "total_landlords": total_landlords,
            "total_tenants": total_tenants,
            "total_properties": total_properties,
            "total_bookings": total_bookings,
            "active_bookings": active_bookings,
            "pending_properties": pending_properties,
            "pending_kyc": pending_kyc,
            "open_disputes": open_disputes,
            "total_revenue": total_revenue,
            "active_escrows_count": active_escrows_count,
            "monthly_revenue": monthly_revenue,
            "recent_signups": recent_signups_list,
            "recent_signups_count": len(recent_signups_list),
            "active_escrows": active_escrows_list,
            "recent_activity": recent_activity,
        }

    async def list_all_users(self, page: int = 1, page_size: int = 20, role: str = None) -> dict:
        query = select(User)
        if role:
            query = query.where(User.role == role)

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        users = result.scalars().all()
        return {"total": total, "users": [
            {"id": str(u.id), "email": u.email, "role": str(u.role), "is_active": u.is_active, "is_verified": u.is_verified, "is_super_admin": u.is_super_admin, "created_at": str(u.created_at)}
            for u in users
        ], "page": page, "page_size": page_size}

    async def get_user_detail(self, user_id: UUID) -> dict:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")

        profile_result = await self.db.execute(
            select(VerificationDocument).where(VerificationDocument.user_id == user_id)
        )
        docs = profile_result.scalars().all()

        return {
            "user": {"id": str(user.id), "email": user.email, "role": str(user.role), "is_active": user.is_active, "is_verified": user.is_verified, "is_super_admin": user.is_super_admin, "created_at": str(user.created_at)},
            "verification_documents": [
                {"id": str(d.id), "document_type": d.document_type, "status": d.status, "document_url": d.document_url, "created_at": str(d.created_at) if d.created_at else None}
                for d in docs
            ],
        }

    async def suspend_user(self, user_id: UUID, admin_id: UUID, reason: str = None) -> dict:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")
        if user.is_super_admin:
            raise Forbidden("Cannot suspend a super admin")
        if user.role == UserRole.ADMIN and await self._count_active_admins() <= 1:
            raise Forbidden("Cannot suspend the last admin")

        user.is_active = False
        await self.record_action(admin_id, AdminActionRequest(
            action="suspend_user",
            target_type="user", target_id=user_id,
            details={"reason": reason} if reason else {},
        ))
        await self.db.commit()
        return {"id": str(user.id), "is_active": user.is_active}

    async def activate_user(self, user_id: UUID, admin_id: UUID) -> dict:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")

        user.is_active = True
        await self.record_action(admin_id, AdminActionRequest(
            action="activate_user",
            target_type="user", target_id=user_id,
            details={},
        ))
        await self.db.commit()
        return {"id": str(user.id), "is_active": user.is_active}

    async def list_pending_properties(self, page: int = 1, page_size: int = 20) -> dict:
        query = select(Property).where(Property.status == PropertyStatus.PENDING_APPROVAL.value)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.order_by(Property.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        properties = result.scalars().all()
        return {"total": total, "properties": [
            {"id": str(p.id), "title": p.title, "status": str(p.status), "price": p.price, "created_at": str(p.created_at)}
            for p in properties
        ], "page": page, "page_size": page_size}

    async def list_pending_kyc(self, page: int = 1, page_size: int = 20) -> dict:
        query = select(VerificationDocument).where(VerificationDocument.status == "pending")
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.order_by(VerificationDocument.id.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        documents = result.scalars().all()
        return {"total": total, "documents": [
            {"id": str(d.id), "user_id": str(d.user_id), "document_type": d.document_type, "status": d.status, "created_at": str(d.created_at) if d.created_at else None}
            for d in documents
        ], "page": page, "page_size": page_size}

    async def get_fraud_alerts(self, page: int = 1, page_size: int = 20) -> dict:
        query = select(FraudAlert).order_by(FraudAlert.created_at.desc())
        count_result = await self.db.execute(select(func.count()).select_from(FraudAlert))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        alerts = result.scalars().all()
        return {
            "total": total,
            "alerts": [
                {
                    "id": str(a.id),
                    "user_id": str(a.user_id) if a.user_id else None,
                    "alert_type": a.alert_type,
                    "severity": a.severity,
                    "description": a.description,
                    "evidence_json": a.evidence_json,
                    "status": a.status,
                    "assigned_to": str(a.assigned_to) if a.assigned_to else None,
                    "resolved_at": str(a.resolved_at) if a.resolved_at else None,
                    "created_at": str(a.created_at),
                }
                for a in alerts
            ],
        }

    async def update_fraud_alert(self, alert_id: UUID, admin_id: UUID, data: FraudAlertUpdate) -> dict:
        result = await self.db.execute(select(FraudAlert).where(FraudAlert.id == alert_id))
        alert = result.scalar_one_or_none()
        if not alert:
            raise NotFound("Alert not found")
        if data.status:
            alert.status = data.status
        if data.assigned_to:
            alert.assigned_to = data.assigned_to
        if data.status == "resolved":
            alert.resolved_at = datetime.now(timezone.utc)
        await self.db.commit()
        return {
            "id": str(alert.id),
            "alert_type": alert.alert_type,
            "severity": alert.severity,
            "status": alert.status,
            "assigned_to": str(alert.assigned_to) if alert.assigned_to else None,
            "resolved_at": str(alert.resolved_at) if alert.resolved_at else None,
        }

    async def _count_active_admins(self) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(User).where(
                User.role == UserRole.ADMIN.value, User.is_active == True
            )
        )
        return result.scalar()

    async def invite_admin(self, super_admin_id: UUID, email: str) -> dict:
        existing = await self.db.execute(select(User).where(User.email == email))
        if existing.scalar_one_or_none():
            raise Conflict("User with this email already exists")

        user = User(
            id=uuid4(), email=email,
            password_hash=hash_password(uuid4().hex),
            role=UserRole.ADMIN, is_super_admin=False,
            is_active=True, is_verified=False,
        )
        self.db.add(user)

        profile = Profile(id=uuid4(), user_id=user.id, first_name="", last_name="")
        self.db.add(profile)

        await self.record_action(super_admin_id, AdminActionRequest(
            action="invite_admin",
            target_type="user", target_id=user.id,
            details={"email": email},
        ))
        await self.db.commit()

        try:
            from app.services.email import email_service
            inviter_result = await self.db.execute(select(User).where(User.id == super_admin_id))
            inviter = inviter_result.scalar_one_or_none()
            inviter_name = "Super Admin"
            if inviter:
                profile_result = await self.db.execute(select(Profile).where(Profile.user_id == inviter.id))
                profile = profile_result.scalar_one_or_none()
                if profile and profile.first_name:
                    inviter_name = f"{profile.first_name} {profile.last_name or ''}".strip()
            await email_service.send_admin_invite(email, invited_by=inviter_name)
        except Exception:
            pass

        return {"id": str(user.id), "email": email, "role": "ADMIN"}

    async def remove_admin(self, super_admin_id: UUID, user_id: UUID) -> dict:
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")
        if user.role != UserRole.ADMIN:
            raise BadRequest("User is not an admin")
        if user.is_super_admin:
            raise Forbidden("Cannot remove a super admin")
        if await self._count_active_admins() <= 1:
            raise Forbidden("Cannot remove the last admin")

        user.role = UserRole.LANDLORD
        existing_landlord = await self.db.execute(select(Landlord).where(Landlord.user_id == user.id))
        if not existing_landlord.scalar_one_or_none():
            landlord = Landlord(id=uuid4(), user_id=user.id)
            self.db.add(landlord)

        await self.record_action(super_admin_id, AdminActionRequest(
            action="remove_admin",
            target_type="user", target_id=user_id,
            details={"demoted_to": "LANDLORD"},
        ))
        await self.db.commit()
        return {"id": str(user_id), "new_role": "LANDLORD"}

    async def list_admins(self, page: int = 1, page_size: int = 20) -> dict:
        query = select(User).where(User.role == UserRole.ADMIN.value)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        admins = result.scalars().all()

        admin_ids = [a.id for a in admins]
        profiles_result = await self.db.execute(
            select(Profile).where(Profile.user_id.in_(admin_ids))
        )
        profiles = {p.user_id: p for p in profiles_result.scalars().all()}

        return {
            "total": total,
            "admins": [
                {
                    "id": str(a.id),
                    "email": a.email,
                    "first_name": profiles[a.id].first_name if a.id in profiles else "",
                    "last_name": profiles[a.id].last_name if a.id in profiles else "",
                    "is_super_admin": a.is_super_admin,
                    "is_active": a.is_active,
                    "role": "SUPER_ADMIN" if a.is_super_admin else "ADMIN",
                    "created_at": str(a.created_at),
                }
                for a in admins
            ],
            "page": page, "page_size": page_size,
        }

    async def change_user_role(self, super_admin_id: UUID, user_id: UUID, new_role: str) -> dict:
        role_enum = UserRole(new_role)
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFound("User not found")

        if user.role == UserRole.ADMIN and role_enum != UserRole.ADMIN:
            if user.is_super_admin:
                raise Forbidden("Cannot change the role of a super admin")
            if await self._count_active_admins() <= 1:
                raise Forbidden("Cannot demote the last admin")

        old_role = user.role
        user.role = role_enum

        if role_enum == UserRole.LANDLORD:
            existing = await self.db.execute(select(Landlord).where(Landlord.user_id == user_id))
            if not existing.scalar_one_or_none():
                self.db.add(Landlord(user_id=user_id))
        elif role_enum == UserRole.TENANT:
            existing = await self.db.execute(select(Tenant).where(Tenant.user_id == user_id))
            if not existing.scalar_one_or_none():
                self.db.add(Tenant(user_id=user_id))

        await self.record_action(super_admin_id, AdminActionRequest(
            action="change_role",
            target_type="user", target_id=user_id,
            details={"old_role": old_role, "new_role": new_role},
        ))
        await self.db.commit()
        return {"id": str(user_id), "old_role": old_role, "new_role": new_role}

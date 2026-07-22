from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from uuid import UUID

from app.database import get_db
from app.dependencies import get_admin, get_super_admin
from app.admin.service import AdminService
from sqlalchemy import select, func
from app.admin.schemas import (
    AdminActionRequest, PropertyApprovalRequest, KYCApprovalRequest,
    FraudAlertUpdate, AdminInviteRequest, AdminRoleChangeRequest,
)
from app.admin.models import AdminAction, AuditLog, PlatformSetting
from app.bookings.models import Booking
from app.payments.models import Transaction
from app.reports.models import BookingReport
from app.common.response import SuccessResponse
from app.common.exceptions import NotFound, Forbidden

router = APIRouter(prefix="/admin", tags=["Admin"])

@router.get("/dashboard", response_model=SuccessResponse)
async def dashboard(user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    data = await service.get_dashboard()
    return SuccessResponse(data=data)

@router.get("/users", response_model=SuccessResponse)
async def list_users(page: int = 1, page_size: int = 20, role: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    users = await service.list_all_users(page=page, page_size=page_size, role=role)
    return SuccessResponse(data=users)

@router.get("/users/{user_id}", response_model=SuccessResponse)
async def get_user_detail(user_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    user_detail = await service.get_user_detail(user_id)
    return SuccessResponse(data=user_detail)

@router.put("/users/{user_id}/suspend", response_model=SuccessResponse)
async def suspend_user(user_id: UUID, reason: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    result = await service.suspend_user(user_id, user.id, reason)
    return SuccessResponse(message="User suspended", data=result)

@router.put("/users/{user_id}/activate", response_model=SuccessResponse)
async def activate_user(user_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    result = await service.activate_user(user_id, user.id)
    return SuccessResponse(message="User activated", data=result)

@router.post("/properties/approve", response_model=SuccessResponse)
async def approve_property(body: PropertyApprovalRequest, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    prop = await service.approve_property(user.id, body.property_id, body.approved, body.rejection_reason)
    return SuccessResponse(message="Property approved" if body.approved else "Property rejected", data=prop)

@router.get("/properties/pending", response_model=SuccessResponse)
async def list_pending_properties(page: int = 1, page_size: int = 20, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    properties = await service.list_pending_properties(page=page, page_size=page_size)
    return SuccessResponse(data=properties)

@router.post("/kyc/approve", response_model=SuccessResponse)
async def approve_kyc(body: KYCApprovalRequest, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    doc = await service.approve_kyc(user.id, body.document_id, body.approved, body.rejection_reason)
    return SuccessResponse(message="KYC approved" if body.approved else "KYC rejected", data={"id": str(doc.id), "status": doc.status})

@router.get("/kyc/pending", response_model=SuccessResponse)
async def list_pending_kyc(page: int = 1, page_size: int = 20, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    documents = await service.list_pending_kyc(page=page, page_size=page_size)
    return SuccessResponse(data=documents)

@router.get("/fraud-alerts", response_model=SuccessResponse)
async def get_fraud_alerts(page: int = 1, page_size: int = 20, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    alerts = await service.get_fraud_alerts(page=page, page_size=page_size)
    return SuccessResponse(data=alerts)

@router.put("/fraud-alerts/{alert_id}", response_model=SuccessResponse)
async def update_fraud_alert(alert_id: UUID, body: FraudAlertUpdate, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    alert = await service.update_fraud_alert(alert_id, user.id, body)
    return SuccessResponse(message="Alert updated", data=alert)

@router.get("/admins", response_model=SuccessResponse)
async def list_admins(page: int = 1, page_size: int = 20, user=Depends(get_super_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    admins = await service.list_admins(page=page, page_size=page_size)
    return SuccessResponse(data=admins)

@router.post("/admins/invite", response_model=SuccessResponse)
async def invite_admin(body: AdminInviteRequest, user=Depends(get_super_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    result = await service.invite_admin(user.id, body.email)
    return SuccessResponse(message="Admin invited", data=result)

@router.delete("/admins/{user_id}", response_model=SuccessResponse)
async def remove_admin(user_id: UUID, user=Depends(get_super_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    result = await service.remove_admin(user.id, user_id)
    return SuccessResponse(message="Admin removed", data=result)

@router.post("/admins/change-role", response_model=SuccessResponse)
async def change_user_role(body: AdminRoleChangeRequest, user=Depends(get_super_admin), db: AsyncSession = Depends(get_db)):
    service = AdminService(db)
    result = await service.change_user_role(user.id, body.user_id, body.role)
    return SuccessResponse(message="Role changed", data=result)

@router.get("/audit-logs", response_model=SuccessResponse)
async def list_admin_audit_logs(page: int = 1, page_size: int = 20, admin_id: UUID = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    query = select(AdminAction)
    if admin_id:
        query = query.where(AdminAction.admin_id == admin_id)
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.offset((page - 1) * page_size).limit(page_size).order_by(AdminAction.created_at.desc())
    result = await db.execute(query)
    logs = result.scalars().all()
    return SuccessResponse(data={"total": total, "logs": [
        {"id": str(l.id), "admin_id": str(l.admin_id), "action": l.action, "target_type": l.target_type, "target_id": str(l.target_id) if l.target_id else None, "details": l.details_json, "created_at": str(l.created_at)}
        for l in logs
    ], "page": page, "page_size": page_size})

@router.get("/system-audit-logs", response_model=SuccessResponse)
async def list_system_audit_logs(page: int = 1, page_size: int = 20, user_id: UUID = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    query = select(AuditLog)
    if user_id:
        query = query.where(AuditLog.user_id == user_id)
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.offset((page - 1) * page_size).limit(page_size).order_by(AuditLog.created_at.desc())
    result = await db.execute(query)
    logs = result.scalars().all()
    return SuccessResponse(data={"total": total, "logs": [
        {"id": str(l.id), "user_id": str(l.user_id) if l.user_id else None, "action": l.action, "resource_type": l.resource_type, "resource_id": str(l.resource_id) if l.resource_id else None, "created_at": str(l.created_at)}
        for l in logs
    ], "page": page, "page_size": page_size})

@router.get("/bookings", response_model=SuccessResponse)
async def list_admin_bookings(page: int = 1, page_size: int = 20, status: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    from app.users.models import User, Profile
    from app.properties.models import Property

    query = select(Booking)
    if status:
        query = query.where(Booking.status == status)
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.order_by(Booking.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    bookings = result.scalars().all()

    # Enrich with names
    all_ids = set()
    for b in bookings:
        all_ids.update([b.tenant_id, b.landlord_id, b.property_id])
    all_ids.discard(None)
    if not all_ids:
        return SuccessResponse(data={"total": total, "bookings": [], "page": page, "page_size": page_size})

    users_result = await db.execute(select(User).where(User.id.in_(all_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}
    profiles_result = await db.execute(select(Profile).where(Profile.user_id.in_(all_ids)))
    profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}
    props_result = await db.execute(select(Property).where(Property.id.in_([b.property_id for b in bookings if b.property_id])))
    props_map = {p.id: p for p in props_result.scalars().all()}

    def _name(uid):
        u = users_map.get(uid)
        p = profiles_map.get(uid)
        if p and p.first_name:
            return f"{p.first_name} {p.last_name}"
        return u.email.split("@")[0] if u else "Unknown"

    enriched = []
    for b in bookings:
        prop = props_map.get(b.property_id)
        enriched.append({
            "id": str(b.id),
            "reference": b.booking_reference,
            "tenant_name": _name(b.tenant_id),
            "landlord_name": _name(b.landlord_id),
            "property": prop.title if prop else "Unknown",
            "amount": float(b.total_amount),
            "status": str(b.status),
            "date": b.created_at.strftime("%Y-%m-%d") if b.created_at else "",
            "escrow_status": "held",
        })

    return SuccessResponse(data={"total": total, "bookings": enriched, "page": page, "page_size": page_size})


@router.put("/bookings/{booking_id}/resolve", response_model=SuccessResponse)
async def resolve_booking_dispute(booking_id: UUID, resolution: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if not booking:
        raise NotFound("Booking not found")
    if resolution:
        from sqlalchemy import update as sa_update
        await db.execute(
            sa_update(Booking).where(Booking.id == booking_id).values(notes=resolution)
        )
        await db.commit()
    return SuccessResponse(message="Dispute resolved", data={"id": str(booking_id)})


@router.get("/transactions", response_model=SuccessResponse)
async def list_admin_transactions(page: int = 1, page_size: int = 20, type: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    from app.users.models import User, Profile

    query = select(Transaction)
    if type:
        query = query.where(Transaction.payment_type == type)
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.order_by(Transaction.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    transactions = result.scalars().all()

    # Enrich with user names
    user_ids = list({t.user_id for t in transactions})
    users_map = {}
    profiles_map = {}
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u for u in users_result.scalars().all()}
        profiles_result = await db.execute(select(Profile).where(Profile.user_id.in_(user_ids)))
        profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}

    def _name(uid):
        u = users_map.get(uid)
        p = profiles_map.get(uid)
        if p and p.first_name:
            return f"{p.first_name} {p.last_name}"
        return u.email.split("@")[0] if u else "Unknown"

    enriched = []
    for t in transactions:
        enriched.append({
            "id": str(t.id),
            "reference": t.gateway_reference or str(t.id)[:8],
            "from_name": _name(t.user_id),
            "to_name": "APEX Housing" if t.payment_type in ("rent", "deposit") else _name(t.user_id),
            "amount": float(t.amount),
            "type": str(t.payment_type),
            "status": str(t.status),
            "date": t.created_at.strftime("%Y-%m-%d") if t.created_at else "",
            "is_credit": t.payment_type in ("rent", "deposit"),
        })

    return SuccessResponse(data={"total": total, "transactions": enriched, "page": page, "page_size": page_size})


@router.get("/transactions/{transaction_id}", response_model=SuccessResponse)
async def get_transaction_detail(transaction_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    from app.users.models import User, Profile

    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    tx = result.scalar_one_or_none()
    if not tx:
        raise NotFound("Transaction not found")

    u_result = await db.execute(select(User).where(User.id == tx.user_id))
    user_obj = u_result.scalar_one_or_none()
    p_result = await db.execute(select(Profile).where(Profile.user_id == tx.user_id))
    profile = p_result.scalar_one_or_none()
    user_name = f"{profile.first_name} {profile.last_name}" if profile and profile.first_name else (user_obj.email.split("@")[0] if user_obj else "Unknown")

    return SuccessResponse(data={
        "id": str(tx.id),
        "reference": tx.gateway_reference or str(tx.id)[:8],
        "user_name": user_name,
        "amount": float(tx.amount),
        "type": str(tx.payment_type),
        "status": str(tx.status),
        "date": tx.created_at.strftime("%Y-%m-%d %H:%M") if tx.created_at else "",
        "payment_method": tx.payment_method,
        "gateway": tx.payment_gateway,
        "gateway_fee": float(tx.gateway_fee),
        "description": tx.description,
    })


@router.get("/reports", response_model=SuccessResponse)
async def list_admin_reports(page: int = 1, page_size: int = 20, status: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    query = select(BookingReport)
    if status:
        query = query.where(BookingReport.is_finalized == (status == "finalized"))
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.order_by(BookingReport.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    reports = result.scalars().all()

    enriched = []
    for r in reports:
        enriched.append({
            "id": str(r.id),
            "type": "property_issue",
            "severity": "medium",
            "status": "finalized" if r.is_finalized else "open",
            "reported_by": r.tenant_full_name or "Unknown",
            "reported_against": r.landlord_full_name or "Unknown",
            "description": f"Report {r.report_number} for booking {r.booking_reference}",
            "date": r.created_at.strftime("%Y-%m-%d") if r.created_at else "",
            "assigned_to": None,
        })

    return SuccessResponse(data={"total": total, "reports": enriched, "page": page, "page_size": page_size})

@router.put("/reports/{report_id}", response_model=SuccessResponse)
async def update_admin_report(report_id: UUID, status: str = None, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(BookingReport).where(BookingReport.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        from app.common.exceptions import NotFound
        raise NotFound("Report not found")
    if status is not None:
        report.is_finalized = status == "finalized"
    await db.commit()
    await db.refresh(report)
    return SuccessResponse(message="Report updated", data={"id": str(report.id), "booking_status": report.booking_status, "is_finalized": report.is_finalized})


# ──────────────────────────────────────────────
# Platform Settings (super admin only for write)
# ──────────────────────────────────────────────

class PlatformSettingsUpdate(BaseModel):
    auto_approve_listings: Optional[bool] = None
    maintenance_mode: Optional[bool] = None
    platform_fee_percentage: Optional[float] = None
    min_booking_amount: Optional[int] = None
    tenant_markup_percentage: Optional[float] = None
    agent_markdown_percentage: Optional[float] = None


DEFAULT_SETTINGS = {
    "auto_approve_listings": "false",
    "maintenance_mode": "false",
    "platform_fee_percentage": "10",      # Total commission (split 50/50 into markup + markdown)
    "min_booking_amount": "1000",
    "tenant_markup_percentage": "5",      # Half of platform_fee — added to rent for tenant
    "agent_markdown_percentage": "5",     # Half of platform_fee — deducted from landlord payout
}


async def _get_all_settings(db: AsyncSession) -> dict:
    result = await db.execute(select(PlatformSetting))
    rows = result.scalars().all()
    settings = {row.key: row.value for row in rows}
    for key, default in DEFAULT_SETTINGS.items():
        settings.setdefault(key, default)
    return settings


@router.get("/settings", response_model=SuccessResponse)
async def get_platform_settings(user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    settings = await _get_all_settings(db)
    return SuccessResponse(data={
        "auto_approve_listings": settings["auto_approve_listings"] == "true",
        "maintenance_mode": settings["maintenance_mode"] == "true",
        "platform_fee_percentage": float(settings["platform_fee_percentage"]),
        "min_booking_amount": int(settings["min_booking_amount"]),
        "tenant_markup_percentage": float(settings["tenant_markup_percentage"]),
        "agent_markdown_percentage": float(settings["agent_markdown_percentage"]),
    })


@router.put("/settings", response_model=SuccessResponse)
async def update_platform_settings(
    body: PlatformSettingsUpdate,
    user=Depends(get_super_admin),
    db: AsyncSession = Depends(get_db),
):
    from uuid import uuid4 as _uuid
    from datetime import datetime, timezone
    updates = body.model_dump(exclude_none=True)

    # Auto-split: when platform_fee_percentage changes, derive markup and markdown as half each
    if "platform_fee_percentage" in updates:
        total_fee = updates["platform_fee_percentage"]
        half = round(total_fee / 2, 2)
        updates["tenant_markup_percentage"] = half
        updates["agent_markdown_percentage"] = half

    for key, value in updates.items():
        result = await db.execute(select(PlatformSetting).where(PlatformSetting.key == key))
        row = result.scalar_one_or_none()
        str_val = str(value).lower() if isinstance(value, bool) else str(value)
        if row:
            row.value = str_val
            row.updated_by = user.id
        else:
            row = PlatformSetting(
                id=_uuid(), key=key, value=str_val,
                updated_by=user.id, updated_at=datetime.now(timezone.utc),
            )
            db.add(row)
    await db.commit()
    settings = await _get_all_settings(db)

    # Notify all other admins about the settings change
    setting_names = {
        "platform_fee_percentage": "Platform Fee",
        "tenant_markup_percentage": "Tenant Markup",
        "agent_markdown_percentage": "Agent Markdown",
        "min_booking_amount": "Minimum Booking Amount",
        "auto_approve_listings": "Auto-approve Listings",
        "maintenance_mode": "Maintenance Mode",
    }
    changed = [setting_names.get(k, k) for k in updates.keys() if k in setting_names]
    if changed:
        from app.notifications.service import NotificationService
        notif_svc = NotificationService(db)
        change_list = ", ".join(changed)
        fee_info = ""
        if "platform_fee_percentage" in updates:
            fee_info = f" — Total fee: {updates['platform_fee_percentage']}% (Tenant: {settings['tenant_markup_percentage']}% / Landlord: {settings['agent_markdown_percentage']}%)"
        title = "Platform Settings Updated"
        message = f"Super admin updated: {change_list}{fee_info}"
        email_html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #1a1a2e;">Platform Settings Updated</h2>
            <p>The super admin has updated the following platform settings:</p>
            <ul><li>{'</li><li>'.join(changed)}</li></ul>
            {f'<p><strong>New fee structure:</strong> {fee_info.strip(" —")}</p>' if fee_info else ''}
            <p style="color: #666; font-size: 13px;">This is an automated notification from APEX Housing.</p>
        </div>
        """
        await notif_svc.send_to_admins(
            title=title, message=message,
            exclude_user_id=user.id,
            email_subject=f"APEX Housing: {title}",
            email_html=email_html,
        )

    return SuccessResponse(message="Settings updated", data={
        "auto_approve_listings": settings["auto_approve_listings"] == "true",
        "maintenance_mode": settings["maintenance_mode"] == "true",
        "platform_fee_percentage": float(settings["platform_fee_percentage"]),
        "min_booking_amount": int(settings["min_booking_amount"]),
        "tenant_markup_percentage": float(settings["tenant_markup_percentage"]),
        "agent_markdown_percentage": float(settings["agent_markdown_percentage"]),
    })


# ──────────────────────────────────────────────
# Broadcast Announcements (Super Admin)
# ──────────────────────────────────────────────

class BroadcastRequest(BaseModel):
    title: str
    message: str
    roles: Optional[list[str]] = None  # e.g. ["TENANT", "LANDLORD"] or None for all non-admins
    send_email: bool = False
    email_subject: Optional[str] = None


@router.post("/broadcast", response_model=SuccessResponse)
async def broadcast_announcement(
    body: BroadcastRequest,
    user=Depends(get_super_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.notifications.service import NotificationService
    notif_svc = NotificationService(db)

    email_html = None
    if body.send_email:
        email_html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: #1a1a2e; color: white; padding: 24px; border-radius: 12px 12px 0 0;">
                <h1 style="margin: 0; font-size: 22px;">APEX Housing</h1>
            </div>
            <div style="background: #f8f9fa; padding: 24px; border: 1px solid #e9ecef; border-top: none; border-radius: 0 0 12px 12px;">
                <h2 style="color: #1a1a2e; margin-top: 0;">{body.title}</h2>
                <p style="color: #333; font-size: 15px; line-height: 1.6;">{body.message}</p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
                <p style="color: #999; font-size: 12px;">This is an official announcement from APEX Housing.</p>
            </div>
        </div>
        """

    sent = await notif_svc.broadcast_to_users(
        title=body.title,
        message=body.message,
        roles=body.roles,
        email_subject=body.email_subject if body.send_email else None,
        email_html=email_html,
    )

    return SuccessResponse(message="Announcement broadcasted", data={"recipients": sent})


# ──────────────────────────────────────────────
# Admin Group Chat
# ──────────────────────────────────────────────

@router.get("/group-chat", response_model=SuccessResponse)
async def get_or_create_admin_group_chat(
    user=Depends(get_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.messages.models import Conversation, ConversationParticipant
    from app.users.models import User, Profile
    from app.common.enums import UserRole
    from uuid import uuid4 as _uuid

    result = await db.execute(
        select(Conversation).where(
            Conversation.conversation_type == "admin_group",
        )
    )
    conv = result.scalar_one_or_none()

    if not conv:
        conv = Conversation(id=_uuid(), conversation_type="admin_group")
        db.add(conv)
        await db.flush()

        admin_result = await db.execute(
            select(User).where(User.role == UserRole.ADMIN.value, User.is_active == True)
        )
        admins = admin_result.scalars().all()
        for admin_user in admins:
            participant = ConversationParticipant(
                id=_uuid(), conversation_id=conv.id,
                user_id=admin_user.id, unread_count=0,
            )
            db.add(participant)
        await db.commit()
        await db.refresh(conv)

    part_result = await db.execute(
        select(ConversationParticipant).where(ConversationParticipant.conversation_id == conv.id)
    )
    participants = part_result.scalars().all()
    participant_ids = [p.user_id for p in participants]

    members = []
    if participant_ids:
        users_result = await db.execute(
            select(User).where(User.id.in_(participant_ids))
        )
        users_map = {u.id: u for u in users_result.scalars().all()}
        profiles_result = await db.execute(
            select(Profile).where(Profile.user_id.in_(participant_ids))
        )
        profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}
        for uid in participant_ids:
            u = users_map.get(uid)
            p = profiles_map.get(uid)
            if u:
                members.append({
                    "id": str(uid),
                    "email": u.email,
                    "name": f"{p.first_name} {p.last_name}" if p and p.first_name else u.email.split("@")[0],
                    "is_super_admin": u.is_super_admin,
                })

    my_part = next((p for p in participants if p.user_id == user.id), None)

    return SuccessResponse(data={
        "conversation_id": str(conv.id),
        "members": members,
        "last_message": conv.last_message_preview,
        "last_message_at": conv.last_message_at.isoformat() if conv.last_message_at else None,
        "unread_count": my_part.unread_count if my_part else 0,
    })


class GroupChatMessageCreate(BaseModel):
    content: str


@router.post("/group-chat/message", response_model=SuccessResponse)
async def send_group_chat_message(
    body: GroupChatMessageCreate,
    user=Depends(get_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.messages.models import Conversation, ConversationParticipant, Message
    from app.users.models import User, Profile
    from app.notifications.service import NotificationService
    from uuid import uuid4 as _uuid
    from datetime import datetime, timezone

    result = await db.execute(
        select(Conversation).where(
            Conversation.conversation_type == "admin_group",
        )
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise NotFound("Admin group chat not found")

    part_check = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv.id,
            ConversationParticipant.user_id == user.id,
        )
    )
    if not part_check.scalar_one_or_none():
        raise Forbidden("You are not a member of this group chat")

    message = Message(
        id=_uuid(), conversation_id=conv.id,
        sender_id=user.id, content=body.content,
        message_type="text",
    )
    db.add(message)

    conv.last_message_at = datetime.now(timezone.utc)
    conv.last_message_preview = body.content[:100]

    unread_result = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv.id,
            ConversationParticipant.user_id != user.id,
        )
    )
    participants = unread_result.scalars().all()
    recipient_ids = []
    for p in participants:
        p.unread_count += 1
        recipient_ids.append(p.user_id)

    await db.commit()
    await db.refresh(message)

    sender_name = user.email.split("@")[0]
    profile_result = await db.execute(
        select(Profile).where(Profile.user_id == user.id)
    )
    profile = profile_result.scalar_one_or_none()
    if profile and profile.first_name:
        sender_name = f"{profile.first_name} {profile.last_name}"

    notif_service = NotificationService(db)
    for rid in recipient_ids:
        await notif_service.send_notification(
            user_id=rid,
            title=f"Admin Chat: {sender_name}",
            message=body.content[:200],
            reference_type="admin_group_chat",
            reference_id=conv.id,
            data={"conversation_id": str(conv.id), "sender_id": str(user.id)},
            push_data={"conversation_id": str(conv.id), "type": "admin_group_chat"},
        )

    return SuccessResponse(message="Message sent", data={
        "id": str(message.id),
        "content": message.content,
        "sender_id": str(user.id),
        "created_at": message.created_at.isoformat() if message.created_at else None,
    })


@router.get("/group-chat/messages", response_model=SuccessResponse)
async def get_group_chat_messages(
    page: int = 1, page_size: int = 50,
    user=Depends(get_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.messages.models import Conversation, ConversationParticipant, Message
    from app.users.models import User, Profile

    result = await db.execute(
        select(Conversation).where(
            Conversation.conversation_type == "admin_group",
        )
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise NotFound("Admin group chat not found")

    part_check = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv.id,
            ConversationParticipant.user_id == user.id,
        )
    )
    if not part_check.scalar_one_or_none():
        raise Forbidden("You are not a member of this group chat")

    query = select(Message).where(
        Message.conversation_id == conv.id,
        Message.is_deleted == False,
    ).order_by(Message.created_at.desc())

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    messages = result.scalars().all()

    sender_ids = list({m.sender_id for m in messages})
    users_map = {}
    profiles_map = {}
    if sender_ids:
        users_result = await db.execute(select(User).where(User.id.in_(sender_ids)))
        users_map = {u.id: u for u in users_result.scalars().all()}
        profiles_result = await db.execute(select(Profile).where(Profile.user_id.in_(sender_ids)))
        profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}

    enriched = []
    for m in messages:
        u = users_map.get(m.sender_id)
        p = profiles_map.get(m.sender_id)
        sender_name = u.email.split("@")[0] if u else "Unknown"
        if p and p.first_name:
            sender_name = f"{p.first_name} {p.last_name}"
        enriched.append({
            "id": str(m.id),
            "content": m.content,
            "message_type": m.message_type,
            "sender_id": str(m.sender_id),
            "sender_name": sender_name,
            "is_edited": m.is_edited,
            "created_at": m.created_at.isoformat() if m.created_at else None,
        })

    return SuccessResponse(data={"total": total, "messages": enriched})


class GroupMemberManage(BaseModel):
    user_id: UUID


@router.post("/group-chat/members", response_model=SuccessResponse)
async def add_group_chat_member(
    body: GroupMemberManage,
    user=Depends(get_super_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.messages.models import Conversation, ConversationParticipant
    from app.users.models import User
    from app.common.enums import UserRole
    from uuid import uuid4 as _uuid

    result = await db.execute(
        select(Conversation).where(
            Conversation.conversation_type == "admin_group",
        )
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise NotFound("Admin group chat not found")

    target = await db.execute(select(User).where(User.id == body.user_id))
    target_user = target.scalar_one_or_none()
    if not target_user or target_user.role != UserRole.ADMIN.value:
        raise NotFound("User is not an admin")

    existing = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv.id,
            ConversationParticipant.user_id == body.user_id,
        )
    )
    if existing.scalar_one_or_none():
        raise NotFound("User is already a member")

    participant = ConversationParticipant(
        id=_uuid(), conversation_id=conv.id,
        user_id=body.user_id, unread_count=0,
    )
    db.add(participant)
    await db.commit()

    return SuccessResponse(message="Member added to group chat")


@router.delete("/group-chat/members/{user_id}", response_model=SuccessResponse)
async def remove_group_chat_member(
    user_id: UUID,
    user=Depends(get_super_admin),
    db: AsyncSession = Depends(get_db),
):
    from app.messages.models import Conversation, ConversationParticipant
    from datetime import datetime, timezone

    result = await db.execute(
        select(Conversation).where(
            Conversation.conversation_type == "admin_group",
        )
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise NotFound("Admin group chat not found")

    existing = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv.id,
            ConversationParticipant.user_id == user_id,
        )
    )
    participant = existing.scalar_one_or_none()
    if not participant:
        raise NotFound("User is not a member of this group chat")

    participant.left_at = datetime.now(timezone.utc)
    await db.commit()

    return SuccessResponse(message="Member removed from group chat")

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta, timezone
from uuid import UUID
from decimal import Decimal
from pydantic import BaseModel
from typing import Optional

from app.database import get_db
from app.dependencies import get_admin
from app.commission.service import CommissionService
from app.commission.models import CommissionRule
from app.common.response import SuccessResponse
from app.common.exceptions import NotFound, BadRequest

router = APIRouter(prefix="/admin/commission", tags=["Admin - Commission"])


class CommissionRuleCreate(BaseModel):
    name: str
    description: str = None
    role_type: str
    percentage: float
    min_amount: float = None
    max_amount: float = None
    applicable_from: str = None
    applicable_to: str = None

class CommissionRuleUpdate(BaseModel):
    name: str = None
    description: str = None
    percentage: float = None
    min_amount: float = None
    max_amount: float = None
    is_active: bool = None
    applicable_from: str = None
    applicable_to: str = None

@router.get("/revenue", response_model=SuccessResponse)
async def get_revenue_summary(days: int = 30, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = CommissionService(db)
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=days)
    summary = await service.get_revenue_summary(start, end)
    return SuccessResponse(data=summary)

@router.get("/logs", response_model=SuccessResponse)
async def get_commission_logs(page: int = 1, page_size: int = 20, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = CommissionService(db)
    logs = await service.list_commission_logs(page=page, page_size=page_size)
    return SuccessResponse(data=logs)

@router.get("/platform-deductions", response_model=SuccessResponse)
async def get_platform_deductions(page: int = 1, page_size: int = 20, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    from app.escrow.models import EscrowTransaction
    from app.admin.router import _get_all_settings
    from app.bookings.models import Booking
    from app.properties.models import Property
    from app.users.models import User, Profile, Tenant, Landlord
    from app.common.enums import EscrowStatus

    settings = await _get_all_settings(db)
    fee_pct = float(settings.get("platform_fee_percentage", 10))

    query = (
        select(EscrowTransaction)
        .where(EscrowTransaction.platform_fee > 0)
        .order_by(EscrowTransaction.created_at.desc())
    )
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    escrows = result.scalars().all()

    if not escrows:
        return SuccessResponse(data={
            "fee_percentage": fee_pct,
            "total": 0,
            "deductions": [],
            "summary": {"total_platform_fee": 0, "total_agent_commission": 0, "total_amount": 0, "count": 0},
        })

    booking_ids = list({e.booking_id for e in escrows})
    property_ids = list({e.property_id for e in escrows})
    tenant_ids = list({e.tenant_id for e in escrows})
    landlord_ids = list({e.landlord_id for e in escrows})

    bookings_map = {}
    if booking_ids:
        br = await db.execute(select(Booking).where(Booking.id.in_(booking_ids)))
        bookings_map = {b.id: b for b in br.scalars().all()}

    properties_map = {}
    if property_ids:
        pr = await db.execute(select(Property).where(Property.id.in_(property_ids)))
        properties_map = {p.id: p for p in pr.scalars().all()}

    users_map = {}
    profiles_map = {}
    all_user_ids = set()
    if tenant_ids:
        tr = await db.execute(select(Tenant).where(Tenant.id.in_(tenant_ids)))
        for t in tr.scalars().all():
            all_user_ids.add(t.user_id)
    if landlord_ids:
        lr = await db.execute(select(Landlord).where(Landlord.id.in_(landlord_ids)))
        for l in lr.scalars().all():
            all_user_ids.add(l.user_id)
    if all_user_ids:
        ur = await db.execute(select(User).where(User.id.in_(all_user_ids)))
        users_map = {u.id: u for u in ur.scalars().all()}
        pr2 = await db.execute(select(Profile).where(Profile.user_id.in_(all_user_ids)))
        profiles_map = {p.user_id: p for p in pr2.scalars().all()}

    def _name(uid):
        u = users_map.get(uid)
        p = profiles_map.get(uid)
        if p and p.first_name:
            return f"{p.first_name} {p.last_name}"
        return u.email.split("@")[0] if u else "Unknown"

    deductions = []
    for e in escrows:
        booking = bookings_map.get(e.booking_id)
        prop = properties_map.get(e.property_id)
        prop_name = prop.title if prop else "Unknown Property"

        tenant_user = None
        if e.tenant_id:
            tr2 = await db.execute(select(Tenant).where(Tenant.id == e.tenant_id))
            t_row = tr2.scalar_one_or_none()
            if t_row:
                tenant_user = users_map.get(t_row.user_id)

        landlord_name = _name(e.landlord_id) if e.landlord_id else "N/A"

        deductions.append({
            "id": str(e.id),
            "property_name": prop_name,
            "landlord_name": landlord_name,
            "booking_ref": str(booking.id)[:8] if booking else str(e.booking_id)[:8],
            "amount": float(e.amount),
            "platform_fee": float(e.platform_fee),
            "agent_commission": float(e.agent_commission),
            "status": str(e.status.value) if hasattr(e.status, 'value') else str(e.status),
            "date": e.created_at.isoformat() if e.created_at else None,
            "is_released": e.status in (EscrowStatus.COMPLETED, EscrowStatus.FUNDS_RELEASED) if hasattr(EscrowStatus, 'COMPLETED') else False,
        })

    total_platform_fee = sum(d["platform_fee"] for d in deductions)
    total_agent_commission = sum(d["agent_commission"] for d in deductions)
    total_amount = sum(d["amount"] for d in deductions)

    return SuccessResponse(data={
        "fee_percentage": fee_pct,
        "total": total,
        "deductions": deductions,
        "summary": {
            "total_platform_fee": total_platform_fee,
            "total_agent_commission": total_agent_commission,
            "total_amount": total_amount,
            "count": total,
        },
    })

@router.get("/agent/{agent_id}", response_model=SuccessResponse)
async def get_agent_commissions(agent_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = CommissionService(db)
    commissions = await service.get_agent_commissions(agent_id)
    return SuccessResponse(data=commissions)

@router.get("/rules", response_model=SuccessResponse)
async def list_commission_rules(user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CommissionRule).order_by(CommissionRule.created_at.desc()))
    rules = result.scalars().all()
    return SuccessResponse(data={"total": len(rules), "rules": [
        {
            "id": str(r.id), "name": r.name, "description": r.description,
            "role": r.role_type, "rate": float(r.percentage),
            "min_amount": float(r.min_amount) if r.min_amount else None,
            "max_amount": float(r.max_amount) if r.max_amount else None,
            "is_active": r.is_active,
            "created_at": str(r.created_at),
        }
        for r in rules
    ]})

@router.post("/rules", response_model=SuccessResponse)
async def create_commission_rule(body: CommissionRuleCreate, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    if body.role_type not in ("agent", "platform", "landlord"):
        raise BadRequest("role_type must be one of: agent, platform, landlord")
    if body.percentage <= 0 or body.percentage > 100:
        raise BadRequest("percentage must be between 0 and 100")

    existing = await db.execute(select(CommissionRule).where(CommissionRule.name == body.name))
    if existing.scalar_one_or_none():
        raise BadRequest(f"Rule '{body.name}' already exists")

    from datetime import date as date_type
    from uuid import uuid4

    rule = CommissionRule(
        id=uuid4(), name=body.name, description=body.description,
        role_type=body.role_type, percentage=Decimal(str(body.percentage)),
        min_amount=Decimal(str(body.min_amount)) if body.min_amount else None,
        max_amount=Decimal(str(body.max_amount)) if body.max_amount else None,
        is_active=True,
        applicable_from=date_type.fromisoformat(body.applicable_from) if body.applicable_from else None,
        applicable_to=date_type.fromisoformat(body.applicable_to) if body.applicable_to else None,
    )
    db.add(rule)
    await db.commit()
    await db.refresh(rule)
    return SuccessResponse(message="Commission rule created", data={
        "id": str(rule.id), "name": rule.name, "description": rule.description,
        "role": rule.role_type, "rate": float(rule.percentage), "is_active": rule.is_active,
    })

@router.put("/rules/{rule_id}", response_model=SuccessResponse)
async def update_commission_rule(rule_id: UUID, body: CommissionRuleUpdate, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CommissionRule).where(CommissionRule.id == rule_id))
    rule = result.scalar_one_or_none()
    if not rule:
        raise NotFound("Commission rule not found")

    from datetime import date as date_type
    update_data = body.model_dump(exclude_unset=True)
    if "applicable_from" in update_data and update_data["applicable_from"]:
        update_data["applicable_from"] = date_type.fromisoformat(update_data["applicable_from"])
    if "applicable_to" in update_data and update_data["applicable_to"]:
        update_data["applicable_to"] = date_type.fromisoformat(update_data["applicable_to"])
    if "percentage" in update_data:
        update_data["percentage"] = Decimal(str(update_data["percentage"]))
    if "min_amount" in update_data and update_data["min_amount"] is not None:
        update_data["min_amount"] = Decimal(str(update_data["min_amount"]))
    if "max_amount" in update_data and update_data["max_amount"] is not None:
        update_data["max_amount"] = Decimal(str(update_data["max_amount"]))

    for key, value in update_data.items():
        setattr(rule, key, value)

    await db.commit()
    await db.refresh(rule)
    return SuccessResponse(message="Commission rule updated", data={
        "id": str(rule.id), "name": rule.name, "description": rule.description,
        "role": rule.role_type, "rate": float(rule.percentage), "is_active": rule.is_active,
    })

@router.delete("/rules/{rule_id}", response_model=SuccessResponse)
async def delete_commission_rule(rule_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CommissionRule).where(CommissionRule.id == rule_id))
    rule = result.scalar_one_or_none()
    if not rule:
        raise NotFound("Commission rule not found")

    await db.delete(rule)
    await db.commit()
    return SuccessResponse(message="Commission rule deleted")

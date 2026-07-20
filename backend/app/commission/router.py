from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
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
    end = datetime.utcnow()
    start = end - timedelta(days=days)
    summary = await service.get_revenue_summary(start, end)
    return SuccessResponse(data=summary)

@router.get("/logs", response_model=SuccessResponse)
async def get_commission_logs(page: int = 1, page_size: int = 20, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = CommissionService(db)
    logs = await service.list_commission_logs(page=page, page_size=page_size)
    return SuccessResponse(data=logs)

@router.get("/agent/{agent_id}", response_model=SuccessResponse)
async def get_agent_commissions(agent_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = CommissionService(db)
    commissions = await service.get_agent_commissions(agent_id)
    return SuccessResponse(data=commissions)

@router.get("/rules", response_model=SuccessResponse)
async def list_commission_rules(user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CommissionRule).order_by(CommissionRule.created_at.desc()))
    rules = result.scalars().all()
    return SuccessResponse(data={"total": len(rules), "rules": rules})

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
    return SuccessResponse(message="Commission rule created", data=rule)

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
    return SuccessResponse(message="Commission rule updated", data=rule)

@router.delete("/rules/{rule_id}", response_model=SuccessResponse)
async def delete_commission_rule(rule_id: UUID, user=Depends(get_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CommissionRule).where(CommissionRule.id == rule_id))
    rule = result.scalar_one_or_none()
    if not rule:
        raise NotFound("Commission rule not found")

    await db.delete(rule)
    await db.commit()
    return SuccessResponse(message="Commission rule deleted")

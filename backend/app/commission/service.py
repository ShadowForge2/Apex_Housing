from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime

from app.commission.models import CommissionRule, CommissionLog, PlatformRevenue
from app.common.exceptions import NotFound

class CommissionService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def calculate_commission(self, booking_id: UUID, escrow_id: UUID, base_amount: float, agent_id: UUID = None, landlord_id: UUID = None) -> CommissionLog:
        rule_result = await self.db.execute(
            select(CommissionRule).where(CommissionRule.is_active == True)
        )
        rules = rule_result.scalars().all()

        agent_commission = 0
        platform_commission = 0
        for rule in rules:
            if rule.role_type == "agent" and agent_id:
                agent_commission = base_amount * (rule.percentage / 100)
            elif rule.role_type == "platform":
                platform_commission = base_amount * (rule.percentage / 100)

        log = CommissionLog(
            id=uuid4(),
            commission_rule_id=rules[0].id if rules else uuid4(),
            booking_id=booking_id, escrow_id=escrow_id,
            agent_id=agent_id, landlord_id=landlord_id,
            base_amount=base_amount,
            commission_rate=agent_commission / base_amount if base_amount > 0 else 0,
            commission_amount=agent_commission + platform_commission,
            platform_share=platform_commission,
            recipient_share=agent_commission,
            status="pending",
        )
        self.db.add(log)
        await self.db.commit()
        await self.db.refresh(log)
        return log

    async def get_revenue_summary(self, start_date, end_date) -> dict:
        result = await self.db.execute(
            select(PlatformRevenue).where(
                PlatformRevenue.period_start >= start_date,
                PlatformRevenue.period_end <= end_date,
            )
        )
        revenues = result.scalars().all()
        total_revenue = sum(r.total_revenue for r in revenues)
        total_commission = sum(r.total_commission for r in revenues)
        return {
            "total_revenue": total_revenue,
            "total_commission": total_commission,
            "periods": len(revenues),
        }

    async def list_commission_logs(self, page: int = 1, page_size: int = 20) -> dict:
        count_result = await self.db.execute(select(func.count()).select_from(CommissionLog))
        total = count_result.scalar()
        query = (
            select(CommissionLog)
            .order_by(CommissionLog.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        result = await self.db.execute(query)
        logs = result.scalars().all()
        return {"total": total, "logs": logs, "page": page, "page_size": page_size}

    async def get_agent_commissions(self, agent_id: UUID) -> list:
        result = await self.db.execute(
            select(CommissionLog).where(CommissionLog.agent_id == agent_id).order_by(CommissionLog.created_at.desc())
        )
        return result.scalars().all()

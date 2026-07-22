"""
APEX Housing — Fraud Detection Engine

Automated rules that scan for suspicious activity and create FraudAlert records.
Called by event handlers after key actions (booking, dispute, payment, etc.).
"""
import logging
from uuid import UUID, uuid4
from datetime import datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.admin.models import FraudAlert

logger = logging.getLogger(__name__)


class FraudDetectionService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def _create_alert(
        self, alert_type: str, severity: str, description: str,
        user_id: UUID = None, evidence: dict = None,
    ) -> FraudAlert | None:
        existing = await self.db.execute(
            select(FraudAlert).where(
                FraudAlert.alert_type == alert_type,
                FraudAlert.user_id == user_id,
                FraudAlert.status == "open",
            )
        )
        if existing.scalar_one_or_none():
            return None

        alert = FraudAlert(
            id=uuid4(), user_id=user_id,
            alert_type=alert_type, severity=severity,
            description=description, evidence_json=evidence or {},
            status="open",
        )
        self.db.add(alert)
        await self.db.commit()
        logger.warning(f"FRAUD ALERT [{severity}]: {alert_type} — {description}")
        return alert

    async def check_rapid_bookings(self, user_id: UUID) -> FraudAlert | None:
        from app.bookings.models import Booking
        from datetime import timezone as _tz
        cutoff = datetime.now(_tz.utc) - timedelta(hours=24)
        result = await self.db.execute(
            select(func.count()).select_from(Booking).where(
                Booking.tenant_id == user_id,
                Booking.created_at >= cutoff,
            )
        )
        count = result.scalar()
        if count >= 3:
            return await self._create_alert(
                alert_type="rapid_bookings",
                severity="medium",
                description=f"User created {count} bookings within 24 hours",
                user_id=user_id,
                evidence={"bookings_24h": count, "window": "24h"},
            )
        return None

    async def check_repeated_disputes(self, user_id: UUID) -> FraudAlert | None:
        from app.disputes.models import Dispute
        from datetime import timezone as _tz
        cutoff = datetime.now(_tz.utc) - timedelta(days=7)
        result = await self.db.execute(
            select(func.count()).select_from(Dispute).where(
                Dispute.reported_by == user_id,
                Dispute.created_at >= cutoff,
            )
        )
        count = result.scalar()
        if count >= 2:
            return await self._create_alert(
                alert_type="repeated_disputes",
                severity="high",
                description=f"User opened {count} disputes within 7 days",
                user_id=user_id,
                evidence={"disputes_7d": count, "window": "7d"},
            )
        return None

    async def check_rapid_withdrawals(self, user_id: UUID) -> FraudAlert | None:
        from app.payments.models import WalletWithdrawal, Wallet
        from datetime import timezone as _tz
        cutoff = datetime.now(_tz.utc) - timedelta(hours=24)
        wallet_result = await self.db.execute(
            select(Wallet.id).where(Wallet.user_id == user_id)
        )
        wallet_ids = [r[0] for r in wallet_result.fetchall()]
        if not wallet_ids:
            return None
        count_result = await self.db.execute(
            select(func.count()).select_from(WalletWithdrawal).where(
                WalletWithdrawal.wallet_id.in_(wallet_ids),
                WalletWithdrawal.status.in_(["pending", "processing", "completed"]),
                WalletWithdrawal.created_at >= cutoff,
            )
        )
        count = count_result.scalar()
        if count >= 3:
            return await self._create_alert(
                alert_type="rapid_withdrawals",
                severity="medium",
                description=f"User initiated {count} wallet withdrawals within 24 hours",
                user_id=user_id,
                evidence={"withdrawals_24h": count, "window": "24h"},
            )
        return None

    async def check_immediate_dispute(self, user_id: UUID, booking_id: UUID) -> FraudAlert | None:
        from app.escrow.models import EscrowTransaction
        from datetime import timezone as _tz
        escrow_result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.booking_id == booking_id)
        )
        escrow = escrow_result.scalar_one_or_none()
        if not escrow or not escrow.hold_started_at:
            return None
        now = datetime.now(_tz.utc)
        hold_started = escrow.hold_started_at
        if hold_started.tzinfo is None:
            hold_started = hold_started.replace(tzinfo=_tz.utc)
        elapsed = now - hold_started
        if elapsed < timedelta(hours=1):
            return await self._create_alert(
                alert_type="immediate_dispute",
                severity="high",
                description=f"Dispute opened within {int(elapsed.total_seconds() / 60)} minutes of escrow creation",
                user_id=user_id,
                evidence={
                    "booking_id": str(booking_id),
                    "escrow_id": str(escrow.id),
                    "minutes_elapsed": int(elapsed.total_seconds() / 60),
                },
            )
        return None

    async def check_payment_failures(self, user_id: UUID) -> FraudAlert | None:
        from app.payments.models import Transaction
        from datetime import timezone as _tz
        cutoff = datetime.now(_tz.utc) - timedelta(hours=24)
        result = await self.db.execute(
            select(func.count()).select_from(Transaction).where(
                Transaction.user_id == user_id,
                Transaction.status == "failed",
                Transaction.created_at >= cutoff,
            )
        )
        count = result.scalar()
        if count >= 3:
            return await self._create_alert(
                alert_type="payment_failure_spike",
                severity="medium",
                description=f"User had {count} failed payments within 24 hours",
                user_id=user_id,
                evidence={"failures_24h": count, "window": "24h"},
            )
        return None

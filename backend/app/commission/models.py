import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import Boolean, DateTime, Date, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelIdOnlyMixin
from app.database import Base


class CommissionRule(BaseModelIdOnlyMixin, Base):
    __tablename__ = "commission_rules"

    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    role_type: Mapped[str] = mapped_column(String(20), nullable=False)
    percentage: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    min_amount: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    max_amount: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    applicable_from: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    applicable_to: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )

    commission_logs: Mapped[list["CommissionLog"]] = relationship(
        "CommissionLog", back_populates="commission_rule"
    )


class CommissionLog(BaseModelIdOnlyMixin, Base):
    __tablename__ = "commission_logs"

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    commission_rule_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("commission_rules.id", ondelete="SET NULL"),
        nullable=True,
    )
    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
    )
    escrow_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("escrow_transactions.id", ondelete="CASCADE"),
        nullable=False,
    )
    agent_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("agents.id", ondelete="SET NULL"),
        nullable=True,
    )
    landlord_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("landlords.id", ondelete="SET NULL"),
        nullable=True,
    )
    base_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    commission_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    commission_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    platform_share: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    recipient_share: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), default="pending", nullable=False
    )
    gateway_reference: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True, index=True,
    )
    processed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    commission_rule: Mapped[Optional["CommissionRule"]] = relationship(
        "CommissionRule", back_populates="commission_logs"
    )
    booking: Mapped["Booking"] = relationship("Booking")
    escrow: Mapped["EscrowTransaction"] = relationship("EscrowTransaction")
    agent: Mapped[Optional["Agent"]] = relationship("Agent")
    landlord: Mapped[Optional["Landlord"]] = relationship("Landlord")


class PlatformRevenue(BaseModelIdOnlyMixin, Base):
    __tablename__ = "platform_revenue"

    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    total_bookings: Mapped[int] = mapped_column(default=0, nullable=False)
    total_revenue: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    total_commission: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    total_escrow_processed: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    total_refunds: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

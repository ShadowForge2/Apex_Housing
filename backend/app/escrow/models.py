import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelCreatedAtMixin, BaseModelMixin, BaseModelIdOnlyMixin
from app.common.enums import EscrowEvent, EscrowStatus
from app.database import Base


class EscrowTransaction(BaseModelCreatedAtMixin, Base):
    __tablename__ = "escrow_transactions"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
    )
    landlord_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("landlords.id", ondelete="CASCADE"),
        nullable=False,
    )
    agent_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("agents.id", ondelete="SET NULL"),
        nullable=True,
    )
    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[EscrowStatus] = mapped_column(
        String(30), default=EscrowStatus.PENDING_PAYMENT, nullable=False
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    security_deposit: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    service_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    agent_commission: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    platform_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    currency: Mapped[str] = mapped_column(String(10), default="NGN", nullable=False)
    payment_reference: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False
    )
    escrow_reference: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False
    )
    hold_started_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    hold_released_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    hold_expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    move_in_confirmed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    move_in_confirmed_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    dispute_opened_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    dispute_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("disputes.id", ondelete="SET NULL"),
        nullable=True,
    )
    resolution: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    resolution_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    resolution_notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    resolved_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    booking: Mapped["Booking"] = relationship("Booking", back_populates="escrow")
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="escrow_transactions")
    landlord: Mapped["Landlord"] = relationship("Landlord", back_populates="escrow_transactions")
    agent: Mapped[Optional["Agent"]] = relationship(
        "Agent", back_populates="escrow_transactions"
    )
    property: Mapped["Property"] = relationship("Property")
    move_in_confirmer: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[move_in_confirmed_by]
    )
    resolver: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[resolved_by]
    )
    dispute: Mapped[Optional["Dispute"]] = relationship(
        "Dispute", uselist=False,
        foreign_keys="EscrowTransaction.dispute_id",
        viewonly=True,
    )
    status_history: Mapped[list["EscrowStatusHistory"]] = relationship(
        "EscrowStatusHistory", back_populates="escrow"
    )
    transactions: Mapped[list["Transaction"]] = relationship(
        "Transaction", back_populates="escrow"
    )


class EscrowStatusHistory(BaseModelIdOnlyMixin, Base):
    __tablename__ = "escrow_status_history"

    escrow_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("escrow_transactions.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[EscrowStatus] = mapped_column(String(30), nullable=False)
    event_type: Mapped[EscrowEvent] = mapped_column(String(50), nullable=False)
    changed_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    escrow: Mapped["EscrowTransaction"] = relationship(
        "EscrowTransaction", back_populates="status_history"
    )
    changer: Mapped[Optional["User"]] = relationship("User")

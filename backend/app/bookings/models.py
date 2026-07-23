import uuid
from datetime import date, datetime, time
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    Time,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelCreatedAtMixin, BaseModelIdOnlyMixin
from app.common.enums import BookingStatus
from app.database import Base


class Booking(BaseModelCreatedAtMixin, Base):
    __tablename__ = "bookings"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    landlord_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    agent_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("agents.id", ondelete="SET NULL"),
        nullable=True,
    )
    status: Mapped[BookingStatus] = mapped_column(
        String(20), default=BookingStatus.PENDING, nullable=False
    )
    booking_reference: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False
    )
    viewing_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    viewing_time: Mapped[Optional[time]] = mapped_column(Time, nullable=True)
    viewing_notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    move_in_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    lease_start_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    total_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    security_deposit: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    service_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    cancellation_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Tenant terms agreement (snapshot of agent terms at booking time)
    tenant_terms_agreed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False,
        comment="Tenant explicitly agreed to agent terms + platform terms before booking")
    tenant_terms_agreed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="Timestamp when tenant agreed to terms"
    )
    terms_text_snapshot: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Snapshot of agent's terms and conditions at time of booking")
    tenant_signature_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Base64 encoded signature image drawn by tenant at booking time")

    property: Mapped["Property"] = relationship("Property", back_populates="bookings")
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="bookings")
    landlord: Mapped["Landlord"] = relationship("Landlord", back_populates="bookings")
    agent: Mapped[Optional["Agent"]] = relationship(
        "Agent", back_populates="bookings"
    )
    status_history: Mapped[list["BookingStatusHistory"]] = relationship(
        "BookingStatusHistory", back_populates="booking"
    )
    viewing_schedules: Mapped[list["ViewingSchedule"]] = relationship(
        "ViewingSchedule", back_populates="booking"
    )
    escrow: Mapped[Optional["EscrowTransaction"]] = relationship(
        "EscrowTransaction", back_populates="booking", uselist=False
    )


class BookingStatusHistory(BaseModelIdOnlyMixin, Base):
    __tablename__ = "booking_status_history"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[BookingStatus] = mapped_column(String(20), nullable=False)
    changed_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=False,
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    booking: Mapped["Booking"] = relationship(
        "Booking", back_populates="status_history"
    )
    changer: Mapped["User"] = relationship("User")


class ViewingSchedule(BaseModelIdOnlyMixin, Base):
    __tablename__ = "viewing_schedules"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
    )
    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
    )
    scheduled_date: Mapped[date] = mapped_column(Date, nullable=False)
    scheduled_time: Mapped[time] = mapped_column(Time, nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    booking: Mapped["Booking"] = relationship(
        "Booking", back_populates="viewing_schedules"
    )
    property: Mapped["Property"] = relationship("Property")
    tenant: Mapped["Tenant"] = relationship("Tenant")

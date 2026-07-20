import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, String, Text, JSON, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelCreatedAtMixin
from app.database import Base


class BookingReport(BaseModelCreatedAtMixin, Base):
    __tablename__ = "booking_reports"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="SET NULL"),
        nullable=True,
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    landlord_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    agent_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    report_number: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

    # --- AGENT (PARTY A) personal details snapshot ---
    agent_full_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    agent_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    agent_phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    agent_agency_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    agent_license_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # --- TENANT (PARTY B) personal details snapshot ---
    tenant_full_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    tenant_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    tenant_phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # --- LANDLORD (PARTY C) personal details snapshot ---
    landlord_full_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    landlord_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    landlord_phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # --- PROPERTY snapshot (captured before listing deletion) ---
    property_title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    property_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    property_address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    property_city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    property_state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    property_country: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    property_photos: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    property_description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    property_rent_amount: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # --- TERMS & CONDITIONS snapshot ---
    agent_terms_snapshot: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Agent's terms and conditions snapshot at booking time")
    tenant_terms_agreed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    tenant_terms_agreed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # --- BOOKING snapshot ---
    booking_reference: Mapped[str] = mapped_column(String(50), nullable=False)
    booking_status: Mapped[str] = mapped_column(String(20), nullable=False)
    move_in_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    lease_start_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    booking_created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # --- PAYMENT snapshot ---
    total_amount: Mapped[str] = mapped_column(String(20), nullable=False)
    security_deposit: Mapped[str] = mapped_column(String(20), nullable=False)
    service_fee: Mapped[str] = mapped_column(String(20), nullable=False)
    platform_fee: Mapped[str] = mapped_column(String(20), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="NGN", nullable=False)
    payment_reference: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    payment_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # --- DISBURSEMENT (when agent received funds) ---
    funds_released_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True,
        comment="Timestamp when escrow funds were released to agent/landlord wallet")

    # --- AGENT signature (drawn when listing property) ---
    agent_signature_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Base64 signature from agent's device at listing time")
    agent_signed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    agent_signed_ip: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # --- TENANT signature (drawn when booking) ---
    tenant_signature_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Base64 signature from tenant's device at booking time")
    tenant_signed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    tenant_signed_ip: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # --- LANDLORD signature (optional, for full endorsement) ---
    landlord_signature_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    landlord_signed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    landlord_signed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    landlord_signed_ip: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # --- Report status ---
    is_finalized: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False,
        comment="True when required parties have signed")
    is_downloaded: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    downloaded_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    download_count: Mapped[int] = mapped_column(default=0, nullable=False)

    # --- Full report data as JSON (for regeneration) ---
    report_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Relationships
    booking: Mapped["Booking"] = relationship("Booking", foreign_keys=[booking_id])

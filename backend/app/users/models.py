import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelMixin, BaseModelIdOnlyMixin, BaseModelCreatedAtMixin
from app.common.enums import UserRole
from app.database import Base


class User(BaseModelMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        String(20), nullable=False, default=UserRole.TENANT
    )
    is_super_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    signature_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    signature_created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    profile: Mapped[Optional["Profile"]] = relationship(
        "Profile", back_populates="user", uselist=False
    )
    landlord: Mapped[Optional["Landlord"]] = relationship(
        "Landlord", back_populates="user", uselist=False
    )
    tenant: Mapped[Optional["Tenant"]] = relationship(
        "Tenant", back_populates="user", uselist=False
    )
    sessions: Mapped[list["UserSession"]] = relationship(
        "UserSession", back_populates="user"
    )
    otp_codes: Mapped[list["OTPCode"]] = relationship(
        "OTPCode", back_populates="user"
    )
    verification_documents: Mapped[list["VerificationDocument"]] = relationship(
        "VerificationDocument", back_populates="user", foreign_keys="VerificationDocument.user_id"
    )
    notifications: Mapped[list["Notification"]] = relationship(
        "Notification", back_populates="user"
    )
    transactions: Mapped[list["Transaction"]] = relationship(
        "Transaction", back_populates="user"
    )
    invoices: Mapped[list["Invoice"]] = relationship(
        "Invoice", back_populates="user"
    )
    wallet: Mapped[Optional["Wallet"]] = relationship(
        "Wallet", back_populates="user", uselist=False
    )
    notification_preference: Mapped[Optional["NotificationPreference"]] = relationship(
        "NotificationPreference", back_populates="user", uselist=False
    )
    saved_searches: Mapped[list["SavedSearch"]] = relationship(
        "SavedSearch", back_populates="user"
    )
    user_activities: Mapped[list["UserActivity"]] = relationship(
        "UserActivity", back_populates="user"
    )
    admin_actions: Mapped[list["AdminAction"]] = relationship(
        "AdminAction", back_populates="admin", foreign_keys="AdminAction.admin_id"
    )
    bank_accounts: Mapped[list["BankAccount"]] = relationship(
        "BankAccount", back_populates="user"
    )
    signatures: Mapped[list["UserSignature"]] = relationship(
        "UserSignature", back_populates="user", order_by="UserSignature.created_at.desc()"
    )
    preference: Mapped[Optional["UserPreference"]] = relationship(
        "UserPreference", back_populates="user", uselist=False
    )


class UserSignature(BaseModelCreatedAtMixin, Base):
    __tablename__ = "user_signatures"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    signature_data: Mapped[str] = mapped_column(Text, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    label: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="signatures")


class Profile(BaseModelIdOnlyMixin, Base):
    __tablename__ = "profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    first_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    last_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    profile_picture: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    phone_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    date_of_birth: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="profile")


class Landlord(BaseModelIdOnlyMixin, Base):
    __tablename__ = "landlords"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    total_properties: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_earned: Mapped[float] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="landlord")
    properties: Mapped[list["Property"]] = relationship(
        "Property", back_populates="landlord"
    )
    bookings: Mapped[list["Booking"]] = relationship(
        "Booking", back_populates="landlord"
    )
    escrow_transactions: Mapped[list["EscrowTransaction"]] = relationship(
        "EscrowTransaction", back_populates="landlord"
    )


class Tenant(BaseModelIdOnlyMixin, Base):
    __tablename__ = "tenants"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    total_bookings: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_spent: Mapped[float] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="tenant")
    bookings: Mapped[list["Booking"]] = relationship(
        "Booking", back_populates="tenant"
    )
    escrow_transactions: Mapped[list["EscrowTransaction"]] = relationship(
        "EscrowTransaction", back_populates="tenant"
    )


class Agent(BaseModelIdOnlyMixin, Base):
    __tablename__ = "agents"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    agency_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    license_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    total_properties: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_commission: Mapped[float] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )

    user: Mapped["User"] = relationship("User")
    properties: Mapped[list["Property"]] = relationship(
        "Property", back_populates="agent"
    )
    bookings: Mapped[list["Booking"]] = relationship(
        "Booking", back_populates="agent"
    )
    escrow_transactions: Mapped[list["EscrowTransaction"]] = relationship(
        "EscrowTransaction", back_populates="agent"
    )


class VerificationDocument(BaseModelIdOnlyMixin, Base):
    __tablename__ = "verification_documents"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    document_type: Mapped[str] = mapped_column(String(50), nullable=False)
    document_url: Mapped[str] = mapped_column(String(512), nullable=False)
    document_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    expiry_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), default="pending", nullable=False
    )
    reviewed_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    rejection_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship(
        "User", back_populates="verification_documents", foreign_keys=[user_id]
    )
    reviewer: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[reviewed_by]
    )


class UserPreference(BaseModelIdOnlyMixin, Base):
    __tablename__ = "user_preferences"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    language: Mapped[str] = mapped_column(String(10), default="en", nullable=False)
    theme: Mapped[str] = mapped_column(String(20), default="light", nullable=False)
    text_scale: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="NGN", nullable=False)
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    biometric_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    push_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    email_notifications: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    quiet_hours_start: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    quiet_hours_end: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    last_screen: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    last_scroll_position: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    draft_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="preference")

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSON, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelIdOnlyMixin, BaseModelCreatedAtMixin
from app.common.enums import PaymentStatus, PaymentType
from app.database import Base


class Transaction(BaseModelIdOnlyMixin, Base):
    __tablename__ = "transactions"

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    escrow_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("escrow_transactions.id", ondelete="SET NULL"),
        nullable=True,
    )
    booking_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="SET NULL"),
        nullable=True,
    )
    payment_type: Mapped[PaymentType] = mapped_column(String(20), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="NGN", nullable=False)
    status: Mapped[PaymentStatus] = mapped_column(
        String(20), default=PaymentStatus.PENDING, nullable=False
    )
    payment_method: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    payment_gateway: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    gateway_reference: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    gateway_response: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    gateway_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False,
        comment="Payment gateway fee (e.g. Paystack) charged to customer",
    )
    amount_charged: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False,
        comment="Total amount charged to customer including gateway fee",
    )
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_refundable: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    refund_deadline: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped["User"] = relationship("User", back_populates="transactions")
    escrow: Mapped[Optional["EscrowTransaction"]] = relationship(
        "EscrowTransaction", back_populates="transactions"
    )
    booking: Mapped[Optional["Booking"]] = relationship("Booking")
    receipt: Mapped[Optional["Receipt"]] = relationship(
        "Receipt", back_populates="transaction", uselist=False
    )
    payment_logs: Mapped[list["PaymentLog"]] = relationship(
        "PaymentLog", back_populates="transaction"
    )


class Receipt(BaseModelIdOnlyMixin, Base):
    __tablename__ = "receipts"

    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("transactions.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    receipt_number: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False
    )
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )
    issued_to_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    issued_to_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    items_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    tax_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    total_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    pdf_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    transaction: Mapped["Transaction"] = relationship(
        "Transaction", back_populates="receipt"
    )


class Invoice(BaseModelIdOnlyMixin, Base):
    __tablename__ = "invoices"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    booking_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="SET NULL"),
        nullable=True,
    )
    invoice_number: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False
    )
    due_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    paid_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(20), default="draft", nullable=False
    )
    items_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    subtotal: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    tax_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    total_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="invoices")
    booking: Mapped[Optional["Booking"]] = relationship("Booking")


class Wallet(BaseModelIdOnlyMixin, Base):
    __tablename__ = "wallets"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    balance: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    pending_balance: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    currency: Mapped[str] = mapped_column(String(10), default="NGN", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    total_earned: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    total_withdrawn: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    version: Mapped[int] = mapped_column(default=1, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="wallet")
    withdrawals: Mapped[list["WalletWithdrawal"]] = relationship(
        "WalletWithdrawal", back_populates="wallet"
    )


class WalletWithdrawal(BaseModelIdOnlyMixin, Base):
    __tablename__ = "wallet_withdrawals"

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    wallet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("wallets.id", ondelete="CASCADE"),
        nullable=False,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default="pending", nullable=False
    )
    bank_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    account_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    account_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    bank_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    account_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    gateway_reference: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    scheduled_for: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="When the transfer should be attempted (next business day if not processed immediately)",
    )
    processed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="Auto-refund to wallet if not processed by this time",
    )

    wallet: Mapped["Wallet"] = relationship("Wallet", back_populates="withdrawals")


class BankAccount(BaseModelCreatedAtMixin, Base):
    __tablename__ = "bank_accounts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    bank_name: Mapped[str] = mapped_column(String(100), nullable=False)
    bank_code: Mapped[str] = mapped_column(String(20), nullable=False)
    account_number: Mapped[str] = mapped_column(String(20), nullable=False)
    account_name: Mapped[str] = mapped_column(String(255), nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    user: Mapped["User"] = relationship("User")


class Commission(BaseModelIdOnlyMixin, Base):
    __tablename__ = "commissions"

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
    commission_rate: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False
    )
    commission_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    platform_share: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    agent_share: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), default="pending", nullable=False
    )
    paid_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    agent: Mapped[Optional["Agent"]] = relationship("Agent")
    landlord: Mapped[Optional["Landlord"]] = relationship("Landlord")
    booking: Mapped["Booking"] = relationship("Booking")
    escrow: Mapped["EscrowTransaction"] = relationship("EscrowTransaction")


class PaymentLog(BaseModelIdOnlyMixin, Base):
    __tablename__ = "payment_logs"

    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("transactions.id", ondelete="CASCADE"),
        nullable=False,
    )
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    gateway_response: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    transaction: Mapped["Transaction"] = relationship(
        "Transaction", back_populates="payment_logs"
    )

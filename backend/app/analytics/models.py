import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelCreatedAtMixin
from app.database import Base


class DailyAnalytics(BaseModelCreatedAtMixin, Base):
    __tablename__ = "daily_analytics"

    date: Mapped[date] = mapped_column(Date, unique=True, index=True, nullable=False)
    total_users: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    new_users: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_properties: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    active_properties: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_bookings: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    new_bookings: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_revenue: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    new_revenue: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    total_escrow: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    escrow_released: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    escrow_refunded: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0.00, nullable=False
    )
    occupancy_rate: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), default=0.00, nullable=False
    )
    popular_areas: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    conversion_rate: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), default=0.00, nullable=False
    )
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )


class UserActivity(BaseModelCreatedAtMixin, Base):
    __tablename__ = "user_activities"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    resource_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    resource_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    user: Mapped["User"] = relationship("User")


class SearchAnalytics(BaseModelCreatedAtMixin, Base):
    __tablename__ = "search_analytics"

    search_query: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    filters_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    results_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )

    user: Mapped[Optional["User"]] = relationship("User")

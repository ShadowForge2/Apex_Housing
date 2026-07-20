import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.common.base_model import BaseModelMixin, BaseModelIdOnlyMixin
from app.common.enums import PropertyStatus
from app.database import Base


class Property(BaseModelMixin, Base):
    __tablename__ = "properties"

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
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    slug: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    property_type: Mapped[str] = mapped_column(String(50), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default=PropertyStatus.DRAFT.value, nullable=False
    )
    agent_tags: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    agent_terms: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Agent's terms and conditions for this property listing")
    agent_signed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True,
        comment="Timestamp when agent signed the listing terms")
    agent_signature_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
        comment="Base64 encoded signature image from agent's device")

    landlord: Mapped["Landlord"] = relationship("Landlord", back_populates="properties")
    agent: Mapped[Optional["Agent"]] = relationship("Agent", back_populates="properties")
    images: Mapped[list["PropertyImage"]] = relationship(
        "PropertyImage", back_populates="property"
    )
    videos: Mapped[list["PropertyVideo"]] = relationship(
        "PropertyVideo", back_populates="property"
    )
    location: Mapped[Optional["PropertyLocation"]] = relationship(
        "PropertyLocation", back_populates="property", uselist=False
    )
    features: Mapped[list["PropertyFeature"]] = relationship(
        "PropertyFeature", back_populates="property"
    )
    pricing: Mapped[Optional["PropertyPricing"]] = relationship(
        "PropertyPricing", back_populates="property", uselist=False
    )
    availability: Mapped[Optional["PropertyAvailability"]] = relationship(
        "PropertyAvailability", back_populates="property"
    )
    bookings: Mapped[list["Booking"]] = relationship(
        "Booking", back_populates="property"
    )
    amenities: Mapped[list["Amenity"]] = relationship(
        "Amenity", secondary="property_amenities", back_populates="properties"
    )


class Amenity(BaseModelIdOnlyMixin, Base):
    __tablename__ = "amenities"

    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    icon: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    category: Mapped[str] = mapped_column(String(50), default="basic", nullable=False)

    properties: Mapped[list["Property"]] = relationship(
        "Property", secondary="property_amenities", back_populates="amenities"
    )


class PropertyAmenity(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_amenities"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    amenity_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("amenities.id", ondelete="CASCADE"),
        nullable=False,
    )


class PropertyImage(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_images"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    url: Mapped[str] = mapped_column(String(512), nullable=False)
    label: Mapped[str] = mapped_column(String(50), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    property: Mapped["Property"] = relationship("Property", back_populates="images")


class PropertyVideo(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_videos"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    url: Mapped[str] = mapped_column(String(512), nullable=False)
    label: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    property: Mapped["Property"] = relationship("Property", back_populates="videos")


class PropertyLocation(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_locations"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    address: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    zip_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    neighborhood: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    property: Mapped["Property"] = relationship("Property", back_populates="location")


class PropertyFeature(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_features"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
    )
    feature_name: Mapped[str] = mapped_column(String(255), nullable=False)
    feature_value: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    property: Mapped["Property"] = relationship("Property", back_populates="features")


class PropertyPricing(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_pricing"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    rent_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    security_deposit: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    service_fee: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0.00, nullable=False
    )
    currency: Mapped[str] = mapped_column(String(10), default="NGN", nullable=False)

    property: Mapped["Property"] = relationship("Property", back_populates="pricing")


class PropertyAvailability(BaseModelIdOnlyMixin, Base):
    __tablename__ = "property_availability"

    property_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("properties.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    available_from: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    available_until: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    plan_type: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    is_booked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False,
        comment="True when property has an active booking - prevents edit/delete")
    minimum_stay_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    maximum_stay_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    property: Mapped["Property"] = relationship(
        "Property", back_populates="availability"
    )

from datetime import datetime, timezone
from uuid import UUID, uuid4
from slugify import slugify
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from typing import Optional, List

from app.properties.models import (
    Property, PropertyImage, PropertyVideo, PropertyLocation, PropertyFeature,
    PropertyPricing, PropertyAvailability, Amenity, PropertyAmenity,
)
from app.properties.schemas import PropertyCreate, PropertyUpdate
from app.properties.config import get_labels_for_property_type
from app.users.models import Landlord, User, UserSignature
from app.common.enums import PropertyStatus, PlanType
from app.common.exceptions import NotFound, Forbidden, BadRequest
from app.events.bus import event_bus
from app.events.types import PropertyCreatedEvent, PropertyStatusChangedEvent
from app.services.maps import geocoding_service
from app.services.storage import supabase_storage


class PropertyService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_property(self, landlord_id: UUID, data: PropertyCreate) -> Property:
        slug = slugify(data.title) + "-" + str(uuid4())[:8]

        if data.images:
            valid_labels = get_labels_for_property_type(data.property_type)
            image_labels = [img.label for img in data.images]
            missing_front = "front" not in image_labels
            invalid_labels = [l for l in image_labels if l not in valid_labels]

            if missing_front:
                raise BadRequest("At least one image must be labeled 'front' for market display")
            if invalid_labels:
                raise BadRequest(f"Invalid labels for {data.property_type}: {', '.join(invalid_labels)}. Valid labels: {', '.join(valid_labels)}")
        if not data.agent_terms or len(data.agent_terms.strip()) < 20:
            raise BadRequest("Agent must provide terms and conditions (minimum 20 characters)")

        from sqlalchemy import select as sa_select
        user_result = await self.db.execute(sa_select(User).where(User.id == landlord_id))
        user_obj = user_result.scalar_one_or_none()

        effective_signature = data.agent_signature_data
        if effective_signature and effective_signature.startswith("data:"):
            effective_signature = effective_signature.split(",", 1)[1]
        if not effective_signature:
            if user_obj and user_obj.signature_data:
                effective_signature = user_obj.signature_data
            else:
                raise BadRequest("Agent must sign the listing terms. No stored signature found.")
        elif len(effective_signature) < 50:
            raise BadRequest("Invalid signature. Must be at least 50 characters.")

        now = datetime.now(timezone.utc)
        property_obj = Property(
            id=uuid4(),
            landlord_id=landlord_id,
            property_type=data.property_type,
            title=data.title,
            slug=slug,
            description=data.description,
            agent_id=data.agent_id,
            agent_tags=data.agent_tags,
            agent_terms=data.agent_terms,
            agent_signature_data=effective_signature,
            agent_signed_at=data.agent_signed_at or now,
            status=PropertyStatus.DRAFT.value,
        )
        self.db.add(property_obj)
        await self.db.flush()

        if data.agent_signature_data and (not user_obj or not user_obj.signature_data):
            sig_record = UserSignature(
                id=uuid4(), user_id=landlord_id,
                signature_data=effective_signature, is_active=True, label="listing",
            )
            self.db.add(sig_record)
            user_obj.signature_data = effective_signature
            user_obj.signature_created_at = now

        location_data = data.location.model_dump()

        location = PropertyLocation(
            id=uuid4(), property_id=property_obj.id,
            **location_data
        )
        self.db.add(location)

        pricing = PropertyPricing(
            id=uuid4(), property_id=property_obj.id,
            **data.pricing.model_dump()
        )
        self.db.add(pricing)

        availability = PropertyAvailability(
            id=uuid4(), property_id=property_obj.id,
            is_available=True,
            available_from=data.available_from,
            available_until=data.available_until,
            plan_type=data.plan_type.upper() if data.plan_type else None,
            minimum_stay_days=data.minimum_stay_days,
            maximum_stay_days=data.maximum_stay_days,
        )
        self.db.add(availability)

        for idx, img in enumerate(data.images):
            is_front = img.label == "front"
            image = PropertyImage(
                id=uuid4(), property_id=property_obj.id,
                url=img.url, label=img.label,
                is_primary=is_front,
                sort_order=img.sort_order if img.sort_order else (0 if is_front else idx + 1),
            )
            self.db.add(image)

        if data.video_url:
            video = PropertyVideo(
                id=uuid4(), property_id=property_obj.id,
                url=data.video_url, label="main",
            )
            self.db.add(video)

        if data.images and data.video_url:
            property_obj.status = PropertyStatus.ACTIVE.value

        for feat in data.features:
            feature = PropertyFeature(
                id=uuid4(), property_id=property_obj.id,
                feature_name=feat.feature_name, feature_value=feat.feature_value,
            )
            self.db.add(feature)

        if data.amenity_ids:
            amenities_result = await self.db.execute(
                select(Amenity).where(Amenity.id.in_(data.amenity_ids))
            )
            amenities = amenities_result.scalars().all()
            property_obj.amenities = list(amenities)

        await self.db.commit()

        await event_bus.emit("property.created", PropertyCreatedEvent(
            property_id=property_obj.id, landlord_id=landlord_id, title=data.title
        ))

        return property_obj

    async def get_property(self, property_id: UUID) -> Property:
        result = await self.db.execute(
            select(Property)
            .options(
                selectinload(Property.images),
                selectinload(Property.videos),
                selectinload(Property.location),
                selectinload(Property.pricing),
                selectinload(Property.availability),
                selectinload(Property.features),
                selectinload(Property.amenities),
            )
            .where(Property.id == property_id)
        )
        prop = result.scalar_one_or_none()
        if not prop:
            raise NotFound("Property not found")
        return prop

    async def get_property_by_slug(self, slug: str) -> Property:
        result = await self.db.execute(
            select(Property)
            .options(
                selectinload(Property.images),
                selectinload(Property.videos),
                selectinload(Property.location),
                selectinload(Property.pricing),
                selectinload(Property.availability),
                selectinload(Property.features),
                selectinload(Property.amenities),
            )
            .where(Property.slug == slug)
        )
        prop = result.scalar_one_or_none()
        if not prop:
            raise NotFound("Property not found")
        return prop

    async def update_property(self, property_id: UUID, user_id: UUID, data: PropertyUpdate, is_admin: bool = False) -> Property:
        result = await self.db.execute(
            select(Property).where(Property.id == property_id)
        )
        prop = result.scalar_one_or_none()
        if not prop:
            raise NotFound("Property not found")
        if not is_admin and prop.landlord_id != user_id:
            raise Forbidden("You can only update your own properties")

        avail_result = await self.db.execute(
            select(PropertyAvailability).where(PropertyAvailability.property_id == property_id)
        )
        availability = avail_result.scalar_one_or_none()
        if availability and availability.is_booked:
            raise BadRequest("Cannot edit listing during an active booking")

        old_status = prop.status
        update_data = data.model_dump(exclude_unset=True)

        location_data = update_data.pop("location", None)
        pricing_data = update_data.pop("pricing", None)

        if "status" in update_data and update_data["status"] != old_status:
            new_status = update_data["status"]
            new_status_val = new_status.value if hasattr(new_status, "value") else new_status
            old_status_val = old_status.value if hasattr(old_status, "value") else old_status
            await event_bus.emit("property.status_changed", PropertyStatusChangedEvent(
                property_id=property_id, old_status=old_status_val,
                new_status=new_status_val,
                triggered_by=user_id,
            ))

        for key, value in update_data.items():
            setattr(prop, key, value)

        if location_data:
            loc_result = await self.db.execute(
                select(PropertyLocation).where(PropertyLocation.property_id == property_id)
            )
            location = loc_result.scalar_one_or_none()
            if location:
                for key, value in location_data.items():
                    setattr(location, key, value)

        if pricing_data:
            price_result = await self.db.execute(
                select(PropertyPricing).where(PropertyPricing.property_id == property_id)
            )
            pricing = price_result.scalar_one_or_none()
            if pricing:
                for key, value in pricing_data.items():
                    setattr(pricing, key, value)

        await self.db.commit()
        await self.db.refresh(prop)
        return prop

    async def list_properties(
        self, page: int = 1, page_size: int = 20, status: str = None,
        landlord_id: UUID = None, city: str = None, property_type: str = None,
        min_price: float = None, max_price: float = None,
    ) -> dict:
        query = (
            select(Property)
            .options(
                selectinload(Property.images),
                selectinload(Property.location),
                selectinload(Property.pricing),
                selectinload(Property.availability),
                selectinload(Property.features),
                selectinload(Property.amenities),
            )
        )

        if status:
            query = query.where(Property.status == status)
        if landlord_id:
            query = query.where(Property.landlord_id == landlord_id)
        if property_type:
            query = query.where(Property.property_type == property_type)
        if city:
            query = query.join(PropertyLocation, Property.id == PropertyLocation.property_id, isouter=True).where(
                PropertyLocation.city.ilike(f"%{city}%")
            )
        if min_price is not None or max_price is not None:
            query = query.join(PropertyPricing, Property.id == PropertyPricing.property_id, isouter=True)
            if min_price is not None:
                query = query.where(PropertyPricing.rent_amount >= min_price)
            if max_price is not None:
                query = query.where(PropertyPricing.rent_amount <= max_price)

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()

        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Property.created_at.desc())
        result = await self.db.execute(query)
        properties = result.scalars().unique().all()

        return {"total": total, "properties": properties, "page": page, "page_size": page_size}

    async def delete_property(self, property_id: UUID, user_id: UUID, is_admin: bool = False) -> None:
        result = await self.db.execute(select(Property).where(Property.id == property_id))
        prop = result.scalar_one_or_none()
        if not prop:
            raise NotFound("Property not found")
        if not is_admin and prop.landlord_id != user_id:
            raise Forbidden("You can only delete your own properties")

        avail_result = await self.db.execute(
            select(PropertyAvailability).where(PropertyAvailability.property_id == property_id)
        )
        availability = avail_result.scalar_one_or_none()
        if availability and availability.is_booked:
            raise BadRequest("Cannot delete listing during an active booking")

        await self.db.delete(prop)
        await self.db.commit()

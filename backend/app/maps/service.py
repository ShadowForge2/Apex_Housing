from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
import math

from app.maps.models import MapPin
from app.maps.schemas import MapPinCreate, RadiusSearchRequest
from app.common.enums import PropertyStatus

class MapService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_pin(self, user_id: UUID, data: MapPinCreate) -> MapPin:
        pin = MapPin(
            id=uuid4(), property_id=data.property_id,
            user_id=user_id, pin_type=data.pin_type,
            latitude=data.latitude, longitude=data.longitude,
            label=data.label, metadata_json=data.metadata_json,
            is_active=True,
        )
        self.db.add(pin)
        await self.db.commit()
        await self.db.refresh(pin)
        return pin

    async def radius_search(self, params: RadiusSearchRequest) -> list:
        from app.properties.models import Property, PropertyLocation
        lat = params.latitude
        lng = params.longitude
        radius = params.radius_km

        # Calculate bounding box to pre-filter (much faster than loading all)
        # Approximate degrees per km at equator
        lat_delta = radius / 111.0
        lng_delta = radius / (111.0 * math.cos(math.radians(lat)))

        min_lat = lat - lat_delta
        max_lat = lat + lat_delta
        min_lng = lng - lng_delta
        max_lng = lng + lng_delta

        query = (
            select(Property, PropertyLocation)
            .join(PropertyLocation, Property.id == PropertyLocation.property_id)
            .where(Property.status == PropertyStatus.ACTIVE)
            .where(PropertyLocation.latitude.between(min_lat, max_lat))
            .where(PropertyLocation.longitude.between(min_lng, max_lng))
        )

        if params.property_type:
            query = query.where(Property.property_type == params.property_type)

        result = await self.db.execute(query)
        candidates = result.all()

        # Now do precise haversine only on candidates within bounding box
        nearby = []
        for prop, loc in candidates:
            distance = self._haversine(lat, lng, float(loc.latitude), float(loc.longitude))
            if distance <= radius:
                nearby.append({
                    "property": prop,
                    "location": loc,
                    "distance_km": round(distance, 2),
                })

        nearby.sort(key=lambda x: x["distance_km"])
        return nearby

    async def get_pins(self, bounds: dict = None) -> list:
        query = select(MapPin).where(MapPin.is_active == True)

        # Filter by map viewport bounds if provided
        if bounds:
            min_lat = bounds.get("min_lat")
            max_lat = bounds.get("max_lat")
            min_lng = bounds.get("min_lng")
            max_lng = bounds.get("max_lng")
            if all(v is not None for v in [min_lat, max_lat, min_lng, max_lng]):
                query = query.where(MapPin.latitude.between(min_lat, max_lat))
                query = query.where(MapPin.longitude.between(min_lng, max_lng))

        result = await self.db.execute(query)
        return result.scalars().all()

    async def verify_location(self, latitude: float, longitude: float, expected_address: str) -> dict:
        from app.services.maps import geocoding_service

        # Reverse geocode the coordinates to get actual address
        reverse_result = await geocoding_service.reverse_geocode(latitude, longitude)

        if not reverse_result.get("address"):
            return {
                "verified": False,
                "latitude": latitude,
                "longitude": longitude,
                "address": None,
                "expected_address": expected_address,
                "confidence": 0.0,
                "reason": "Could not verify coordinates",
            }

        # Check if coordinates are in Nigeria
        in_nigeria = geocoding_service.validate_nigeria_bounds(latitude, longitude)

        # Compare addresses (simple string similarity)
        actual_address = reverse_result["address"].lower()
        expected_lower = expected_address.lower()

        # Check if key parts match (city, state, street name)
        actual_parts = set(actual_address.replace(",", " ").split())
        expected_parts = set(expected_lower.replace(",", " ").split())
        common_parts = actual_parts.intersection(expected_parts)
        confidence = len(common_parts) / max(len(expected_parts), 1)

        verified = in_nigeria and confidence >= 0.3

        return {
            "verified": verified,
            "latitude": latitude,
            "longitude": longitude,
            "address": reverse_result["address"],
            "city": reverse_result.get("city"),
            "state": reverse_result.get("state"),
            "expected_address": expected_address,
            "confidence": round(confidence, 2),
            "in_nigeria": in_nigeria,
        }

    def _haversine(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        R = 6371
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        return R * c

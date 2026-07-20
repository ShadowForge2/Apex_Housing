import math
from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, case, text
from typing import Optional

from app.search.models import SavedSearch, SearchSuggestion
from app.search.schemas import SearchFilters, SearchResponse, PropertySearchResult, PRICE_RANGES
from app.properties.models import (
    Property, PropertyLocation, PropertyPricing, PropertyAvailability,
    PropertyImage, PropertyFeature, Amenity, PropertyAmenity,
)
from app.common.enums import PropertyStatus


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lon / 2) ** 2)
    c = 2 * math.asin(math.sqrt(a))
    return R * c


class SearchService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def search_properties(self, filters: SearchFilters, user_id: UUID = None) -> SearchResponse:
        has_location = filters.latitude is not None and filters.longitude is not None

        query = (
            select(Property, PropertyLocation, PropertyPricing, PropertyAvailability)
            .join(PropertyLocation, Property.id == PropertyLocation.property_id, isouter=True)
            .join(PropertyPricing, Property.id == PropertyPricing.property_id, isouter=True)
            .join(PropertyAvailability, Property.id == PropertyAvailability.property_id, isouter=True)
            .where(Property.status == PropertyStatus.ACTIVE.value)
            .where(
                or_(
                    PropertyAvailability.is_booked == False,
                    PropertyAvailability.is_booked.is_(None),
                )
            )
        )

        filters_applied = {}

        if filters.q:
            search_term = f"%{filters.q}%"
            query = query.where(
                or_(
                    Property.title.ilike(search_term),
                    Property.description.ilike(search_term),
                    Property.agent_tags.ilike(search_term),
                    Property.id.in_(
                        select(PropertyFeature.property_id).where(
                            or_(
                                PropertyFeature.feature_name.ilike(search_term),
                                PropertyFeature.feature_value.ilike(search_term),
                            )
                        )
                    ),
                )
            )
            filters_applied["search"] = filters.q

        if filters.state:
            query = query.where(PropertyLocation.state.ilike(f"%{filters.state}%"))
            filters_applied["state"] = filters.state

        if filters.city:
            query = query.where(PropertyLocation.city.ilike(f"%{filters.city}%"))
            filters_applied["city"] = filters.city

        if filters.area:
            query = query.where(PropertyLocation.neighborhood.ilike(f"%{filters.area}%"))
            filters_applied["area"] = filters.area

        if filters.price_range and filters.price_range in PRICE_RANGES:
            pr = PRICE_RANGES[filters.price_range]
            if pr["min"] is not None:
                query = query.where(PropertyPricing.rent_amount >= pr["min"])
            if pr["max"] is not None:
                query = query.where(PropertyPricing.rent_amount <= pr["max"])
            filters_applied["price_range"] = filters.price_range
        else:
            if filters.min_price is not None:
                query = query.where(PropertyPricing.rent_amount >= filters.min_price)
                filters_applied["min_price"] = filters.min_price
            if filters.max_price is not None:
                query = query.where(PropertyPricing.rent_amount <= filters.max_price)
                filters_applied["max_price"] = filters.max_price

        if filters.property_type:
            query = query.where(Property.property_type == filters.property_type)
            filters_applied["property_type"] = filters.property_type

        if filters.agent_tags:
            query = query.where(Property.agent_tags.ilike(f"%{filters.agent_tags}%"))
            filters_applied["tags"] = filters.agent_tags

        if filters.amenity_ids:
            for amenity_id in filters.amenity_ids:
                query = query.where(
                    Property.id.in_(
                        select(PropertyAmenity.property_id).where(
                            PropertyAmenity.amenity_id == amenity_id
                        )
                    )
                )
            filters_applied["amenities"] = [str(a) for a in filters.amenity_ids]

        if has_location:
            radius_km = getattr(filters, 'radius_km', None) or 50.0
            lat_delta = radius_km / 111.0
            lng_delta = radius_km / (111.0 * math.cos(math.radians(filters.latitude)))
            query = query.where(
                PropertyLocation.latitude.between(
                    filters.latitude - lat_delta,
                    filters.latitude + lat_delta,
                )
            ).where(
                PropertyLocation.longitude.between(
                    filters.longitude - lng_delta,
                    filters.longitude + lng_delta,
                )
            )
            filters_applied["latitude"] = filters.latitude
            filters_applied["longitude"] = filters.longitude
            filters_applied["radius_km"] = radius_km

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()

        fallback_used = False
        fallback_message = None

        if total == 0 and (filters.q or filters.price_range or filters.area):
            query = await self._build_relaxed_query(filters)
            count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
            total = count_result.scalar()
            fallback_used = True
            fallback_message = "No exact matches found. Showing similar properties instead."

        if has_location and filters.sort_by == "distance":
            pass
        elif filters.sort_by == "price_low":
            query = query.order_by(PropertyPricing.rent_amount.asc())
        elif filters.sort_by == "price_high":
            query = query.order_by(PropertyPricing.rent_amount.desc())
        elif filters.sort_by == "newest":
            query = query.order_by(Property.created_at.desc())
        else:
            query = query.order_by(Property.created_at.desc())

        query = query.offset((filters.page - 1) * filters.page_size).limit(filters.page_size)
        result = await self.db.execute(query)
        rows = result.all()

        property_ids = [row[0].id for row in rows]
        images_map = {}
        if property_ids:
            img_result = await self.db.execute(
                select(PropertyImage.property_id, PropertyImage.url).where(
                    PropertyImage.property_id.in_(property_ids),
                    PropertyImage.label == "front",
                )
            )
            for pid, url in img_result.all():
                images_map[pid] = url

        properties = []
        for row in rows:
            prop, location, pricing, availability = row

            front_image = images_map.get(prop.id)

            distance = None
            if has_location and location and location.latitude and location.longitude:
                distance = haversine_distance(
                    filters.latitude, filters.longitude,
                    float(location.latitude), float(location.longitude),
                )
                distance = round(distance, 2)

            properties.append(PropertySearchResult(
                id=prop.id,
                title=prop.title,
                slug=prop.slug,
                description=prop.description or "",
                property_type=prop.property_type,
                agent_tags=prop.agent_tags,
                front_image=front_image,
                rent_amount=float(pricing.rent_amount) if pricing else None,
                security_deposit=float(pricing.security_deposit) if pricing else None,
                currency=pricing.currency if pricing else "NGN",
                city=location.city if location else None,
                state=location.state if location else None,
                neighborhood=location.neighborhood if location else None,
                latitude=location.latitude if location else None,
                longitude=location.longitude if location else None,
                distance_km=distance,
                is_available=availability.is_available if availability else True,
                created_at=prop.created_at,
            ))

        if has_location and filters.sort_by == "distance":
            properties.sort(key=lambda p: p.distance_km if p.distance_km is not None else float('inf'))

        if user_id and filters.q:
            await self.record_search(filters.q, user_id)

        return SearchResponse(
            total=total,
            properties=properties,
            page=filters.page,
            page_size=filters.page_size,
            filters_applied=filters_applied,
            fallback_used=fallback_used,
            fallback_message=fallback_message,
        )

    async def _build_relaxed_query(self, filters: SearchFilters):
        query = (
            select(Property, PropertyLocation, PropertyPricing, PropertyAvailability)
            .join(PropertyLocation, Property.id == PropertyLocation.property_id, isouter=True)
            .join(PropertyPricing, Property.id == PropertyPricing.property_id, isouter=True)
            .join(PropertyAvailability, Property.id == PropertyAvailability.property_id, isouter=True)
            .where(Property.status == PropertyStatus.ACTIVE.value)
            .where(
                or_(
                    PropertyAvailability.is_booked == False,
                    PropertyAvailability.is_booked.is_(None),
                )
            )
        )

        if filters.state:
            query = query.where(PropertyLocation.state.ilike(f"%{filters.state}%"))

        if filters.city:
            query = query.where(PropertyLocation.city.ilike(f"%{filters.city}%"))

        if filters.price_range and filters.price_range in PRICE_RANGES:
            pr = PRICE_RANGES[filters.price_range]
            if pr["min"] is not None:
                query = query.where(PropertyPricing.rent_amount >= pr["min"] * 0.7)
            if pr["max"] is not None:
                query = query.where(PropertyPricing.rent_amount <= pr["max"] * 1.3)
        elif filters.min_price is not None or filters.max_price is not None:
            min_p = (filters.min_price or 0) * 0.7
            max_p = (filters.max_price or 999999999) * 1.3
            query = query.where(PropertyPricing.rent_amount.between(min_p, max_p))

        if filters.area:
            location_state = select(PropertyLocation.state).where(
                PropertyLocation.neighborhood.ilike(f"%{filters.area}%")
            ).limit(1)
            state_result = await self.db.execute(location_state)
            area_state = state_result.scalar_one_or_none()
            if area_state:
                query = query.where(PropertyLocation.state.ilike(f"%{area_state}%"))

        query = query.order_by(Property.created_at.desc())
        return query

    async def get_location_hierarchy(self) -> dict:
        result = await self.db.execute(
            select(PropertyLocation.state, PropertyLocation.city, PropertyLocation.neighborhood)
            .where(PropertyLocation.state.isnot(None))
        )
        rows = result.all()

        states = set()
        cities_by_state = {}
        areas_by_city = {}

        for state, city, neighborhood in rows:
            if state:
                states.add(state)
                if state not in cities_by_state:
                    cities_by_state[state] = set()
                if city:
                    cities_by_state[state].add(city)
                    city_key = f"{state}|{city}"
                    if city_key not in areas_by_city:
                        areas_by_city[city_key] = set()
                    if neighborhood:
                        areas_by_city[city_key].add(neighborhood)

        return {
            "states": sorted(states),
            "cities_by_state": {k: sorted(v) for k, v in cities_by_state.items()},
            "areas_by_city": {k: sorted(v) for k, v in areas_by_city.items()},
        }

    async def save_search(self, user_id: UUID, data) -> SavedSearch:
        saved = SavedSearch(
            id=uuid4(), user_id=user_id,
            name=data.name,
            filters_json=data.filters_json,
            notify_new_matches=data.notify_new_matches if hasattr(data, 'notify_new_matches') else False,
        )
        self.db.add(saved)
        await self.db.commit()
        await self.db.refresh(saved)
        return saved

    async def get_saved_searches(self, user_id: UUID) -> list:
        result = await self.db.execute(
            select(SavedSearch).where(SavedSearch.user_id == user_id)
        )
        return result.scalars().all()

    async def get_popular_searches(self, limit: int = 10) -> list:
        result = await self.db.execute(
            select(SearchSuggestion).order_by(SearchSuggestion.result_count.desc()).limit(limit)
        )
        return result.scalars().all()

    async def record_search(self, query: str, user_id: UUID = None) -> None:
        result = await self.db.execute(
            select(SearchSuggestion).where(SearchSuggestion.query_text == query)
        )
        suggestion = result.scalar_one_or_none()
        if suggestion:
            suggestion.result_count += 1
        else:
            suggestion = SearchSuggestion(
                id=uuid4(), query_text=query, result_count=1,
            )
            self.db.add(suggestion)
        await self.db.commit()

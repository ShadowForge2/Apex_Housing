"""
Google Maps Geocoding + Places service.
Handles reverse/forward geocoding and nearby places search.
"""
import logging
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

GOOGLE_MAPS_BASE = "https://maps.googleapis.com/maps/api"

# Nigeria bounding box
NIGERIA_BOUNDS = {
    "lat_min": 4.0,
    "lat_max": 14.0,
    "lng_min": 2.5,
    "lng_max": 14.7,
}


class GeocodingService:
    def __init__(self):
        self.api_key = settings.GOOGLE_MAPS_API_KEY

    async def _get(self, endpoint: str, params: dict) -> dict:
        params["key"] = self.api_key
        url = f"{GOOGLE_MAPS_BASE}{endpoint}"
        async with httpx.AsyncClient() as client:
            response = await client.get(url, params=params, timeout=15)
            return response.json()

    def validate_nigeria_bounds(self, lat: float, lng: float) -> bool:
        return (
            NIGERIA_BOUNDS["lat_min"] <= lat <= NIGERIA_BOUNDS["lat_max"]
            and NIGERIA_BOUNDS["lng_min"] <= lng <= NIGERIA_BOUNDS["lng_max"]
        )

    async def reverse_geocode(self, lat: float, lng: float) -> dict:
        data = await self._get("/geocode/json", {"latlng": f"{lat},{lng}"})

        if data.get("status") != "OK" or not data.get("results"):
            logger.warning(f"Reverse geocode failed for {lat},{lng}: {data.get('status')}")
            return {
                "latitude": lat,
                "longitude": lng,
                "address": None,
                "city": None,
                "state": None,
                "country": None,
                "zip_code": None,
                "neighborhood": None,
                "full_address": None,
                "confidence": 0.0,
            }

        result = data["results"][0]
        components = {}
        for comp in result.get("address_components", []):
            for comp_type in comp["types"]:
                components[comp_type] = comp["long_name"]

        city = (
            components.get("locality")
            or components.get("sublocality")
            or components.get("administrative_area_level_2")
        )
        state = components.get("administrative_area_level_1")
        neighborhood = (
            components.get("sublocality_level_1")
            or components.get("neighborhood")
        )

        return {
            "latitude": lat,
            "longitude": lng,
            "address": result.get("formatted_address"),
            "city": city,
            "state": state,
            "country": components.get("country"),
            "zip_code": components.get("postal_code"),
            "neighborhood": neighborhood,
            "full_address": result.get("formatted_address"),
            "confidence": 1.0 - (len(data["results"]) - 1) * 0.1,
        }

    async def forward_geocode(self, address: str, country: str = "NG") -> dict:
        data = await self._get(
            "/geocode/json",
            {"address": address, "components": f"country:{country}"},
        )

        if data.get("status") != "OK" or not data.get("results"):
            logger.warning(f"Forward geocode failed for '{address}': {data.get('status')}")
            return {"latitude": None, "longitude": None, "address": None, "confidence": 0.0}

        result = data["results"][0]
        location = result["geometry"]["location"]

        components = {}
        for comp in result.get("address_components", []):
            for comp_type in comp["types"]:
                components[comp_type] = comp["long_name"]

        city = (
            components.get("locality")
            or components.get("sublocality")
            or components.get("administrative_area_level_2")
        )
        state = components.get("administrative_area_level_1")

        return {
            "latitude": location["lat"],
            "longitude": location["lng"],
            "address": result.get("formatted_address"),
            "city": city,
            "state": state,
            "country": components.get("country"),
            "zip_code": components.get("postal_code"),
            "full_address": result.get("formatted_address"),
            "confidence": 1.0 - (len(data["results"]) - 1) * 0.1,
        }

    async def search_nearby_places(
        self,
        lat: float,
        lng: float,
        radius_meters: int = 5000,
        place_type: str = None,
        keyword: str = None,
    ) -> list:
        params = {
            "location": f"{lat},{lng}",
            "radius": radius_meters,
        }
        if place_type:
            params["type"] = place_type
        if keyword:
            params["keyword"] = keyword

        data = await self._get("/place/nearbysearch/json", params)

        if data.get("status") != "OK":
            return []

        places = []
        for place in data.get("results", []):
            loc = place.get("geometry", {}).get("location", {})
            places.append({
                "name": place.get("name"),
                "place_type": place.get("types", [None])[0],
                "latitude": loc.get("lat"),
                "longitude": loc.get("lng"),
                "rating": place.get("rating"),
                "vicinity": place.get("vicinity"),
                "place_id": place.get("place_id"),
            })

        return places

    async def get_place_details(self, place_id: str) -> dict:
        data = await self._get("/place/details/json", {"place_id": place_id})

        if data.get("status") != "OK":
            return {}

        result = data.get("result", {})
        loc = result.get("geometry", {}).get("location", {})
        return {
            "name": result.get("name"),
            "address": result.get("formatted_address"),
            "latitude": loc.get("lat"),
            "longitude": loc.get("lng"),
            "rating": result.get("rating"),
            "phone": result.get("formatted_phone_number"),
            "website": result.get("website"),
            "place_id": result.get("place_id"),
        }


geocoding_service = GeocodingService()

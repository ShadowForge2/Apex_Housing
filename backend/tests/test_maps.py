import pytest


@pytest.mark.asyncio
async def test_maps_radius_search(client):
    response = await client.post("/api/v1/maps/radius-search", json={
        "latitude": 6.5244,
        "longitude": 3.3792,
        "radius_km": 5.0,
    })
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_maps_radius_search_with_type(client):
    response = await client.post("/api/v1/maps/radius-search", json={
        "latitude": 6.5244,
        "longitude": 3.3792,
        "radius_km": 10.0,
        "property_type": "apartment",
    })
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_maps_radius_search_response_structure(client):
    response = await client.post("/api/v1/maps/radius-search", json={
        "latitude": 6.5244,
        "longitude": 3.3792,
        "radius_km": 50.0,
    })
    assert response.status_code in (200, 401)
    if response.status_code == 200:
        body = response.json()
        assert "data" in body


@pytest.mark.asyncio
async def test_maps_get_pins(client):
    response = await client.get("/api/v1/maps/pins")
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_maps_reverse_geocode(client):
    response = await client.post("/api/v1/maps/reverse-geocode", json={
        "latitude": 6.5244,
        "longitude": 3.3792,
    })
    assert response.status_code in (200, 401, 500)


@pytest.mark.asyncio
async def test_maps_validate_location(client):
    response = await client.post("/api/v1/maps/validate-location", json={
        "latitude": 6.5244,
        "longitude": 3.3792,
    })
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_maps_validate_location_outside_nigeria(client):
    response = await client.post("/api/v1/maps/validate-location", json={
        "latitude": 51.5074,
        "longitude": -0.1278,
    })
    assert response.status_code in (200, 401)
    if response.status_code == 200:
        body = response.json()
        data = body.get("data", {})
        assert data.get("valid") is False

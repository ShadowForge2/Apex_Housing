import pytest


@pytest.mark.asyncio
async def test_search_properties_empty(client):
    response = await client.get("/api/v1/search/properties", params={"page_size": 5})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_properties_with_query(client):
    response = await client.get("/api/v1/search/properties", params={"q": "lagos", "page_size": 5})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_properties_with_price_range(client):
    response = await client.get("/api/v1/search/properties", params={"price_range": "budget"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_properties_with_location(client):
    response = await client.get("/api/v1/search/properties", params={
        "latitude": 6.5244,
        "longitude": 3.3792,
        "radius_km": 10,
        "sort_by": "distance",
    })
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_properties_with_property_type(client):
    response = await client.get("/api/v1/search/properties", params={"property_type": "apartment"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_properties_with_state(client):
    response = await client.get("/api/v1/search/properties", params={"state": "Lagos"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_properties_with_city(client):
    response = await client.get("/api/v1/search/properties", params={"city": "Ikeja"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_locations(client):
    response = await client.get("/api/v1/search/locations")
    assert response.status_code in (200, 404)
    if response.status_code == 200:
        body = response.json()
        assert "data" in body
        data = body["data"]
        assert "states" in data


@pytest.mark.asyncio
async def test_search_price_ranges(client):
    response = await client.get("/api/v1/search/price-ranges")
    assert response.status_code in (200, 404)
    if response.status_code == 200:
        body = response.json()
        assert "data" in body
        data = body["data"]
        assert isinstance(data, list)
        assert len(data) >= 5
        keys = [r.get("key") for r in data]
        assert "budget" in keys
        assert "luxury" in keys


@pytest.mark.asyncio
async def test_search_sort_price_low(client):
    response = await client.get("/api/v1/search/properties", params={"sort_by": "price_low"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_sort_price_high(client):
    response = await client.get("/api/v1/search/properties", params={"sort_by": "price_high"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_sort_newest(client):
    response = await client.get("/api/v1/search/properties", params={"sort_by": "newest"})
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_pagination(client):
    response = await client.get("/api/v1/search/properties", params={"page": 1, "page_size": 5})
    assert response.status_code in (200, 401)
    if response.status_code == 200:
        body = response.json()
        data = body.get("data", {})
        assert "total" in data
        assert "properties" in data
        assert "page" in data
        assert "page_size" in data

import pytest


@pytest.mark.asyncio
async def test_list_properties(client):
    response = await client.get("/api/v1/properties")
    assert response.status_code in (200, 401)


@pytest.mark.asyncio
async def test_search_popular(client):
    response = await client.get("/api/v1/search/popular")
    assert response.status_code in (200, 404)


@pytest.mark.asyncio
async def test_search_price_ranges(client):
    response = await client.get("/api/v1/search/price-ranges")
    assert response.status_code in (200, 404)

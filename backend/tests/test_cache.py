import pytest
from app.services.cache import (
    cache_service,
    make_search_cache_key,
    cache_search_results,
    get_cached_search,
)


@pytest.mark.asyncio
async def test_cache_set_and_get():
    await cache_service.connect()
    if cache_service._redis is None:
        pytest.skip("Redis not available")

    key = f"test_{__name__}"
    await cache_service.set(key, "hello", ttl=30)
    result = await cache_service.get(key)
    assert result == "hello"
    await cache_service.delete(key)


@pytest.mark.asyncio
async def test_search_cache_key_deterministic():
    key1 = make_search_cache_key(city="Lagos", min_price=100)
    key2 = make_search_cache_key(city="Lagos", min_price=100)
    assert key1 == key2

    key3 = make_search_cache_key(city="Abuja", min_price=100)
    assert key1 != key3


@pytest.mark.asyncio
async def test_cache_search_results():
    await cache_service.connect()
    if cache_service._redis is None:
        pytest.skip("Redis not available")

    key = f"test_search_{__name__}"
    await cache_search_results(key, [{"id": 1, "title": "Test"}], ttl=30)
    results = await get_cached_search(key)
    assert results is not None
    assert len(results) == 1
    assert results[0]["title"] == "Test"
    await cache_service.delete(f"search:{key}")

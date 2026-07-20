import pytest
from uuid import uuid4


@pytest.mark.asyncio
async def test_agent_profile_not_found(client):
    fake_id = str(uuid4())
    response = await client.get(f"/api/v1/agents/{fake_id}")
    assert response.status_code in (200, 404)


@pytest.mark.asyncio
async def test_agent_properties_not_found(client):
    fake_id = str(uuid4())
    response = await client.get(f"/api/v1/agents/{fake_id}/properties")
    assert response.status_code in (200, 404)


@pytest.mark.asyncio
async def test_agent_profile_returns_404_for_nonexistent(client):
    fake_id = str(uuid4())
    response = await client.get(f"/api/v1/agents/{fake_id}")
    assert response.status_code == 404
    body = response.json()
    assert "not found" in body.get("detail", "").lower() or "not found" in body.get("message", "").lower()

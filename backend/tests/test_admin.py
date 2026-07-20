import pytest


@pytest.mark.asyncio
async def test_admin_properties_requires_auth(client):
    response = await client.get("/api/v1/admin/properties")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_disputes_requires_auth(client):
    response = await client.get("/api/v1/admin/disputes")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_commission_revenue_requires_auth(client):
    response = await client.get("/api/v1/admin/commission/revenue")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_commission_logs_requires_auth(client):
    response = await client.get("/api/v1/admin/commission/logs")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_commission_rules_requires_auth(client):
    response = await client.get("/api/v1/admin/commission/rules")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_create_rule_requires_auth(client):
    response = await client.post("/api/v1/admin/commission/rules", json={
        "name": "Test Rule",
        "role_type": "agent",
        "percentage": 10.0,
    })
    assert response.status_code in (401, 403)

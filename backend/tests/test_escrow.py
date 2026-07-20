import pytest


@pytest.mark.asyncio
async def test_list_escrows_requires_auth(client):
    response = await client.get("/api/v1/escrow/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_escrow_requires_auth(client):
    from uuid import uuid4
    response = await client.post("/api/v1/escrow/", json={
        "booking_id": str(uuid4()),
        "amount": 500000,
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_escrow_detail_requires_auth(client):
    from uuid import uuid4
    fake_id = str(uuid4())
    response = await client.get(f"/api/v1/escrow/{fake_id}")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_list_bookings_requires_auth(client):
    response = await client.get("/api/v1/bookings/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_booking_requires_auth(client):
    from uuid import uuid4
    response = await client.post("/api/v1/bookings/", json={
        "property_id": str(uuid4()),
        "move_in_date": "2026-08-01",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_disputes_requires_auth(client):
    response = await client.get("/api/v1/disputes/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_wallet_requires_auth(client):
    response = await client.get("/api/v1/payments/wallet")
    assert response.status_code == 401

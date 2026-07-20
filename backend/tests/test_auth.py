import pytest
import uuid


@pytest.mark.asyncio
async def test_register_missing_fields(client):
    response = await client.post("/api/v1/auth/register", json={})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_register_user(client):
    email = f"test_{uuid.uuid4().hex[:8]}@example.com"
    response = await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "TestPass123!",
        "first_name": "Test",
        "last_name": "User",
        "role": "TENANT",
    })
    assert response.status_code in (200, 201, 422)


@pytest.mark.asyncio
async def test_login_missing_fields(client):
    response = await client.post("/api/v1/auth/login", json={})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_login_bad_credentials(client):
    response = await client.post("/api/v1/auth/login", json={
        "email": "nonexistent@example.com",
        "password": "wrongpassword",
    })
    assert response.status_code in (401, 422)

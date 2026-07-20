import pytest


@pytest.mark.asyncio
async def test_get_reviews_for_property(client):
    from uuid import uuid4
    fake_id = str(uuid4())
    response = await client.get(f"/api/v1/reviews/property/{fake_id}")
    assert response.status_code in (200, 401, 404)


@pytest.mark.asyncio
async def test_create_review_requires_auth(client):
    response = await client.post("/api/v1/reviews/", json={
        "rating": 5,
        "title": "Great property",
        "content": "Really enjoyed staying here.",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_review_vote_requires_auth(client):
    from uuid import uuid4
    fake_id = str(uuid4())
    response = await client.post(f"/api/v1/reviews/{fake_id}/vote", json={
        "is_helpful": True,
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_review_flag_requires_auth(client):
    from uuid import uuid4
    fake_id = str(uuid4())
    response = await client.post(f"/api/v1/reviews/{fake_id}/flag")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_review_respond_requires_auth(client):
    from uuid import uuid4
    fake_id = str(uuid4())
    response = await client.post(f"/api/v1/reviews/{fake_id}/respond", json={
        "content": "Thank you for the review!",
    })
    assert response.status_code == 401

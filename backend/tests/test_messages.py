import pytest


@pytest.mark.asyncio
async def test_list_conversations_requires_auth(client):
    response = await client.get("/api/v1/messages/conversations")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_conversation_requires_auth(client):
    from uuid import uuid4
    response = await client.post("/api/v1/messages/conversations", json={
        "participant_ids": [str(uuid4())],
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_send_message_requires_auth(client):
    from uuid import uuid4
    response = await client.post("/api/v1/messages/messages", json={
        "conversation_id": str(uuid4()),
        "content": "Hello!",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_messages_requires_auth(client):
    from uuid import uuid4
    fake_id = str(uuid4())
    response = await client.get(f"/api/v1/messages/conversations/{fake_id}/messages")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_complaint_requires_auth(client):
    response = await client.post("/api/v1/messages/complaint", json={
        "content": "I have an issue with my booking",
    })
    assert response.status_code == 401

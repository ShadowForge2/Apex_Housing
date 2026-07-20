from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime

from app.database import get_db
from app.dependencies import get_current_user, get_tenant
from app.messages.service import MessageService
from app.messages.schemas import ConversationCreate, MessageCreate, ComplaintCreate
from app.messages.models import Message, MessageAttachment, ConversationParticipant, MessageReadReceipt, Conversation
from app.users.models import User
from app.common.response import SuccessResponse
from app.common.exceptions import NotFound, BadRequest
from app.services.storage import supabase_storage

router = APIRouter(prefix="/messages", tags=["Messages"])

@router.post("/conversations", response_model=SuccessResponse)
async def create_conversation(body: ConversationCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Identity verification required to send messages. Please complete KYC first.")
    from sqlalchemy import select as sa_select
    from app.users.models import User as UserModel
    from app.common.enums import UserRole

    creator_result = await db.execute(sa_select(UserModel).where(UserModel.id == user.id))
    creator = creator_result.scalar_one_or_none()

    target_ids = [pid for pid in body.participant_ids if pid != user.id]
    if target_ids:
        targets_result = await db.execute(sa_select(UserModel).where(UserModel.id.in_(target_ids)))
        targets = targets_result.scalars().all()

        creator_is_landlord = creator.role in (UserRole.LANDLORD.value, UserRole.LANDLORD)
        all_targets_landlords = all(t.role in (UserRole.LANDLORD.value, UserRole.LANDLORD) for t in targets)

        if creator_is_landlord and all_targets_landlords and len(targets) == len(target_ids):
            from app.common.exceptions import BadRequest
            raise BadRequest("Agents cannot message other agents. You can only message tenants.")

    service = MessageService(db)
    conv = await service.create_conversation(user.id, body)
    return SuccessResponse(message="Conversation created", data={"id": str(conv.id)})

@router.get("/conversations", response_model=SuccessResponse)
async def list_conversations(page: int = 1, page_size: int = 20, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = MessageService(db)
    convs = await service.get_conversations(user.id, page=page, page_size=page_size)
    return SuccessResponse(data=convs)

@router.post("/messages", response_model=SuccessResponse)
async def send_message(body: MessageCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Identity verification required to send messages. Please complete KYC first.")
    service = MessageService(db)
    msg = await service.send_message(user.id, body)
    return SuccessResponse(message="Message sent", data=msg)

@router.get("/conversations/{conversation_id}/messages", response_model=SuccessResponse)
async def get_messages(conversation_id: UUID, page: int = 1, page_size: int = 50, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = MessageService(db)
    messages = await service.get_messages(conversation_id, user.id, page=page, page_size=page_size)
    return SuccessResponse(data=messages)

@router.post("/complaint", response_model=SuccessResponse)
async def create_complaint(body: ComplaintCreate, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    service = MessageService(db)
    conv = await service.create_complaint_chat(user.id, body)
    return SuccessResponse(message="Complaint chat opened with admin", data={"conversation_id": str(conv.id)})

@router.post("/messages/{message_id}/attachments", response_model=SuccessResponse)
async def upload_message_attachment(
    message_id: UUID,
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    msg_result = await db.execute(select(Message).where(Message.id == message_id))
    message = msg_result.scalar_one_or_none()
    if not message:
        raise NotFound("Message not found")
    if message.sender_id != user.id:
        raise BadRequest("Only the message sender can add attachments")

    participant_result = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == message.conversation_id,
            ConversationParticipant.user_id == user.id,
        )
    )
    if not participant_result.scalar_one_or_none():
        raise BadRequest("You are not a participant in this conversation")

    content = await file.read()
    if len(content) > 25 * 1024 * 1024:
        raise BadRequest("File too large. Max 25MB.")

    try:
        result = await supabase_storage.upload_file(
            file_bytes=content,
            file_name=file.filename or "attachment",
            content_type=file.content_type or "application/octet-stream",
            folder=f"messages/{message.conversation_id}/{message_id}",
        )
    except Exception as e:
        raise BadRequest(f"Upload failed: {str(e)}")

    file_type = "document"
    if file.content_type and file.content_type.startswith("image/"):
        file_type = "image"
    elif file.content_type and file.content_type.startswith("video/"):
        file_type = "video"

    from uuid import uuid4
    attachment = MessageAttachment(
        id=uuid4(), message_id=message_id,
        file_url=result["url"],
        file_name=file.filename or "attachment",
        file_size=len(content),
        file_type=file_type,
    )
    db.add(attachment)
    await db.commit()

    return SuccessResponse(message="Attachment uploaded", data={
        "id": str(attachment.id),
        "file_url": result["url"],
        "file_name": attachment.file_name,
        "file_type": file_type,
    })

@router.get("/messages/{message_id}/attachments", response_model=SuccessResponse)
async def get_message_attachments(message_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    participant_result = await db.execute(
        select(ConversationParticipant)
        .join(Message, Message.conversation_id == ConversationParticipant.conversation_id)
        .where(Message.id == message_id, ConversationParticipant.user_id == user.id)
    )
    if not participant_result.scalar_one_or_none():
        raise BadRequest("Access denied")

    result = await db.execute(
        select(MessageAttachment).where(MessageAttachment.message_id == message_id)
    )
    attachments = result.scalars().all()
    return SuccessResponse(data={"total": len(attachments), "attachments": attachments})

@router.put("/messages/{message_id}", response_model=SuccessResponse)
async def edit_message(message_id: UUID, content: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    msg_result = await db.execute(select(Message).where(Message.id == message_id))
    message = msg_result.scalar_one_or_none()
    if not message:
        raise NotFound("Message not found")
    if message.sender_id != user.id:
        raise BadRequest("Only the sender can edit a message")
    if message.is_deleted:
        raise BadRequest("Cannot edit a deleted message")

    message.content = content
    message.is_edited = True
    message.edited_at = datetime.utcnow()
    await db.commit()

    return SuccessResponse(message="Message edited", data={"id": str(message.id), "content": message.content, "is_edited": True})

@router.delete("/messages/{message_id}", response_model=SuccessResponse)
async def delete_message(message_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    msg_result = await db.execute(select(Message).where(Message.id == message_id))
    message = msg_result.scalar_one_or_none()
    if not message:
        raise NotFound("Message not found")
    if message.sender_id != user.id:
        raise BadRequest("Only the sender can delete a message")
    if message.is_deleted:
        raise BadRequest("Message already deleted")

    message.is_deleted = True
    message.deleted_at = datetime.utcnow()
    message.content = "[deleted]"
    await db.commit()

    return SuccessResponse(message="Message deleted")

@router.get("/conversations/{conversation_id}/participants", response_model=SuccessResponse)
async def list_conversation_participants(conversation_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    participant_check = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id == user.id,
        )
    )
    if not participant_check.scalar_one_or_none():
        raise BadRequest("You are not a participant in this conversation")

    from app.users.models import Profile
    result = await db.execute(
        select(ConversationParticipant, Profile)
        .join(Profile, Profile.user_id == ConversationParticipant.user_id, isouter=True)
        .where(ConversationParticipant.conversation_id == conversation_id)
    )
    participants = []
    for row in result.all():
        cp, profile = row
        participants.append({
            "user_id": str(cp.user_id),
            "first_name": profile.first_name if profile else None,
            "last_name": profile.last_name if profile else None,
            "profile_picture": profile.profile_picture if profile else None,
            "joined_at": cp.joined_at.isoformat() if cp.joined_at else None,
            "unread_count": cp.unread_count,
            "is_muted": cp.is_muted,
        })
    return SuccessResponse(data={"total": len(participants), "participants": participants})

@router.post("/conversations/{conversation_id}/mute", response_model=SuccessResponse)
async def toggle_mute_conversation(conversation_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id == user.id,
        )
    )
    participant = result.scalar_one_or_none()
    if not participant:
        raise BadRequest("You are not a participant in this conversation")

    participant.is_muted = not participant.is_muted
    await db.commit()

    action = "muted" if participant.is_muted else "unmuted"
    return SuccessResponse(message=f"Conversation {action}", data={"is_muted": participant.is_muted})

@router.post("/conversations/{conversation_id}/leave", response_model=SuccessResponse)
async def leave_conversation(conversation_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id == user.id,
        )
    )
    participant = result.scalar_one_or_none()
    if not participant:
        raise BadRequest("You are not a participant in this conversation")

    participant.left_at = datetime.utcnow()
    participant.is_muted = True
    await db.commit()

    return SuccessResponse(message="Left conversation")

@router.post("/conversations/{conversation_id}/read", response_model=SuccessResponse)
async def mark_conversation_read(conversation_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    participant_result = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id == user.id,
        )
    )
    participant = participant_result.scalar_one_or_none()
    if not participant:
        raise BadRequest("You are not a participant in this conversation")

    unread_result = await db.execute(
        select(Message).where(
            Message.conversation_id == conversation_id,
            Message.sender_id != user.id,
        ).order_by(Message.created_at.desc())
    )
    unread_messages = unread_result.scalars().all()

    now = datetime.utcnow()
    for msg in unread_messages:
        existing = await db.execute(
            select(MessageReadReceipt).where(
                MessageReadReceipt.message_id == msg.id,
                MessageReadReceipt.user_id == user.id,
            )
        )
        if not existing.scalar_one_or_none():
            receipt = MessageReadReceipt(
                id=UUID.__new__(UUID), message_id=msg.id,
                user_id=user.id, read_at=now,
            )
            db.add(receipt)

    participant.unread_count = 0
    participant.last_read_at = now
    await db.commit()

    return SuccessResponse(message="Conversation marked as read", data={
        "conversation_id": str(conversation_id),
        "messages_marked_read": len(unread_messages),
        "read_at": now.isoformat(),
    })

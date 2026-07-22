from uuid import UUID, uuid4
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload

from app.messages.models import Conversation, ConversationParticipant, Message, MessageReadReceipt, MessageAttachment
from app.messages.schemas import ConversationCreate, MessageCreate, ComplaintCreate
from app.messages.moderation import moderate_content
from app.common.exceptions import NotFound, Forbidden, BadRequest
from app.events.bus import event_bus
from app.events.types import MessageSentEvent

class MessageService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_conversation(self, creator_id: UUID, data: ConversationCreate) -> Conversation:
        conversation = Conversation(
            id=uuid4(), booking_id=data.booking_id,
        )
        self.db.add(conversation)
        await self.db.flush()

        all_participants = set(data.participant_ids)
        all_participants.add(creator_id)

        for user_id in all_participants:
            participant = ConversationParticipant(
                id=uuid4(), conversation_id=conversation.id,
                user_id=user_id, unread_count=0,
            )
            self.db.add(participant)

        await self.db.commit()
        return conversation

    async def send_message(self, sender_id: UUID, data: MessageCreate) -> Message:
        participant_result = await self.db.execute(
            select(ConversationParticipant).where(
                ConversationParticipant.conversation_id == data.conversation_id,
                ConversationParticipant.user_id == sender_id,
            )
        )
        if not participant_result.scalar_one_or_none():
            raise Forbidden("You are not a participant in this conversation")

        # Fix #3: Block messages in locked/completed conversations
        conv_result = await self.db.execute(
            select(Conversation).where(Conversation.id == data.conversation_id)
        )
        conv = conv_result.scalar_one()
        if not conv.is_active:
            raise Forbidden("This conversation is locked. The booking has been completed and this chat is now read-only.")

        is_direct = conv.conversation_type == "direct"

        if is_direct and data.message_type != "text":
            raise BadRequest("Only text messages are allowed in direct conversations.")

        if is_direct and data.attachment_urls:
            raise BadRequest("File attachments are not allowed in direct conversations. Please use text only.")

        moderation = moderate_content(data.content)
        if not moderation.is_allowed:
            raise BadRequest(moderation.reason)

        message = Message(
            id=uuid4(), conversation_id=data.conversation_id,
            sender_id=sender_id, content=data.content,
            message_type=data.message_type,
            is_edited=False, is_deleted=False,
        )
        self.db.add(message)

        conv.last_message_at = datetime.now(timezone.utc)
        conv.last_message_preview = data.content[:100]

        unread_result = await self.db.execute(
            select(ConversationParticipant).where(
                ConversationParticipant.conversation_id == data.conversation_id,
                ConversationParticipant.user_id != sender_id,
            )
        )
        for p in unread_result.scalars().all():
            p.unread_count += 1

        await self.db.commit()
        await self.db.refresh(message)

        if not is_direct and data.attachment_urls:
            for url in data.attachment_urls:
                attachment = MessageAttachment(
                    id=uuid4(), message_id=message.id,
                    file_url=url,
                    file_name=url.split("/")[-1] if "/" in url else "attachment",
                    file_size=0,
                    file_type="image" if any(ext in url.lower() for ext in [".jpg", ".jpeg", ".png", ".gif"]) else "document",
                )
                self.db.add(attachment)
            await self.db.commit()

        await event_bus.emit("message.sent", MessageSentEvent(
            message_id=message.id, conversation_id=data.conversation_id,
            sender_id=sender_id,
        ))

        from app.users.models import User as UserModel
        from app.common.enums import UserRole
        sender_result = await self.db.execute(select(UserModel).where(UserModel.id == sender_id))
        sender_user = sender_result.scalar_one_or_none()
        if sender_user and sender_user.role != UserRole.ADMIN.value:
            from app.notifications.service import NotificationService
            notif_service = NotificationService(self.db)
            admin_part_result = await self.db.execute(
                select(ConversationParticipant)
                .join(UserModel, UserModel.id == ConversationParticipant.user_id)
                .where(
                    ConversationParticipant.conversation_id == data.conversation_id,
                    ConversationParticipant.user_id != sender_id,
                    UserModel.role == UserRole.ADMIN.value,
                )
            )
            for admin_part in admin_part_result.scalars().all():
                from app.users.models import Profile
                prof_result = await self.db.execute(select(Profile).where(Profile.user_id == sender_id))
                prof = prof_result.scalar_one_or_none()
                sender_name = sender_user.email.split("@")[0]
                if prof and prof.first_name:
                    sender_name = f"{prof.first_name} {prof.last_name}"
                await notif_service.send_notification(
                    user_id=admin_part.user_id,
                    title=f"New Message: {sender_name}",
                    message=data.content[:200],
                    reference_type="complaint_message",
                    reference_id=data.conversation_id,
                    data={"conversation_id": str(data.conversation_id)},
                    push_data={"conversation_id": str(data.conversation_id), "type": "complaint_message"},
                )

        return message

    async def create_complaint_chat(self, tenant_id: UUID, data: ComplaintCreate) -> Conversation:
        from app.users.models import User
        from app.common.enums import UserRole
        from app.escrow.models import EscrowTransaction
        from app.bookings.models import Booking

        booking_result = await self.db.execute(
            select(Booking).where(Booking.id == data.booking_id)
        )
        booking = booking_result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")
        if booking.tenant_id != tenant_id:
            raise Forbidden("Only the tenant can open a complaint for this booking")

        escrow_result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.booking_id == data.booking_id)
        )
        escrow = escrow_result.scalar_one_or_none()

        admin_result = await self.db.execute(
            select(User).where(User.role == UserRole.ADMIN.value, User.is_active == True)
        )
        all_admins = admin_result.scalars().all()
        if not all_admins:
            raise NotFound("No admin available to handle complaint")

        admin_ids = [a.id for a in all_admins]
        ticket_counts = await self.db.execute(
            select(
                ConversationParticipant.user_id,
                func.count(ConversationParticipant.conversation_id).label("ticket_count"),
            )
            .join(Conversation, ConversationParticipant.conversation_id == Conversation.id)
            .where(
                ConversationParticipant.user_id.in_(admin_ids),
                Conversation.conversation_type != "admin_group",
                Conversation.booking_id.isnot(None),
            )
            .group_by(ConversationParticipant.user_id)
        )
        count_map = {row.user_id: row.ticket_count for row in ticket_counts}
        least_loaded = min(all_admins, key=lambda a: count_map.get(a.id, 0))
        admin = least_loaded

        conversation = Conversation(
            id=uuid4(), booking_id=data.booking_id,
            conversation_type="complaint",
        )
        self.db.add(conversation)
        await self.db.flush()

        participant_ids = {tenant_id, admin.id}
        if booking.landlord_id:
            participant_ids.add(booking.landlord_id)

        for uid in participant_ids:
            participant = ConversationParticipant(
                id=uuid4(), conversation_id=conversation.id,
                user_id=uid, unread_count=0,
            )
            self.db.add(participant)

        await self.db.flush()

        complaint_message = Message(
            id=uuid4(), conversation_id=conversation.id,
            sender_id=tenant_id,
            content=f"[COMPLAINT] {data.reason}\n\n{data.description}",
            message_type="complaint",
            is_edited=False, is_deleted=False,
        )
        self.db.add(complaint_message)

        conv_result = await self.db.execute(
            select(Conversation).where(Conversation.id == conversation.id)
        )
        conv = conv_result.scalar_one()
        conv.last_message_at = datetime.now(timezone.utc)
        conv.last_message_preview = f"[COMPLAINT] {data.reason}"

        unread_result = await self.db.execute(
            select(ConversationParticipant).where(
                ConversationParticipant.conversation_id == conversation.id,
                ConversationParticipant.user_id != tenant_id,
            )
        )
        for p in unread_result.scalars().all():
            p.unread_count += 1

        await self.db.flush()

        if data.evidence_urls:
            for url in data.evidence_urls:
                attachment = MessageAttachment(
                    id=uuid4(), message_id=complaint_message.id,
                    file_url=url,
                    file_name=url.split("/")[-1] if "/" in url else "evidence",
                    file_size=0,
                    file_type="image" if any(ext in url.lower() for ext in [".jpg", ".jpeg", ".png", ".gif"]) else "document",
                )
                self.db.add(attachment)

        if escrow and escrow.status.value in ("FUNDS_HELD", "TIMER_RUNNING"):
            from app.common.enums import EscrowStatus
            escrow.status = EscrowStatus.DISPUTED
            from app.escrow.models import EscrowStatusHistory
            from app.common.enums import EscrowEvent
            history = EscrowStatusHistory(
                id=uuid4(), escrow_id=escrow.id,
                status=EscrowStatus.DISPUTED,
                event_type=EscrowEvent.DISPUTE_OPENED,
                changed_by=tenant_id,
                notes=f"Tenant opened complaint: {data.reason}",
            )
            self.db.add(history)

        await self.db.commit()
        await self.db.refresh(conversation)

        await event_bus.emit("message.sent", MessageSentEvent(
            message_id=complaint_message.id, conversation_id=conversation.id,
            sender_id=tenant_id,
        ))

        from app.notifications.service import NotificationService
        notif_service = NotificationService(self.db)
        await notif_service.send_notification(
            user_id=admin.id,
            title="New Complaint Assigned",
            message=f"A new complaint has been assigned to you: {data.reason}",
            reference_type="complaint",
            reference_id=conversation.id,
            data={"conversation_id": str(conversation.id), "booking_id": str(data.booking_id)},
            push_data={"conversation_id": str(conversation.id), "type": "complaint"},
        )

        return conversation

    async def get_conversations(self, user_id: UUID, page: int = 1, page_size: int = 20) -> dict:
        from app.users.models import User as UserModel, Profile

        query = (
            select(Conversation)
            .join(ConversationParticipant)
            .where(ConversationParticipant.user_id == user_id)
            .order_by(Conversation.last_message_at.desc())
        )
        count_result = await self.db.execute(
            select(func.count()).select_from(
                select(Conversation).join(ConversationParticipant).where(ConversationParticipant.user_id == user_id).subquery()
            )
        )
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        conversations = result.scalars().all()

        enriched = []
        for conv in conversations:
            part_result = await self.db.execute(
                select(ConversationParticipant).where(ConversationParticipant.conversation_id == conv.id)
            )
            participants = part_result.scalars().all()

            other_participant_ids = [p.user_id for p in participants if p.user_id != user_id]

            other_users_info = []
            if other_participant_ids:
                users_result = await self.db.execute(
                    select(UserModel).where(UserModel.id.in_(other_participant_ids))
                )
                other_users = {u.id: u for u in users_result.scalars().all()}

                profiles_result = await self.db.execute(
                    select(Profile).where(Profile.user_id.in_(other_participant_ids))
                )
                profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}

                for uid in other_participant_ids:
                    u = other_users.get(uid)
                    p = profiles_map.get(uid)
                    if u:
                        name = f"{p.first_name} {p.last_name}" if p and p.first_name else u.email.split("@")[0]
                        other_users_info.append({
                            "id": str(uid),
                            "name": name,
                            "role": u.role,
                            "profile_picture": p.profile_picture if p else None,
                        })

            my_part = next((p for p in participants if p.user_id == user_id), None)

            enriched.append({
                "id": str(conv.id),
                "booking_id": str(conv.booking_id) if conv.booking_id else None,
                "conversation_type": conv.conversation_type,
                "is_active": conv.is_active,
                "participants": other_users_info,
                "last_message": conv.last_message_preview,
                "last_message_at": conv.last_message_at.isoformat() if conv.last_message_at else None,
                "unread_count": my_part.unread_count if my_part else 0,
                "created_at": conv.created_at.isoformat() if conv.created_at else None,
            })

        return {"total": total, "conversations": enriched}

    async def get_messages(self, conversation_id: UUID, user_id: UUID, page: int = 1, page_size: int = 50) -> dict:
        participant_result = await self.db.execute(
            select(ConversationParticipant).where(
                ConversationParticipant.conversation_id == conversation_id,
                ConversationParticipant.user_id == user_id,
            )
        )
        if not participant_result.scalar_one_or_none():
            raise Forbidden("You are not a participant")

        query = select(Message).where(
            Message.conversation_id == conversation_id,
            Message.is_deleted == False,
        ).order_by(Message.created_at.desc())

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        messages = result.scalars().all()
        return {"total": total, "messages": messages}

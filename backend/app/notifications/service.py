from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime
import logging

from app.notifications.models import Notification, NotificationPreference, DeviceToken
from app.common.enums import NotificationType

logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_notification(
        self, user_id: UUID, title: str, message: str,
        notification_type: str = NotificationType.IN_APP,
        reference_type: str = None, reference_id: UUID = None,
        data: dict = None,
    ) -> Notification:
        meta = dict(data) if data else {}
        if reference_type:
            meta["reference_type"] = reference_type
        if reference_id:
            meta["reference_id"] = str(reference_id)
        notification = Notification(
            id=uuid4(), user_id=user_id,
            title=title, body=message,
            notification_type=notification_type,
            data_json=meta or None,
        )
        self.db.add(notification)
        await self.db.commit()
        await self.db.refresh(notification)
        return notification

    async def send_notification(
        self, user_id: UUID, title: str, message: str,
        reference_type: str = None, reference_id: UUID = None,
        data: dict = None,
        email_subject: str = None, email_html: str = None,
        push_data: dict = None,
    ) -> Notification:
        pref = await self.get_preference(user_id)
        notification = None

        if pref.in_app_enabled:
            notification = await self.create_notification(
                user_id=user_id, title=title, message=message,
                notification_type=NotificationType.IN_APP,
                reference_type=reference_type, reference_id=reference_id,
                data=data,
            )

        if pref.push_enabled and push_data:
            await self._send_push(user_id, title, message, push_data)

        if pref.email_enabled and email_subject and email_html:
            await self._send_email(user_id, email_subject, email_html)

        return notification

    async def _send_push(self, user_id: UUID, title: str, body: str, data: dict = None):
        try:
            from app.services.notification import fcm_service
            result = await self.db.execute(
                select(DeviceToken).where(
                    DeviceToken.user_id == user_id,
                    DeviceToken.is_active == True,
                )
            )
            tokens = result.scalars().all()
            if not tokens:
                return
            token_list = [t.token for t in tokens]
            if len(token_list) == 1:
                await fcm_service.send_to_token(token_list[0], title, body, data=data)
            else:
                await fcm_service.send_to_multiple_tokens(token_list, title, body, data=data)
        except Exception as e:
            logger.error(f"Push notification failed for user {user_id}: {e}")

    async def _send_email(self, user_id: UUID, subject: str, html: str):
        try:
            from app.services.email import email_service
            from app.users.models import User
            result = await self.db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user and user.email:
                await email_service.send(to=user.email, subject=subject, html=html)
        except Exception as e:
            logger.error(f"Email notification failed for user {user_id}: {e}")

    async def mark_as_read(self, notification_id: UUID, user_id: UUID) -> Notification:
        result = await self.db.execute(
            select(Notification).where(
                Notification.id == notification_id,
                Notification.user_id == user_id,
            )
        )
        notification = result.scalar_one_or_none()
        if notification:
            notification.is_read = True
            await self.db.commit()
        return notification

    async def mark_all_as_read(self, user_id: UUID) -> int:
        result = await self.db.execute(
            select(Notification).where(
                Notification.user_id == user_id,
                Notification.is_read == False,
            )
        )
        notifications = result.scalars().all()
        for n in notifications:
            n.is_read = True
        await self.db.commit()
        return len(notifications)

    async def get_notifications(self, user_id: UUID, page: int = 1, page_size: int = 20) -> dict:
        query = select(Notification).where(Notification.user_id == user_id)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()

        unread_result = await self.db.execute(
            select(func.count()).select_from(Notification).where(
                Notification.user_id == user_id,
                Notification.is_read == False,
            )
        )
        unread_count = unread_result.scalar()

        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Notification.created_at.desc())
        result = await self.db.execute(query)
        notifications = result.scalars().all()

        return {"total": total, "unread_count": unread_count, "notifications": notifications}

    async def get_preference(self, user_id: UUID) -> NotificationPreference:
        result = await self.db.execute(
            select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        )
        pref = result.scalar_one_or_none()
        if not pref:
            pref = NotificationPreference(
                id=uuid4(), user_id=user_id,
                push_enabled=True, sms_enabled=False,
                email_enabled=True, in_app_enabled=True,
            )
            self.db.add(pref)
            await self.db.commit()
            await self.db.refresh(pref)
        return pref

    async def update_preference(self, user_id: UUID, data: dict) -> NotificationPreference:
        pref = await self.get_preference(user_id)
        for key, value in data.items():
            if value is not None:
                setattr(pref, key, value)
        await self.db.commit()
        await self.db.refresh(pref)
        return pref

    async def register_device_token(self, user_id: UUID, token: str, platform: str, device_name: str = None) -> DeviceToken:
        result = await self.db.execute(
            select(DeviceToken).where(DeviceToken.token == token)
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.is_active = True
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        device = DeviceToken(
            id=uuid4(), user_id=user_id,
            token=token, platform=platform,
            is_active=True,
        )
        self.db.add(device)
        await self.db.commit()
        await self.db.refresh(device)
        return device

    async def remove_device_token(self, token: str) -> bool:
        result = await self.db.execute(
            select(DeviceToken).where(DeviceToken.token == token)
        )
        device = result.scalar_one_or_none()
        if device:
            device.is_active = False
            await self.db.commit()
            return True
        return False

    async def send_to_admins(
        self, title: str, message: str,
        exclude_user_id: UUID = None,
        email_subject: str = None, email_html: str = None,
    ) -> int:
        """Send an in-app notification (and optionally email) to all active admins."""
        from app.users.models import User
        from app.common.enums import UserRole

        result = await self.db.execute(
            select(User.id, User.email).where(
                User.role == UserRole.ADMIN.value,
                User.is_active == True,
            )
        )
        admins = result.all()
        sent = 0
        for admin_id, admin_email in admins:
            if exclude_user_id and admin_id == exclude_user_id:
                continue
            await self.create_notification(
                user_id=admin_id, title=title, message=message,
                notification_type=NotificationType.IN_APP,
            )
            if email_subject and email_html and admin_email:
                try:
                    from app.services.email import email_service
                    await email_service.send(to=admin_email, subject=email_subject, html=email_html)
                except Exception as e:
                    logger.error(f"Admin notification email failed for {admin_email}: {e}")
            sent += 1
        return sent

    async def broadcast_to_users(
        self, title: str, message: str,
        roles: list[str] = None,
        email_subject: str = None, email_html: str = None,
    ) -> int:
        """Broadcast an in-app notification (and optionally email) to users.

        Args:
            roles: List of role strings to target (e.g. ["TENANT", "LANDLORD"]).
                   If None or empty, sends to ALL users (excluding admins).
        """
        from app.users.models import User
        from app.common.enums import UserRole

        query = select(User.id, User.email).where(User.is_active == True)
        if roles:
            query = query.where(User.role.in_(roles))
        else:
            query = query.where(User.role.in_([UserRole.TENANT.value, UserRole.LANDLORD.value]))

        result = await self.db.execute(query)
        users = result.all()
        sent = 0
        for user_id, user_email in users:
            await self.create_notification(
                user_id=user_id, title=title, message=message,
                notification_type=NotificationType.IN_APP,
                data={"announcement": True},
            )
            if email_subject and email_html and user_email:
                try:
                    from app.services.email import email_service
                    await email_service.send(to=user_email, subject=email_subject, html=email_html)
                except Exception as e:
                    logger.error(f"Broadcast email failed for {user_email}: {e}")
            sent += 1
        return sent

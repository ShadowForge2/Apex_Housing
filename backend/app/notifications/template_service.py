from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.notifications.models import NotificationTemplate
from app.common.exceptions import NotFound, Conflict


class NotificationTemplateService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_template(self, data: dict) -> NotificationTemplate:
        existing = await self.db.execute(
            select(NotificationTemplate).where(NotificationTemplate.name == data["name"])
        )
        if existing.scalar_one_or_none():
            raise Conflict(f"Template with name '{data['name']}' already exists")

        template = NotificationTemplate(
            id=uuid4(),
            name=data["name"],
            title_template=data["title_template"],
            message_template=data["message_template"],
            notification_type=data["notification_type"],
            is_active=data.get("is_active", True),
            variables=data.get("variables"),
        )
        self.db.add(template)
        await self.db.commit()
        await self.db.refresh(template)
        return template

    async def list_templates(self, page: int = 1, page_size: int = 20) -> dict:
        query = select(NotificationTemplate).order_by(NotificationTemplate.name)
        count_result = await self.db.execute(select(func.count()).select_from(NotificationTemplate))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        return {"total": total, "templates": result.scalars().all()}

    async def get_template(self, template_id: UUID) -> NotificationTemplate:
        result = await self.db.execute(
            select(NotificationTemplate).where(NotificationTemplate.id == template_id)
        )
        template = result.scalar_one_or_none()
        if not template:
            raise NotFound("Template not found")
        return template

    async def get_template_by_name(self, name: str) -> NotificationTemplate | None:
        result = await self.db.execute(
            select(NotificationTemplate).where(
                NotificationTemplate.name == name,
                NotificationTemplate.is_active == True,
            )
        )
        return result.scalar_one_or_none()

    async def update_template(self, template_id: UUID, data: dict) -> NotificationTemplate:
        template = await self.get_template(template_id)
        for key, value in data.items():
            if value is not None:
                setattr(template, key, value)
        await self.db.commit()
        await self.db.refresh(template)
        return template

    async def delete_template(self, template_id: UUID) -> bool:
        template = await self.get_template(template_id)
        await self.db.delete(template)
        await self.db.commit()
        return True

    async def render(self, name: str, context: dict = None) -> dict | None:
        template = await self.get_template_by_name(name)
        if not template:
            return None
        title = template.title_template
        message = template.message_template
        if context:
            for key, value in context.items():
                title = title.replace(f"{{{{{key}}}}}", str(value))
                message = message.replace(f"{{{{{key}}}}}", str(value))
        return {
            "title": title,
            "message": message,
            "notification_type": template.notification_type,
        }

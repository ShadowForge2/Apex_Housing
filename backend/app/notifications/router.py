from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from pydantic import BaseModel
from typing import Optional, Any

from app.database import get_db
from app.dependencies import get_current_user, get_admin
from app.notifications.service import NotificationService
from app.notifications.template_service import NotificationTemplateService
from app.notifications.schemas import NotificationPreferenceUpdate
from app.users.models import User
from app.common.response import SuccessResponse

router = APIRouter(prefix="/notifications", tags=["Notifications"])


class DeviceTokenRequest(BaseModel):
    token: str
    platform: str
    device_name: str = None


class TemplateCreateRequest(BaseModel):
    name: str
    title_template: str
    message_template: str
    notification_type: str = "in_app"
    is_active: bool = True
    variables: Optional[dict] = None


class TemplateUpdateRequest(BaseModel):
    title_template: Optional[str] = None
    message_template: Optional[str] = None
    notification_type: Optional[str] = None
    is_active: Optional[bool] = None
    variables: Optional[dict] = None


@router.get("/", response_model=SuccessResponse)
async def list_notifications(page: int = 1, page_size: int = 20, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    notifications = await service.get_notifications(user.id, page=page, page_size=page_size)
    return SuccessResponse(data=notifications)


@router.put("/{notification_id}/read", response_model=SuccessResponse)
async def mark_read(notification_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    await service.mark_as_read(notification_id, user.id)
    return SuccessResponse(message="Marked as read")


@router.put("/read-all")
async def mark_all_read(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    count = await service.mark_all_as_read(user.id)
    return SuccessResponse(message=f"Marked {count} notifications as read")


@router.get("/preferences", response_model=SuccessResponse)
async def get_preferences(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    pref = await service.get_preference(user.id)
    return SuccessResponse(data=pref)


@router.put("/preferences", response_model=SuccessResponse)
async def update_preferences(body: NotificationPreferenceUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    pref = await service.update_preference(user.id, body.model_dump(exclude_unset=True))
    return SuccessResponse(message="Preferences updated", data=pref)


@router.post("/device-token", response_model=SuccessResponse)
async def register_device_token(body: DeviceTokenRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    device = await service.register_device_token(user.id, body.token, body.platform, body.device_name)
    return SuccessResponse(message="Device token registered", data={"id": device.id})


@router.delete("/device-token")
async def remove_device_token(token: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = NotificationService(db)
    removed = await service.remove_device_token(token)
    return SuccessResponse(message="Device token removed" if removed else "Token not found")


# --- Admin: Notification Templates ---

@router.get("/templates", response_model=SuccessResponse)
async def list_templates(page: int = 1, page_size: int = 20, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = NotificationTemplateService(db)
    result = await service.list_templates(page=page, page_size=page_size)
    templates = [
        {
            "id": str(t.id), "name": t.name,
            "title_template": t.title_template, "message_template": t.message_template,
            "notification_type": t.notification_type, "is_active": t.is_active,
            "variables": t.variables,
            "created_at": str(t.created_at), "updated_at": str(t.updated_at),
        }
        for t in result["templates"]
    ]
    return SuccessResponse(data={"total": result["total"], "templates": templates})


@router.post("/templates", response_model=SuccessResponse)
async def create_template(body: TemplateCreateRequest, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = NotificationTemplateService(db)
    template = await service.create_template(body.model_dump())
    return SuccessResponse(message="Template created", data={"id": str(template.id), "name": template.name})


@router.get("/templates/{template_id}", response_model=SuccessResponse)
async def get_template(template_id: UUID, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = NotificationTemplateService(db)
    t = await service.get_template(template_id)
    return SuccessResponse(data={
        "id": str(t.id), "name": t.name,
        "title_template": t.title_template, "message_template": t.message_template,
        "notification_type": t.notification_type, "is_active": t.is_active,
        "variables": t.variables,
        "created_at": str(t.created_at), "updated_at": str(t.updated_at),
    })


@router.put("/templates/{template_id}", response_model=SuccessResponse)
async def update_template(template_id: UUID, body: TemplateUpdateRequest, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = NotificationTemplateService(db)
    template = await service.update_template(template_id, body.model_dump(exclude_unset=True))
    return SuccessResponse(message="Template updated", data={"id": str(template.id), "name": template.name})


@router.delete("/templates/{template_id}", response_model=SuccessResponse)
async def delete_template(template_id: UUID, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = NotificationTemplateService(db)
    await service.delete_template(template_id)
    return SuccessResponse(message="Template deleted")

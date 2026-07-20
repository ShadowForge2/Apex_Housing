from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime

class ConversationCreate(BaseModel):
    participant_ids: List[UUID]
    booking_id: Optional[UUID] = None

class MessageCreate(BaseModel):
    conversation_id: UUID
    content: str = Field(min_length=1)
    message_type: str = "text"
    attachment_urls: List[str] = []

class ComplaintCreate(BaseModel):
    booking_id: UUID
    reason: str = Field(min_length=3, description="Reason for complaint")
    description: str = Field(min_length=10, description="Detailed description of the issue")
    evidence_urls: List[str] = []

class MessageUpdate(BaseModel):
    content: str = Field(min_length=1)

class MessageAttachmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    file_url: str
    file_name: str
    file_size: Optional[int] = None
    file_type: Optional[str] = None
    thumbnail_url: Optional[str] = None

class MessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    conversation_id: UUID
    sender_id: UUID
    content: str
    message_type: str
    is_edited: bool
    is_deleted: bool
    attachments: List[MessageAttachmentResponse] = []
    created_at: datetime

class ConversationParticipantResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    joined_at: datetime
    is_muted: bool
    unread_count: int

class ConversationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: Optional[UUID] = None
    conversation_type: str = "direct"
    is_active: bool = True
    participants: List[ConversationParticipantResponse] = []
    last_message_at: Optional[datetime] = None
    last_message_preview: Optional[str] = None
    created_at: datetime

class ConversationListResponse(BaseModel):
    total: int
    conversations: List[ConversationResponse]

class MessageListResponse(BaseModel):
    total: int
    messages: List[MessageResponse]

from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.common.enums import DocumentType

class DocumentCreate(BaseModel):
    booking_id: Optional[UUID] = None
    property_id: Optional[UUID] = None
    document_type: DocumentType
    title: str
    description: Optional[str] = None
    file_url: str
    file_size: Optional[int] = None
    file_type: Optional[str] = None
    expires_at: Optional[datetime] = None

class DocumentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    booking_id: Optional[UUID] = None
    property_id: Optional[UUID] = None
    document_type: DocumentType
    title: str
    description: Optional[str] = None
    file_url: str
    file_size: Optional[int] = None
    file_type: Optional[str] = None
    version: int
    status: str
    signed_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    created_at: datetime

class DocumentListResponse(BaseModel):
    total: int
    documents: List[DocumentResponse]

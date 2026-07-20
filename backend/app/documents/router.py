from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user
from app.documents.service import DocumentService
from app.documents.schemas import DocumentCreate
from app.users.models import User
from app.common.response import SuccessResponse
from app.services.storage import supabase_storage

router = APIRouter(prefix="/documents", tags=["Documents"])

MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_TYPES = {
    "application/pdf", "image/jpeg", "image/png", "image/webp",
    "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}


@router.post("/", response_model=SuccessResponse)
async def upload_document(
    file: UploadFile = File(...),
    booking_id: UUID = None,
    property_id: UUID = None,
    document_type: str = "general",
    title: str = None,
    description: str = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large. Max 10MB.")

    if file.content_type and file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail=f"File type {file.content_type} not allowed.")

    try:
        upload_result = await supabase_storage.upload_file(
            file_bytes=content,
            file_name=file.filename or "document",
            content_type=file.content_type or "application/octet-stream",
            folder=f"users/{user.id}/documents",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

    data = DocumentCreate(
        booking_id=booking_id,
        property_id=property_id,
        document_type=document_type,
        title=title or file.filename or "Untitled",
        description=description,
        file_url=upload_result["url"],
        file_size=len(content),
        file_type=file.content_type,
    )

    service = DocumentService(db)
    doc = await service.create_document(user.id, data)
    return SuccessResponse(message="Document uploaded", data=doc)


@router.get("/", response_model=SuccessResponse)
async def list_documents(
    booking_id: UUID = None, document_type: str = None,
    page: int = 1, page_size: int = 20,
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db),
):
    service = DocumentService(db)
    docs = await service.list_documents(
        user_id=user.id, booking_id=booking_id,
        document_type=document_type, page=page, page_size=page_size,
    )
    return SuccessResponse(data=docs)


@router.get("/{document_id}", response_model=SuccessResponse)
async def get_document(document_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = DocumentService(db)
    doc = await service.get_document(document_id)
    return SuccessResponse(data=doc)


@router.get("/{document_id}/download")
async def download_document(document_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = DocumentService(db)
    doc = await service.get_document(document_id)
    try:
        signed_url = await supabase_storage.get_signed_url(doc.file_url.split("/object/public/")[1], expires_in=3600)
        return SuccessResponse(data={"download_url": signed_url})
    except Exception:
        return SuccessResponse(data={"download_url": doc.file_url})


@router.delete("/{document_id}", response_model=SuccessResponse)
async def delete_document(document_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = DocumentService(db)
    doc = await service.archive_document(document_id, user.id)
    return SuccessResponse(message="Document archived", data=doc)

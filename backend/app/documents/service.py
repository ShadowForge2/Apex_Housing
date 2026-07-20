from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.documents.models import Document
from app.documents.schemas import DocumentCreate
from app.common.exceptions import NotFound, Forbidden

class DocumentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_document(self, user_id: UUID, data: DocumentCreate) -> Document:
        doc = Document(
            id=uuid4(), user_id=user_id,
            booking_id=data.booking_id, property_id=data.property_id,
            document_type=data.document_type, title=data.title,
            description=data.description, file_url=data.file_url,
            file_size=data.file_size, file_type=data.file_type,
            version=1, status="active",
            expires_at=data.expires_at,
        )
        self.db.add(doc)
        await self.db.commit()
        await self.db.refresh(doc)
        return doc

    async def get_document(self, document_id: UUID) -> Document:
        result = await self.db.execute(select(Document).where(Document.id == document_id))
        doc = result.scalar_one_or_none()
        if not doc:
            raise NotFound("Document not found")
        return doc

    async def list_documents(self, user_id: UUID = None, booking_id: UUID = None, document_type: str = None, page: int = 1, page_size: int = 20) -> dict:
        query = select(Document)
        if user_id:
            query = query.where(Document.user_id == user_id)
        if booking_id:
            query = query.where(Document.booking_id == booking_id)
        if document_type:
            query = query.where(Document.document_type == document_type)

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Document.created_at.desc())
        result = await self.db.execute(query)
        return {"total": total, "documents": result.scalars().all()}

    async def archive_document(self, document_id: UUID, user_id: UUID) -> Document:
        doc = await self.get_document(document_id)
        if doc.user_id != user_id:
            raise Forbidden("Not your document")
        doc.status = "archived"
        await self.db.commit()
        return doc

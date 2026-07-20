from fastapi import APIRouter, Depends, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user, get_admin
from app.disputes.service import DisputeService
from app.disputes.schemas import DisputeCreate, DisputeUpdate, DisputeMessageCreate
from app.disputes.models import Dispute, DisputeEvidence, DisputeMessage
from app.common.enums import DisputeStatus
from app.users.models import User
from app.common.response import SuccessResponse
from app.common.exceptions import NotFound, BadRequest, Forbidden
from app.services.storage import supabase_storage

router = APIRouter(prefix="/disputes", tags=["Disputes"])

@router.post("/", response_model=SuccessResponse)
async def open_dispute(body: DisputeCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = DisputeService(db)
    dispute = await service.open_dispute(user.id, body)
    return SuccessResponse(message="Dispute opened", data=dispute)

@router.get("/", response_model=SuccessResponse)
async def list_disputes(
    page: int = 1,
    page_size: int = 20,
    status: DisputeStatus = Query(None, description="Filter by dispute status"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = DisputeService(db)
    disputes = await service.list_disputes(page=page, page_size=page_size, status=status, user=user)
    return SuccessResponse(data=disputes)

@router.get("/{dispute_id}", response_model=SuccessResponse)
async def get_dispute(dispute_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = DisputeService(db)
    dispute = await service.get_dispute(dispute_id)
    if not getattr(user, 'is_super_admin', False):
        if dispute.tenant_id != user.id and dispute.landlord_id != user.id:
            raise Forbidden("Access denied")
    return SuccessResponse(data=dispute)

@router.put("/{dispute_id}/resolve", response_model=SuccessResponse)
async def resolve_dispute(dispute_id: UUID, resolution: str, notes: str = None, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = DisputeService(db)
    dispute = await service.resolve_dispute(dispute_id, user.id, resolution, notes)
    return SuccessResponse(message="Dispute resolved", data=dispute)

@router.post("/{dispute_id}/messages", response_model=SuccessResponse)
async def add_dispute_message(dispute_id: UUID, body: DisputeMessageCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = DisputeService(db)
    dispute = await service.get_dispute(dispute_id)
    if not getattr(user, 'is_super_admin', False):
        if dispute.tenant_id != user.id and dispute.landlord_id != user.id:
            raise Forbidden("Access denied")
        body.is_admin_note = False
    msg = await service.add_message(dispute_id, user.id, body)
    return SuccessResponse(message="Message added", data=msg)

@router.get("/{dispute_id}/messages", response_model=SuccessResponse)
async def list_dispute_messages(dispute_id: UUID, page: int = 1, page_size: int = 50, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    dispute_result = await db.execute(select(Dispute).where(Dispute.id == dispute_id))
    dispute = dispute_result.scalar_one_or_none()
    if not dispute:
        raise NotFound("Dispute not found")

    if not getattr(user, 'is_super_admin', False):
        if dispute.tenant_id != user.id and dispute.landlord_id != user.id:
            raise Forbidden("Access denied")

    from sqlalchemy import func as sql_func
    query = select(DisputeMessage).where(DisputeMessage.dispute_id == dispute_id)
    count_result = await db.execute(select(sql_func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.offset((page - 1) * page_size).limit(page_size).order_by(DisputeMessage.created_at)
    result = await db.execute(query)
    messages = result.scalars().all()
    return SuccessResponse(data={"total": total, "messages": messages, "page": page, "page_size": page_size})

@router.post("/{dispute_id}/evidence", response_model=SuccessResponse)
async def upload_dispute_evidence(
    dispute_id: UUID,
    file: UploadFile = File(...),
    description: str = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    dispute_result = await db.execute(select(Dispute).where(Dispute.id == dispute_id))
    dispute = dispute_result.scalar_one_or_none()
    if not dispute:
        raise NotFound("Dispute not found")
    if dispute.reported_by != user.id:
        raise BadRequest("Only the dispute reporter can upload evidence")

    content = await file.read()
    if len(content) > 20 * 1024 * 1024:
        raise BadRequest("File too large. Max 20MB.")

    try:
        result = await supabase_storage.upload_file(
            file_bytes=content,
            file_name=file.filename or "evidence",
            content_type=file.content_type or "application/octet-stream",
            folder=f"disputes/{dispute_id}/evidence",
        )
    except Exception as e:
        raise BadRequest(f"Upload failed: {str(e)}")

    evidence_type = "image"
    if file.content_type and file.content_type.startswith("video/"):
        evidence_type = "video"
    elif file.content_type and "pdf" in file.content_type:
        evidence_type = "document"

    from uuid import uuid4
    evidence = DisputeEvidence(
        id=uuid4(), dispute_id=dispute_id,
        uploaded_by=user.id, evidence_type=evidence_type,
        file_url=result["url"], description=description,
    )
    db.add(evidence)

    dispute.status = DisputeStatus.EVIDENCE_SUBMITTED
    await db.commit()

    return SuccessResponse(message="Evidence uploaded", data={"id": str(evidence.id), "file_url": result["url"]})

@router.get("/{dispute_id}/evidence", response_model=SuccessResponse)
async def list_dispute_evidence(dispute_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    dispute_result = await db.execute(select(Dispute).where(Dispute.id == dispute_id))
    dispute = dispute_result.scalar_one_or_none()
    if not dispute:
        raise NotFound("Dispute not found")

    if not getattr(user, 'is_super_admin', False):
        if dispute.tenant_id != user.id and dispute.landlord_id != user.id:
            raise Forbidden("Access denied")

    evidence_result = await db.execute(
        select(DisputeEvidence).where(DisputeEvidence.dispute_id == dispute_id).order_by(DisputeEvidence.uploaded_at)
    )
    evidence = evidence_result.scalars().all()
    return SuccessResponse(data={"total": len(evidence), "evidence": evidence})

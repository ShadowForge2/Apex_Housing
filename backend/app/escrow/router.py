from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user, get_landlord, get_tenant, get_admin
from app.escrow.service import EscrowService
from app.escrow.models import EscrowTransaction
from app.escrow.schemas import AdminDecisionRequest
from sqlalchemy import select, func as sql_func
from app.users.models import User
from app.common.response import SuccessResponse

router = APIRouter(prefix="/escrow", tags=["Escrow"])

@router.post("/booking/{booking_id}", response_model=SuccessResponse)
async def create_escrow(booking_id: UUID, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.create_escrow(booking_id, user.id)
    return SuccessResponse(message="Escrow created", data={"id": str(escrow.id), "reference": escrow.escrow_reference})

@router.get("/{escrow_id}", response_model=SuccessResponse)
async def get_escrow(escrow_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.get_escrow(escrow_id)
    return SuccessResponse(data=escrow)

@router.get("/booking/{booking_id}", response_model=SuccessResponse)
async def get_escrow_by_booking(booking_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.get_escrow_by_booking(booking_id)
    return SuccessResponse(data=escrow)

@router.get("/{escrow_id}/history", response_model=SuccessResponse)
async def get_escrow_status_history(escrow_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.escrow.models import EscrowStatusHistory

    escrow_result = await db.execute(select(EscrowTransaction).where(EscrowTransaction.id == escrow_id))
    escrow = escrow_result.scalar_one_or_none()
    if not escrow:
        from app.common.exceptions import NotFound
        raise NotFound("Escrow not found")

    query = select(EscrowStatusHistory).where(EscrowStatusHistory.escrow_id == escrow_id)
    count_result = await db.execute(select(sql_func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.order_by(EscrowStatusHistory.created_at)
    result = await db.execute(query)
    history = result.scalars().all()
    return SuccessResponse(data={"total": total, "history": history})

@router.get("/{escrow_id}/transactions", response_model=SuccessResponse)
async def get_escrow_transactions(escrow_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.payments.models import Transaction

    escrow_result = await db.execute(select(EscrowTransaction).where(EscrowTransaction.id == escrow_id))
    escrow = escrow_result.scalar_one_or_none()
    if not escrow:
        from app.common.exceptions import NotFound
        raise NotFound("Escrow not found")

    result = await db.execute(
        select(Transaction).where(Transaction.escrow_id == escrow_id).order_by(Transaction.created_at)
    )
    transactions = result.scalars().all()
    return SuccessResponse(data={"total": len(transactions), "transactions": transactions})

@router.post("/{escrow_id}/hold", response_model=SuccessResponse)
async def hold_funds(escrow_id: UUID, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.funds_held(escrow_id)
    return SuccessResponse(message="Funds held in escrow. Timer starts after move-in confirmation.", data=escrow)

@router.post("/{escrow_id}/satisfied", response_model=SuccessResponse)
async def mark_satisfied(escrow_id: UUID, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.mark_satisfied(escrow_id, user.id)
    return SuccessResponse(message="Satisfied — funds released, booking completed, chat locked", data=escrow)

@router.post("/{escrow_id}/confirm-move-in", response_model=SuccessResponse)
async def confirm_move_in(escrow_id: UUID, user: User = Depends(get_tenant), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.confirm_move_in(escrow_id, user.id)
    return SuccessResponse(message="Move-in confirmed, 30-hour inspection timer started", data=escrow)

@router.post("/{escrow_id}/release", response_model=SuccessResponse)
async def release_funds(escrow_id: UUID, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.release_funds(escrow_id, user.id)
    return SuccessResponse(message="Funds released — booking completed, chat locked", data=escrow)

@router.post("/{escrow_id}/admin-decide", response_model=SuccessResponse)
async def admin_decide(escrow_id: UUID, body: AdminDecisionRequest, user: User = Depends(get_admin), db: AsyncSession = Depends(get_db)):
    service = EscrowService(db)
    escrow = await service.admin_decide(escrow_id, user.id, body)
    return SuccessResponse(message=f"Admin decision: {body.decision}", data=escrow)

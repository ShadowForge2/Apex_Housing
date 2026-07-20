from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime

from app.disputes.models import Dispute, DisputeEvidence, DisputeMessage
from app.disputes.schemas import DisputeCreate, DisputeUpdate, DisputeMessageCreate
from app.escrow.models import EscrowTransaction, EscrowStatusHistory
from app.common.enums import DisputeStatus, EscrowStatus, EscrowEvent
from app.common.exceptions import NotFound, BadRequest, Forbidden
from app.events.bus import event_bus
from app.events.types import DisputeOpenedEvent, DisputeResolvedEvent
import logging

logger = logging.getLogger(__name__)

VALID_RESOLUTIONS = {
    "REFUNDED_TO_TENANT",
    "RELEASED_TO_LANDLORD",
    "DISMISSED",
}


class DisputeService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def open_dispute(self, user_id: UUID, data: DisputeCreate) -> Dispute:
        escrow_result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.id == data.escrow_id)
        )
        escrow = escrow_result.scalar_one_or_none()
        if not escrow:
            raise NotFound("Escrow not found")
        if user_id != escrow.tenant_id and user_id != escrow.landlord_id:
            raise Forbidden("You are not a party to this escrow")
        if escrow.status not in (EscrowStatus.FUNDS_HELD, EscrowStatus.TIMER_RUNNING, EscrowStatus.MOVE_IN_CONFIRMED):
            raise BadRequest("Cannot open dispute for this escrow")

        dispute = Dispute(
            id=uuid4(), escrow_id=data.escrow_id,
            booking_id=data.booking_id,
            tenant_id=escrow.tenant_id,
            landlord_id=escrow.landlord_id,
            reported_by=user_id,
            status=DisputeStatus.OPEN,
            category=data.category,
            title=data.title,
            description=data.description,
        )
        self.db.add(dispute)
        await self.db.flush()

        for url in (data.evidence_urls or []):
            evidence = DisputeEvidence(
                id=uuid4(), dispute_id=dispute.id,
                uploaded_by=user_id, evidence_type="image",
                file_url=url,
            )
            self.db.add(evidence)

        escrow.status = EscrowStatus.DISPUTED
        escrow.dispute_opened_at = datetime.utcnow()
        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.DISPUTED,
            event_type=EscrowEvent.DISPUTE_OPENED,
            changed_by=user_id,
        )
        self.db.add(history)

        await self.db.commit()
        await self.db.refresh(dispute)

        await event_bus.emit("escrow.dispute_opened", DisputeOpenedEvent(
            dispute_id=dispute.id, escrow_id=data.escrow_id,
            booking_id=data.booking_id,
            opened_by=user_id, category=data.category,
        ))
        return dispute

    async def resolve_dispute(self, dispute_id: UUID, admin_id: UUID, resolution: str, notes: str = None) -> Dispute:
        result = await self.db.execute(
            select(Dispute).where(Dispute.id == dispute_id).with_for_update()
        )
        dispute = result.scalar_one_or_none()
        if not dispute:
            raise NotFound("Dispute not found")
        if dispute.status == DisputeStatus.RESOLVED:
            raise BadRequest("Dispute already resolved")

        if resolution not in VALID_RESOLUTIONS:
            raise BadRequest(f"Invalid resolution. Must be one of: {', '.join(VALID_RESOLUTIONS)}")

        dispute.status = DisputeStatus.RESOLVED
        dispute.resolution = resolution
        dispute.resolution_notes = notes
        dispute.resolved_by = admin_id
        dispute.resolved_at = datetime.utcnow()

        # Load the escrow to trigger the actual financial action
        escrow_result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.id == dispute.escrow_id).with_for_update()
        )
        escrow = escrow_result.scalar_one_or_none()

        if escrow and resolution == "REFUNDED_TO_TENANT":
            from app.escrow.service import EscrowService
            from app.escrow.schemas import AdminDecisionRequest
            escrow_service = EscrowService(self.db)
            await escrow_service.admin_decide(
                escrow.id, admin_id,
                AdminDecisionRequest(decision="refund", notes=notes or f"Dispute resolved: {resolution}")
            )
        elif escrow and resolution == "RELEASED_TO_LANDLORD":
            from app.escrow.service import EscrowService
            from app.escrow.schemas import AdminDecisionRequest
            escrow_service = EscrowService(self.db)
            await escrow_service.admin_decide(
                escrow.id, admin_id,
                AdminDecisionRequest(decision="release", notes=notes or f"Dispute resolved: {resolution}")
            )
        elif escrow and resolution == "DISMISSED":
            # Dismissed: restore escrow to pre-dispute status so normal flow resumes
            from app.common.enums import EscrowEvent
            previous_status = escrow._pre_dispute_status if hasattr(escrow, '_pre_dispute_status') else EscrowStatus.TIMER_RUNNING
            # Default to TIMER_RUNNING if timer was active, or FUNDS_HELD otherwise
            if escrow.hold_expires_at and escrow.hold_expires_at > datetime.utcnow():
                previous_status = EscrowStatus.TIMER_RUNNING
            else:
                previous_status = EscrowStatus.FUNDS_HELD
            escrow.status = previous_status
            escrow.resolution = "dismissed"
            escrow.resolution_at = datetime.utcnow()
            escrow.resolved_by = admin_id
            escrow.resolution_notes = notes or "Dispute dismissed — funds return to normal escrow flow"

            history = EscrowStatusHistory(
                id=uuid4(), escrow_id=escrow.id,
                status=previous_status,
                event_type=EscrowEvent.DISPUTE_OPENED,
                changed_by=admin_id,
                notes="Dispute dismissed — escrow restored",
            )
            self.db.add(history)

        await self.db.commit()
        await self.db.refresh(dispute)

        await event_bus.emit("dispute.resolved", DisputeResolvedEvent(
            dispute_id=dispute_id, escrow_id=dispute.escrow_id,
            booking_id=dispute.booking_id,
            resolution=resolution,
            resolved_by=admin_id,
        ))
        return dispute

    async def add_message(self, dispute_id: UUID, user_id: UUID, data: DisputeMessageCreate) -> DisputeMessage:
        dispute = await self.get_dispute(dispute_id)
        if dispute.status in (DisputeStatus.RESOLVED, DisputeStatus.CLOSED):
            raise BadRequest("Cannot add messages to a closed dispute")

        msg = DisputeMessage(
            id=uuid4(), dispute_id=dispute_id,
            sender_id=user_id, content=data.content,
            is_admin_note=data.is_admin_note,
        )
        self.db.add(msg)
        await self.db.commit()
        await self.db.refresh(msg)
        return msg

    async def get_dispute(self, dispute_id: UUID) -> Dispute:
        result = await self.db.execute(select(Dispute).where(Dispute.id == dispute_id))
        dispute = result.scalar_one_or_none()
        if not dispute:
            raise NotFound("Dispute not found")
        return dispute

    async def list_disputes(self, page: int = 1, page_size: int = 20, status: DisputeStatus = None, user=None) -> dict:
        from app.common.enums import UserRole
        query = select(Dispute)
        if user and not getattr(user, 'is_super_admin', False):
            if user.role == UserRole.TENANT:
                query = query.where(Dispute.tenant_id == user.id)
            elif user.role == UserRole.LANDLORD:
                query = query.where(Dispute.landlord_id == user.id)
        if status:
            query = query.where(Dispute.status == status)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Dispute.created_at.desc())
        result = await self.db.execute(query)
        return {"total": total, "disputes": result.scalars().all()}

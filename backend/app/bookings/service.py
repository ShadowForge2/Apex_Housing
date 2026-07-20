from uuid import UUID, uuid4
from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update
from typing import Optional
import secrets
from datetime import datetime, timezone

from app.bookings.models import Booking, BookingStatusHistory, ViewingSchedule
from app.bookings.schemas import BookingCreate, BookingStatusUpdate, ViewingScheduleCreate
from app.properties.models import Property, PropertyAvailability, PropertyPricing
from app.users.models import Tenant, Landlord, User, UserSignature
from app.common.enums import BookingStatus, PropertyStatus
from app.common.exceptions import NotFound, BadRequest, Forbidden
from app.events.bus import event_bus
from app.events.types import BookingCreatedEvent, BookingConfirmedEvent, BookingCancelledEvent, BookingCompletedEvent
from datetime import date as date_type, datetime as datetime_type

DEPOSIT_PERCENTAGE = Decimal("0.10")

def generate_booking_reference() -> str:
    return f"APX-{secrets.token_hex(4).upper()}"

class BookingService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_booking(self, tenant_id: UUID, data: BookingCreate) -> Booking:
        if not data.terms_agreed:
            raise BadRequest("You must agree to the agent's terms and conditions and platform terms before booking")

        tenant_result = await self.db.execute(select(User).where(User.id == tenant_id))
        tenant_user = tenant_result.scalar_one_or_none()

        effective_signature = data.signature_data
        if effective_signature and effective_signature.startswith("data:"):
            effective_signature = effective_signature.split(",", 1)[1]
        if not effective_signature:
            if tenant_user and tenant_user.signature_data:
                effective_signature = tenant_user.signature_data
            else:
                raise BadRequest("You must provide a signature. No stored signature found on your account.")
        elif len(effective_signature) < 50:
            raise BadRequest("Invalid signature. Must be at least 50 characters.")

        if not effective_signature:
            raise BadRequest("Signature required to complete booking")

        prop_result = await self.db.execute(
            select(Property).where(Property.id == data.property_id).with_for_update()
        )
        prop = prop_result.scalar_one_or_none()
        if not prop:
            raise NotFound("Property not found")
        if prop.status != PropertyStatus.ACTIVE:
            raise BadRequest("Property is not available for booking")

        avail_result = await self.db.execute(
            select(PropertyAvailability)
            .where(PropertyAvailability.property_id == data.property_id)
            .with_for_update()
        )
        avail = avail_result.scalar_one_or_none()
        if avail and not avail.is_available:
            raise BadRequest("Property is currently unavailable")
        if avail and avail.is_booked:
            raise BadRequest("Property is already booked")

        # Snapshot agent terms for the report (capture before listing gets deleted)
        agent_terms_snapshot = prop.agent_terms if prop else None

        # Validate tenant's requested dates fall within availability window
        if avail and avail.available_from and data.move_in_date:
            if data.move_in_date < avail.available_from:
                raise BadRequest(f"Requested start date must be on or after {avail.available_from}")
        if avail and avail.available_until and hasattr(data, 'lease_end_date') and data.lease_end_date:
            if data.lease_end_date > avail.available_until:
                raise BadRequest(f"Requested end date must be on or before {avail.available_until}")

        pricing_result = await self.db.execute(
            select(PropertyPricing).where(PropertyPricing.property_id == data.property_id)
        )
        pricing = pricing_result.scalar_one_or_none()
        rent_amount = pricing.rent_amount if pricing else Decimal("0.00")
        service_fee = pricing.service_fee if pricing else Decimal("0.00")

        from app.admin.service import AdminService
        admin_svc = AdminService(self.db)
        tenant_markup_pct = await admin_svc.get_setting_float("tenant_markup_percentage", 5.0)

        tenant_price = int(round(rent_amount * (Decimal("1") + Decimal(str(tenant_markup_pct / 100)))))

        # Security deposit: 10% of tenant's marked-up price
        security_deposit = round(tenant_price * DEPOSIT_PERCENTAGE, 2)

        # Total amount tenant pays
        total_amount = tenant_price + security_deposit + service_fee

        booking = Booking(
            id=uuid4(),
            property_id=data.property_id,
            tenant_id=tenant_id,
            landlord_id=prop.landlord_id,
            agent_id=prop.agent_id,
            status=BookingStatus.PENDING,
            booking_reference=generate_booking_reference(),
            viewing_date=data.viewing_date,
            viewing_time=data.viewing_time,
            viewing_notes=data.viewing_notes,
            move_in_date=data.move_in_date,
            lease_start_date=data.move_in_date,
            notes=data.notes,
            total_amount=total_amount,
            security_deposit=security_deposit,
            service_fee=service_fee,
            tenant_terms_agreed=True,
            tenant_terms_agreed_at=datetime.now(timezone.utc).replace(tzinfo=None),
            terms_text_snapshot=agent_terms_snapshot,
            tenant_signature_data=effective_signature,
        )
        self.db.add(booking)

        if data.signature_data and (not tenant_user or not tenant_user.signature_data):
            sig_record = UserSignature(
                id=uuid4(), user_id=tenant_id,
                signature_data=effective_signature, is_active=True, label="booking",
            )
            self.db.add(sig_record)
            if tenant_user:
                tenant_user.signature_data = effective_signature
                tenant_user.signature_created_at = datetime.now(timezone.utc).replace(tzinfo=None)

        # Lock the property — prevent edit/delete during booking
        if avail:
            avail.is_booked = True

        # Change property status to INACTIVE so no other tenant can book
        prop.status = PropertyStatus.INACTIVE.value

        status_history = BookingStatusHistory(
            id=uuid4(), booking_id=booking.id,
            status=BookingStatus.PENDING, changed_by=tenant_id,
        )
        self.db.add(status_history)

        await self.db.commit()
        await self.db.refresh(booking)

        await self._auto_create_escrow(booking)

        await event_bus.emit("booking.created", BookingCreatedEvent(
            booking_id=booking.id, property_id=data.property_id,
            tenant_id=tenant_id, landlord_id=prop.landlord_id,
            agent_id=prop.agent_id, triggered_by=tenant_id,
        ))

        return booking

    async def _auto_create_escrow(self, booking: Booking):
        from app.escrow.models import EscrowTransaction, EscrowStatusHistory
        from app.common.enums import EscrowStatus, EscrowEvent
        from app.payments.service import generate_reference

        # Platform fee calculated later at fund release time (Fix #4)
        # Using placeholder values here; actual calculation happens in EscrowService._calculate_commission
        escrow = EscrowTransaction(
            id=uuid4(), booking_id=booking.id,
            tenant_id=booking.tenant_id, landlord_id=booking.landlord_id,
            agent_id=booking.agent_id, property_id=booking.property_id,
            status=EscrowStatus.PENDING_PAYMENT,
            amount=booking.total_amount,
            security_deposit=booking.security_deposit,
            service_fee=booking.service_fee,
            agent_commission=Decimal("0.00"),  # Calculated at release time
            platform_fee=Decimal("0.00"),      # Calculated at release time
            currency="NGN",
            payment_reference=generate_reference("PAY"),
            escrow_reference=generate_reference("ESC"),
        )
        self.db.add(escrow)

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.PENDING_PAYMENT,
            event_type=EscrowEvent.PAYMENT_RECEIVED,
            changed_by=booking.tenant_id,
        )
        self.db.add(history)
        await self.db.commit()

    async def confirm_booking(self, booking_id: UUID, user_id: UUID) -> Booking:
        result = await self.db.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update()
        )
        booking = result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")
        if booking.status != BookingStatus.PENDING:
            raise BadRequest("Can only confirm pending bookings")
        if booking.tenant_id != user_id:
            raise Forbidden("Only the tenant can confirm this booking")

        # Fix #1: Verify payment was received before holding funds
        from app.payments.models import Transaction
        from app.common.enums import PaymentStatus
        from app.escrow.models import EscrowTransaction

        escrow_result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.booking_id == booking.id)
        )
        escrow = escrow_result.scalar_one_or_none()
        if not escrow:
            raise BadRequest("No escrow found for this booking")

        payment_result = await self.db.execute(
            select(Transaction).where(
                Transaction.escrow_id == escrow.id,
                Transaction.user_id == user_id,
                Transaction.status == PaymentStatus.SUCCESS,
            )
        )
        successful_payment = payment_result.scalar_one_or_none()
        if not successful_payment:
            raise BadRequest(
                "Payment not confirmed. Please complete payment before confirming your booking."
            )

        booking.status = BookingStatus.CONFIRMED

        history = BookingStatusHistory(
            id=uuid4(), booking_id=booking.id,
            status=BookingStatus.CONFIRMED, changed_by=user_id,
            notes="Booking confirmed, payment verified",
        )
        self.db.add(history)
        await self.db.commit()
        await self.db.refresh(booking)

        from app.escrow.service import EscrowService
        escrow_service = EscrowService(self.db)
        escrow = await escrow_service.get_escrow_by_booking(booking.id)
        await escrow_service.funds_held(escrow.id)

        # Fix #7: Create chat AFTER payment confirmation (not before)
        await self._auto_create_booking_conversation(booking)

        await event_bus.emit("booking.confirmed", BookingConfirmedEvent(
            booking_id=booking.id, property_id=booking.property_id,
            tenant_id=booking.tenant_id, triggered_by=user_id,
        ))

        return booking

    async def _auto_create_booking_conversation(self, booking: Booking):
        from app.messages.models import Conversation, ConversationParticipant

        conversation = Conversation(
            id=uuid4(), booking_id=booking.id,
        )
        self.db.add(conversation)
        await self.db.flush()

        participant_ids = {booking.tenant_id, booking.landlord_id}
        if booking.agent_id:
            participant_ids.add(booking.agent_id)

        for uid in participant_ids:
            participant = ConversationParticipant(
                id=uuid4(), conversation_id=conversation.id,
                user_id=uid, unread_count=0,
            )
            self.db.add(participant)

        await self.db.commit()

    async def get_booking(self, booking_id: UUID) -> Booking:
        result = await self.db.execute(
            select(Booking).where(Booking.id == booking_id)
        )
        booking = result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")
        return booking

    async def update_booking_status(self, booking_id: UUID, user_id: UUID, data: BookingStatusUpdate) -> Booking:
        result = await self.db.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update()
        )
        booking = result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")

        from app.common.enums import UserRole
        if data.status == BookingStatus.CANCELLED:
            if booking.tenant_id != user_id and booking.landlord_id != user_id:
                raise Forbidden("Only the tenant or landlord can cancel a booking")
            if data.cancellation_reason:
                booking.cancellation_reason = data.cancellation_reason
            from datetime import datetime, timezone
            booking.cancelled_at = datetime.now(timezone.utc).replace(tzinfo=None)

        # Guard: confirming a booking requires verified payment (use POST /confirm instead)
        if data.status == BookingStatus.CONFIRMED:
            raise BadRequest("Use POST /bookings/{id}/confirm to confirm a booking with payment verification")

        booking.status = data.status

        status_history = BookingStatusHistory(
            id=uuid4(), booking_id=booking.id,
            status=data.status, changed_by=user_id,
            notes=data.notes,
        )
        self.db.add(status_history)
        await self.db.commit()
        await self.db.refresh(booking)

        if data.status == BookingStatus.CANCELLED:
            from app.escrow.models import EscrowTransaction as EscrowTxn
            from app.common.enums import EscrowStatus as ES
            escrow_result2 = await self.db.execute(
                select(EscrowTxn).where(EscrowTxn.booking_id == booking.id)
            )
            escrow2 = escrow_result2.scalar_one_or_none()
            if escrow2 and escrow2.status not in (ES.REFUNDED, ES.RELEASED, ES.CANCELLED):
                from app.escrow.service import EscrowService
                escrow_svc = EscrowService(self.db)
                await escrow_svc.cancel_escrow(escrow2.id, user_id, reason=data.cancellation_reason or "")

            avail_result = await self.db.execute(
                select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
            )
            avail = avail_result.scalar_one_or_none()
            if avail:
                avail.is_booked = False

            # Restore property listing so it can be booked again
            from app.properties.models import Property as PropModel
            from app.common.enums import PropertyStatus as PS
            prop_result = await self.db.execute(
                select(PropModel).where(PropModel.id == booking.property_id)
            )
            prop = prop_result.scalar_one_or_none()
            if prop and prop.status in (PS.INACTIVE.value, PS.RENTED.value):
                prop.status = PS.ACTIVE.value

            await self.db.commit()

            await event_bus.emit("booking.cancelled", BookingCancelledEvent(
                booking_id=booking.id, cancelled_by=user_id,
                reason=data.cancellation_reason or "",
            ))
        elif data.status == BookingStatus.COMPLETED:
            avail_result = await self.db.execute(
                select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
            )
            avail = avail_result.scalar_one_or_none()
            if avail:
                avail.is_booked = False
                avail.is_available = False

            # Lock the booking chat when booking is manually completed
            from app.escrow.models import EscrowTransaction
            escrow_result = await self.db.execute(
                select(EscrowTransaction).where(EscrowTransaction.booking_id == booking.id)
            )
            escrow = escrow_result.scalar_one_or_none()
            if escrow:
                from app.escrow.service import EscrowService
                escrow_svc = EscrowService(self.db)
                await escrow_svc._lock_booking_chat(booking.id)

            await self.db.commit()

            await event_bus.emit("booking.completed", BookingCompletedEvent(
                booking_id=booking.id, completed_by=user_id, triggered_by=user_id,
            ))

        return booking

    async def list_bookings(
        self, page: int = 1, page_size: int = 20,
        tenant_id: UUID = None, landlord_id: UUID = None, status: str = None,
    ) -> dict:
        query = select(Booking)
        if tenant_id:
            query = query.where(Booking.tenant_id == tenant_id)
        if landlord_id:
            query = query.where(Booking.landlord_id == landlord_id)
        if status:
            try:
                query = query.where(Booking.status == BookingStatus(status).value)
            except ValueError:
                raise BadRequest(f"Invalid booking status: {status}")

        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()

        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Booking.created_at.desc())
        result = await self.db.execute(query)
        bookings = result.scalars().all()

        return {"total": total, "bookings": bookings}

    async def schedule_viewing(self, data: ViewingScheduleCreate, tenant_id: UUID) -> ViewingSchedule:
        schedule = ViewingSchedule(
            id=uuid4(), booking_id=data.booking_id,
            property_id=data.property_id, tenant_id=tenant_id,
            scheduled_date=data.scheduled_date, scheduled_time=data.scheduled_time,
            duration_minutes=data.duration_minutes, notes=data.notes,
            is_completed=False,
        )
        self.db.add(schedule)
        await self.db.commit()
        await self.db.refresh(schedule)
        return schedule

    async def cancel_booking(self, booking_id: UUID, user_id: UUID, reason: str = "") -> Booking:
        from app.common.enums import EscrowStatus
        from app.escrow.models import EscrowTransaction

        result = await self.db.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update()
        )
        booking = result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")

        if booking.tenant_id != user_id and booking.landlord_id != user_id:
            raise Forbidden("Only the tenant or landlord can cancel a booking")

        if booking.status in (BookingStatus.CANCELLED, BookingStatus.COMPLETED, BookingStatus.EXPIRED):
            raise BadRequest(f"Cannot cancel booking in '{booking.status.value}' status")

        booking.status = BookingStatus.CANCELLED
        booking.cancellation_reason = reason
        from datetime import datetime, timezone
        booking.cancelled_at = datetime.now(timezone.utc).replace(tzinfo=None)

        status_history = BookingStatusHistory(
            id=uuid4(), booking_id=booking.id,
            status=BookingStatus.CANCELLED, changed_by=user_id,
            notes=reason or "Booking cancelled",
        )
        self.db.add(status_history)

        escrow_result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.booking_id == booking.id)
        )
        escrow = escrow_result.scalar_one_or_none()

        if escrow and escrow.status not in (
            EscrowStatus.REFUNDED, EscrowStatus.RELEASED, EscrowStatus.CANCELLED
        ):
            from app.escrow.service import EscrowService
            escrow_service = EscrowService(self.db)
            await escrow_service.cancel_escrow(escrow.id, user_id, reason=reason)

        avail_result = await self.db.execute(
            select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
        )
        avail = avail_result.scalar_one_or_none()
        if avail:
            avail.is_booked = False

        # Restore property listing so it can be booked again
        from app.properties.models import Property as PropModel
        from app.common.enums import PropertyStatus as PS
        prop_result = await self.db.execute(
            select(PropModel).where(PropModel.id == booking.property_id)
        )
        prop = prop_result.scalar_one_or_none()
        if prop and prop.status in (PS.INACTIVE.value, PS.RENTED.value):
            prop.status = PS.ACTIVE.value

        await self.db.commit()
        await self.db.refresh(booking)

        await event_bus.emit("booking.cancelled", BookingCancelledEvent(
            booking_id=booking.id, cancelled_by=user_id,
            reason=reason or "",
        ))

        return booking

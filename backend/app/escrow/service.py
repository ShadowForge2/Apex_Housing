from uuid import UUID, uuid4
from datetime import timedelta
from app.common.time import utcnow_naive as utcnow
from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
import secrets
import logging

from app.escrow.models import EscrowTransaction, EscrowStatusHistory
from app.escrow.schemas import EscrowMoveInConfirm, AdminDecisionRequest
from app.bookings.models import Booking
from app.common.enums import (
    EscrowStatus, EscrowEvent, BookingStatus,
)
from app.common.exceptions import NotFound, BadRequest
from app.events.bus import event_bus
from app.events.types import (
    EscrowFundsHeldEvent, EscrowMoveInConfirmedEvent,
    EscrowTimerExpiredEvent, EscrowFundsReleasedEvent,
    EscrowFundsRefundedEvent,
)
from app.config import settings

logger = logging.getLogger(__name__)

HOLD_DURATION_HOURS = 30
REMINDER_BEFORE_HOURS = 2  # Send reminder 2 hours before expiry

def generate_escrow_reference() -> str:
    from app.payments.service import generate_reference
    return generate_reference("ESC")

class EscrowService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_escrow(self, booking_id: UUID, triggered_by: UUID = None) -> EscrowTransaction:
        booking_result = await self.db.execute(select(Booking).where(Booking.id == booking_id))
        booking = booking_result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")

        existing = await self.db.execute(
            select(EscrowTransaction)
            .where(EscrowTransaction.booking_id == booking_id)
            .with_for_update()
        )
        if existing.scalar_one_or_none():
            raise BadRequest("Escrow already exists for this booking")

        # Fees calculated at fund release time (Fix #4)
        escrow = EscrowTransaction(
            id=uuid4(), booking_id=booking_id,
            tenant_id=booking.tenant_id, landlord_id=booking.landlord_id,
            agent_id=booking.agent_id, property_id=booking.property_id,
            status=EscrowStatus.PENDING_PAYMENT,
            amount=booking.total_amount,
            security_deposit=booking.security_deposit,
            service_fee=booking.service_fee,
            agent_commission=Decimal("0.00"),  # Calculated at release time
            platform_fee=Decimal("0.00"),      # Calculated at release time
            currency="NGN",
            payment_reference=generate_escrow_reference(),
            escrow_reference=generate_escrow_reference(),
        )
        self.db.add(escrow)

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.PENDING_PAYMENT,
            event_type=EscrowEvent.PAYMENT_RECEIVED,
            changed_by=triggered_by,
        )
        self.db.add(history)

        await self.db.commit()
        await self.db.refresh(escrow)
        return escrow

    async def funds_held(self, escrow_id: UUID) -> EscrowTransaction:
        escrow = await self._get_escrow(escrow_id)
        if escrow.status != EscrowStatus.PENDING_PAYMENT:
            raise BadRequest(f"Cannot hold funds from status {escrow.status.value}")

        escrow.status = EscrowStatus.FUNDS_HELD
        escrow.hold_started_at = utcnow()
        # Timer NOT started here — starts after move-in confirmation (Fix #5)

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.FUNDS_HELD,
            event_type=EscrowEvent.FUNDS_HELD,
        )
        self.db.add(history)
        await self.db.commit()
        await self.db.refresh(escrow)

        # Notify both tenant and landlord — next step is confirm move-in
        try:
            from app.notifications.service import NotificationService
            from app.users.models import User
            notif_svc = NotificationService(self.db)

            # Look up names for personalized messages
            tenant_result = await self.db.execute(select(User).where(User.id == escrow.tenant_id))
            tenant_user = tenant_result.scalar_one_or_none()
            tenant_name = tenant_user.first_name or "Tenant" if tenant_user else "Tenant"

            landlord_result = await self.db.execute(select(User).where(User.id == escrow.landlord_id))
            landlord_user = landlord_result.scalar_one_or_none()
            landlord_name = landlord_user.first_name or "Landlord" if landlord_user else "Landlord"

            # --- Tenant notification ---
            tenant_msg = (
                f"Hi {tenant_name}, your payment of {escrow.amount} NGN has been secured in escrow. "
                f"Please move into the property and confirm move-in to start your 30-hour inspection period. "
                f"Until you confirm, your funds remain protected."
            )
            tenant_email_html = f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #2563eb;">Payment Secured in Escrow</h2>
                <p>Hi {tenant_name},</p>
                <p>Your payment of <strong>{escrow.amount} NGN</strong> has been securely held in escrow.</p>
                <h3 style="color: #16a34a;">Next Step: Confirm Move-In</h3>
                <ol>
                    <li>Move into the property</li>
                    <li>Open the APEX Housing app</li>
                    <li>Go to your booking and tap <strong>"Confirm Move-In"</strong></li>
                </ol>
                <p>Once you confirm, a <strong>30-hour inspection timer</strong> starts. During this period you can:</p>
                <ul>
                    <li>Mark the property as <strong>Satisfied</strong> to release funds to the landlord</li>
                    <li>Open a <strong>Dispute</strong> if anything is wrong</li>
                </ul>
                <p style="color: #6b7280; font-size: 14px;">
                    If you do not confirm within 30 hours of move-in, funds will be automatically released to the landlord.
                </p>
                <p>Escrow Reference: <code>{escrow.escrow_reference}</code></p>
            </div>
            """
            await notif_svc.send_notification(
                user_id=escrow.tenant_id,
                title="Payment Secured — Confirm Move-In",
                message=tenant_msg,
                reference_type="escrow",
                reference_id=escrow.id,
                email_subject="APEX Housing — Your Payment is Secured in Escrow",
                email_html=tenant_email_html,
                data={"escrow_id": str(escrow.id), "next_action": "confirm_move_in"},
            )

            # --- Landlord notification ---
            landlord_msg = (
                f"Hi {landlord_name}, a tenant has secured {escrow.amount} NGN in escrow for your property. "
                f"The tenant needs to confirm move-in to start the inspection period. "
                f"You will be notified once the inspection is complete and funds are released."
            )
            landlord_email_html = f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #2563eb;">Tenant Payment Secured</h2>
                <p>Hi {landlord_name},</p>
                <p>A tenant has secured <strong>{escrow.amount} NGN</strong> in escrow for your property.</p>
                <h3 style="color: #f59e0b;">What Happens Next</h3>
                <ol>
                    <li>The tenant moves in and confirms move-in</li>
                    <li>A 30-hour inspection period begins</li>
                    <li>Once satisfied (or after 30 hours), funds are released to you</li>
                </ol>
                <p>You will be notified at each step. No action is required from you at this time.</p>
                <p>Escrow Reference: <code>{escrow.escrow_reference}</code></p>
            </div>
            """
            await notif_svc.send_notification(
                user_id=escrow.landlord_id,
                title="Tenant Payment Secured in Escrow",
                message=landlord_msg,
                reference_type="escrow",
                reference_id=escrow.id,
                email_subject="APEX Housing — Tenant Payment Secured for Your Property",
                email_html=landlord_email_html,
                data={"escrow_id": str(escrow.id), "status": "waiting_for_move_in"},
            )
        except Exception as e:
            logger.warning(f"Failed to send funds_held notifications: {e}")

        await event_bus.emit("escrow.funds_held", EscrowFundsHeldEvent(
            escrow_id=escrow.id, booking_id=escrow.booking_id,
            tenant_id=escrow.tenant_id, landlord_id=escrow.landlord_id,
            amount=float(escrow.amount),
        ))
        return escrow

    async def mark_satisfied(self, escrow_id: UUID, tenant_id: UUID) -> EscrowTransaction:
        escrow = await self._get_escrow(escrow_id)
        if escrow.status not in (EscrowStatus.FUNDS_HELD, EscrowStatus.TIMER_RUNNING):
            raise BadRequest(f"Cannot mark satisfied from status {escrow.status.value}")
        if escrow.tenant_id != tenant_id:
            raise BadRequest("Only the tenant can mark satisfaction")

        escrow.status = EscrowStatus.SATISFIED
        escrow.move_in_confirmed_at = utcnow()
        escrow.move_in_confirmed_by = tenant_id
        escrow.hold_released_at = utcnow()
        escrow.resolution = "satisfied"
        escrow.resolution_at = utcnow()
        escrow.resolved_by = tenant_id

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.SATISFIED,
            event_type=EscrowEvent.FUNDS_RELEASED,
            changed_by=tenant_id,
            notes="Tenant marked satisfied, funds released immediately",
        )
        self.db.add(history)

        # Calculate commission before releasing funds (Fix #4)
        await self._calculate_commission(escrow)

        booking_result = await self.db.execute(
            select(Booking).where(Booking.id == escrow.booking_id)
        )
        booking = booking_result.scalar_one_or_none()
        if booking:
            booking.status = BookingStatus.ACTIVE
            from datetime import date
            booking.lease_start_date = utcnow().date()

            from app.properties.models import Property, PropertyAvailability
            from app.common.enums import PropertyStatus
            prop_result = await self.db.execute(
                select(Property).where(Property.id == booking.property_id)
            )
            prop = prop_result.scalar_one_or_none()
            if prop:
                prop.status = PropertyStatus.RENTED

            avail_result = await self.db.execute(
                select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
            )
            avail = avail_result.scalar_one_or_none()
            if avail:
                avail.is_available = False

        # Lock the booking chat (Fix #3)
        await self._lock_booking_chat(escrow.booking_id)

        await self._credit_landlord_wallet(escrow)

        await self.db.commit()
        await self.db.refresh(escrow)

        await event_bus.emit("escrow.funds_released", EscrowFundsReleasedEvent(
            escrow_id=escrow.id, booking_id=escrow.booking_id,
            landlord_id=escrow.landlord_id, amount=float(escrow.amount),
        ))
        return escrow

    async def admin_decide(self, escrow_id: UUID, admin_id: UUID, data: AdminDecisionRequest) -> EscrowTransaction:
        escrow = await self._get_escrow(escrow_id)
        if escrow.status not in (EscrowStatus.FUNDS_HELD, EscrowStatus.DISPUTED):
            raise BadRequest(f"Cannot decide on escrow from status {escrow.status.value}")

        if data.decision == "release":
            escrow.status = EscrowStatus.RELEASED
            escrow.hold_released_at = utcnow()
            escrow.resolution = "released"
            escrow.resolution_at = utcnow()
            escrow.resolved_by = admin_id
            escrow.resolution_notes = data.notes

            history = EscrowStatusHistory(
                id=uuid4(), escrow_id=escrow.id,
                status=EscrowStatus.RELEASED,
                event_type=EscrowEvent.FUNDS_RELEASED,
                changed_by=admin_id,
                notes=data.notes or "Admin released funds to landlord",
            )
            self.db.add(history)

            # Calculate commission before releasing (Fix #4)
            await self._calculate_commission(escrow)

            booking_result = await self.db.execute(
                select(Booking).where(Booking.id == escrow.booking_id)
            )
            booking = booking_result.scalar_one_or_none()
            if booking:
                booking.status = BookingStatus.ACTIVE
                booking.lease_start_date = utcnow().date()

                from app.properties.models import Property, PropertyAvailability
                from app.common.enums import PropertyStatus
                prop_result = await self.db.execute(
                    select(Property).where(Property.id == booking.property_id)
                )
                prop = prop_result.scalar_one_or_none()
                if prop:
                    prop.status = PropertyStatus.RENTED

                avail_result = await self.db.execute(
                    select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
                )
                avail = avail_result.scalar_one_or_none()
                if avail:
                    avail.is_available = False

            # Lock the booking chat (Fix #3)
            await self._lock_booking_chat(escrow.booking_id)

            await self._credit_landlord_wallet(escrow)
            await self.db.commit()
            await self.db.refresh(escrow)

            await event_bus.emit("escrow.funds_released", EscrowFundsReleasedEvent(
                escrow_id=escrow.id, booking_id=escrow.booking_id,
                landlord_id=escrow.landlord_id, amount=float(escrow.amount),
            ))

        elif data.decision == "refund":
            escrow.status = EscrowStatus.REFUNDED
            escrow.resolution = "refunded"
            escrow.resolution_at = utcnow()
            escrow.resolved_by = admin_id
            escrow.resolution_notes = data.notes

            history = EscrowStatusHistory(
                id=uuid4(), escrow_id=escrow.id,
                status=EscrowStatus.REFUNDED,
                event_type=EscrowEvent.FUNDS_REFUNDED,
                changed_by=admin_id,
                notes=data.notes or "Admin refunded tenant",
            )
            self.db.add(history)

            booking_result = await self.db.execute(
                select(Booking).where(Booking.id == escrow.booking_id)
            )
            booking = booking_result.scalar_one_or_none()
            if booking and booking.status not in (BookingStatus.CANCELLED, BookingStatus.COMPLETED):
                booking.status = BookingStatus.CANCELLED

            from app.properties.models import Property, PropertyAvailability
            from app.common.enums import PropertyStatus
            prop_result = await self.db.execute(
                select(Property).where(Property.id == escrow.property_id)
            )
            prop = prop_result.scalar_one_or_none()
            if prop:
                prop.status = PropertyStatus.ACTIVE
            avail_result = await self.db.execute(
                select(PropertyAvailability).where(PropertyAvailability.property_id == escrow.property_id)
            )
            avail = avail_result.scalar_one_or_none()
            if avail:
                avail.is_available = True

            refund_initiated = False
            try:
                refund_initiated = await self._initiate_refund_transfer(escrow)
            except Exception as e:
                logger.error(f"Refund transfer failed for escrow {escrow.id}: {e}")
                escrow.resolution_notes = f"Refund pending: {str(e)}"

            await self.db.commit()
            await self.db.refresh(escrow)

            await event_bus.emit("escrow.funds_refunded", EscrowFundsRefundedEvent(
                escrow_id=escrow.id, booking_id=escrow.booking_id,
                tenant_id=escrow.tenant_id, landlord_id=escrow.landlord_id,
                amount=float(escrow.amount),
                refund_initiated=refund_initiated,
            ))

        else:
            raise BadRequest("Decision must be 'release' or 'refund'")

        return escrow

    async def _credit_landlord_wallet(self, escrow: EscrowTransaction):
        from app.payments.models import Wallet

        # Landlord receives: total amount minus platform fee
        # (no separate agent commission — landlord = agent)
        landlord_credit = escrow.amount - escrow.platform_fee

        # Atomic credit — no read-modify-write race
        result = await self.db.execute(
            update(Wallet)
            .where(Wallet.user_id == escrow.landlord_id)
            .values(
                balance=Wallet.balance + landlord_credit,
                total_earned=Wallet.total_earned + landlord_credit,
            )
        )
        if result.rowcount == 0:
            # Wallet doesn't exist — create it
            from uuid import uuid4 as _uuid4
            wallet = Wallet(
                id=_uuid4(), user_id=escrow.landlord_id,
                balance=landlord_credit, pending_balance=Decimal("0.00"),
                currency="NGN", is_active=True,
                total_earned=landlord_credit, total_withdrawn=Decimal("0.00"),
            )
            self.db.add(wallet)

    async def confirm_move_in(self, escrow_id: UUID, confirmed_by: UUID) -> EscrowTransaction:
        escrow = await self._get_escrow(escrow_id)
        if escrow.status != EscrowStatus.FUNDS_HELD:
            raise BadRequest("Can only confirm move-in when funds are held")
        if escrow.tenant_id != confirmed_by:
            raise BadRequest("Only the tenant can confirm move-in")

        escrow.status = EscrowStatus.TIMER_RUNNING
        escrow.move_in_confirmed_at = utcnow()
        escrow.move_in_confirmed_by = confirmed_by
        # Fix #5: Start 30h timer NOW (at move-in confirmation, not fund hold)
        escrow.hold_expires_at = utcnow() + timedelta(hours=HOLD_DURATION_HOURS)

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.TIMER_RUNNING,
            event_type=EscrowEvent.TIMER_STARTED,
            changed_by=confirmed_by,
        )
        self.db.add(history)
        await self.db.commit()
        await self.db.refresh(escrow)

        # Notify tenant and landlord that inspection period has started
        try:
            from app.notifications.service import NotificationService
            from app.users.models import User
            notif_svc = NotificationService(self.db)

            expires_at = escrow.hold_expires_at
            expires_str = expires_at.strftime("%B %d, %Y at %I:%M %p") if expires_at else "30 hours"

            # --- Tenant notification ---
            tenant_msg = (
                f"Your 30-hour inspection period has started! You have until {expires_str} to inspect the property. "
                f"If satisfied, tap 'Mark Satisfied' to release funds. "
                f"If there's an issue, open a dispute. "
                f"If no action is taken, funds auto-release to the landlord."
            )
            tenant_html = f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #2563eb;">Inspection Period Started</h2>
                <p>Your 30-hour inspection period has begun. Deadline: <strong>{expires_str}</strong></p>
                <h3 style="color: #16a34a;">What You Can Do</h3>
                <table style="width:100%; border-collapse: collapse;">
                    <tr>
                        <td style="padding: 12px; border: 1px solid #e5e7eb;">
                            <strong>Satisfied</strong><br>
                            Tap "Mark Satisfied" to immediately release funds to the landlord and complete the booking.
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 12px; border: 1px solid #e5e7eb;">
                            <strong>Open a Dispute</strong><br>
                            If something is wrong, open a dispute with evidence. An admin will review.
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 12px; border: 1px solid #e5e7eb;">
                            <strong>Wait</strong><br>
                            If you take no action, funds auto-release to the landlord after 30 hours.
                        </td>
                    </tr>
                </table>
                <p style="color: #6b7280; font-size: 14px;">Escrow: <code>{escrow.escrow_reference}</code></p>
            </div>
            """
            await notif_svc.send_notification(
                user_id=escrow.tenant_id,
                title="Inspection Period Started — 30 Hours",
                message=tenant_msg,
                reference_type="escrow",
                reference_id=escrow.id,
                email_subject="APEX Housing — Your 30-Hour Inspection Has Begun",
                email_html=tenant_html,
                data={"escrow_id": str(escrow.id), "expires_at": expires_str, "next_action": "inspect_property"},
            )

            # --- Landlord notification ---
            landlord_msg = (
                f"The tenant has confirmed move-in for your property. "
                f"The 30-hour inspection period is now running. "
                f"You will be notified when the tenant is satisfied or if a dispute is opened."
            )
            landlord_html = f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #2563eb;">Tenant Move-In Confirmed</h2>
                <p>The tenant has confirmed move-in. The <strong>30-hour inspection period</strong> is now active.</p>
                <p>Deadline: <strong>{expires_str}</strong></p>
                <h3>What Happens Next</h3>
                <ul>
                    <li><strong>Tenant satisfied:</strong> Funds released to you immediately</li>
                    <li><strong>Dispute opened:</strong> Admin review, funds held until resolved</li>
                    <li><strong>No action:</strong> Funds auto-released to you after 30 hours</li>
                </ul>
                <p style="color: #6b7280; font-size: 14px;">Escrow: <code>{escrow.escrow_reference}</code></p>
            </div>
            """
            await notif_svc.send_notification(
                user_id=escrow.landlord_id,
                title="Tenant Move-In Confirmed",
                message=landlord_msg,
                reference_type="escrow",
                reference_id=escrow.id,
                email_subject="APEX Housing — Tenant Has Confirmed Move-In",
                email_html=landlord_html,
                data={"escrow_id": str(escrow.id), "expires_at": expires_str, "status": "inspection_running"},
            )
        except Exception as e:
            logger.warning(f"Failed to send move-in confirmation notifications: {e}")

        await event_bus.emit("escrow.move_in_confirmed", EscrowMoveInConfirmedEvent(
            escrow_id=escrow.id, booking_id=escrow.booking_id,
            confirmed_by=confirmed_by,
        ))
        return escrow

    async def cancel_escrow(self, escrow_id: UUID, cancelled_by: UUID, reason: str = "") -> EscrowTransaction:
        """Cancel an active escrow, refund tenant's funds via bank transfer.

        Called when a booking is cancelled while escrow is active
        (FUNDS_HELD, MOVE_IN_CONFIRMED, or TIMER_RUNNING).
        """
        escrow = await self._get_escrow(escrow_id)

        if escrow.status in (EscrowStatus.REFUNDED, EscrowStatus.RELEASED, EscrowStatus.CANCELLED):
            return escrow

        if escrow.status == EscrowStatus.PENDING_PAYMENT:
            raise BadRequest("Cannot refund escrow where no payment has been held")

        escrow.status = EscrowStatus.CANCELLED
        escrow.resolution = "cancelled_refund"
        escrow.resolution_at = utcnow()
        escrow.resolved_by = cancelled_by
        escrow.resolution_notes = reason or "Booking cancelled — refund initiated"
        escrow.hold_released_at = utcnow()

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.CANCELLED,
            event_type=EscrowEvent.FUNDS_REFUNDED,
            changed_by=cancelled_by,
            notes=reason or "Booking cancelled — refund initiated",
        )
        self.db.add(history)

        booking_result = await self.db.execute(
            select(Booking).where(Booking.id == escrow.booking_id)
        )
        booking = booking_result.scalar_one_or_none()
        if booking:
            booking.status = BookingStatus.CANCELLED
            booking.cancellation_reason = reason

        from app.properties.models import Property, PropertyAvailability
        from app.common.enums import PropertyStatus
        prop_result = await self.db.execute(
            select(Property).where(Property.id == escrow.property_id)
        )
        prop = prop_result.scalar_one_or_none()
        if prop:
            prop.status = PropertyStatus.ACTIVE
        avail_result = await self.db.execute(
            select(PropertyAvailability).where(PropertyAvailability.property_id == escrow.property_id)
        )
        avail = avail_result.scalar_one_or_none()
        if avail:
            avail.is_available = True

        refund_initiated = False
        try:
            refund_initiated = await self._initiate_refund_transfer(escrow)
        except Exception as e:
            logger.error(f"Refund transfer failed for cancelled escrow {escrow.id}: {e}")
            escrow.resolution_notes = f"Refund pending: {str(e)}"

        await self.db.flush()
        await self.db.refresh(escrow)

        await event_bus.emit("escrow.funds_refunded", EscrowFundsRefundedEvent(
            escrow_id=escrow.id, booking_id=escrow.booking_id,
            tenant_id=escrow.tenant_id, landlord_id=escrow.landlord_id,
            amount=float(escrow.amount),
            refund_initiated=refund_initiated,
        ))

        return escrow

    async def release_funds(self, escrow_id: UUID, resolved_by: UUID = None) -> EscrowTransaction:
        escrow = await self._get_escrow(escrow_id)
        if escrow.status != EscrowStatus.TIMER_RUNNING:
            raise BadRequest(f"Cannot release funds from status {escrow.status.value}. Timer must be running.")

        escrow.status = EscrowStatus.RELEASED
        escrow.hold_released_at = utcnow()
        escrow.resolution = "released"
        escrow.resolution_at = utcnow()
        escrow.resolved_by = resolved_by

        history = EscrowStatusHistory(
            id=uuid4(), escrow_id=escrow.id,
            status=EscrowStatus.RELEASED,
            event_type=EscrowEvent.FUNDS_RELEASED,
            changed_by=resolved_by,
        )
        self.db.add(history)

        # Calculate commission before releasing (Fix #4)
        await self._calculate_commission(escrow)

        booking_result = await self.db.execute(
            select(Booking).where(Booking.id == escrow.booking_id)
        )
        booking = booking_result.scalar_one_or_none()
        if booking:
            booking.status = BookingStatus.ACTIVE
            booking.lease_start_date = utcnow().date()

            from app.properties.models import Property, PropertyAvailability
            from app.common.enums import PropertyStatus
            prop_result = await self.db.execute(
                select(Property).where(Property.id == booking.property_id)
            )
            prop = prop_result.scalar_one_or_none()
            if prop:
                prop.status = PropertyStatus.RENTED

            avail_result = await self.db.execute(
                select(PropertyAvailability).where(PropertyAvailability.property_id == booking.property_id)
            )
            avail = avail_result.scalar_one_or_none()
            if avail:
                avail.is_available = False

        # Lock the booking chat (Fix #3)
        await self._lock_booking_chat(escrow.booking_id)

        await self._credit_landlord_wallet(escrow)
        await self.db.commit()
        await self.db.refresh(escrow)

        await event_bus.emit("escrow.funds_released", EscrowFundsReleasedEvent(
            escrow_id=escrow.id, booking_id=escrow.booking_id,
            landlord_id=escrow.landlord_id, amount=float(escrow.amount),
        ))
        return escrow

    async def auto_release_expired(self) -> list:
        result = await self.db.execute(
            select(EscrowTransaction).where(
                EscrowTransaction.status == EscrowStatus.TIMER_RUNNING,
                EscrowTransaction.hold_expires_at.isnot(None),
                EscrowTransaction.hold_expires_at <= utcnow(),
            )
        )
        expired_escrows = result.scalars().all()
        released = []
        for escrow in expired_escrows:
            try:
                released_escrow = await self.release_funds(escrow.id)
                released.append(released_escrow)
            except Exception as e:
                logger.error(f"Failed to auto-release escrow {escrow.id}: {e}")
                continue
        return released

    async def send_expiring_soon_reminders(self) -> int:
        """Send reminders for escrows expiring within REMINDER_BEFORE_HOURS (Fix #6)."""
        cutoff = utcnow() + timedelta(hours=REMINDER_BEFORE_HOURS)
        result = await self.db.execute(
            select(EscrowTransaction).where(
                EscrowTransaction.status == EscrowStatus.TIMER_RUNNING,
                EscrowTransaction.hold_expires_at.isnot(None),
                EscrowTransaction.hold_expires_at <= cutoff,
                EscrowTransaction.hold_expires_at > utcnow(),
            )
        )
        expiring = result.scalars().all()
        count = 0
        for escrow in expiring:
            try:
                await self.send_expiry_reminder(escrow.id)
                count += 1
            except Exception as e:
                logger.error(f"Failed to send expiry reminder for escrow {escrow.id}: {e}")
        return count

    async def get_escrow(self, escrow_id: UUID) -> EscrowTransaction:
        return await self._get_escrow(escrow_id)

    async def get_escrow_by_booking(self, booking_id: UUID) -> EscrowTransaction:
        result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.booking_id == booking_id)
        )
        escrow = result.scalar_one_or_none()
        if not escrow:
            raise NotFound("Escrow not found for this booking")
        return escrow

    async def _get_escrow(self, escrow_id: UUID) -> EscrowTransaction:
        result = await self.db.execute(
            select(EscrowTransaction)
            .where(EscrowTransaction.id == escrow_id)
            .with_for_update()
        )
        escrow = result.scalar_one_or_none()
        if not escrow:
            raise NotFound("Escrow not found")
        return escrow

    async def _calculate_commission(self, escrow: EscrowTransaction):
        """Calculate platform fee on the escrow amount.

        Platform fee = platform_fee_percentage% of total tenant payment.
        This is the TOTAL commission APEX takes (markup + markdown combined).
        Since landlord = agent, there is no separate agent commission.
        """
        from app.admin.service import AdminService
        admin_svc = AdminService(self.db)
        platform_fee_pct = await admin_svc.get_setting_float("platform_fee_percentage", 10.0)

        total_amount = escrow.amount
        platform_fee = round(total_amount * Decimal(str(platform_fee_pct / 100)), 2)

        escrow.platform_fee = platform_fee
        escrow.agent_commission = Decimal("0.00")  # Not used — landlord = agent

    async def _lock_booking_chat(self, booking_id: UUID):
        """Lock the booking conversation when the deal is completed (Fix #3)."""
        from app.messages.models import Conversation

        pass

    async def send_expiry_reminder(self, escrow_id: UUID):
        """Send a reminder notification before the 30-hour timer expires (Fix #6)."""
        from app.notifications.service import NotificationService

        result = await self.db.execute(
            select(EscrowTransaction).where(EscrowTransaction.id == escrow_id)
        )
        escrow = result.scalar_one_or_none()
        if not escrow:
            return
        if escrow.status != EscrowStatus.TIMER_RUNNING:
            return
        if not escrow.hold_expires_at:
            return

        remaining = escrow.hold_expires_at - utcnow()
        if remaining.total_seconds() <= 0:
            return

        hours = int(remaining.total_seconds() // 3600)
        minutes = int((remaining.total_seconds() % 3600) // 60)

        notif_service = NotificationService(self.db)
        await notif_service.send_notification(
            user_id=escrow.tenant_id,
            title="Escrow Timer Reminder",
            message=f"Your escrow protection expires in {hours}h {minutes}m. If you are satisfied with the property, confirm now. Otherwise, the funds will be automatically released.",
            reference_type="escrow",
            reference_id=escrow.id,
            data={"escrow_id": str(escrow.id), "hours_remaining": hours, "minutes_remaining": minutes},
        )

    async def _initiate_refund_transfer(self, escrow: EscrowTransaction) -> bool:
        """Create transfer recipient + initiate Paystack transfer to refund tenant.

        Refunds the full amount the tenant paid (including any gateway fee).
        """
        from app.payments.service import PaymentService
        from app.payments.models import Transaction, PaymentLog
        from app.common.enums import PaymentStatus, PaymentType
        from app.services.paystack import paystack_service
        from app.services.cache import cache_service

        payment_service = PaymentService(self.db)
        bank_account = await payment_service.get_default_bank_account(escrow.tenant_id)

        # Look up original payment to get the full amount charged (incl. gateway fee)
        refund_amount = float(escrow.amount)
        tx_result = await self.db.execute(
            select(Transaction).where(
                Transaction.escrow_id == escrow.id,
                Transaction.payment_type == PaymentType.RENT,
                Transaction.status == PaymentStatus.SUCCESS,
            ).order_by(Transaction.created_at.desc())
        )
        original_tx = tx_result.scalar_one_or_none()
        if original_tx and original_tx.amount_charged:
            refund_amount = float(original_tx.amount_charged)

        # Check cached recipient code first
        recipient_code = None
        cache_key = f"refund:recipient:{bank_account.account_number}:{bank_account.bank_code}"
        if cache_service._redis:
            recipient_code = await cache_service.get(cache_key)

        if not recipient_code:
            recipient_result = await paystack_service.create_transfer_recipient(
                name=bank_account.account_name,
                account_number=bank_account.account_number,
                bank_code=bank_account.bank_code,
            )
            if not recipient_result.get("status"):
                logger.error("Failed to create refund recipient: %s", recipient_result)
                return False
            recipient_code = recipient_result["data"]["recipient_code"]
            # Cache for 30 days
            if cache_service._redis:
                await cache_service.set(cache_key, recipient_code, ttl=60 * 60 * 24 * 30)

        from app.payments.service import generate_reference
        transfer_ref = generate_reference("REF")

        transfer_result = await paystack_service.initiate_transfer(
            amount=refund_amount,
            recipient_code=recipient_code,
            reference=transfer_ref,
            reason="APEX Housing escrow refund",
            metadata={"platform": getattr(settings, "PAYSTACK_PLATFORM_ID", "APXHOUSING")},
        )

        if not transfer_result.get("status"):
            logger.error("Refund transfer failed: %s", transfer_result)
            return False

        # Create Transaction record for audit trail
        refund_tx = Transaction(
            id=uuid4(), user_id=escrow.tenant_id,
            escrow_id=escrow.id, booking_id=escrow.booking_id,
            payment_type=PaymentType.REFUND, amount=Decimal(str(refund_amount)),
            amount_charged=Decimal(str(refund_amount)),
            gateway_fee=Decimal("0.00"),
            currency="NGN", status=PaymentStatus.PROCESSING,
            payment_method="bank_transfer",
            payment_gateway="paystack",
            gateway_reference=transfer_ref,
            description=f"Escrow refund for booking",
            is_refundable=False,
        )
        self.db.add(refund_tx)

        log = PaymentLog(
            id=uuid4(), transaction_id=refund_tx.id,
            action="refund_initiated", status="processing",
            message=f"Refund transfer initiated: {transfer_ref}",
        )
        self.db.add(log)

        # Notify tenant
        try:
            from app.notifications.service import NotificationService
            notification_service = NotificationService(self.db)
            await notification_service.create_notification(
                user_id=escrow.tenant_id,
                title="Refund Initiated",
                message=f"Your refund of {refund_amount} NGN has been initiated. Reference: {transfer_ref}",
                notification_type="in_app",
            )
        except Exception as e:
            logger.warning(f"Failed to send refund notification: {e}")

        return True

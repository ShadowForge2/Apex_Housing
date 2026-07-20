"""
Event handlers - each module subscribes to events it cares about.
Import and register these in main.py startup.
"""
from app.events.bus import event_bus
from app.events.types import (
    BookingConfirmedEvent, BookingCreatedEvent, BookingCancelledEvent, BookingCompletedEvent,
    EscrowFundsHeldEvent, EscrowTimerExpiredEvent,
    EscrowDisputeOpenedEvent, EscrowFundsReleasedEvent, EscrowFundsRefundedEvent,
    EscrowMoveInConfirmedEvent,
    PaymentSuccessEvent, DisputeResolvedEvent, ReviewCreatedEvent,
    PropertyCreatedEvent, PropertyStatusChangedEvent,
    MessageSentEvent,
)
from app.services.email_templates import (
    booking_confirmed_email, escrow_release_email, dispute_opened_email,
    dispute_resolved_email, payment_receipt_email, report_ready_email,
    refund_processed_email, move_in_reminder_email,
)
import logging

logger = logging.getLogger(__name__)


async def _run_fraud_checks(db, user_id=None, booking_id=None, dispute_opened=False):
    try:
        from app.fraud.service import FraudDetectionService
        fraud = FraudDetectionService(db)
        if user_id:
            await fraud.check_rapid_bookings(user_id)
            await fraud.check_repeated_disputes(user_id)
            await fraud.check_rapid_withdrawals(user_id)
            await fraud.check_payment_failures(user_id)
        if dispute_opened and user_id and booking_id:
            await fraud.check_immediate_dispute(user_id, booking_id)
    except Exception as e:
        logger.error(f"Fraud check failed: {e}")


async def on_booking_created(data: BookingCreatedEvent):
    logger.info(f"Booking {data.booking_id} created - notifying landlord")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.users.models import User
    from app.properties.models import Property
    from sqlalchemy import select

    async with async_session() as db:
        try:
            prop_result = await db.execute(select(Property).where(Property.id == data.property_id))
            prop = prop_result.scalar_one_or_none()
            prop_title = prop.title if prop else "your property"

            notif_service = NotificationService(db)
            landlord_result = await db.execute(select(User).where(User.id == data.landlord_id))
            landlord = landlord_result.scalar_one_or_none()
            if landlord:
                from app.services.email_templates import wrap_email
                await notif_service.send_notification(
                    user_id=data.landlord_id,
                    title="New Booking Request",
                    message=f"A tenant has booked {prop_title}. Please review and confirm.",
                    reference_type="booking", reference_id=data.booking_id,
                    push_data={"booking_id": str(data.booking_id), "type": "booking_created"},
                    email_subject=f"New Booking Request — {prop_title}",
                    email_html=wrap_email(f"""
                        <h2 style="color:#1a1a2e; margin: 0 0 15px; font-size: 22px;">New Booking Request</h2>
                        <p style="margin: 0 0 12px;">A tenant has booked <strong>{prop_title}</strong>.</p>
                        <p style="margin: 0 0 12px;">Please review the booking and confirm it in the app.</p>
                    """),
                )
        except Exception as e:
            logger.error(f"Failed to notify landlord for booking {data.booking_id}: {e}")


async def on_booking_confirmed(data: BookingConfirmedEvent):
    logger.info(f"Booking {data.booking_id} confirmed - creating escrow + notifying")
    from app.database import async_session
    from app.escrow.service import EscrowService
    from app.notifications.service import NotificationService
    from app.services.email import email_service
    from app.users.models import User
    from app.bookings.models import Booking
    from app.properties.models import Property
    from sqlalchemy import select

    async with async_session() as db:
        try:
            escrow_service = EscrowService(db)
            await escrow_service.create_escrow(data.booking_id, data.triggered_by)
        except Exception as e:
            logger.error(f"Failed to create escrow for booking {data.booking_id}: {e}")

        await _run_fraud_checks(db, user_id=data.tenant_id, booking_id=data.booking_id)

        try:
            booking_result = await db.execute(select(Booking).where(Booking.id == data.booking_id))
            booking = booking_result.scalar_one_or_none()
            if booking:
                prop_result = await db.execute(select(Property).where(Property.id == booking.property_id))
                prop = prop_result.scalar_one_or_none()
                prop_title = prop.title if prop else "a property"

                notif_service = NotificationService(db)

                # Notify tenant: payment + chat activated
                await notif_service.send_notification(
                    user_id=booking.tenant_id,
                    title="Payment Confirmed — Chat Activated",
                    message=f"Payment for {prop_title} has been verified. Your conversation with the agent is now open.",
                    reference_type="booking", reference_id=data.booking_id,
                    push_data={"booking_id": str(data.booking_id), "type": "booking_confirmed"},
                    email_subject=f"Payment Confirmed — Chat Open for {prop_title}",
                    email_html=booking_confirmed_email(
                        booking.booking_reference or str(data.booking_id)[:8], prop_title
                    ),
                )

                # Fix #8: Notify landlord — chat is active
                await notif_service.send_notification(
                    user_id=booking.landlord_id,
                    title="New Booking — Chat Activated",
                    message=f"A tenant has booked {prop_title}. Payment confirmed. You can now communicate through the app.",
                    reference_type="booking", reference_id=data.booking_id,
                    push_data={"booking_id": str(data.booking_id), "type": "booking_confirmed"},
                    email_subject=f"New Booking — Chat Open for {prop_title}",
                    email_html=booking_confirmed_email(
                        booking.booking_reference or str(data.booking_id)[:8], prop_title
                    ),
                )

                # Fix #8: Notify agent — chat is active
                if booking.agent_id:
                    await notif_service.send_notification(
                        user_id=booking.agent_id,
                        title="New Booking — Chat Activated",
                        message=f"A tenant has booked {prop_title}. Payment confirmed. You can now communicate through the app.",
                        reference_type="booking", reference_id=data.booking_id,
                        push_data={"booking_id": str(data.booking_id), "type": "booking_confirmed"},
                        email_subject=f"New Booking — Chat Open for {prop_title}",
                        email_html=booking_confirmed_email(
                            booking.booking_reference or str(data.booking_id)[:8], prop_title
                        ),
                    )
        except Exception as e:
            logger.error(f"Failed to notify for booking {data.booking_id}: {e}")


async def on_booking_cancelled(data: BookingCancelledEvent):
    logger.info(f"Booking {data.booking_id} cancelled by {data.cancelled_by}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.bookings.models import Booking
    from app.properties.models import Property
    from sqlalchemy import select

    async with async_session() as db:
        try:
            notif_service = NotificationService(db)
            booking_result = await db.execute(select(Booking).where(Booking.id == data.booking_id))
            booking = booking_result.scalar_one_or_none()

            prop_title = "the property"
            if booking:
                prop_result = await db.execute(select(Property).where(Property.id == booking.property_id))
                prop = prop_result.scalar_one_or_none()
                prop_title = prop.title if prop else "the property"

                # Notify the other party
                other_user = booking.landlord_id if data.cancelled_by == booking.tenant_id else booking.tenant_id
                from app.services.email_templates import booking_cancelled_email
                await notif_service.send_notification(
                    user_id=other_user,
                    title="Booking Cancelled",
                    message=f"A booking for {prop_title} has been cancelled. Reason: {data.reason}",
                    reference_type="booking", reference_id=data.booking_id,
                    push_data={"booking_id": str(data.booking_id), "type": "booking_cancelled"},
                    email_subject=f"Booking Cancelled — {prop_title}",
                    email_html=booking_cancelled_email(
                        booking.booking_reference or str(data.booking_id)[:8], prop_title, data.reason
                    ),
                )
        except Exception as e:
            logger.error(f"Failed to notify for cancelled booking {data.booking_id}: {e}")


async def on_booking_completed(data: BookingCompletedEvent):
    logger.info(f"Booking {data.booking_id} completed")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.bookings.models import Booking
    from app.properties.models import Property
    from sqlalchemy import select

    async with async_session() as db:
        try:
            booking_result = await db.execute(select(Booking).where(Booking.id == data.booking_id))
            booking = booking_result.scalar_one_or_none()
            if booking:
                prop_result = await db.execute(select(Property).where(Property.id == booking.property_id))
                prop = prop_result.scalar_one_or_none()
                prop_title = prop.title if prop else "the property"

                notif_service = NotificationService(db)
                from app.services.email_templates import report_ready_email
                await notif_service.send_notification(
                    user_id=booking.tenant_id,
                    title="Booking Completed",
                    message=f"Your booking for {prop_title} has been completed successfully.",
                    reference_type="booking", reference_id=data.booking_id,
                    push_data={"booking_id": str(data.booking_id), "type": "booking_completed"},
                    email_subject=f"Booking Completed — {prop_title}",
                    email_html=report_ready_email(prop_title, booking.booking_reference or str(data.booking_id)[:8]),
                )
                if booking.landlord_id:
                    await notif_service.send_notification(
                        user_id=booking.landlord_id,
                        title="Booking Completed",
                        message=f"A booking for {prop_title} has been completed.",
                        reference_type="booking", reference_id=data.booking_id,
                        push_data={"booking_id": str(data.booking_id), "type": "booking_completed"},
                        email_subject=f"Booking Completed — {prop_title}",
                        email_html=report_ready_email(prop_title, booking.booking_reference or str(data.booking_id)[:8]),
                    )
        except Exception as e:
            logger.error(f"Failed to notify for completed booking {data.booking_id}: {e}")


async def on_escrow_funds_held(data: EscrowFundsHeldEvent):
    logger.info(f"Escrow {data.escrow_id} funds held - notifying landlord")
    from app.database import async_session
    from app.notifications.service import NotificationService
    async with async_session() as db:
        try:
            service = NotificationService(db)
            from app.services.email_templates import wrap_email
            await service.send_notification(
                user_id=data.landlord_id,
                title="Funds Held in Escrow",
                message=f"Tenant payment of {data.amount} NGN is now held in escrow for booking.",
                reference_type="escrow", reference_id=data.escrow_id,
                push_data={"escrow_id": str(data.escrow_id), "type": "funds_held"},
                email_subject="Escrow Payment Received",
                email_html=wrap_email(f"""
                    <h2 style="color:#1a1a2e; margin: 0 0 15px; font-size: 22px;">Escrow Payment Received</h2>
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #f8f9fa; border-radius: 8px; border-left: 4px solid #27ae60;">
                        <tr>
                            <td style="padding: 15px 20px;">
                                <p style="margin: 0 0 5px; font-size: 13px; color: #666;">Amount Held</p>
                                <p style="margin: 0; font-size: 24px; font-weight: bold; color: #27ae60;">{data.amount:,.2f} NGN</p>
                            </td>
                        </tr>
                    </table>
                    <p style="margin: 0 0 12px;">A tenant payment is now held securely in escrow.</p>
                    <p style="margin: 0;">The funds will be released after the tenant confirms move-in and the 30-hour timer expires.</p>
                """),
            )
        except Exception as e:
            logger.error(f"Failed to notify landlord for escrow {data.escrow_id}: {e}")


async def on_escrow_timer_expired(data: EscrowTimerExpiredEvent):
    logger.info(f"Escrow {data.escrow_id} timer expired - auto-releasing funds")
    from app.database import async_session
    from app.escrow.service import EscrowService
    async with async_session() as db:
        service = EscrowService(db)
        try:
            await service.release_funds(data.escrow_id)
        except Exception as e:
            logger.error(f"Failed to auto-release escrow {data.escrow_id}: {e}")


async def on_escrow_dispute_opened(data: EscrowDisputeOpenedEvent):
    logger.info(f"Dispute opened for escrow {data.escrow_id}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.users.models import User
    from app.disputes.models import Dispute
    from sqlalchemy import select

    async with async_session() as db:
        try:
            service = NotificationService(db)

            dispute_result = await db.execute(select(Dispute).where(Dispute.id == data.dispute_id))
            dispute = dispute_result.scalar_one_or_none()

            admin_result = await db.execute(
                select(User).where(User.role == "ADMIN").limit(1)
            )
            admin = admin_result.scalar_one_or_none()
            if admin:
                await service.send_notification(
                    user_id=admin.id,
                    title="New Dispute Opened",
                    message=f"A dispute has been opened for escrow {data.escrow_id}. Please review immediately.",
                    reference_type="dispute", reference_id=data.dispute_id,
                    push_data={"dispute_id": str(data.dispute_id), "type": "dispute_opened"},
                    email_subject="New Dispute Requires Review",
                    email_html=dispute_opened_email(str(data.dispute_id), str(data.escrow_id)),
                )

            if dispute:
                for uid in [dispute.tenant_id, dispute.landlord_id]:
                    if uid and uid != data.opened_by:
                        await service.send_notification(
                            user_id=uid,
                            title="Dispute Opened",
                            message=f"A dispute has been opened for your booking. You will be notified once resolved.",
                            reference_type="dispute", reference_id=data.dispute_id,
                        )
        except Exception as e:
            logger.error(f"Failed to notify for dispute on escrow {data.escrow_id}: {e}")

        await _run_fraud_checks(db, user_id=data.opened_by, booking_id=data.booking_id, dispute_opened=True)


async def on_escrow_funds_released(data: EscrowFundsReleasedEvent):
    logger.info(f"Escrow {data.escrow_id} funds released to landlord - generating report + commission")

    # CRITICAL: Dispatch commission Celery task to create CommissionLog
    try:
        from app.tasks.commission_tasks import calculate_commission
        calculate_commission.delay(str(data.booking_id), str(data.escrow_id))
        logger.info(f"Dispatched calculate_commission task for booking {data.booking_id}")
    except Exception as e:
        logger.error(f"CRITICAL: Failed to dispatch commission task for booking {data.booking_id}: {e}")

    from app.database import async_session
    from app.reports.service import BookingReportService
    from app.notifications.service import NotificationService
    from app.properties.models import Property
    from app.bookings.models import Booking
    from app.escrow.models import EscrowTransaction
    from sqlalchemy import select

    async with async_session() as db:
        # Generate booking report (snapshots everything before listing deletion)
        try:
            report_service = BookingReportService(db)
            report = await report_service.generate_report(data.booking_id, escrow_id=data.escrow_id)
            logger.info(f"Report {report.report_number} generated for booking {data.booking_id} (funds released)")
        except Exception as e:
            logger.error(f"Failed to generate report for booking {data.booking_id}: {e}")

        # Notify landlord
        try:
            service = NotificationService(db)
            prop_title = "your property"

            booking_result = await db.execute(
                select(Booking).join(EscrowTransaction, EscrowTransaction.booking_id == Booking.id)
                .where(EscrowTransaction.id == data.escrow_id)
            )
            booking = booking_result.scalar_one_or_none()
            if booking:
                prop_result = await db.execute(select(Property).where(Property.id == booking.property_id))
                prop = prop_result.scalar_one_or_none()
                if prop:
                    prop_title = prop.title

            await service.send_notification(
                user_id=data.landlord_id,
                title="Funds Released",
                message=f"Escrow funds of {data.amount} NGN have been released to your wallet for {prop_title}. Your booking report is now ready to download.",
                reference_type="escrow", reference_id=data.escrow_id,
                push_data={"escrow_id": str(data.escrow_id), "type": "funds_released"},
                email_subject="Escrow Funds Released - APEX Housing",
                email_html=escrow_release_email(data.amount, prop_title),
            )
        except Exception as e:
            logger.error(f"Failed to notify landlord for released escrow {data.escrow_id}: {e}")

        # Notify tenant that report is ready
        if booking:
            try:
                await service.send_notification(
                    user_id=booking.tenant_id,
                    title="Booking Report Ready",
                    message=f"Payment for {prop_title} has been successfully disbursed. Your official booking report is ready to download from your report history.",
                    reference_type="booking_report", reference_id=booking.id,
                    push_data={"booking_id": str(booking.id), "type": "report_ready"},
                    email_subject="Booking Report Ready - APEX Housing",
                    email_html=report_ready_email(prop_title, booking.booking_reference or str(booking.id)[:8]),
                )
            except Exception as e:
                logger.error(f"Failed to notify tenant for report {data.booking_id}: {e}")


async def on_escrow_funds_refunded(data: EscrowFundsRefundedEvent):
    logger.info(f"Escrow {data.escrow_id} funds refunded to tenant")
    from app.database import async_session
    from app.notifications.service import NotificationService

    async with async_session() as db:
        try:
            service = NotificationService(db)
            status_msg = "Refund has been initiated and will be processed shortly." if data.refund_initiated else "Refund has been processed."
            await service.send_notification(
                user_id=data.tenant_id,
                title="Refund Processed",
                message=f"Your refund of {data.amount} NGN has been processed. {status_msg}",
                reference_type="escrow", reference_id=data.escrow_id,
                push_data={"escrow_id": str(data.escrow_id), "type": "refund_processed"},
                email_subject="Refund Confirmation - APEX Housing",
                email_html=refund_processed_email(data.amount, status_msg),
            )
        except Exception as e:
            logger.error(f"Failed to notify tenant for refund on escrow {data.escrow_id}: {e}")

        if data.landlord_id:
            try:
                service = NotificationService(db)
                await service.send_notification(
                    user_id=data.landlord_id,
                    title="Escrow Refunded to Tenant",
                    message=f"Escrow funds of {data.amount} NGN have been refunded to the tenant. The booking has been cancelled.",
                    reference_type="escrow", reference_id=data.escrow_id,
                    push_data={"escrow_id": str(data.escrow_id), "type": "refund_to_tenant"},
                )
            except Exception as e:
                logger.error(f"Failed to notify landlord for refund on escrow {data.escrow_id}: {e}")


async def on_escrow_move_in_confirmed(data: EscrowMoveInConfirmedEvent):
    logger.info(f"Escrow {data.escrow_id} move-in confirmed by {data.confirmed_by}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.escrow.models import EscrowTransaction
    from sqlalchemy import select

    async with async_session() as db:
        try:
            service = NotificationService(db)
            escrow_result = await db.execute(select(EscrowTransaction).where(EscrowTransaction.id == data.escrow_id))
            escrow = escrow_result.scalar_one_or_none()
            if escrow:
                from app.services.email_templates import wrap_email
                await service.send_notification(
                    user_id=escrow.landlord_id,
                    title="Tenant Move-In Confirmed",
                    message=f"Tenant has confirmed move-in. The 30-hour inspection timer has started.",
                    reference_type="escrow", reference_id=data.escrow_id,
                    push_data={"escrow_id": str(data.escrow_id), "type": "move_in_confirmed"},
                    email_subject="Move-In Confirmed - APEX Housing",
                    email_html=wrap_email(f"""
                        <h2 style="color:#27ae60; margin: 0 0 15px; font-size: 22px;">Move-In Confirmed</h2>
                        <p style="margin: 0 0 12px;">The tenant has confirmed move-in. The <strong>30-hour inspection timer</strong> has started.</p>
                        <p style="margin: 0;">Funds will be automatically released after the timer expires unless a dispute is raised.</p>
                    """),
                )
        except Exception as e:
            logger.error(f"Failed to notify for move-in on escrow {data.escrow_id}: {e}")


async def on_payment_success(data: PaymentSuccessEvent):
    logger.info(f"Payment {data.transaction_id} succeeded")
    from app.database import async_session
    from app.notifications.service import NotificationService
    async with async_session() as db:
        try:
            service = NotificationService(db)
            await service.send_notification(
                user_id=data.user_id,
                title="Payment Successful",
                message=f"Your payment of {data.amount} NGN ({data.payment_type}) was successful.",
                reference_type="transaction", reference_id=data.transaction_id,
                push_data={"transaction_id": str(data.transaction_id), "type": "payment_success"},
                email_subject="Payment Receipt - APEX Housing",
                email_html=payment_receipt_email(data.amount, str(data.transaction_id)),
            )
        except Exception as e:
            logger.error(f"Failed to notify user {data.user_id} for payment {data.transaction_id}: {e}")

        await _run_fraud_checks(db, user_id=data.user_id)


async def on_dispute_resolved(data: DisputeResolvedEvent):
    logger.info(f"Dispute resolved with resolution: {data.resolution}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.disputes.models import Dispute
    from sqlalchemy import select

    async with async_session() as db:
        try:
            service = NotificationService(db)
            dispute_result = await db.execute(
                select(Dispute).where(Dispute.id == data.dispute_id)
            )
            dispute = dispute_result.scalar_one_or_none()
            if dispute:
                for uid in [dispute.tenant_id, dispute.landlord_id]:
                    if uid:
                        await service.send_notification(
                            user_id=uid,
                            title="Dispute Resolved",
                            message=f"Your dispute has been resolved. Resolution: {data.resolution}",
                            reference_type="dispute", reference_id=data.dispute_id,
                            push_data={"dispute_id": str(data.dispute_id), "type": "dispute_resolved"},
                            email_subject="Dispute Resolved - APEX Housing",
                            email_html=dispute_resolved_email(data.resolution),
                        )
        except Exception as e:
            logger.error(f"Failed to notify for resolved dispute {data.dispute_id}: {e}")


async def on_review_created(data: ReviewCreatedEvent):
    logger.info(f"Review created for {data.target_type} {data.target_id}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.users.models import User
    from app.bookings.models import Booking
    from app.properties.models import Property
    from sqlalchemy import select

    async with async_session() as db:
        try:
            service = NotificationService(db)
            notify_user_id = None
            if data.target_type == "PROPERTY":
                prop_result = await db.execute(select(Property).where(Property.id == data.target_id))
                prop = prop_result.scalar_one_or_none()
                if prop:
                    notify_user_id = prop.landlord_id
            elif data.target_type == "BOOKING":
                booking_result = await db.execute(select(Booking).where(Booking.id == data.target_id))
                booking = booking_result.scalar_one_or_none()
                if booking:
                    notify_user_id = booking.landlord_id

            if notify_user_id:
                await service.send_notification(
                    user_id=notify_user_id,
                    title="New Review Received",
                    message=f"You received a {data.rating}-star review.",
                    reference_type="review", reference_id=data.review_id,
                )
        except Exception as e:
            logger.error(f"Failed to notify for review {data.review_id}: {e}")


async def on_property_created(data: PropertyCreatedEvent):
    logger.info(f"Property {data.property_id} created - notifying admin for approval")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.users.models import User
    from sqlalchemy import select

    async with async_session() as db:
        try:
            service = NotificationService(db)
            # Notify all admins about new property awaiting approval
            admin_result = await db.execute(select(User).where(User.role == "ADMIN"))
            admins = admin_result.scalars().all()
            for admin in admins:
                await service.send_notification(
                    user_id=admin.id,
                    title="New Property Submitted",
                    message=f"A new property '{data.title}' has been submitted and requires review.",
                    reference_type="property", reference_id=data.property_id,
                )
        except Exception as e:
            logger.error(f"Failed to notify admin for property {data.property_id}: {e}")


async def on_property_status_changed(data: PropertyStatusChangedEvent):
    logger.info(f"Property {data.property_id} status changed: {data.old_status} -> {data.new_status}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.properties.models import Property
    from sqlalchemy import select

    async with async_session() as db:
        try:
            service = NotificationService(db)
            prop_result = await db.execute(select(Property).where(Property.id == data.property_id))
            prop = prop_result.scalar_one_or_none()
            if prop:
                status_messages = {
                    "active": "Your property has been approved and is now live.",
                    "rejected": "Your property submission has been rejected. Please review the feedback.",
                    "suspended": "Your property has been suspended. Please contact support.",
                    "draft": "Your property is now in draft status.",
                }
                msg = status_messages.get(data.new_status, f"Property status changed to {data.new_status}.")
                await service.send_notification(
                    user_id=prop.landlord_id,
                    title="Property Status Updated",
                    message=msg,
                    reference_type="property", reference_id=data.property_id,
                )
        except Exception as e:
            logger.error(f"Failed to notify for property status {data.property_id}: {e}")


async def on_message_sent(data: MessageSentEvent):
    logger.debug(f"Message {data.message_id} sent in conversation {data.conversation_id}")
    from app.database import async_session
    from app.notifications.service import NotificationService
    from app.messages.models import ConversationParticipant
    from sqlalchemy import select

    async with async_session() as db:
        try:
            result = await db.execute(
                select(ConversationParticipant).where(
                    ConversationParticipant.conversation_id == data.conversation_id,
                    ConversationParticipant.user_id != data.sender_id,
                    ConversationParticipant.is_active == True,
                )
            )
            participants = result.scalars().all()
            service = NotificationService(db)
            for p in participants:
                await service.send_notification(
                    user_id=p.user_id,
                    title="New Message",
                    message="You have a new message.",
                    reference_type="conversation", reference_id=data.conversation_id,
                )
        except Exception as e:
            logger.error(f"Failed to notify for message {data.message_id}: {e}")


async def register_all_handlers():
    event_bus.subscribe("booking.created", on_booking_created)
    event_bus.subscribe("booking.confirmed", on_booking_confirmed)
    event_bus.subscribe("booking.cancelled", on_booking_cancelled)
    event_bus.subscribe("booking.completed", on_booking_completed)
    event_bus.subscribe("escrow.funds_held", on_escrow_funds_held)
    event_bus.subscribe("escrow.timer_expired", on_escrow_timer_expired)
    event_bus.subscribe("escrow.dispute_opened", on_escrow_dispute_opened)
    event_bus.subscribe("escrow.funds_released", on_escrow_funds_released)
    event_bus.subscribe("escrow.funds_refunded", on_escrow_funds_refunded)
    event_bus.subscribe("escrow.move_in_confirmed", on_escrow_move_in_confirmed)
    event_bus.subscribe("payment.success", on_payment_success)
    event_bus.subscribe("dispute.resolved", on_dispute_resolved)
    event_bus.subscribe("review.created", on_review_created)
    event_bus.subscribe("property.created", on_property_created)
    event_bus.subscribe("property.status_changed", on_property_status_changed)
    event_bus.subscribe("message.sent", on_message_sent)
    logger.info("All event handlers registered (16 handlers)")

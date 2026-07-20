import logging
import asyncio
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.cleanup_tasks.cleanup_completed_bookings")
def cleanup_completed_bookings():
    """
    Delete completed booking data after 1 hour.
    Runs every 5 minutes. Removes:
    - Property images (Supabase storage)
    - Property videos (Supabase storage)
    - Property records
    - Booking records
    - Escrow records
    - Related messages/conversations
    """
    logger.info("Cleaning up completed bookings older than 1 hour")

    async def _cleanup():
        from datetime import datetime, timedelta
        from sqlalchemy import select, delete
        from app.database import async_session
        from app.bookings.models import Booking, BookingStatusHistory, ViewingSchedule
        from app.escrow.models import EscrowTransaction, EscrowStatusHistory
        from app.properties.models import Property, PropertyImage, PropertyVideo, PropertyLocation, PropertyFeature, PropertyPricing, PropertyAvailability
        from app.messages.models import Conversation, Message, MessageAttachment, MessageReadReceipt, ConversationParticipant
        from app.common.enums import BookingStatus, EscrowStatus

        cutoff = datetime.utcnow() - timedelta(hours=1)

        async with async_session() as db:
            result = await db.execute(
                select(Booking).where(
                    Booking.status == BookingStatus.COMPLETED,
                    Booking.lease_start_date.isnot(None),
                    Booking.created_at <= cutoff,
                )
            )
            stale_bookings = result.scalars().all()

            deleted_count = 0
            notified_count = 0
            for booking in stale_bookings:
                prop_result = await db.execute(
                    select(Property).where(Property.id == booking.property_id)
                )
                prop = prop_result.scalar_one_or_none()

                if prop:
                    # Notify landlord before deleting the listing
                    try:
                        from app.notifications.service import NotificationService
                        from app.users.models import User
                        from app.services.email_templates import wrap_email

                        landlord_result = await db.execute(
                            select(User).where(User.id == prop.landlord_id)
                        )
                        landlord = landlord_result.scalar_one_or_none()
                        if landlord:
                            notif_svc = NotificationService(db)
                            prop_title = prop.title or "your property"
                            removal_msg = (
                                f"Your listing '{prop_title}' has been automatically removed "
                                f"because the booking was completed and the tenant is satisfied. "
                                f"If you have a similar property to list, you can create a new listing."
                            )
                            removal_html = wrap_email(f"""
                                <h2 style="color:#2563eb; margin: 0 0 15px; font-size: 22px;">Listing Removed</h2>
                                <p style="margin: 0 0 12px;">Your listing <strong>{prop_title}</strong> has been automatically removed from APEX Housing.</p>
                                <p style="margin: 0 0 12px;">This happened because the tenant confirmed satisfaction with the property and the booking has been completed.</p>
                                <p style="margin: 0 0 12px;">If you have a similar property to list, you can create a new listing at any time from your dashboard.</p>
                                <p style="margin: 0; color: #6b7280; font-size: 14px;">
                                    Booking Reference: {booking.booking_reference or str(booking.id)[:8]}
                                </p>
                            """)
                            await notif_svc.send_notification(
                                user_id=prop.landlord_id,
                                title="Listing Removed — Booking Completed",
                                message=removal_msg,
                                reference_type="property",
                                reference_id=prop.id,
                                email_subject=f"APEX Housing — Your Listing '{prop_title}' Has Been Removed",
                                email_html=removal_html,
                                data={"property_id": str(prop.id), "reason": "booking_completed"},
                            )
                            notified_count += 1
                    except Exception as e:
                        logger.warning(f"Failed to notify landlord before deleting property {prop.id}: {e}")

                    image_result = await db.execute(
                        select(PropertyImage).where(PropertyImage.property_id == prop.id)
                    )
                    images = image_result.scalars().all()
                    for img in images:
                        await db.delete(img)

                    video_result = await db.execute(
                        select(PropertyVideo).where(PropertyVideo.property_id == prop.id)
                    )
                    videos = video_result.scalars().all()
                    for vid in videos:
                        await db.delete(vid)

                    loc_result = await db.execute(
                        select(PropertyLocation).where(PropertyLocation.property_id == prop.id)
                    )
                    loc = loc_result.scalar_one_or_none()
                    if loc:
                        await db.delete(loc)

                    feat_result = await db.execute(
                        select(PropertyFeature).where(PropertyFeature.property_id == prop.id)
                    )
                    for feat in feat_result.scalars().all():
                        await db.delete(feat)

                    pricing_result = await db.execute(
                        select(PropertyPricing).where(PropertyPricing.property_id == prop.id)
                    )
                    pricing = pricing_result.scalar_one_or_none()
                    if pricing:
                        await db.delete(pricing)

                    avail_result = await db.execute(
                        select(PropertyAvailability).where(PropertyAvailability.property_id == prop.id)
                    )
                    avail = avail_result.scalar_one_or_none()
                    if avail:
                        await db.delete(avail)

                    await db.delete(prop)

                conv_result = await db.execute(
                    select(Conversation).where(Conversation.booking_id == booking.id)
                )
                for conv in conv_result.scalars().all():
                    msg_result = await db.execute(
                        select(Message).where(Message.conversation_id == conv.id)
                    )
                    for msg in msg_result.scalars().all():
                        attach_result = await db.execute(
                            select(MessageAttachment).where(MessageAttachment.message_id == msg.id)
                        )
                        for att in attach_result.scalars().all():
                            await db.delete(att)

                        receipt_result = await db.execute(
                            select(MessageReadReceipt).where(MessageReadReceipt.message_id == msg.id)
                        )
                        for rec in receipt_result.scalars().all():
                            await db.delete(rec)

                        await db.delete(msg)

                    part_result = await db.execute(
                        select(ConversationParticipant).where(ConversationParticipant.conversation_id == conv.id)
                    )
                    for part in part_result.scalars().all():
                        await db.delete(part)

                    await db.delete(conv)

                history_result = await db.execute(
                    select(BookingStatusHistory).where(BookingStatusHistory.booking_id == booking.id)
                )
                for hist in history_result.scalars().all():
                    await db.delete(hist)

                view_result = await db.execute(
                    select(ViewingSchedule).where(ViewingSchedule.booking_id == booking.id)
                )
                for view in view_result.scalars().all():
                    await db.delete(view)

                escrow_result = await db.execute(
                    select(EscrowTransaction).where(EscrowTransaction.booking_id == booking.id)
                )
                escrow = escrow_result.scalar_one_or_none()
                if escrow:
                    escrow_hist_result = await db.execute(
                        select(EscrowStatusHistory).where(EscrowStatusHistory.escrow_id == escrow.id)
                    )
                    for eh in escrow_hist_result.scalars().all():
                        await db.delete(eh)
                    await db.delete(escrow)

                await db.delete(booking)
                deleted_count += 1

            await db.commit()
            logger.info(f"Cleaned up {deleted_count} completed bookings, notified {notified_count} landlords")

    _run_async(_cleanup())


@celery_app.task(name="app.tasks.cleanup_tasks.cleanup_expired_sessions")
def cleanup_expired_sessions():
    """Delete expired and inactive user sessions."""
    logger.info("Cleaning up expired user sessions")

    async def _cleanup():
        from datetime import datetime
        from sqlalchemy import delete
        from app.database import async_session
        from app.auth.models import UserSession

        async with async_session() as db:
            result = await db.execute(
                delete(UserSession).where(
                    (UserSession.expires_at < datetime.utcnow()) |
                    (UserSession.is_active == False)
                )
            )
            await db.commit()
            logger.info(f"Deleted {result.rowcount} expired/inactive sessions")

    _run_async(_cleanup())

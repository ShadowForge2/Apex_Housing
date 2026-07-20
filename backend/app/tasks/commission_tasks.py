import logging
import asyncio
from app.tasks.celery_app import celery_app
from app.config import settings

logger = logging.getLogger(__name__)


def _run_async(coro):
    asyncio.run(coro)


@celery_app.task(name="app.tasks.commission_tasks.calculate_commission")
def calculate_commission(booking_id: str, escrow_id: str):
    """Create CommissionLog after escrow release. Fees are pre-calculated on the escrow."""
    logger.info(f"Calculating commission for booking {booking_id}")

    async def _calculate():
        from uuid import UUID
        from decimal import Decimal
        from sqlalchemy import select
        from app.database import async_session
        from app.bookings.models import Booking
        from app.escrow.models import EscrowTransaction
        from app.commission.models import CommissionLog

        async with async_session() as db:
            booking_result = await db.execute(select(Booking).where(Booking.id == UUID(booking_id)))
            booking = booking_result.scalar_one_or_none()
            if not booking or not booking.agent_id:
                logger.info(f"No agent for booking {booking_id}, skipping commission")
                return

            escrow_result = await db.execute(select(EscrowTransaction).where(EscrowTransaction.id == UUID(escrow_id)))
            escrow = escrow_result.scalar_one_or_none()
            if not escrow:
                return

            total_amount = escrow.amount
            platform_fee = escrow.platform_fee or round(total_amount * Decimal("0.10"), 2)
            agent_commission = Decimal("0.00")  # Not used — landlord = agent

            # Check if CommissionLog already exists for this escrow
            existing = await db.execute(
                select(CommissionLog).where(CommissionLog.escrow_id == escrow.id)
            )
            if existing.scalar_one_or_none():
                logger.info(f"CommissionLog already exists for escrow {escrow_id}, skipping")
                return

            log = CommissionLog(
                booking_id=booking.id,
                escrow_id=escrow.id,
                agent_id=booking.agent_id,
                landlord_id=booking.landlord_id,
                base_amount=total_amount,
                commission_rate=Decimal("0.10"),
                commission_amount=platform_fee,
                platform_share=platform_fee,
                recipient_share=Decimal("0.00"),
                status="calculated",
                notes=f"Platform fee: {platform_fee}. Landlord payout: {total_amount - platform_fee}",
            )
            db.add(log)
            await db.commit()
            logger.info(f"Commission recorded for agent {booking.agent_id}: platform={platform_fee}, agent={agent_commission}")

    _run_async(_calculate())


@celery_app.task(name="app.tasks.commission_tasks.process_agent_payouts")
def process_agent_payouts():
    """Process pending agent commission payouts via Paystack.

    Looks up the agent's default bank account from the BankAccount table.
    Falls back to wallet withdrawal if no bank account found.
    """
    logger.info("Processing agent payouts")

    async def _process():
        from datetime import datetime
        from sqlalchemy import select
        from app.database import async_session
        from app.commission.models import CommissionLog
        from app.payments.models import BankAccount
        from app.services.paystack import paystack_service
        from app.services.cache import cache_service

        async with async_session() as db:
            result = await db.execute(
                select(CommissionLog).where(CommissionLog.status == "calculated").limit(50)
            )
            pending = result.scalars().all()
            processed = 0

            for log in pending:
                try:
                    if not log.agent_id:
                        log.status = "skipped"
                        log.notes = (log.notes or "") + " | No agent ID"
                        continue

                    bank_result = await db.execute(
                        select(BankAccount).where(
                            BankAccount.user_id == log.agent_id,
                            BankAccount.is_default == True,
                        )
                    )
                    bank_account = bank_result.scalar_one_or_none()

                    if not bank_account:
                        all_banks = await db.execute(
                            select(BankAccount).where(BankAccount.user_id == log.agent_id)
                        )
                        bank_account = all_banks.scalar_one_or_none()

                    if not bank_account:
                        log.status = "pending_bank"
                        log.notes = (log.notes or "") + " | Agent has no bank account on file"
                        logger.warning(f"Agent {log.agent_id} has no bank account for commission {log.id}")
                        continue

                    cache_key = f"payout:recipient:{log.agent_id}:{bank_account.account_number}:{bank_account.bank_code}"
                    recipient_code = None
                    if cache_service._redis:
                        recipient_code = await cache_service.get(cache_key)

                    if not recipient_code:
                        recipient_result = await paystack_service.create_transfer_recipient(
                            name=bank_account.account_name,
                            account_number=bank_account.account_number,
                            bank_code=bank_account.bank_code,
                        )
                        if not recipient_result.get("status"):
                            log.status = "failed"
                            log.notes = (log.notes or "") + f" | Failed to create recipient: {recipient_result.get('message', 'unknown error')}"
                            logger.error(f"Failed to create transfer recipient for agent {log.agent_id}: {recipient_result}")
                            continue
                        recipient_code = recipient_result["data"]["recipient_code"]
                        if cache_service._redis:
                            await cache_service.set(cache_key, recipient_code, ttl=60 * 60 * 24 * 30)

                    from app.payments.service import generate_reference
                    transfer_ref = generate_reference("AGT")

                    transfer_result = await paystack_service.initiate_transfer(
                        amount=float(log.recipient_share),
                        recipient_code=recipient_code,
                        reference=transfer_ref,
                        reason="APEX Housing agent commission payout",
                        metadata={"platform": getattr(settings, "PAYSTACK_PLATFORM_ID", "APXHOUSING")},
                    )

                    if transfer_result.get("status"):
                        log.status = "paid"
                        log.gateway_reference = transfer_ref
                        log.processed_at = datetime.utcnow()
                        log.notes = (log.notes or "") + f" | Paid via {transfer_ref} to {bank_account.bank_name}"
                        processed += 1
                        logger.info(f"Agent commission {log.id} paid: {log.recipient_share} NGN")
                    else:
                        log.status = "failed"
                        log.gateway_reference = transfer_ref
                        log.notes = (log.notes or "") + f" | Transfer failed: {transfer_result.get('message', 'unknown error')}"
                        logger.error(f"Transfer failed for commission {log.id}: {transfer_result}")

                except Exception as e:
                    logger.error(f"Failed to process commission {log.id}: {e}")
                    log.status = "failed"
                    log.notes = (log.notes or "") + f" | Error: {str(e)}"

            await db.commit()
            logger.info(f"Processed {processed}/{len(pending)} agent payouts")

    _run_async(_process())

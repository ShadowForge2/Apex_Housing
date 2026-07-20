"""
Webhook endpoint for Paystack events.

Mounted WITHOUT the API_V1_PREFIX because Paystack sends webhooks
directly to the root path (e.g. ``/webhooks/paystack``).

Handles:
- charge.success / charge.failed → PaymentService (tenant payments)
- transfer.success / transfer.failed / transfer.reversed → payout tracking
"""
import logging
from datetime import datetime

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from sqlalchemy import select, update

from app.config import settings
from app.database import async_session
from app.payments.models import Wallet, WalletWithdrawal
from app.services.paystack import paystack_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])


@router.post("/paystack", include_in_schema=False)
async def paystack_webhook(request: Request):
    body = await request.body()
    signature = request.headers.get("x-paystack-signature", "")

    if not settings.PAYSTACK_WEBHOOK_SECRET:
        logger.critical("PAYSTACK_WEBHOOK_SECRET is not set — rejecting webhook")
        return JSONResponse(status_code=500, content={"error": "Server misconfiguration"})

    if not paystack_service.verify_webhook_signature(body, signature, settings.PAYSTACK_WEBHOOK_SECRET):
        logger.warning("Invalid Paystack webhook signature")
        return JSONResponse(status_code=400, content={"error": "Invalid signature"})

    try:
        payload = await request.json()
    except Exception:
        return JSONResponse(status_code=400, content={"error": "Invalid JSON"})

    event_type = payload.get("event", "")
    data = payload.get("data", {})
    logger.info("Paystack webhook: event=%s", event_type)

    async with async_session() as db:
        try:
            if event_type == "charge.success":
                reference = data.get("reference")
                if reference:
                    from app.payments.service import PaymentService
                    svc = PaymentService(db)
                    await svc.verify_paystack_payment(reference)

            elif event_type in ("transfer.success", "transfer.failed", "transfer.reversed"):
                await _handle_transfer_event(db, event_type, data)

        except Exception as exc:
            logger.error("Webhook processing error: %s", exc, exc_info=True)
            await db.rollback()
        else:
            await db.commit()

    return {"status": "ok"}


async def _handle_transfer_event(db, event_type: str, data: dict):
    reference = data.get("reference")
    if not reference:
        return

    # 1. Check WalletWithdrawal (landlord/agent wallet withdrawals)
    result = await db.execute(
        select(WalletWithdrawal)
        .where(WalletWithdrawal.gateway_reference == reference)
        .with_for_update()
    )
    withdrawal = result.scalar_one_or_none()
    if withdrawal:
        await _handle_withdrawal_event(db, event_type, withdrawal)
        return

    # 2. Check CommissionLog (agent commission Paystack transfers)
    from app.commission.models import CommissionLog
    commission_result = await db.execute(
        select(CommissionLog)
        .where(CommissionLog.gateway_reference == reference)
        .with_for_update()
    )
    commission_log = commission_result.scalar_one_or_none()
    if commission_log:
        await _handle_commission_transfer_event(db, event_type, commission_log)
        return

    logger.info("No withdrawal or commission for ref %s — ignoring %s", reference, event_type)


async def _handle_withdrawal_event(db, event_type: str, withdrawal):
    if event_type == "transfer.success":
        if withdrawal.status in ("completed", "cancelled", "failed", "expired"):
            return
        withdrawal.status = "completed"
        withdrawal.processed_at = datetime.utcnow()

        wallet_result = await db.execute(
            select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
        )
        wallet = wallet_result.scalar_one_or_none()
        if wallet:
            wallet.pending_balance = wallet.pending_balance - withdrawal.amount
            wallet.total_withdrawn = wallet.total_withdrawn + withdrawal.amount
        logger.info("Withdrawal %s completed", withdrawal.id)

    elif event_type in ("transfer.failed", "transfer.reversed"):
        if withdrawal.status in ("failed", "expired", "completed", "cancelled"):
            return
        withdrawal.status = "failed" if event_type == "transfer.failed" else "reversed"

        wallet_result = await db.execute(
            select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
        )
        wallet = wallet_result.scalar_one_or_none()
        if wallet:
            wallet.pending_balance = wallet.pending_balance - withdrawal.amount
            wallet.balance = wallet.balance + withdrawal.amount
        logger.warning("Withdrawal %s %s", withdrawal.id, withdrawal.status)


async def _handle_commission_transfer_event(db, event_type: str, commission_log):
    if event_type == "transfer.success":
        if commission_log.status in ("paid", "failed", "skipped"):
            return
        commission_log.status = "paid"
        commission_log.processed_at = datetime.utcnow()
        commission_log.notes = (commission_log.notes or "") + " | Transfer confirmed by webhook"
        logger.info("Commission %s paid (webhook confirmed)", commission_log.id)

    elif event_type in ("transfer.failed", "transfer.reversed"):
        if commission_log.status in ("failed", "skipped", "paid"):
            return
        commission_log.status = "failed"
        commission_log.notes = (commission_log.notes or "") + f" | Transfer {event_type} (webhook)"
        logger.warning("Commission %s %s (webhook)", commission_log.id, event_type)

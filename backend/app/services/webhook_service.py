"""
Webhook service for Paystack event handling.
Verifies signatures and dispatches transfer lifecycle events.
"""
import hashlib
import hmac
import logging
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session
from app.payments.models import Wallet, WalletWithdrawal

logger = logging.getLogger(__name__)


class WebhookService:
    """Stateless helpers for Paystack webhook verification and event handling."""

    # ------------------------------------------------------------------
    # Signature verification
    # ------------------------------------------------------------------

    @staticmethod
    def verify_signature(payload: bytes, signature: str) -> bool:
        """Verify Paystack webhook signature using HMAC-SHA512.

        Returns ``True`` if the signature matches, ``False`` otherwise.
        """
        secret = settings.PAYSTACK_WEBHOOK_SECRET
        if not secret:
            logger.critical("PAYSTACK_WEBHOOK_SECRET not set — rejecting webhook")
            return False
        try:
            expected = hmac.new(
                secret.encode("utf-8"), payload, hashlib.sha512
            ).hexdigest()
            return hmac.compare_digest(expected, signature)
        except Exception as exc:
            logger.error("Webhook signature verification error: %s", exc)
            return False

    # ------------------------------------------------------------------
    # Transfer event handlers
    # ------------------------------------------------------------------

    @staticmethod
    async def handle_transfer_event(event_data: dict) -> bool:
        """Handle ``transfer.success``, ``transfer.failed``, and ``transfer.reversed``.

        Opens its own DB session so it can be called from the webhook endpoint
        without sharing the request session.

        Returns ``True`` if the event was processed, ``False`` otherwise.
        """
        event_type = event_data.get("event", "")
        data = event_data.get("data", {})
        reference = data.get("reference")
        transfer_code = data.get("transfer_code")

        if not reference and not transfer_code:
            logger.warning("Transfer event missing reference/transfer_code: %s", event_type)
            return False

        async with async_session() as db:
            try:
                result = await db.execute(
                    select(WalletWithdrawal).where(
                        WalletWithdrawal.gateway_reference == reference
                    )
                )
                withdrawal = result.scalar_one_or_none()

                if not withdrawal:
                    logger.info(
                        "No withdrawal found for reference %s — ignoring %s",
                        reference,
                        event_type,
                    )
                    return False

                if event_type == "transfer.success":
                    await _handle_transfer_success(db, withdrawal, data)
                elif event_type == "transfer.failed":
                    await _handle_transfer_failed(db, withdrawal, data)
                elif event_type == "transfer.reversed":
                    await _handle_transfer_reversed(db, withdrawal, data)
                else:
                    logger.info("Unhandled transfer event: %s", event_type)
                    return False

                await db.commit()
                return True

            except Exception as exc:
                await db.rollback()
                logger.error(
                    "Error handling %s for reference %s: %s",
                    event_type,
                    reference,
                    exc,
                    exc_info=True,
                )
                return False


# ------------------------------------------------------------------
# Private event handlers
# ------------------------------------------------------------------

async def _handle_transfer_success(
    db: AsyncSession, withdrawal: WalletWithdrawal, data: dict
):
    if withdrawal.status == "completed":
        logger.info("Withdrawal %s already completed — skipping", withdrawal.id)
        return

    withdrawal.status = "completed"
    withdrawal.processed_at = datetime.utcnow()

    await db.execute(
        update(Wallet)
        .where(Wallet.id == withdrawal.wallet_id)
        .values(
            pending_balance=Wallet.pending_balance - withdrawal.amount,
            total_withdrawn=Wallet.total_withdrawn + withdrawal.amount,
        )
    )

    logger.info(
        "Withdrawal %s completed via webhook (transfer=%s)",
        withdrawal.id,
        data.get("transfer_code"),
    )


async def _handle_transfer_failed(
    db: AsyncSession, withdrawal: WalletWithdrawal, data: dict
):
    if withdrawal.status in ("failed", "expired", "completed"):
        logger.info("Withdrawal %s already in terminal state — skipping", withdrawal.id)
        return

    withdrawal.status = "failed"

    await db.execute(
        update(Wallet)
        .where(Wallet.id == withdrawal.wallet_id)
        .values(
            pending_balance=Wallet.pending_balance - withdrawal.amount,
            balance=Wallet.balance + withdrawal.amount,
        )
    )

    logger.warning(
        "Withdrawal %s failed via webhook (transfer=%s, reason=%s)",
        withdrawal.id,
        data.get("transfer_code"),
        data.get("failure_reason", "unknown"),
    )


async def _handle_transfer_reversed(
    db: AsyncSession, withdrawal: WalletWithdrawal, data: dict
):
    if withdrawal.status in ("failed", "expired", "completed"):
        return

    withdrawal.status = "reversed"

    await db.execute(
        update(Wallet)
        .where(Wallet.id == withdrawal.wallet_id)
        .values(
            pending_balance=Wallet.pending_balance - withdrawal.amount,
            balance=Wallet.balance + withdrawal.amount,
        )
    )

    logger.warning(
        "Withdrawal %s reversed via webhook (transfer=%s)",
        withdrawal.id,
        data.get("transfer_code"),
    )

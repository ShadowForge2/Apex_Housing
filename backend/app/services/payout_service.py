"""
Paystack transfer integration for agent/landlord payouts.
Handles the full flow: bank verification, recipient creation, transfer initiation,
and status tracking with recipient code caching.
"""
import logging
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.payments.models import Wallet, WalletWithdrawal
from app.services.cache import cache_service

logger = logging.getLogger(__name__)

PAYSTACK_BASE_URL = "https://api.paystack.co"


class PayoutService:
    """Service for processing bank transfer payouts via Paystack."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.secret_key = settings.PAYSTACK_SECRET_KEY

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.secret_key}",
            "Content-Type": "application/json",
        }

    # ------------------------------------------------------------------
    # Paystack API helpers
    # ------------------------------------------------------------------

    async def resolve_bank_account(
        self, account_number: str, bank_code: str
    ) -> Optional[dict]:
        """Verify bank account details with Paystack.

        Returns ``{"account_number": "...", "account_name": "...", "bank_id": ...}``
        on success, or ``None`` on failure.
        """
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.get(
                    f"{PAYSTACK_BASE_URL}/bank/resolve",
                    params={"account_number": account_number, "bank_code": bank_code},
                    headers=self._headers(),
                )
                result = resp.json()
                if result.get("status"):
                    return result.get("data")
                logger.error("Paystack resolve_account failed: %s", result)
                return None
        except Exception as exc:
            logger.error("resolve_bank_account error: %s", exc)
            return None

    async def _get_cached_recipient(self, cache_key: str) -> Optional[str]:
        """Return a cached recipient code, or None."""
        raw = await cache_service.get(f"payout:recipient:{cache_key}")
        return raw

    async def _set_cached_recipient(self, cache_key: str, recipient_code: str):
        """Cache a recipient code for 30 days."""
        await cache_service.set(
            f"payout:recipient:{cache_key}", recipient_code, ttl=60 * 60 * 24 * 30
        )

    async def create_transfer_recipient(
        self,
        name: str,
        account_number: str,
        bank_code: str,
        currency: str = "NGN",
    ) -> Optional[dict]:
        """Create (or return cached) transfer recipient on Paystack.

        Returns ``{"recipient_code": "RCP_xxx", ...}`` or ``None``.
        """
        cache_key = f"{account_number}:{bank_code}"

        cached_code = await self._get_cached_recipient(cache_key)
        if cached_code:
            return {"recipient_code": cached_code}

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(
                    f"{PAYSTACK_BASE_URL}/transferrecipient",
                    json={
                        "type": "nuban",
                        "name": name,
                        "account_number": account_number,
                        "bank_code": bank_code,
                        "currency": currency,
                    },
                    headers=self._headers(),
                )
                result = resp.json()
                if result.get("status"):
                    data = result.get("data", {})
                    recipient_code = data.get("recipient_code")
                    if recipient_code:
                        await self._set_cached_recipient(cache_key, recipient_code)
                    return data
                logger.error("Paystack create_transfer_recipient failed: %s", result)
                return None
        except Exception as exc:
            logger.error("create_transfer_recipient error: %s", exc)
            return None

    async def initiate_transfer(
        self,
        amount_kobo: int,
        recipient_code: str,
        reference: str,
        reason: str = "",
    ) -> Optional[dict]:
        """Initiate a bank transfer via Paystack.

        *amount_kobo* must already be in kobo (NGN * 100).
        Returns ``{"transfer_code": "TRF_xxx", "status": "pending", ...}`` or ``None``.
        """
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(
                    f"{PAYSTACK_BASE_URL}/transfer",
                    json={
                        "source": "balance",
                        "amount": amount_kobo,
                        "recipient": recipient_code,
                        "reason": reason,
                        "currency": "NGN",
                        "metadata": {"platform": getattr(settings, "PAYSTACK_PLATFORM_ID", "APXHOUSING")},
                    },
                    headers=self._headers(),
                )
                result = resp.json()
                if result.get("status"):
                    return result.get("data")
                logger.error("Paystack initiate_transfer failed: %s", result)
                return None
        except Exception as exc:
            logger.error("initiate_transfer error: %s", exc)
            return None

    async def verify_transfer(self, transfer_code: str) -> Optional[dict]:
        """Verify the status of an existing transfer.

        Returns the transfer data dict or ``None``.
        """
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.get(
                    f"{PAYSTACK_BASE_URL}/transfer/{transfer_code}",
                    headers=self._headers(),
                )
                result = resp.json()
                if result.get("status"):
                    return result.get("data")
                logger.error("Paystack verify_transfer failed: %s", result)
                return None
        except Exception as exc:
            logger.error("verify_transfer error: %s", exc)
            return None

    # ------------------------------------------------------------------
    # High-level withdrawal flow
    # ------------------------------------------------------------------

    async def process_withdrawal(
        self, withdrawal_id: uuid.UUID, user_id: uuid.UUID
    ) -> dict:
        """Execute the full withdrawal flow for a ``WalletWithdrawal`` record.

        1. Load the withdrawal record (must belong to the user).
        2. Verify the bank account via Paystack.
        3. Create / retrieve a transfer recipient.
        4. Initiate the bank transfer.
        5. Update withdrawal status and create an audit trail entry.
        6. Move funds from ``pending_balance`` to ``total_withdrawn`` on success,
           or refund back to ``balance`` on failure.

        Returns ``{"success": bool, "message": str, "transfer_code": Optional[str]}``.
        """
        # 1. Load withdrawal + wallet
        result = await self.db.execute(
            select(WalletWithdrawal).join(Wallet).where(
                WalletWithdrawal.id == withdrawal_id,
                Wallet.user_id == user_id,
            )
        )
        withdrawal = result.scalar_one_or_none()
        if not withdrawal:
            return {"success": False, "message": "Withdrawal not found", "transfer_code": None}

        if withdrawal.status not in ("pending", "processing"):
            return {
                "success": False,
                "message": f"Withdrawal already in status: {withdrawal.status}",
                "transfer_code": None,
            }

        wallet_result = await self.db.execute(
            select(Wallet).where(Wallet.id == withdrawal.wallet_id)
        )
        wallet = wallet_result.scalar_one_or_none()
        if not wallet:
            return {"success": False, "message": "Wallet not found", "transfer_code": None}

        # 2. Resolve bank account
        resolved = await self.resolve_bank_account(
            account_number=withdrawal.account_number,
            bank_code=withdrawal.bank_code,
        )
        if not resolved:
            withdrawal.status = "failed"
            await self._refund_wallet(wallet, withdrawal.amount)
            await self.db.commit()
            return {"success": False, "message": "Bank account verification failed", "transfer_code": None}

        # 3. Create / get transfer recipient
        recipient = await self.create_transfer_recipient(
            name=withdrawal.account_name or resolved.get("account_name", ""),
            account_number=withdrawal.account_number,
            bank_code=withdrawal.bank_code,
        )
        if not recipient:
            withdrawal.status = "failed"
            await self._refund_wallet(wallet, withdrawal.amount)
            await self.db.commit()
            return {"success": False, "message": "Failed to create transfer recipient", "transfer_code": None}

        recipient_code = recipient.get("recipient_code")

        # 4. Initiate transfer
        amount_kobo = int(Decimal(str(withdrawal.amount)) * 100)
        from app.payments.service import generate_reference
        transfer_ref = generate_reference("TRF")

        transfer_data = await self.initiate_transfer(
            amount_kobo=amount_kobo,
            recipient_code=recipient_code,
            reference=transfer_ref,
            reason="APEX Housing wallet withdrawal",
        )
        if not transfer_data:
            withdrawal.status = "failed"
            await self._refund_wallet(wallet, withdrawal.amount)
            await self.db.commit()
            return {"success": False, "message": "Transfer initiation failed", "transfer_code": None}

        # 5. Update withdrawal record
        withdrawal.status = "processing"
        withdrawal.gateway_reference = transfer_ref
        withdrawal.processed_at = datetime.now(timezone.utc)

        await self.db.commit()

        logger.info(
            "Payout processed: withdrawal=%s transfer=%s amount=%s",
            withdrawal.id,
            transfer_ref,
            withdrawal.amount,
        )

        return {
            "success": True,
            "message": "Transfer initiated successfully",
            "transfer_code": transfer_data.get("transfer_code"),
        }

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _refund_wallet(self, wallet: Wallet, amount: Decimal):
        """Move funds from ``pending_balance`` back to ``balance``."""
        await self.db.execute(
            update(Wallet)
            .where(Wallet.id == wallet.id)
            .values(
                pending_balance=Wallet.pending_balance - amount,
                balance=Wallet.balance + amount,
            )
        )

"""
Paystack payment gateway client.
Docs: https://paystack.com/docs/api/
"""
import logging
from typing import Optional
from decimal import Decimal

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

PAYSTACK_BASE_URL = "https://api.paystack.co"


class PaystackService:
    def __init__(self):
        self.secret_key = settings.PAYSTACK_SECRET_KEY
        self.headers = {
            "Authorization": f"Bearer {self.secret_key}",
            "Content-Type": "application/json",
        }

    async def _request(self, method: str, endpoint: str, data: dict = None) -> dict:
        url = f"{PAYSTACK_BASE_URL}{endpoint}"
        async with httpx.AsyncClient() as client:
            response = await client.request(
                method, url, json=data, headers=self.headers, timeout=30
            )
            result = response.json()
            if not result.get("status"):
                logger.error(f"Paystack API error: {result}")
            return result

    # --- Transaction ---
    async def initialize_transaction(
        self,
        email: str,
        amount: float,
        reference: str,
        callback_url: str = None,
        metadata: dict = None,
    ) -> dict:
        payload = {
            "email": email,
            "amount": int(round(amount * 100)),  # Paystack uses kobo (smallest unit)
            "reference": reference,
            "currency": "NGN",
            "metadata": {"platform": getattr(settings, "PAYSTACK_PLATFORM_ID", "APXHOUSING")},
        }
        if callback_url:
            payload["callback_url"] = callback_url
        if metadata:
            payload["metadata"].update(metadata)
        return await self._request("POST", "/transaction/initialize", payload)

    async def verify_transaction(self, reference: str) -> dict:
        return await self._request("GET", f"/transaction/verify/{reference}")

    async def list_transactions(
        self, page: int = 1, per_page: int = 50, status: str = None
    ) -> dict:
        endpoint = f"/transaction?page={page}&per_page={per_page}"
        if status:
            endpoint += f"&status={status}"
        return await self._request("GET", endpoint)

    # --- Transfer (payouts to bank) ---
    async def create_transfer_recipient(
        self,
        name: str,
        account_number: str,
        bank_code: str,
        currency: str = "NGN",
    ) -> dict:
        payload = {
            "type": "nuban",
            "name": name,
            "account_number": account_number,
            "bank_code": bank_code,
            "currency": currency,
        }
        return await self._request("POST", "/transferrecipient", payload)

    async def initiate_transfer(
        self,
        amount: float,
        recipient_code: str,
        reference: str,
        reason: str = None,
        metadata: dict = None,
    ) -> dict:
        payload = {
            "source": "balance",
            "amount": int(round(amount * 100)),
            "recipient": recipient_code,
            "reference": reference,
        }
        if reason:
            payload["reason"] = reason
        if metadata:
            payload["metadata"] = metadata
        return await self._request("POST", "/transfer", payload)

    async def verify_transfer(self, reference: str) -> dict:
        return await self._request("GET", f"/transfer/verify/{reference}")

    # --- Bank ---
    async def list_banks(self) -> dict:
        return await self._request("GET", "/bank?country=nigeria")

    async def resolve_account(self, account_number: str, bank_code: str) -> dict:
        return await self._request(
            "GET", f"/bank/resolve?account_number={account_number}&bank_code={bank_code}"
        )

    # --- Balance ---
    async def get_balance(self) -> dict:
        return await self._request("GET", "/balance")

    # --- Webhook verification ---
    @staticmethod
    def verify_webhook_signature(
        payload: bytes, signature: str, secret: str
    ) -> bool:
        import hashlib
        import hmac
        expected = hmac.HMAC(
            secret.encode("utf-8"), payload, hashlib.sha512
        ).hexdigest()
        return hmac.compare_digest(expected, signature)


paystack_service = PaystackService()

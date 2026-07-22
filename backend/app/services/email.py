"""
Email service supporting SMTP, SendGrid, and Console (development).
All emails are wrapped with APEX Housing branded template.
"""
import logging
import asyncio
from typing import Optional
from abc import ABC, abstractmethod

import httpx

from app.config import settings
from app.services.email_templates import (
    wrap_email, otp_email, welcome_email, booking_confirmed_email,
    payment_receipt_email, escrow_release_email, password_reset_email,
    booking_cancelled_email, dispute_opened_email, dispute_resolved_email,
    move_in_reminder_email, report_ready_email, refund_processed_email,
    property_approved_email, property_rejected_email,
    kyc_approved_email, kyc_rejected_email, admin_dispute_alert_email,
    admin_invite_email,
)

logger = logging.getLogger(__name__)


class EmailProvider(ABC):
    @abstractmethod
    async def send(self, to: str, subject: str, html: str, text: str = None) -> bool:
        pass


class ConsoleEmailProvider(EmailProvider):
    async def send(self, to: str, subject: str, html: str, text: str = None) -> bool:
        logger.info(f"EMAIL TO: {to}")
        logger.info(f"SUBJECT: {subject}")
        if text:
            logger.info(f"TEXT: {text}")
        import re
        otp_match = re.search(r'letter-spacing:\s*10px[^>]*>\s*(\d{6})', html)
        if otp_match:
            logger.info(f"OTP CODE: {otp_match.group(1)}")
        logger.info(f"HTML length: {len(html)} chars")
        return True


class SMTPEmailProvider(EmailProvider):
    def __init__(self):
        self.host = settings.SMTP_HOST
        self.port = settings.SMTP_PORT
        self.username = settings.SMTP_USERNAME
        self.password = settings.SMTP_PASSWORD
        self.from_name = settings.SMTP_FROM_NAME
        self.from_email = settings.SMTP_FROM_EMAIL or self.username
        if "gmail" in self.host and "@" in self.from_email and self.from_email != self.username:
            logger.warning(f"Gmail SMTP detected but FROM '{self.from_email}' != username '{self.username}'. Using username as FROM.")
            self.from_email = self.username

    async def send(self, to: str, subject: str, html: str, text: str = None) -> bool:
        try:
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, self._send_sync, to, subject, html, text)
            logger.info(f"Email sent to {to}: {subject}")
            return True
        except Exception as e:
            logger.error(f"SMTP error sending to {to}: {e}")
            return False

    def _send_sync(self, to: str, subject: str, html: str, text: str = None) -> None:
        import smtplib
        from email.mime.text import MIMEText
        from email.mime.multipart import MIMEMultipart

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{self.from_name} <{self.from_email}>"
        msg["To"] = to

        if text:
            msg.attach(MIMEText(text, "plain"))
        msg.attach(MIMEText(html, "html"))

        with smtplib.SMTP(self.host, self.port, timeout=15) as server:
            server.starttls()
            server.login(self.username, self.password)
            server.sendmail(self.from_email, to, msg.as_string())


class ResendEmailProvider(EmailProvider):
    """Resend provider with automatic multi-key rotation.
    
    Supports comma-separated RESEND_API_KEYS for failover.
    When a key hits rate limit (429), automatically switches to the next key.
    Failed keys are cooled down for 60 seconds before retrying.
    """
    RATE_LIMIT_STATUS = 429
    COOLDOWN_SECONDS = 60

    def __init__(self):
        self.from_name = settings.SMTP_FROM_NAME or "APEX Housing"
        self.from_email = settings.SMTP_FROM_EMAIL or "support@apex-housing-api.onrender.com"

        # Build key list from RESEND_API_KEYS (comma-separated) or fall back to single RESEND_API_KEY
        raw = settings.RESEND_API_KEYS or settings.RESEND_API_KEY
        self._keys = [k.strip() for k in raw.split(",") if k.strip()]
        self._current_index = 0
        self._cooldowns: dict[str, float] = {}  # key -> unix timestamp when available again
        logger.info(f"Resend provider initialized with {len(self._keys)} API key(s)")

    def _get_available_key(self) -> Optional[str]:
        """Return the next available key, or None if all are on cooldown."""
        import time
        now = time.time()
        for _ in range(len(self._keys)):
            key = self._keys[self._current_index]
            cooldown_until = self._cooldowns.get(key, 0)
            if now >= cooldown_until:
                return key
            self._current_index = (self._current_index + 1) % len(self._keys)
        return None

    def _rotate_key(self, failed_key: str):
        """Mark key as on cooldown and move to next."""
        import time
        self._cooldowns[failed_key] = time.time() + self.COOLDOWN_SECONDS
        self._current_index = (self._current_index + 1) % len(self._keys)
        remaining = sum(1 for k, t in self._cooldowns.items() if time.time() < t)
        logger.warning(f"Resend key rotated. {remaining} key(s) on cooldown.")

    async def send(self, to: str, subject: str, html: str, text: str = None) -> bool:
        for attempt in range(len(self._keys)):
            api_key = self._get_available_key()
            if not api_key:
                logger.error("All Resend API keys are on cooldown. Email not sent.")
                return False

            success = await self._send_with_key(api_key, to, subject, html, text)
            if success:
                return True

            # Failed — rotate to next key and retry
            self._rotate_key(api_key)

        logger.error(f"Resend: all {len(self._keys)} keys failed for '{subject}' to {to}")
        return False

    async def _send_with_key(self, api_key: str, to: str, subject: str, html: str, text: str = None) -> bool:
        payload = {
            "from": f"{self.from_name} <{self.from_email}>",
            "to": [to],
            "subject": subject,
            "html": html,
        }
        if text:
            payload["text"] = text

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.resend.com/emails",
                json=payload,
                headers=headers,
                timeout=30,
            )
            if response.status_code in (200, 201):
                data = response.json()
                logger.info(f"Resend email sent to {to}: {subject} (id={data.get('id', '?')})")
                return True

            if response.status_code == self.RATE_LIMIT_STATUS:
                logger.warning(f"Resend rate limit hit on key ...{api_key[-6:]}. Rotating.")
                return False

            logger.error(f"Resend error (key ...{api_key[-6:]}): {response.status_code} {response.text}")
            return False


class SendGridEmailProvider(EmailProvider):
    def __init__(self):
        self.api_key = settings.SENDGRID_API_KEY
        self.from_email = settings.SENDGRID_FROM_EMAIL

    async def send(self, to: str, subject: str, html: str, text: str = None) -> bool:
        payload = {
            "personalizations": [{"to": [{"email": to}]}],
            "from": {"email": self.from_email, "name": settings.SMTP_FROM_NAME},
            "subject": subject,
            "content": [
                {"type": "text/html", "value": html},
            ],
        }
        if text:
            payload["content"].append({"type": "text/plain", "value": text})

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.sendgrid.com/v3/mail/send",
                json=payload,
                headers=headers,
                timeout=30,
            )
            if response.status_code in (200, 202):
                logger.info(f"SendGrid email sent to {to}: {subject}")
                return True
            logger.error(f"SendGrid error: {response.status_code} {response.text}")
            return False


class EmailService:
    _PLACEHOLDER_USERNAMES = {"your-email@gmail.com", "", "your_email@gmail.com"}

    def __init__(self):
        smtp_valid = (
            settings.SMTP_USERNAME
            and settings.SMTP_USERNAME not in self._PLACEHOLDER_USERNAMES
            and settings.SMTP_PASSWORD
            and settings.SMTP_PASSWORD not in {"your-app-password", "your_app_password", ""}
        )

        has_resend = bool(settings.RESEND_API_KEY or settings.RESEND_API_KEYS)

        if has_resend:
            self.provider = ResendEmailProvider()
            key_count = len([k for k in (settings.RESEND_API_KEYS or settings.RESEND_API_KEY).split(",") if k.strip()])
            logger.info(f"Email provider: Resend ({key_count} key(s) configured)")
        elif settings.EMAIL_PROVIDER == "sendgrid" and settings.SENDGRID_API_KEY:
            self.provider = SendGridEmailProvider()
            logger.info("Email provider: SendGrid")
        elif settings.ENVIRONMENT == "development":
            self.provider = ConsoleEmailProvider()
            logger.info("Email provider: CONSOLE (emails printed to log)")
        elif not smtp_valid:
            raise RuntimeError(
                "Production email delivery requires RESEND_API_KEYS (comma-separated), "
                "RESEND_API_KEY, SendGrid credentials, or valid SMTP_USERNAME and SMTP_PASSWORD."
            )
        else:
            self.provider = SMTPEmailProvider()
            logger.info(f"Email provider: SMTP ({settings.SMTP_USERNAME})")

    async def send(self, to: str, subject: str, html: str, text: str = None) -> bool:
        return await self.provider.send(to, subject, html, text)

    async def send_otp(self, to: str, otp: str, purpose: str = "verification") -> bool:
        html = otp_email(otp, purpose)
        return await self.send(to, f"APEX Housing - {purpose.title()} Code", html)

    async def send_welcome(self, to: str, name: str) -> bool:
        html = welcome_email(name)
        return await self.send(to, "Welcome to APEX Housing!", html)

    async def send_booking_confirmation(self, to: str, booking_ref: str, property_title: str) -> bool:
        html = booking_confirmed_email(booking_ref, property_title)
        return await self.send(to, f"Booking Confirmed - {booking_ref}", html)

    async def send_payment_receipt(self, to: str, amount: float, reference: str, receipt_url: str = None) -> bool:
        html = payment_receipt_email(amount, reference, receipt_url)
        return await self.send(to, f"Payment Receipt - {reference}", html)

    async def send_escrow_release(self, to: str, amount: float, property_title: str) -> bool:
        html = escrow_release_email(amount, property_title)
        return await self.send(to, "Escrow Funds Released", html)

    async def send_password_reset(self, to: str, reset_link: str) -> bool:
        html = password_reset_email(reset_link)
        return await self.send(to, "APEX Housing - Password Reset", html)

    async def send_booking_cancelled(self, to: str, booking_ref: str, property_title: str, reason: str) -> bool:
        html = booking_cancelled_email(booking_ref, property_title, reason)
        return await self.send(to, f"Booking Cancelled - {booking_ref}", html)

    async def send_dispute_opened(self, to: str, dispute_id: str, escrow_id: str) -> bool:
        html = dispute_opened_email(dispute_id, escrow_id)
        return await self.send(to, "New Dispute Opened - APEX Housing", html)

    async def send_dispute_resolved(self, to: str, resolution: str) -> bool:
        html = dispute_resolved_email(resolution)
        return await self.send(to, "Dispute Resolved - APEX Housing", html)

    async def send_move_in_reminder(self, to: str, property_title: str, hours_remaining: int) -> bool:
        html = move_in_reminder_email(property_title, hours_remaining)
        return await self.send(to, "Escrow Timer Reminder - APEX Housing", html)

    async def send_report_ready(self, to: str, property_title: str, report_number: str) -> bool:
        html = report_ready_email(property_title, report_number)
        return await self.send(to, "Booking Report Ready - APEX Housing", html)

    async def send_refund_processed(self, to: str, amount: float, status_msg: str) -> bool:
        html = refund_processed_email(amount, status_msg)
        return await self.send(to, "Refund Processed - APEX Housing", html)

    async def send_property_approved(self, to: str, property_title: str) -> bool:
        html = property_approved_email(property_title)
        return await self.send(to, f"Property Approved - {property_title}", html)

    async def send_property_rejected(self, to: str, property_title: str, reason: str = "") -> bool:
        html = property_rejected_email(property_title, reason)
        return await self.send(to, f"Property Not Approved - {property_title}", html)

    async def send_kyc_approved(self, to: str) -> bool:
        html = kyc_approved_email()
        return await self.send(to, "Identity Verified - APEX Housing", html)

    async def send_kyc_rejected(self, to: str, reason: str = "") -> bool:
        html = kyc_rejected_email(reason)
        return await self.send(to, "Verification Not Approved - APEX Housing", html)

    async def send_admin_dispute_alert(self, to: str, escrow_id: str) -> bool:
        html = admin_dispute_alert_email(escrow_id)
        return await self.send(to, "New Dispute Requires Review - APEX Housing", html)

    async def send_admin_invite(self, to: str, invited_by: str = "Super Admin") -> bool:
        html = admin_invite_email(invited_by)
        return await self.send(to, "You're Invited to APEX Housing Admin Team", html)


email_service = EmailService()

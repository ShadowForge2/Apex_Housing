from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from datetime import datetime, timedelta
import secrets
import logging

from app.payments.models import Transaction, Receipt, Wallet, PaymentLog, BankAccount
from app.payments.schemas import TransactionInitiate, WithdrawalRequest, BankAccountCreate
from app.common.enums import PaymentStatus, PaymentType
from app.common.exceptions import NotFound, BadRequest
from app.common.business_days import (
    can_withdraw_now, get_next_business_datetime, format_next_business_day,
)
from app.events.bus import event_bus
from app.events.types import PaymentSuccessEvent, PaymentFailedEvent
from app.services.paystack import paystack_service
from app.services.email import email_service
from app.notifications.service import NotificationService

logger = logging.getLogger(__name__)


def generate_reference(prefix: str = "APX") -> str:
    """Generate a reference tagged with the platform ID.

    Format: ``{PLATFORM_ID}-{PREFIX}-{RANDOM}``
    Paystack reference limit is 50 chars; we use 8-char random to stay safe.
    """
    from app.config import settings
    platform = getattr(settings, "PAYSTACK_PLATFORM_ID", "APX")
    return f"{platform}-{prefix}-{secrets.token_hex(4).upper()}"


class PaymentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def initiate_transaction(self, user_id: UUID, data: TransactionInitiate, user_email: str = None) -> dict:
        reference = generate_reference("PAY")

        # If escrow_id provided, use escrow amount (tenant's marked-up price)
        amount = data.amount
        if data.escrow_id:
            from app.escrow.models import EscrowTransaction
            escrow_result = await self.db.execute(
                select(EscrowTransaction).where(EscrowTransaction.id == data.escrow_id)
            )
            escrow = escrow_result.scalar_one_or_none()
            if escrow:
                amount = escrow.amount  # Tenant's payment amount (already marked up)

        # Calculate Paystack fee (customer pays the gateway fee)
        from app.config import settings
        from decimal import Decimal
        fee_pct = Decimal(str(settings.PAYSTACK_FEE_PERCENT))
        fee_cap = Decimal(str(settings.PAYSTACK_FEE_CAP))
        amount_decimal = Decimal(str(float(amount)))
        gateway_fee = min(amount_decimal * fee_pct / Decimal("100"), fee_cap)
        gateway_fee = gateway_fee.quantize(Decimal("0.01"))
        amount_charged = (amount_decimal + gateway_fee).quantize(Decimal("0.01"))

        transaction = Transaction(
            id=uuid4(), user_id=user_id,
            escrow_id=data.escrow_id, booking_id=data.booking_id,
            payment_type=data.payment_type, amount=amount,
            amount_charged=amount_charged,
            gateway_fee=gateway_fee,
            currency="NGN", status=PaymentStatus.PENDING,
            payment_method=data.payment_method,
            payment_gateway="paystack",
            gateway_reference=reference,
            description=data.description,
            is_refundable=True,
        )
        self.db.add(transaction)

        log = PaymentLog(
            id=uuid4(), transaction_id=transaction.id,
            action="initiated", status="pending",
            message=f"Transaction created with ref {reference}",
        )
        self.db.add(log)
        await self.db.commit()
        await self.db.refresh(transaction)

        paystack_response = None
        if user_email and paystack_service.secret_key:
            try:
                metadata = {
                    "transaction_id": str(transaction.id),
                    "user_id": str(user_id),
                    "payment_type": data.payment_type.value,
                    "platform": getattr(settings, "PAYSTACK_PLATFORM_ID", "APXHOUSING"),
                }
                if data.escrow_id:
                    metadata["escrow_id"] = str(data.escrow_id)
                if data.booking_id:
                    metadata["booking_id"] = str(data.booking_id)

                paystack_response = await paystack_service.initialize_transaction(
                    email=user_email,
                    amount=amount_charged,  # Customer pays amount + gateway fee
                    reference=reference,
                    metadata=metadata,
                )
            except Exception as e:
                log = PaymentLog(
                    id=uuid4(), transaction_id=transaction.id,
                    action="paystack_init_failed", status="failed",
                    message=str(e),
                )
                self.db.add(log)
                await self.db.commit()

        return {
            "transaction": transaction,
            "paystack_response": paystack_response,
            "reference": reference,
        }

    async def verify_paystack_payment(self, reference: str) -> Transaction:
        paystack_result = await paystack_service.verify_transaction(reference)

        if not paystack_result.get("status") or not paystack_result.get("data"):
            raise BadRequest("Payment verification failed with Paystack")

        data = paystack_result["data"]
        if data.get("status") != "success":
            raise BadRequest(f"Payment status: {data.get('status')}")

        result = await self.db.execute(
            select(Transaction).where(Transaction.gateway_reference == reference)
        )
        transaction = result.scalar_one_or_none()
        if not transaction:
            transaction_result = await self.db.execute(
                select(Transaction).where(Transaction.id == data["metadata"]["transaction_id"])
            )
            transaction = transaction_result.scalar_one_or_none()

        if not transaction:
            raise NotFound("Transaction not found")

        # Idempotency: skip if already processed
        if transaction.status == PaymentStatus.SUCCESS:
            return transaction

        transaction.status = PaymentStatus.SUCCESS
        transaction.payment_gateway = "paystack"
        transaction.gateway_reference = reference
        transaction.gateway_response = data

        # Update with actual gateway fee from Paystack (returned in kobo)
        actual_fee_kobo = data.get("fees", 0)
        if actual_fee_kobo:
            actual_fee = round(actual_fee_kobo / 100, 2)
            transaction.gateway_fee = actual_fee
            transaction.amount_charged = float(transaction.amount) + actual_fee

        log = PaymentLog(
            id=uuid4(), transaction_id=transaction.id,
            action="verified", status="success",
            message=f"Payment verified via Paystack",
            gateway_response=data,
        )
        self.db.add(log)
        await self.db.commit()

        await event_bus.emit("payment.success", PaymentSuccessEvent(
            transaction_id=transaction.id, user_id=transaction.user_id,
            amount=float(transaction.amount),
            payment_type=transaction.payment_type.value,
        ))

        from app.users.models import User as UserModel
        user_result = await self.db.execute(
            select(UserModel).where(UserModel.id == transaction.user_id)
        )
        tx_user = user_result.scalar_one_or_none()
        if tx_user and tx_user.email:
            await email_service.send_payment_receipt(
                to=tx_user.email, amount=float(transaction.amount), reference=reference
            )

        return transaction

    async def verify_payment(self, transaction_id: UUID, gateway_reference: str, payment_gateway: str, user_id: UUID = None) -> Transaction:
        filters = [Transaction.id == transaction_id]
        if user_id:
            filters.append(Transaction.user_id == user_id)
        result = await self.db.execute(select(Transaction).where(*filters))
        transaction = result.scalar_one_or_none()
        if not transaction:
            raise NotFound("Transaction not found")

        # Idempotency: skip if already processed
        if transaction.status == PaymentStatus.SUCCESS:
            return transaction

        transaction.status = PaymentStatus.SUCCESS
        transaction.payment_gateway = payment_gateway
        transaction.gateway_reference = gateway_reference

        log = PaymentLog(
            id=uuid4(), transaction_id=transaction.id,
            action="verified", status="success",
            message=f"Payment verified via {payment_gateway}",
        )
        self.db.add(log)
        await self.db.commit()

        await event_bus.emit("payment.success", PaymentSuccessEvent(
            transaction_id=transaction.id, user_id=transaction.user_id,
            amount=float(transaction.amount),
            payment_type=transaction.payment_type.value,
        ))
        return transaction

    async def get_wallet(self, user_id: UUID, lock: bool = False) -> Wallet:
        query = select(Wallet).where(Wallet.user_id == user_id)
        if lock:
            query = query.with_for_update()
        result = await self.db.execute(query)
        wallet = result.scalar_one_or_none()
        if not wallet:
            from sqlalchemy.exc import IntegrityError
            try:
                wallet = Wallet(
                    id=uuid4(), user_id=user_id,
                    balance=0, pending_balance=0,
                    currency="NGN", is_active=True,
                    total_earned=0, total_withdrawn=0,
                )
                self.db.add(wallet)
                await self.db.flush()
                await self.db.refresh(wallet)
            except IntegrityError:
                await self.db.rollback()
                result = await self.db.execute(select(Wallet).where(Wallet.user_id == user_id))
                wallet = result.scalar_one()
        return wallet

    # --- Bank Account Management ---

    async def add_bank_account(self, user_id: UUID, data: BankAccountCreate) -> BankAccount:
        # Verify account with Paystack first
        account_result = await paystack_service.resolve_account(
            account_number=data.account_number,
            bank_code=data.bank_code,
        )
        if not account_result.get("status"):
            raise BadRequest("Invalid bank account details")

        resolved_name = account_result.get("data", {}).get("account_name", "")

        # If setting as default, unset other defaults
        if data.is_default:
            result = await self.db.execute(
                select(BankAccount).where(
                    BankAccount.user_id == user_id,
                    BankAccount.is_default == True,
                )
            )
            for acc in result.scalars().all():
                acc.is_default = False

        bank_account = BankAccount(
            id=uuid4(), user_id=user_id,
            bank_name=data.bank_name, bank_code=data.bank_code,
            account_number=data.account_number,
            account_name=resolved_name,
            is_default=data.is_default,
            is_verified=True,
        )
        self.db.add(bank_account)
        await self.db.commit()
        await self.db.refresh(bank_account)
        return bank_account

    async def get_bank_accounts(self, user_id: UUID) -> list:
        result = await self.db.execute(
            select(BankAccount).where(BankAccount.user_id == user_id)
        )
        return result.scalars().all()

    async def get_default_bank_account(self, user_id: UUID) -> BankAccount:
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.user_id == user_id,
                BankAccount.is_default == True,
            )
        )
        account = result.scalar_one_or_none()
        if not account:
            raise NotFound("No default bank account found. Please add a bank account first.")
        return account

    async def delete_bank_account(self, user_id: UUID, account_id: UUID) -> bool:
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.id == account_id,
                BankAccount.user_id == user_id,
            )
        )
        account = result.scalar_one_or_none()
        if not account:
            raise NotFound("Bank account not found")
        await self.db.delete(account)
        await self.db.commit()
        return True

    async def set_default_bank_account(self, user_id: UUID, account_id: UUID) -> BankAccount:
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.id == account_id,
                BankAccount.user_id == user_id,
            )
        )
        account = result.scalar_one_or_none()
        if not account:
            raise NotFound("Bank account not found")

        # Unset other defaults
        all_result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.user_id == user_id,
                BankAccount.is_default == True,
            )
        )
        for acc in all_result.scalars().all():
            acc.is_default = False

        account.is_default = True
        await self.db.commit()
        await self.db.refresh(account)
        return account

    async def verify_bank_account(self, account_number: str, bank_code: str) -> dict:
        account_result = await paystack_service.resolve_account(
            account_number=account_number,
            bank_code=bank_code,
        )
        if not account_result.get("status"):
            return {"verified": False, "account_name": None}

        return {
            "verified": True,
            "account_name": account_result.get("data", {}).get("account_name"),
        }

    # --- Withdrawal ---

    async def request_withdrawal(self, user_id: UUID, data: WithdrawalRequest) -> dict:
        from app.payments.models import WalletWithdrawal

        now = datetime.utcnow()

        # Determine processing mode BEFORE locking
        is_immediate = can_withdraw_now(now)

        # Lock wallet row to prevent double-spend
        wallet = await self.get_wallet(user_id, lock=True)

        if is_immediate:
            # Atomic deduct: only proceeds if balance >= amount
            result = await self.db.execute(
                update(Wallet)
                .where(Wallet.user_id == user_id, Wallet.balance >= data.amount)
                .values(
                    balance=Wallet.balance - data.amount,
                    pending_balance=Wallet.pending_balance + data.amount,
                )
            )
            if result.rowcount == 0:
                raise BadRequest("Insufficient balance")

        # Get the saved bank account
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.id == data.bank_account_id,
                BankAccount.user_id == user_id,
            )
        )
        bank_account = result.scalar_one_or_none()
        if not bank_account:
            raise NotFound("Bank account not found")
        if not bank_account.is_verified:
            raise BadRequest("Bank account not verified")

        if is_immediate:
            status = "pending"
            scheduled_for = now
        else:
            next_biz = get_next_business_datetime(now)
            status = "scheduled"
            scheduled_for = next_biz

        expires_at = scheduled_for + timedelta(hours=48)

        withdrawal = WalletWithdrawal(
            id=uuid4(), wallet_id=wallet.id,
            amount=data.amount, status=status,
            bank_name=bank_account.bank_name, account_number=bank_account.account_number,
            account_name=bank_account.account_name, bank_code=bank_account.bank_code,
            account_verified=True,
            scheduled_for=scheduled_for,
            expires_at=expires_at,
        )
        self.db.add(withdrawal)

        await self.db.commit()
        await self.db.refresh(withdrawal)

        # Immediate withdrawals: initiate Paystack transfer right away
        if is_immediate:
            try:
                await self._initiate_paystack_transfer(withdrawal)
                await self.db.commit()
            except Exception as e:
                logger.error(f"Failed to initiate immediate transfer for {withdrawal.id}: {e}")
                # Notify user of failure
                try:
                    await NotificationService(self.db).send_notification(
                        user_id=user_id,
                        title="Withdrawal Failed",
                        message=f"Your immediate withdrawal of ₦{data.amount:,.2f} could not be initiated. Please try again or contact support.",
                        reference_type="wallet_withdrawal",
                        reference_id=withdrawal.id,
                        data={"amount": str(data.amount), "status": "failed", "reason": "transfer_init_error"},
                    )
                except Exception:
                    logger.warning(f"Failed to send notification for withdrawal {withdrawal.id}")

        result_data = {
            "id": withdrawal.id,
            "status": withdrawal.status,
            "amount": data.amount,
        }
        if not is_immediate:
            result_data["scheduled_for"] = scheduled_for.isoformat()
            result_data["message"] = (
                f"Withdrawals are processed on business days only. "
                f"Your withdrawal has been scheduled for {format_next_business_day(now)}. "
                f"Funds will remain in your balance until then."
            )
        else:
            result_data["message"] = "Withdrawal submitted for processing."

        return result_data

    async def process_pending_withdrawals(self) -> list:
        """
        Celery task entry point: process all withdrawals that are scheduled and due.
        Called periodically to pick up withdrawals scheduled for today or earlier.

        Uses SELECT ... FOR UPDATE SKIP LOCKED to prevent double-processing
        when multiple Celery workers run concurrently.
        """
        from app.payments.models import WalletWithdrawal

        now = datetime.utcnow()
        result = await self.db.execute(
            select(WalletWithdrawal).where(
                WalletWithdrawal.status == "scheduled",
                WalletWithdrawal.scheduled_for <= now,
            ).with_for_update(skip_locked=True)
        )
        pending = result.scalars().all()
        processed = []

        for withdrawal in pending:
            try:
                # Lock wallet row before balance check to prevent race conditions
                wallet_result = await self.db.execute(
                    select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
                )
                wallet = wallet_result.scalar_one_or_none()
                if not wallet or wallet.balance < withdrawal.amount:
                    withdrawal.status = "cancelled"
                    continue

                # Deduct from balance, move to pending
                wallet.balance = wallet.balance - withdrawal.amount
                wallet.pending_balance = wallet.pending_balance + withdrawal.amount
                withdrawal.status = "processing"

                await self._initiate_paystack_transfer(withdrawal)
                if withdrawal.status == "processing":
                    processed.append(withdrawal.id)
            except Exception as e:
                logger.error(f"Failed to process withdrawal {withdrawal.id}: {e}")
                withdrawal.status = "failed"
                try:
                    await NotificationService(self.db).send_notification(
                        user_id=await self._get_wallet_owner(withdrawal.wallet_id),
                        title="Withdrawal Failed",
                        message=f"Your withdrawal of ₦{withdrawal.amount:,.2f} could not be processed. Funds have been returned to your wallet.",
                        reference_type="wallet_withdrawal",
                        reference_id=withdrawal.id,
                        data={"amount": str(withdrawal.amount), "status": "failed", "reason": "system_error"},
                    )
                except Exception:
                    logger.warning(f"Failed to send notification for withdrawal {withdrawal.id}")

        await self.db.commit()
        return processed

    async def auto_refund_expired_withdrawals(self) -> list:
        """
        Celery task entry point: auto-refund withdrawals that have been pending/scheduled
        for more than 48 hours without being processed.

        Uses SELECT ... FOR UPDATE SKIP LOCKED to prevent double-refund
        when multiple Celery workers run concurrently.
        """
        from app.payments.models import WalletWithdrawal

        now = datetime.utcnow()
        result = await self.db.execute(
            select(WalletWithdrawal).where(
                WalletWithdrawal.status.in_(["pending", "scheduled"]),
                WalletWithdrawal.expires_at <= now,
            ).with_for_update(skip_locked=True)
        )
        expired = result.scalars().all()
        refunded = []

        for withdrawal in expired:
            try:
                if withdrawal.status == "pending":
                    # Lock wallet before refunding
                    wallet_result = await self.db.execute(
                        select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
                    )
                    wallet = wallet_result.scalar_one_or_none()
                    if wallet:
                        wallet.pending_balance = wallet.pending_balance - withdrawal.amount
                        wallet.balance = wallet.balance + withdrawal.amount

                # else: scheduled — funds still in balance, just mark expired

                withdrawal.status = "expired"
                refunded.append(withdrawal.id)
            except Exception as e:
                logger.error(f"Failed to refund withdrawal {withdrawal.id}: {e}")

        await self.db.commit()
        return refunded

    async def _get_wallet_owner(self, wallet_id: UUID) -> UUID:
        """Resolve user_id from wallet_id."""
        result = await self.db.execute(select(Wallet.user_id).where(Wallet.id == wallet_id))
        return result.scalar_one()

    async def _initiate_paystack_transfer(self, withdrawal) -> None:
        """Internal: create transfer recipient and initiate Paystack transfer."""
        from app.config import settings
        recipient_result = await paystack_service.create_transfer_recipient(
            name=withdrawal.account_name,
            account_number=withdrawal.account_number,
            bank_code=withdrawal.bank_code,
        )

        if not recipient_result.get("status"):
            withdrawal.status = "failed"
            # Atomic refund: lock wallet, move from pending back to balance
            wallet_result = await self.db.execute(
                select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
            )
            wallet = wallet_result.scalar_one_or_none()
            if wallet:
                wallet.pending_balance = wallet.pending_balance - withdrawal.amount
                wallet.balance = wallet.balance + withdrawal.amount
            # Notify agent: withdrawal failed (bank details issue)
            try:
                await NotificationService(self.db).send_notification(
                    user_id=await self._get_wallet_owner(withdrawal.wallet_id),
                    title="Withdrawal Failed",
                    message=f"Your withdrawal of ₦{withdrawal.amount:,.2f} could not be processed. Please verify your bank account details.",
                    reference_type="wallet_withdrawal",
                    reference_id=withdrawal.id,
                    data={"amount": str(withdrawal.amount), "status": "failed", "reason": "bank_details"},
                )
            except Exception:
                logger.warning(f"Failed to send notification for withdrawal {withdrawal.id}")
            return

        recipient_code = recipient_result["data"]["recipient_code"]
        transfer_ref = generate_reference("TRF")

        transfer_result = await paystack_service.initiate_transfer(
            amount=float(withdrawal.amount),
            recipient_code=recipient_code,
            reference=transfer_ref,
            reason="APEX Housing withdrawal",
            metadata={"platform": getattr(settings, "PAYSTACK_PLATFORM_ID", "APXHOUSING")},
        )

        if transfer_result.get("status"):
            withdrawal.status = "processing"
            withdrawal.gateway_reference = transfer_ref
            withdrawal.processed_at = datetime.utcnow()
        else:
            withdrawal.status = "failed"
            # Atomic refund: lock wallet, move from pending back to balance
            wallet_result = await self.db.execute(
                select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
            )
            wallet = wallet_result.scalar_one_or_none()
            if wallet:
                wallet.pending_balance = wallet.pending_balance - withdrawal.amount
                wallet.balance = wallet.balance + withdrawal.amount
            # Notify agent: withdrawal failed (transfer issue)
            try:
                await NotificationService(self.db).send_notification(
                    user_id=await self._get_wallet_owner(withdrawal.wallet_id),
                    title="Withdrawal Failed",
                    message=f"Your withdrawal of ₦{withdrawal.amount:,.2f} could not be completed. Funds have been returned to your wallet.",
                    reference_type="wallet_withdrawal",
                    reference_id=withdrawal.id,
                    data={"amount": str(withdrawal.amount), "status": "failed", "reason": "transfer_failed"},
                )
            except Exception:
                logger.warning(f"Failed to send notification for withdrawal {withdrawal.id}")

    async def get_transactions(self, user_id: UUID, page: int = 1, page_size: int = 20) -> dict:
        from sqlalchemy import func
        query = select(Transaction).where(Transaction.user_id == user_id)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Transaction.created_at.desc())
        result = await self.db.execute(query)
        return {"total": total, "transactions": result.scalars().all()}

    async def handle_paystack_webhook(self, event_data: dict) -> None:
        event_type = event_data.get("event")
        data = event_data.get("data", {})

        if event_type == "charge.success":
            reference = data.get("reference")
            if reference:
                await self.verify_paystack_payment(reference)

        elif event_type == "transfer.success":
            reference = data.get("reference")
            if reference:
                from app.payments.models import WalletWithdrawal
                result = await self.db.execute(
                    select(WalletWithdrawal).where(WalletWithdrawal.gateway_reference == reference)
                )
                withdrawal = result.scalar_one_or_none()
                if withdrawal and withdrawal.status != "completed":
                    withdrawal.status = "completed"
                    withdrawal.processed_at = datetime.utcnow()

                    # Atomic: move from pending_balance to completed
                    await self.db.execute(
                        update(Wallet)
                        .where(Wallet.id == withdrawal.wallet_id)
                        .values(
                            pending_balance=Wallet.pending_balance - withdrawal.amount,
                            total_withdrawn=Wallet.total_withdrawn + withdrawal.amount,
                        )
                    )

                    # Notify agent: withdrawal completed
                    await NotificationService(self.db).send_notification(
                        user_id=await self._get_wallet_owner(withdrawal.wallet_id),
                        title="Withdrawal Completed",
                        message=f"Your withdrawal of ₦{withdrawal.amount:,.2f} to {withdrawal.account_name} ({withdrawal.bank_name}) has been completed.",
                        reference_type="wallet_withdrawal",
                        reference_id=withdrawal.id,
                        data={"amount": str(withdrawal.amount), "status": "completed", "bank": withdrawal.bank_name},
                    )

                    await self.db.commit()

        elif event_type == "transfer.failed":
            reference = data.get("reference")
            if reference:
                from app.payments.models import WalletWithdrawal
                result = await self.db.execute(
                    select(WalletWithdrawal).where(WalletWithdrawal.gateway_reference == reference)
                )
                withdrawal = result.scalar_one_or_none()
                if withdrawal and withdrawal.status not in ("failed", "expired"):
                    withdrawal.status = "failed"
                    # Atomic refund: move from pending_balance back to balance
                    await self.db.execute(
                        update(Wallet)
                        .where(Wallet.id == withdrawal.wallet_id)
                        .values(
                            pending_balance=Wallet.pending_balance - withdrawal.amount,
                            balance=Wallet.balance + withdrawal.amount,
                        )
                    )
                    # Notify agent: withdrawal failed (bank transfer failed)
                    await NotificationService(self.db).send_notification(
                        user_id=await self._get_wallet_owner(withdrawal.wallet_id),
                        title="Withdrawal Failed",
                        message=f"Your bank transfer of ₦{withdrawal.amount:,.2f} was rejected. Funds have been returned to your wallet.",
                        reference_type="wallet_withdrawal",
                        reference_id=withdrawal.id,
                        data={"amount": str(withdrawal.amount), "status": "failed", "reason": "bank_transfer_rejected"},
                    )
                    await self.db.commit()

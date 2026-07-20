from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user, get_landlord
from app.payments.service import PaymentService
from app.payments.schemas import TransactionInitiate, WithdrawalRequest, BankAccountCreate, BankAccountVerify
from app.payments.models import WalletWithdrawal, Wallet, Transaction, Receipt
from app.users.models import User
from app.common.response import SuccessResponse
from app.common.business_days import can_withdraw_now, get_next_business_datetime, format_next_business_day
from app.common.exceptions import NotFound, BadRequest

router = APIRouter(prefix="/payments", tags=["Payments"])

@router.post("/initiate", response_model=SuccessResponse)
async def initiate_payment(body: TransactionInitiate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Identity verification required to make payments. Please complete KYC first.")
    service = PaymentService(db)
    result = await service.initiate_transaction(user.id, body, user_email=user.email)
    return SuccessResponse(message="Transaction initiated", data=result)

@router.post("/verify/{reference}", response_model=SuccessResponse)
async def verify_payment(reference: str, db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    transaction = await service.verify_paystack_payment(reference)
    return SuccessResponse(message="Payment verified", data=transaction)

@router.post("/{transaction_id}/verify", response_model=SuccessResponse)
async def verify_payment_manual(transaction_id: UUID, gateway_reference: str, payment_gateway: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    transaction = await service.verify_payment(transaction_id, gateway_reference, payment_gateway, user_id=user.id)
    return SuccessResponse(message="Payment verified", data=transaction)

@router.get("/wallet", response_model=SuccessResponse)
async def get_wallet(user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    wallet = await service.get_wallet(user.id)
    return SuccessResponse(data=wallet)

@router.post("/withdraw", response_model=SuccessResponse)
async def request_withdrawal(body: WithdrawalRequest, user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Identity verification required to withdraw funds. Please complete KYC first.")
    service = PaymentService(db)
    result = await service.request_withdrawal(user.id, body)
    return SuccessResponse(message="Withdrawal requested", data=result)

@router.get("/transactions", response_model=SuccessResponse)
async def list_transactions(page: int = 1, page_size: int = 20, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    transactions = await service.get_transactions(user.id, page=page, page_size=page_size)
    return SuccessResponse(data=transactions)

@router.get("/transactions/{transaction_id}/logs", response_model=SuccessResponse)
async def get_transaction_logs(transaction_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.payments.models import PaymentLog

    tx_result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == user.id)
    )
    tx = tx_result.scalar_one_or_none()
    if not tx:
        raise NotFound("Transaction not found")

    result = await db.execute(
        select(PaymentLog).where(PaymentLog.transaction_id == transaction_id).order_by(PaymentLog.created_at)
    )
    logs = result.scalars().all()
    return SuccessResponse(data={"total": len(logs), "logs": logs})

@router.get("/withdrawals/{withdrawal_id}", response_model=SuccessResponse)
async def get_withdrawal_status(withdrawal_id: UUID, user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db)):
    from app.payments.models import Wallet
    result = await db.execute(
        select(WalletWithdrawal).join(Wallet).where(
            WalletWithdrawal.id == withdrawal_id,
            Wallet.user_id == user.id,
        )
    )
    withdrawal = result.scalar_one_or_none()
    if not withdrawal:
        from app.common.exceptions import NotFound
        raise NotFound("Withdrawal not found")
    return SuccessResponse(data=withdrawal)

@router.get("/business-days/check", response_model=SuccessResponse)
async def check_business_day(user: User = Depends(get_current_user)):
    can_process = can_withdraw_now()
    if can_process:
        return SuccessResponse(data={
            "can_withdraw": True,
            "message": "Withdrawals are being processed now.",
        })
    else:
        return SuccessResponse(data={
            "can_withdraw": False,
            "next_business_day": format_next_business_day(),
            "message": (
                f"Paystack only processes transfers on business days (Mon-Fri, excluding holidays). "
                f"Your withdrawal will be scheduled for the next business day."
            ),
        })

# --- Bank Account Management ---

@router.post("/bank-accounts", response_model=SuccessResponse)
async def add_bank_account(body: BankAccountCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    account = await service.add_bank_account(user.id, body)
    return SuccessResponse(message="Bank account added", data=account)

@router.get("/bank-accounts", response_model=SuccessResponse)
async def list_bank_accounts(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    accounts = await service.get_bank_accounts(user.id)
    return SuccessResponse(data=accounts)

@router.delete("/bank-accounts/{account_id}", response_model=SuccessResponse)
async def delete_bank_account(account_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    await service.delete_bank_account(user.id, account_id)
    return SuccessResponse(message="Bank account deleted")

@router.put("/bank-accounts/{account_id}/default", response_model=SuccessResponse)
async def set_default_bank_account(account_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    account = await service.set_default_bank_account(user.id, account_id)
    return SuccessResponse(message="Default bank account updated", data=account)

@router.post("/bank-accounts/verify", response_model=SuccessResponse)
async def verify_bank_account(body: BankAccountVerify, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = PaymentService(db)
    result = await service.verify_bank_account(body.account_number, body.bank_code)
    return SuccessResponse(data=result)

@router.get("/banks", response_model=SuccessResponse)
async def list_banks():
    from app.services.paystack import PaystackService
    paystack = PaystackService()
    result = await paystack.list_banks()
    banks = result.get("data", [])
    ng_banks = [b for b in banks if b.get("country") == "Nigeria"]
    ng_banks.sort(key=lambda b: b.get("name", ""))
    return SuccessResponse(data=ng_banks)


# --- Withdrawal History ---

@router.get("/withdrawals", response_model=SuccessResponse)
async def list_withdrawals(
    page: int = 1, page_size: int = 20, status: str = None,
    user: User = Depends(get_landlord), db: AsyncSession = Depends(get_db),
):
    query = (
        select(WalletWithdrawal)
        .join(Wallet, WalletWithdrawal.wallet_id == Wallet.id)
        .where(Wallet.user_id == user.id)
    )
    if status:
        query = query.where(WalletWithdrawal.status == status)

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    query = (
        query
        .offset((page - 1) * page_size)
        .limit(page_size)
        .order_by(WalletWithdrawal.created_at.desc())
    )
    result = await db.execute(query)
    withdrawals = result.scalars().all()

    return SuccessResponse(data={
        "total": total,
        "withdrawals": withdrawals,
        "page": page,
        "page_size": page_size,
    })


# --- Cancel Withdrawal ---

@router.post("/withdraw/{withdrawal_id}/cancel", response_model=SuccessResponse)
async def cancel_withdrawal(
    withdrawal_id: UUID,
    user: User = Depends(get_landlord),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(WalletWithdrawal).join(Wallet).where(
            WalletWithdrawal.id == withdrawal_id,
            Wallet.user_id == user.id,
        ).with_for_update()
    )
    withdrawal = result.scalar_one_or_none()
    if not withdrawal:
        raise NotFound("Withdrawal not found")

    if withdrawal.status not in ("pending", "scheduled"):
        raise BadRequest(f"Cannot cancel withdrawal in status '{withdrawal.status}'")

    if withdrawal.status == "pending":
        from sqlalchemy import update as sa_update
        wallet_result = await db.execute(
            select(Wallet).where(Wallet.id == withdrawal.wallet_id).with_for_update()
        )
        wallet = wallet_result.scalar_one_or_none()
        if wallet:
            wallet.pending_balance = wallet.pending_balance - withdrawal.amount
            wallet.balance = wallet.balance + withdrawal.amount

    withdrawal.status = "cancelled"
    await db.commit()

    return SuccessResponse(message="Withdrawal cancelled", data={
        "id": withdrawal.id,
        "status": withdrawal.status,
        "amount": float(withdrawal.amount),
    })


# --- Receipts ---

@router.get("/receipts", response_model=SuccessResponse)
async def list_receipts(page: int = 1, page_size: int = 20, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    query = (
        select(Receipt)
        .join(Transaction, Receipt.transaction_id == Transaction.id)
        .where(Transaction.user_id == user.id)
    )
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()
    query = query.offset((page - 1) * page_size).limit(page_size).order_by(Receipt.issued_at.desc())
    result = await db.execute(query)
    receipts = result.scalars().all()
    return SuccessResponse(data={
        "total": total,
        "receipts": receipts,
        "page": page,
        "page_size": page_size,
    })

@router.get("/receipts/{receipt_id}", response_model=SuccessResponse)
async def get_receipt(receipt_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Receipt)
        .join(Transaction, Receipt.transaction_id == Transaction.id)
        .where(Receipt.id == receipt_id, Transaction.user_id == user.id)
    )
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise NotFound("Receipt not found")
    return SuccessResponse(data=receipt)


# --- Refund Status (Tenant) ---

@router.get("/refund-status/{escrow_id}", response_model=SuccessResponse)
async def get_refund_status(
    escrow_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.escrow.models import EscrowTransaction
    from sqlalchemy import func as sql_func

    escrow_result = await db.execute(
        select(EscrowTransaction).where(EscrowTransaction.id == escrow_id)
    )
    escrow = escrow_result.scalar_one_or_none()
    if not escrow:
        raise NotFound("Escrow not found")

    if escrow.tenant_id != user.id and not getattr(user, 'is_super_admin', False):
        raise BadRequest("Not authorized")

    tx_result = await db.execute(
        select(Transaction).where(
            Transaction.escrow_id == escrow_id,
            Transaction.payment_type == "REFUND",
        ).order_by(Transaction.created_at.desc())
    )
    refund_tx = tx_result.scalar_one_or_none()

    refund_amount = None
    if refund_tx:
        # Use the amount_charged from the refund tx (includes any gateway fee the tenant paid)
        refund_amount = float(refund_tx.amount_charged) if refund_tx.amount_charged else float(refund_tx.amount)
    elif escrow.resolution == "refunded":
        refund_amount = float(escrow.amount)

    return SuccessResponse(data={
        "escrow_id": escrow.id,
        "escrow_status": escrow.status.value if hasattr(escrow.status, 'value') else str(escrow.status),
        "resolution": escrow.resolution,
        "resolution_at": escrow.resolution_at.isoformat() if escrow.resolution_at else None,
        "refund_amount": refund_amount,
        "refund_transaction": {
            "id": refund_tx.id,
            "status": refund_tx.status.value if hasattr(refund_tx.status, 'value') else str(refund_tx.status),
            "gateway_reference": refund_tx.gateway_reference,
            "created_at": refund_tx.created_at.isoformat(),
        } if refund_tx else None,
    })



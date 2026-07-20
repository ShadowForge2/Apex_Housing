from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from app.common.enums import PaymentStatus, PaymentType

class TransactionInitiate(BaseModel):
    amount: Decimal
    payment_type: PaymentType
    booking_id: Optional[UUID] = None
    escrow_id: Optional[UUID] = None
    payment_method: str = "card"
    description: Optional[str] = None

class TransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    escrow_id: Optional[UUID] = None
    booking_id: Optional[UUID] = None
    payment_type: PaymentType
    amount: float
    gateway_fee: float = 0.0
    amount_charged: float = 0.0
    currency: str
    status: PaymentStatus
    payment_method: str
    payment_gateway: Optional[str] = None
    gateway_reference: Optional[str] = None
    description: Optional[str] = None
    is_refundable: bool
    created_at: datetime

class PaymentVerification(BaseModel):
    gateway_reference: str
    payment_gateway: str

class ReceiptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    transaction_id: UUID
    receipt_number: str
    issued_at: datetime
    issued_to_name: str
    issued_to_email: str
    total_amount: float
    pdf_url: Optional[str] = None

class InvoiceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    booking_id: Optional[UUID] = None
    invoice_number: str
    due_date: datetime
    paid_at: Optional[datetime] = None
    status: str
    total_amount: float
    created_at: datetime

class WalletResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    balance: float
    pending_balance: float
    currency: str
    total_earned: float
    total_withdrawn: float

class WithdrawalResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    wallet_id: UUID
    amount: float
    status: str
    bank_name: str
    account_number: str
    account_name: str
    processed_at: Optional[datetime] = None
    created_at: datetime

class CommissionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    agent_id: Optional[UUID] = None
    landlord_id: Optional[UUID] = None
    booking_id: UUID
    commission_rate: float
    commission_amount: float
    platform_share: float
    agent_share: float
    status: str
    paid_at: Optional[datetime] = None


class BankAccountCreate(BaseModel):
    bank_name: str
    bank_code: str
    account_number: str = Field(min_length=10, max_length=10)
    account_name: str
    is_default: bool = False


class BankAccountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    bank_name: str
    bank_code: str
    account_number: str
    account_name: str
    is_default: bool
    is_verified: bool
    created_at: datetime


class BankAccountVerify(BaseModel):
    account_number: str
    bank_code: str


class WithdrawalRequest(BaseModel):
    bank_account_id: UUID
    amount: float = Field(gt=0)

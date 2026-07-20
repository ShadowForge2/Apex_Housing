from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional, Any
from datetime import datetime

class BaseEvent(BaseModel):
    triggered_by: Optional[UUID] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

# Auth Events
class UserRegisteredEvent(BaseEvent):
    user_id: UUID
    email: str
    role: str

class UserLoginEvent(BaseEvent):
    user_id: UUID
    ip_address: str

class PasswordResetEvent(BaseEvent):
    user_id: UUID
    email: str

# Property Events
class PropertyCreatedEvent(BaseEvent):
    property_id: UUID
    landlord_id: UUID
    title: str

class PropertyApprovedEvent(BaseEvent):
    property_id: UUID
    approved_by: UUID

class PropertyStatusChangedEvent(BaseEvent):
    property_id: UUID
    old_status: str
    new_status: str

# Booking Events
class BookingCreatedEvent(BaseEvent):
    booking_id: UUID
    property_id: UUID
    tenant_id: UUID
    landlord_id: UUID
    agent_id: Optional[UUID] = None

class BookingConfirmedEvent(BaseEvent):
    booking_id: UUID
    property_id: UUID
    tenant_id: UUID

class BookingCancelledEvent(BaseEvent):
    booking_id: UUID
    cancelled_by: UUID
    reason: str

class BookingCompletedEvent(BaseEvent):
    booking_id: UUID
    completed_by: UUID

# Escrow Events
class EscrowFundsHeldEvent(BaseEvent):
    escrow_id: UUID
    booking_id: UUID
    tenant_id: UUID
    landlord_id: UUID
    amount: float

class EscrowMoveInConfirmedEvent(BaseEvent):
    escrow_id: UUID
    booking_id: UUID
    confirmed_by: UUID

class EscrowTimerExpiredEvent(BaseEvent):
    escrow_id: UUID
    booking_id: UUID

class EscrowDisputeOpenedEvent(BaseEvent):
    escrow_id: UUID
    booking_id: UUID
    dispute_id: UUID
    opened_by: UUID

class EscrowFundsReleasedEvent(BaseEvent):
    escrow_id: UUID
    booking_id: UUID
    landlord_id: UUID
    amount: float

class EscrowFundsRefundedEvent(BaseEvent):
    escrow_id: UUID
    booking_id: UUID
    tenant_id: UUID
    landlord_id: Optional[UUID] = None
    amount: float
    refund_initiated: bool = False

# Payment Events
class PaymentSuccessEvent(BaseEvent):
    transaction_id: UUID
    user_id: UUID
    amount: float
    payment_type: str

class PaymentFailedEvent(BaseEvent):
    transaction_id: UUID
    user_id: UUID
    reason: str

class RefundProcessedEvent(BaseEvent):
    transaction_id: UUID
    user_id: UUID
    amount: float

# Dispute Events
class DisputeOpenedEvent(BaseEvent):
    dispute_id: UUID
    escrow_id: UUID
    booking_id: UUID
    opened_by: UUID
    category: str

class DisputeResolvedEvent(BaseEvent):
    dispute_id: UUID
    escrow_id: UUID
    booking_id: UUID
    resolution: str
    resolved_by: UUID
    refund_amount: Optional[float] = None

# Messaging Events
class MessageSentEvent(BaseEvent):
    message_id: UUID
    conversation_id: UUID
    sender_id: UUID

# Review Events
class ReviewCreatedEvent(BaseEvent):
    review_id: UUID
    reviewer_id: UUID
    target_type: str
    target_id: UUID
    rating: int

# Notification Events
class NotificationSendEvent(BaseEvent):
    user_id: UUID
    title: str
    message: str
    notification_type: str
    reference_type: Optional[str] = None
    reference_id: Optional[UUID] = None
    metadata: Optional[dict] = None

# Commission Events
class CommissionCalculatedEvent(BaseEvent):
    commission_id: UUID
    agent_id: Optional[UUID]
    landlord_id: Optional[UUID]
    booking_id: UUID
    amount: float

# Admin Events
class AdminActionEvent(BaseEvent):
    admin_id: UUID
    action: str
    target_type: str
    target_id: UUID
    details: dict

import enum
from decimal import Decimal


class UserRole(str, enum.Enum):
    TENANT = "TENANT"
    LANDLORD = "LANDLORD"
    ADMIN = "ADMIN"


class PropertyStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PENDING_APPROVAL = "PENDING_APPROVAL"
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    RENTED = "RENTED"
    SOLD = "SOLD"


class PropertyType(str, enum.Enum):
    APARTMENT = "APARTMENT"
    HOUSE = "HOUSE"
    STUDIO = "STUDIO"
    ROOM = "ROOM"
    DUPLEX = "DUPLEX"
    MANSION = "MANSION"
    LAND = "LAND"
    OFFICE = "OFFICE"
    SHOP = "SHOP"
    WAREHOUSE = "WAREHOUSE"


class PlanType(str, enum.Enum):
    MONTHLY = "MONTHLY"
    YEARLY = "YEARLY"
    FLEXIBLE = "FLEXIBLE"


class BookingStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    VIEWED = "VIEWED"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class EscrowStatus(str, enum.Enum):
    PENDING_PAYMENT = "PENDING_PAYMENT"
    FUNDS_HELD = "FUNDS_HELD"
    MOVE_IN_CONFIRMED = "MOVE_IN_CONFIRMED"
    TIMER_RUNNING = "TIMER_RUNNING"
    SATISFIED = "SATISFIED"
    DISPUTED = "DISPUTED"
    REFUNDED = "REFUNDED"
    RELEASED = "RELEASED"
    CANCELLED = "CANCELLED"


class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"
    PARTIALLY_REFUNDED = "PARTIALLY_REFUNDED"


class PaymentType(str, enum.Enum):
    RENT = "RENT"
    DEPOSIT = "DEPOSIT"
    SERVICE_FEE = "SERVICE_FEE"
    LATE_FEE = "LATE_FEE"
    MAINTENANCE = "MAINTENANCE"
    COMMISSION = "COMMISSION"
    REFUND = "REFUND"


class DisputeStatus(str, enum.Enum):
    OPEN = "OPEN"
    UNDER_REVIEW = "UNDER_REVIEW"
    EVIDENCE_SUBMITTED = "EVIDENCE_SUBMITTED"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"
    APPEALED = "APPEALED"


class DisputeResolution(str, enum.Enum):
    REFUNDED_TO_TENANT = "REFUNDED_TO_TENANT"
    RELEASED_TO_LANDLORD = "RELEASED_TO_LANDLORD"
    DISMISSED = "DISMISSED"


class NotificationType(str, enum.Enum):
    PUSH = "PUSH"
    SMS = "SMS"
    EMAIL = "EMAIL"
    IN_APP = "IN_APP"


class NotificationStatus(str, enum.Enum):
    PENDING = "PENDING"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    READ = "READ"
    FAILED = "FAILED"


class DocumentType(str, enum.Enum):
    LEASE_AGREEMENT = "LEASE_AGREEMENT"
    RECEIPT = "RECEIPT"
    INVOICE = "INVOICE"
    CONTRACT = "CONTRACT"
    KYC_DOCUMENT = "KYC_DOCUMENT"
    PROPERTY_DOCUMENT = "PROPERTY_DOCUMENT"


class ReviewTargetType(str, enum.Enum):
    PROPERTY = "PROPERTY"
    LANDLORD = "LANDLORD"
    TENANT = "TENANT"


class EscrowEvent(str, enum.Enum):
    PAYMENT_RECEIVED = "PAYMENT_RECEIVED"
    FUNDS_HELD = "FUNDS_HELD"
    MOVE_IN_CONFIRMED = "MOVE_IN_CONFIRMED"
    TIMER_STARTED = "TIMER_STARTED"
    TIMER_EXPIRED = "TIMER_EXPIRED"
    DISPUTE_OPENED = "DISPUTE_OPENED"
    DISPUTE_RESOLVED = "DISPUTE_RESOLVED"
    FUNDS_RELEASED = "FUNDS_RELEASED"
    FUNDS_REFUNDED = "FUNDS_REFUNDED"
    CANCELLED = "CANCELLED"


# Display-only price estimates (real calculation in bookings/service.py reads from DB)
def get_tenant_price(rent_amount: Decimal) -> int:
    """Estimate tenant price: rent + 5% markup. Display only — actual booking reads from platform_settings."""
    return int(round(rent_amount * Decimal("1.05")))


def get_agent_net_price(rent_amount: Decimal) -> int:
    """Estimate landlord net: rent - 5% markdown. Display only — actual booking reads from platform_settings."""
    return int(round(rent_amount * Decimal("0.95")))

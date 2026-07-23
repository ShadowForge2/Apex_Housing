"""
Central model registry — imports all ORM models so SQLAlchemy can resolve
cross-module relationship() strings. Import this module early in both the
FastAPI app and the Celery worker.
"""

from app.users.models import (  # noqa: F401
    User, Profile, Landlord, Tenant, VerificationDocument, UserPreference,
)
from app.auth.models import UserSession, OTPCode  # noqa: F401
from app.properties.models import (  # noqa: F401
    Property, PropertyImage, PropertyVideo, PropertyLocation,
    PropertyFeature, PropertyPricing, PropertyAvailability, Amenity,
)
from app.bookings.models import (  # noqa: F401
    Booking, BookingStatusHistory, ViewingSchedule,
)
from app.escrow.models import EscrowTransaction, EscrowStatusHistory  # noqa: F401
from app.payments.models import (  # noqa: F401
    Transaction, Receipt, Wallet, PaymentLog,
    BankAccount, WalletWithdrawal,
)
from app.messages.models import (  # noqa: F401
    Conversation, ConversationParticipant, Message,
    MessageAttachment, MessageReadReceipt,
)
from app.notifications.models import Notification, NotificationPreference  # noqa: F401
from app.reviews.models import Review, ReviewImage, ReviewResponse, ReviewVote  # noqa: F401
from app.disputes.models import Dispute, DisputeEvidence, DisputeMessage  # noqa: F401
from app.documents.models import Document  # noqa: F401
from app.admin.models import AdminAction, AuditLog, FraudAlert, PlatformSetting  # noqa: F401
from app.analytics.models import DailyAnalytics, UserActivity, SearchAnalytics  # noqa: F401
from app.commission.models import CommissionRule, CommissionLog, PlatformRevenue  # noqa: F401
from app.search.models import SavedSearch, SearchSuggestion  # noqa: F401
from app.favorites.models import Favorite, PropertyWishList, WishListItem  # noqa: F401
from app.reports.models import BookingReport, DisputeReport  # noqa: F401

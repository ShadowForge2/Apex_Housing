"""
Central registry for all external service clients.
Import from here for convenience:
    from app.services import paystack_service, email_service, etc.
"""
from app.services.paystack import paystack_service
from app.services.storage import supabase_storage
from app.services.notification import fcm_service
from app.services.email import email_service
from app.services.maps import geocoding_service
from app.services.sentry_service import init_sentry, capture_exception, capture_message
from app.services.google_oauth import google_oauth_service

__all__ = [
    "paystack_service",
    "supabase_storage",
    "fcm_service",
    "email_service",
    "geocoding_service",
    "init_sentry",
    "capture_exception",
    "capture_message",
    "google_oauth_service",
]

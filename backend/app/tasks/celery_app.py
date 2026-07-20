import os
from celery import Celery
from app.config import settings

celery_app = Celery(
    "apex_housing",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,
    task_soft_time_limit=25 * 60,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=100,
    result_expires=3600,
    broker_transport_options={
        "visibility_timeout": 43200,
        "fanout_prefix": True,
    },
    beat_schedule={
        "escrow-timer-check": {
            "task": "app.tasks.escrow_tasks.check_expired_escrows",
            "schedule": 60.0,
        },
        "escrow-expiry-reminders": {
            "task": "app.tasks.escrow_tasks.send_escrow_expiry_reminders",
            "schedule": 1800.0,  # Every 30 minutes (Fix #6)
        },
        "rent-due-reminders": {
            "task": "app.tasks.notification_tasks.send_rent_reminders",
            "schedule": 86400.0,
        },
        "daily-analytics": {
            "task": "app.tasks.analytics_tasks.aggregate_daily_analytics",
            "schedule": 86400.0,
        },
        "cleanup-expired-otps": {
            "task": "app.tasks.otp_tasks.cleanup_expired_otps",
            "schedule": 3600.0,
        },
        "cleanup-completed-bookings": {
            "task": "app.tasks.cleanup_tasks.cleanup_completed_bookings",
            "schedule": 300.0,
        },
        "cleanup-expired-sessions": {
            "task": "app.tasks.cleanup_tasks.cleanup_expired_sessions",
            "schedule": 3600.0,
        },
        "process-scheduled-withdrawals": {
            "task": "app.tasks.withdrawal_tasks.process_scheduled_withdrawals",
            "schedule": 900.0,
        },
        "refund-expired-withdrawals": {
            "task": "app.tasks.withdrawal_tasks.refund_expired_withdrawals",
            "schedule": 3600.0,
        },
        "expire-pending-bookings": {
            "task": "app.tasks.booking_tasks.expire_pending_bookings",
            "schedule": 86400.0,
        },
        "process-agent-payouts": {
            "task": "app.tasks.commission_tasks.process_agent_payouts",
            "schedule": 86400.0,
        },
        "lease-expiry-reminders": {
            "task": "app.tasks.notification_tasks.send_lease_expiry_reminders",
            "schedule": 86400.0,
        },
        "update-popular-searches": {
            "task": "app.tasks.analytics_tasks.update_popular_searches",
            "schedule": 86400.0,
        },
        "update-property-stats": {
            "task": "app.tasks.analytics_tasks.update_property_stats",
            "schedule": 86400.0,
        },
    },
)

# Import all models first to resolve cross-module relationship() strings
import app.common.model_registry  # noqa: F401

# Import all task modules to register them with Celery
import app.tasks.escrow_tasks  # noqa: F401
import app.tasks.booking_tasks  # noqa: F401
import app.tasks.cleanup_tasks  # noqa: F401
import app.tasks.withdrawal_tasks  # noqa: F401
import app.tasks.notification_tasks  # noqa: F401
import app.tasks.analytics_tasks  # noqa: F401
import app.tasks.otp_tasks  # noqa: F401
import app.tasks.commission_tasks  # noqa: F401

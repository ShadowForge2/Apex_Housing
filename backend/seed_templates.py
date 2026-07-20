"""Seed default notification templates into the DB."""
import asyncio, json, os
from uuid import uuid4
import asyncpg
from dotenv import load_dotenv

load_dotenv()
DSN = os.getenv("DATABASE_URL")

TEMPLATES = [
    ("booking_confirmed", "Booking Confirmed",
     "Your booking for {property_title} has been confirmed. Please proceed with payment.",
     "in_app", {"property_title": "Property name"}),
    ("escrow_funds_held", "Funds Held in Escrow",
     "Tenant payment of {amount} NGN is now held in escrow for booking.",
     "in_app", {"amount": "Payment amount"}),
    ("escrow_funds_released", "Funds Released",
     "Escrow funds of {amount} NGN for {property_title} have been released to your wallet.",
     "in_app", {"amount": "Amount", "property_title": "Property name"}),
    ("dispute_opened", "Dispute Opened",
     "A dispute has been opened for your booking. You will be notified once resolved.",
     "in_app", None),
    ("dispute_resolved", "Dispute Resolved",
     "Your dispute has been resolved. Resolution: {resolution}",
     "in_app", {"resolution": "Resolution outcome"}),
    ("payment_successful", "Payment Successful",
     "Your payment of {amount} NGN ({payment_type}) was successful.",
     "in_app", {"amount": "Amount", "payment_type": "Payment type"}),
    ("new_review", "New Review Received",
     "You received a {rating}-star review.",
     "in_app", {"rating": "Star rating 1-5"}),
    ("otp_verification", "APEX Housing - Verification Code",
     "Your verification code is: {otp}. Expires in 10 minutes.",
     "email", {"otp": "6-digit OTP code"}),
    ("password_reset", "APEX Housing - Password Reset",
     "Click here to reset your password: {reset_link}. Expires in 1 hour.",
     "email", {"reset_link": "Password reset URL"}),
    ("welcome", "Welcome to APEX Housing",
     "Your account has been created. Browse properties and start booking.",
     "email", None),
    ("kyc_approved", "KYC Verification Approved",
     "Your identity verification has been approved. You can now access all platform features.",
     "in_app", None),
    ("kyc_rejected", "KYC Verification Rejected",
     "Your identity verification was rejected. Reason: {reason}. Please resubmit.",
     "in_app", {"reason": "Rejection reason"}),
    ("fraud_alert", "Suspicious Activity Detected",
     "Unusual activity was detected on your account. Please contact support if this wasn't you.",
     "in_app", None),
]


async def main():
    conn = await asyncpg.connect(DSN)

    existing = await conn.fetch("SELECT name FROM notification_templates")
    existing_names = {r["name"] for r in existing}

    inserted = 0
    for name, title, msg, ntype, variables in TEMPLATES:
        if name in existing_names:
            print(f"  SKIP  {name}")
            continue
        tid = str(uuid4())
        vars_json = json.dumps(variables) if variables else None
        await conn.execute(
            "INSERT INTO notification_templates (id, name, title_template, message_template, "
            "notification_type, is_active, variables, created_at, updated_at) "
            "VALUES ($1, $2, $3, $4, $5, true, $6::jsonb, now(), now())",
            tid, name, title, msg, ntype, vars_json
        )
        inserted += 1
        print(f"  INSERTED  {name}")

    count = await conn.fetchval("SELECT count(*) FROM notification_templates")
    print(f"\nInserted: {inserted}, Skipped: {len(existing_names)}, Total: {count}")
    await conn.close()


asyncio.run(main())

"""Check columns for key sub-tables."""
import asyncio, sys
sys.path.insert(0, ".")
asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from app.database import engine
from sqlalchemy import text

async def check():
    tables = [
        "user_sessions", "otp_codes", "profiles", "landlords", "tenants", "agents",
        "property_images", "property_videos", "property_locations", "property_features",
        "property_pricing", "property_availability", "property_amenities", "amenities",
        "bookings", "escrow_transactions", "wallets", "wallet_withdrawals",
        "disputes", "reviews", "favorites", "property_wishlists", "wishlist_items",
        "notifications", "notification_preferences", "device_tokens",
        "transactions", "invoices", "receipts", "payment_logs",
        "search_suggestions", "search_analytics", "saved_searches",
        "booking_status_history", "escrow_status_history",
        "commissions", "commission_rules", "commission_logs",
        "documents", "verification_documents", "viewing_schedules",
        "maintenance_requests", "map_pins", "user_activities",
        "admin_audit_logs", "platform_revenue", "daily_analytics",
        "dispute_evidence", "dispute_messages", "conversations",
        "conversation_participants", "messages", "message_attachments",
        "message_read_receipts",
    ]
    async with engine.connect() as conn:
        for t in tables:
            try:
                r = await conn.execute(text(
                    "SELECT column_name, data_type FROM information_schema.columns "
                    "WHERE table_name = :t AND table_schema = 'public' ORDER BY ordinal_position"
                ), {"t": t})
                rows = list(r)
                if rows:
                    cols = [f"{row[0]}:{row[1]}" for row in rows]
                    print(f"{t}: {', '.join(cols)}")
                else:
                    print(f"{t}: (EMPTY / NOT FOUND)")
            except Exception as e:
                print(f"{t}: ERROR {e}")

asyncio.run(check())

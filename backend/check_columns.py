import asyncio
import os

os.environ.setdefault("OPENCODE_VENDOR", "pip")

async def main():
    from dotenv import load_dotenv
    load_dotenv()
    from sqlalchemy.ext.asyncio import create_async_engine
    from sqlalchemy import text
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL not set"); return
    engine = create_async_engine(db_url, connect_args={"statement_cache_size": 0})
    tables = [
        "profiles", "landlords", "tenants", "agents", "users",
        "user_sessions", "otp_codes", "search_suggestions", "saved_searches",
        "property_images", "property_videos", "property_features",
        "property_pricing", "property_availability", "property_locations",
        "property_amenities", "amenities", "properties",
        "escrow_transactions", "escrow_status_histories",
        "bookings", "booking_status_histories", "reviews",
        "wallets", "wallet_withdrawals", "bank_accounts",
        "transactions", "notifications", "device_tokens",
        "admin_audit_logs", "fraud_alerts", "disputes",
        "map_pins", "daily_analytics", "user_activities",
        "search_analytics", "maintenance_requests",
    ]
    async with engine.begin() as conn:
        result = await conn.execute(text(
            "SELECT table_name, column_name FROM information_schema.columns "
            "WHERE table_schema = 'public' ORDER BY table_name, ordinal_position"
        ))
        rows = result.fetchall()
    by_table = {}
    for table_name, col_name in rows:
        by_table.setdefault(table_name, []).append(col_name)
    for t in tables:
        if t in by_table:
            print(f"\n=== {t} ({len(by_table[t])} cols) ===")
            print(", ".join(by_table[t]))
        else:
            print(f"\n=== {t} === NOT FOUND")
    await engine.dispose()

asyncio.run(main())

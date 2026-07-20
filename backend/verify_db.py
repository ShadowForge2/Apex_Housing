"""
APEX Housing — Database Connection Verifier
Run: python verify_db.py
"""
import asyncio
import sys

async def verify():
    try:
        from app.config import settings
        print(f"[1/5] Config loaded: {settings.PROJECT_NAME} v{settings.VERSION}")
        print(f"       Environment: {settings.ENVIRONMENT}")
        print(f"       DB URL host: {settings.DATABASE_URL.split('@')[-1] if '@' in settings.DATABASE_URL else 'N/A'}")
    except Exception as e:
        print(f"FAIL: Could not load config: {e}")
        return False

    try:
        import redis.asyncio as aioredis
        _redis = aioredis.from_url(settings.REDIS_URL, socket_connect_timeout=3)
        await _redis.ping()
        await _redis.aclose()
        print(f"[2/5] Redis OK ({settings.REDIS_URL})")
    except Exception as e:
        print(f"[2/5] Redis UNAVAILABLE (non-fatal): {e}")

    try:
        from sqlalchemy import text
        from app.database import engine
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT version()"))
            pg_version = result.scalar()
            print(f"[3/5] PostgreSQL OK: {pg_version}")
    except Exception as e:
        print(f"FAIL: Could not connect to PostgreSQL: {e}")
        await engine.dispose()
        return False

    try:
        from sqlalchemy import text
        from app.database import engine
        async with engine.connect() as conn:
            result = await conn.execute(text(
                "SELECT table_name FROM information_schema.tables "
                "WHERE table_schema = 'public' ORDER BY table_name"
            ))
            tables = [row[0] for row in result.fetchall()]
            print(f"[4/5] Tables found: {len(tables)}")
            expected = [
                "users", "profiles", "landlords", "tenants", "agents",
                "user_sessions", "otp_codes", "properties", "property_images",
                "property_locations", "property_pricing", "property_availability",
                "property_features", "amenities", "bookings", "booking_status_history",
                "viewing_schedules", "escrow_transactions", "escrow_status_history",
                "transactions", "wallets", "bank_accounts", "conversations",
                "conversation_participants", "messages", "message_attachments",
                "notifications", "reviews", "documents", "disputes",
                "admin_audit_logs", "fraud_alerts",
                "daily_analytics", "user_activities", "search_analytics",
                "commission_rules", "commission_logs",
                "favorites", "booking_reports",
                "user_signatures", "verification_documents",
            ]
            missing = [t for t in expected if t not in tables]
            if missing:
                print(f"       Missing tables: {missing}")
                print(f"       Run: alembic upgrade head")
            else:
                print(f"       All expected tables present!")
            print(f"       Tables: {', '.join(sorted(tables)[:20])}...")
    except Exception as e:
        print(f"FAIL: Could not inspect tables: {e}")
        await engine.dispose()
        return False

    try:
        from sqlalchemy import text
        from app.database import engine
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT COUNT(*) FROM users"))
            count = result.scalar()
            print(f"[5/5] Users table has {count} row(s)")
    except Exception as e:
        print(f"[5/5] Could not query users: {e}")

    await engine.dispose()
    print("\n=== Database verification complete ===")
    return True

if __name__ == "__main__":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    ok = asyncio.run(verify())
    sys.exit(0 if ok else 1)

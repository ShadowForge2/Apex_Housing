import asyncio, os
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
    async with engine.begin() as conn:
        for table in ["user_sessions", "otp_codes", "profiles", "landlords", "tenants"]:
            await conn.execute(text(f"DELETE FROM {table} WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'smoke_%')"))
        r = await conn.execute(text("DELETE FROM users WHERE email LIKE 'smoke_%'"))
        print(f"Deleted {r.rowcount} smoke test users")
    await engine.dispose()
asyncio.run(main())

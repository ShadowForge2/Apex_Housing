"""
Database setup script.
Run this after starting PostgreSQL to create all tables.

Usage:
    python scripts/setup_db.py

Or use Alembic directly:
    alembic revision --autogenerate -m "initial"
    alembic upgrade head
"""
import asyncio
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))


async def create_tables():
    from app.database import engine, Base

    import app.auth.models
    import app.users.models
    import app.properties.models
    import app.bookings.models
    import app.escrow.models
    import app.payments.models
    import app.messages.models
    import app.notifications.models
    import app.reviews.models
    import app.documents.models
    import app.disputes.models
    import app.commission.models
    import app.analytics.models
    import app.admin.models
    import app.search.models
    import app.maps.models

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    print("All tables created successfully.")


def create_alembic_migration():
    import subprocess
    result = subprocess.run(
        ["alembic", "revision", "--autogenerate", "-m", "initial"],
        capture_output=True, text=True,
    )
    print(result.stdout)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
    else:
        print("Migration created. Run 'alembic upgrade head' to apply.")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "alembic":
        create_alembic_migration()
    else:
        asyncio.run(create_tables())

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import declarative_base

from app.config import settings

# Disable prepared statement caching — required for pgbouncer (transaction mode)
# used by Supabase pooler, Render, and most managed Postgres providers.
connect_args = {"statement_cache_size": 0, "prepared_statement_cache_size": 0}

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.ENVIRONMENT == "development",
    pool_size=20,
    max_overflow=30,
    pool_pre_ping=True,
    pool_recycle=1800,  # Recycle connections after 30 min to avoid stale connections
    connect_args=connect_args,
)

async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        try:
            yield session
            if session.is_active and session.is_modified():
                await session.commit()
        except Exception:
            if session.is_active:
                await session.rollback()
            raise

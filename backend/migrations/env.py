from logging.config import fileConfig
from sqlalchemy import pool, create_engine
from alembic import context

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

from app.database import Base
from app.config import settings

target_metadata = Base.metadata

# Import all models so Alembic can detect them
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
import app.favorites.models


def get_sync_url() -> str:
    url = settings.DATABASE_URL
    # Convert async URL to sync for Alembic
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    # Remove any query params like ?ssl=require
    if "?" in url:
        url = url.split("?")[0]
    return url


def run_migrations_offline() -> None:
    url = get_sync_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        sslmode="require",
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    sync_url = get_sync_url()
    connectable = create_engine(
        sync_url,
        poolclass=pool.NullPool,
        connect_args={"sslmode": "require"},
    )

    with connectable.connect() as connection:
        do_run_migrations(connection)
    connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

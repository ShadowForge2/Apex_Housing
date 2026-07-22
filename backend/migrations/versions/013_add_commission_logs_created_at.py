"""Add created_at column to commission_logs.

Revision ID: 013
Revises: 012
"""
from alembic import op
import sqlalchemy as sa

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "commission_logs",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_commission_logs_created_at",
        "commission_logs",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_commission_logs_created_at", table_name="commission_logs")
    op.drop_column("commission_logs", "created_at")

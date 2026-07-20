"""Add platform settings table and conversation_type column.

Revision ID: 005_platform_settings_and_admin_group_chat
Revises: 004_add_user_signatures
Create Date: 2026-07-17
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "005_platform_settings_and_admin_group_chat"
down_revision = "004_add_user_signatures"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "platform_settings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("key", sa.String(100), unique=True, nullable=False),
        sa.Column("value", sa.Text(), nullable=False),
        sa.Column("updated_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_platform_settings_key", "platform_settings", ["key"])

    op.add_column(
        "conversations",
        sa.Column("conversation_type", sa.String(30), nullable=False, server_default="direct"),
    )


def downgrade() -> None:
    op.drop_column("conversations", "conversation_type")
    op.drop_table("platform_settings")

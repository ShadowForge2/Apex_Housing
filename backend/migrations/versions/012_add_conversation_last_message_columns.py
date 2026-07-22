"""Add last_message_at and last_message_preview to conversations.

Revision ID: 012
Revises: 011
"""
from alembic import op
import sqlalchemy as sa

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "conversations",
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "conversations",
        sa.Column("last_message_preview", sa.String(255), nullable=True),
    )
    op.create_index(
        "ix_conversations_last_message_at",
        "conversations",
        ["last_message_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_conversations_last_message_at", table_name="conversations")
    op.drop_column("conversations", "last_message_preview")
    op.drop_column("conversations", "last_message_at")

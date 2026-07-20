"""Add user_preferences table for language, theme, state restoration.

Revision ID: 007_add_user_preferences
Revises: 006_add_phone_number_to_profiles
Create Date: 2026-07-19
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSON

revision = "007_add_user_preferences"
down_revision = "006_add_phone_number_to_profiles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_preferences",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("language", sa.String(10), nullable=False, server_default="en"),
        sa.Column("theme", sa.String(20), nullable=False, server_default="light"),
        sa.Column("text_scale", sa.Float, nullable=False, server_default="1.0"),
        sa.Column("currency", sa.String(10), nullable=False, server_default="NGN"),
        sa.Column("notifications_enabled", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("biometric_enabled", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("push_enabled", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("email_notifications", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("quiet_hours_start", sa.String(5), nullable=True),
        sa.Column("quiet_hours_end", sa.String(5), nullable=True),
        sa.Column("last_screen", sa.String(100), nullable=True),
        sa.Column("last_scroll_position", sa.Integer, nullable=True),
        sa.Column("draft_data", JSON, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_user_preferences_user_id", "user_preferences", ["user_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_user_preferences_user_id")
    op.drop_table("user_preferences")

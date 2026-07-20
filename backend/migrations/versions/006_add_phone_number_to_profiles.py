"""Add phone_number column to profiles table.

Revision ID: 006_add_phone_number_to_profiles
Revises: 005_platform_settings_and_admin_group_chat
Create Date: 2026-07-17
"""
from alembic import op
import sqlalchemy as sa

revision = "006_add_phone_number_to_profiles"
down_revision = "005_platform_settings_and_admin_group_chat"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("profiles", sa.Column("phone_number", sa.String(20), nullable=True))


def downgrade() -> None:
    op.drop_column("profiles", "phone_number")

"""Add user signature storage and history.

Revision ID: 004_add_user_signatures
Revises: 003_add_booking_reports_and_terms
Create Date: 2026-07-15
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "004_add_user_signatures"
down_revision = "003_add_booking_reports_and_terms"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("signature_data", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("signature_created_at", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "user_signatures",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("signature_data", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("label", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_user_signatures_user_id", "user_signatures", ["user_id"])


def downgrade() -> None:
    op.drop_table("user_signatures")
    op.drop_column("users", "signature_created_at")
    op.drop_column("users", "signature_data")

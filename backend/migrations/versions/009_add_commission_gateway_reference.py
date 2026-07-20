"""Add gateway_reference column to commission_logs for Paystack transfer tracking.

Revision ID: 009_add_commission_gateway_ref
Revises: 008_add_gateway_fee
Create Date: 2026-07-20
"""
from alembic import op
import sqlalchemy as sa

revision = "009_add_commission_gateway_ref"
down_revision = "008_add_gateway_fee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "commission_logs",
        sa.Column(
            "gateway_reference",
            sa.String(100),
            nullable=True,
            comment="Paystack transfer reference for agent commission payout",
        ),
    )
    op.create_index(
        "ix_commission_logs_gateway_reference",
        "commission_logs",
        ["gateway_reference"],
    )


def downgrade() -> None:
    op.drop_index("ix_commission_logs_gateway_reference", table_name="commission_logs")
    op.drop_column("commission_logs", "gateway_reference")

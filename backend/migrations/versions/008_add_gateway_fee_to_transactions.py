"""Add gateway_fee and amount_charged to transactions table.

Revision ID: 008_add_gateway_fee
Revises: 007_add_user_preferences
Create Date: 2026-07-19
"""
from alembic import op
import sqlalchemy as sa

revision = "008_add_gateway_fee"
down_revision = "007_add_user_preferences"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "transactions",
        sa.Column(
            "gateway_fee",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0.00",
            comment="Payment gateway fee (e.g. Paystack) charged to customer",
        ),
    )
    op.add_column(
        "transactions",
        sa.Column(
            "amount_charged",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0.00",
            comment="Total amount charged to customer including gateway fee",
        ),
    )


def downgrade() -> None:
    op.drop_column("transactions", "amount_charged")
    op.drop_column("transactions", "gateway_fee")

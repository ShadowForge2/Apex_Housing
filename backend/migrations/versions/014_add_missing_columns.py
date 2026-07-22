"""Add created_at to transactions/wallet_withdrawals, reviewed_by/reviewed_at to verification_documents.

Revision ID: 014
Revises: 013
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # transactions: add created_at
    op.add_column(
        "transactions",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_transactions_created_at", "transactions", ["created_at"])

    # wallet_withdrawals: add created_at
    op.add_column(
        "wallet_withdrawals",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_wallet_withdrawals_created_at", "wallet_withdrawals", ["created_at"])

    # verification_documents: add reviewed_by and reviewed_at
    op.add_column(
        "verification_documents",
        sa.Column(
            "reviewed_by",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.add_column(
        "verification_documents",
        sa.Column(
            "reviewed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.create_index("ix_verification_documents_reviewed_by", "verification_documents", ["reviewed_by"])


def downgrade() -> None:
    op.drop_index("ix_verification_documents_reviewed_by", table_name="verification_documents")
    op.drop_column("verification_documents", "reviewed_at")
    op.drop_column("verification_documents", "reviewed_by")
    op.drop_index("ix_wallet_withdrawals_created_at", table_name="wallet_withdrawals")
    op.drop_column("wallet_withdrawals", "created_at")
    op.drop_index("ix_transactions_created_at", table_name="transactions")
    op.drop_column("transactions", "created_at")

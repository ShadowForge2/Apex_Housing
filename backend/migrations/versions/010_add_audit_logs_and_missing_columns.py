"""Add audit_logs table + missing columns on fraud_alerts and escrow_transactions.

Revision ID: 010
Revises: 009
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- audit_logs table (was never created) ---
    op.create_table(
        "audit_logs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("resource_type", sa.String(50), nullable=False),
        sa.Column("resource_id", UUID(as_uuid=True), nullable=True),
        sa.Column("old_value", JSONB, nullable=True),
        sa.Column("new_value", JSONB, nullable=True),
        sa.Column("ip_address", sa.String(45), nullable=True),
        sa.Column("user_agent", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_audit_logs_user_id", "audit_logs", ["user_id"])
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"])
    op.create_index("ix_audit_logs_created_at", "audit_logs", ["created_at"])

    # --- fraud_alerts: add missing columns ---
    op.add_column("fraud_alerts", sa.Column("assigned_to", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True))
    op.add_column("fraud_alerts", sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True))

    # --- escrow_transactions: add missing columns ---
    op.add_column("escrow_transactions", sa.Column("dispute_opened_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("escrow_transactions", sa.Column("dispute_id", UUID(as_uuid=True), sa.ForeignKey("disputes.id", ondelete="SET NULL"), nullable=True))


def downgrade() -> None:
    op.drop_column("escrow_transactions", "dispute_id")
    op.drop_column("escrow_transactions", "dispute_opened_at")
    op.drop_column("fraud_alerts", "resolved_at")
    op.drop_column("fraud_alerts", "assigned_to")
    op.drop_table("audit_logs")

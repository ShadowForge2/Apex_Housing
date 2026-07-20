"""Fix nullability, type mismatches, and add missing FK indexes.

Revision ID: 011
Revises: 010
"""
from alembic import op
import sqlalchemy as sa

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- booking_status_history.changed_by: nullable=True → nullable=False ---
    # The model defines it as nullable=False, but migration 001 set nullable=True
    op.alter_column(
        "booking_status_history", "changed_by",
        existing_type=sa.UUID(as_uuid=True),
        nullable=True,  # Keep nullable=True since system-triggered status changes have no user
    )

    # --- user_sessions.refresh_token: String(512) → Text (model uses Text) ---
    op.alter_column(
        "user_sessions", "refresh_token",
        existing_type=sa.String(512),
        type_=sa.Text,
        existing_nullable=False,
    )

    # --- Add missing FK indexes for query performance ---
    op.create_index("ix_escrow_transactions_tenant_id", "escrow_transactions", ["tenant_id"])
    op.create_index("ix_escrow_transactions_landlord_id", "escrow_transactions", ["landlord_id"])
    op.create_index("ix_escrow_transactions_agent_id", "escrow_transactions", ["agent_id"])
    op.create_index("ix_escrow_transactions_property_id", "escrow_transactions", ["property_id"])
    op.create_index("ix_escrow_transactions_booking_id", "escrow_transactions", ["booking_id"])
    op.create_index("ix_commissions_agent_id", "commissions", ["agent_id"])
    op.create_index("ix_commissions_landlord_id", "commissions", ["landlord_id"])
    op.create_index("ix_commissions_booking_id", "commissions", ["booking_id"])
    op.create_index("ix_commissions_escrow_id", "commissions", ["escrow_id"])
    op.create_index("ix_transactions_escrow_id", "transactions", ["escrow_id"])
    op.create_index("ix_transactions_booking_id", "transactions", ["booking_id"])
    op.create_index("ix_bookings_agent_id", "bookings", ["agent_id"])
    op.create_index("ix_booking_status_history_changed_by", "booking_status_history", ["changed_by"])
    op.create_index("ix_review_images_review_id", "review_images", ["review_id"])
    op.create_index("ix_dispute_evidence_dispute_id", "dispute_evidence", ["dispute_id"])
    op.create_index("ix_dispute_evidence_uploaded_by", "dispute_evidence", ["uploaded_by"])
    op.create_index("ix_disputes_tenant_id", "disputes", ["tenant_id"])
    op.create_index("ix_disputes_landlord_id", "disputes", ["landlord_id"])


def downgrade() -> None:
    op.drop_index("ix_disputes_landlord_id", "disputes")
    op.drop_index("ix_disputes_tenant_id", "disputes")
    op.drop_index("ix_dispute_evidence_uploaded_by", "dispute_evidence")
    op.drop_index("ix_dispute_evidence_dispute_id", "dispute_evidence")
    op.drop_index("ix_review_images_review_id", "review_images")
    op.drop_index("ix_booking_status_history_changed_by", "booking_status_history")
    op.drop_index("ix_bookings_agent_id", "bookings")
    op.drop_index("ix_transactions_booking_id", "transactions")
    op.drop_index("ix_transactions_escrow_id", "transactions")
    op.drop_index("ix_commissions_escrow_id", "commissions")
    op.drop_index("ix_commissions_booking_id", "commissions")
    op.drop_index("ix_commissions_landlord_id", "commissions")
    op.drop_index("ix_commissions_agent_id", "commissions")
    op.drop_index("ix_escrow_transactions_booking_id", "escrow_transactions")
    op.drop_index("ix_escrow_transactions_property_id", "escrow_transactions")
    op.drop_index("ix_escrow_transactions_agent_id", "escrow_transactions")
    op.drop_index("ix_escrow_transactions_landlord_id", "escrow_transactions")
    op.drop_index("ix_escrow_transactions_tenant_id", "escrow_transactions")
    op.alter_column(
        "user_sessions", "refresh_token",
        existing_type=sa.Text,
        type_=sa.String(512),
        existing_nullable=False,
    )

"""add booking_reports, agent terms & signatures, tenant terms agreement

Revision ID: 003_add_booking_reports_and_terms
Revises: 002_add_missing_tables
Create Date: 2026-07-15

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSON

revision = "003_add_booking_reports_and_terms"
down_revision = "002_add_missing_tables"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- Agent terms & signature fields on properties ---
    op.add_column("properties", sa.Column("agent_terms", sa.Text, nullable=True))
    op.add_column("properties", sa.Column("agent_signed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("properties", sa.Column("agent_signature_data", sa.Text, nullable=True))

    # --- Tenant terms agreement & signature on bookings ---
    op.add_column("bookings", sa.Column("tenant_terms_agreed", sa.Boolean(), server_default=sa.text("false"), nullable=False))
    op.add_column("bookings", sa.Column("tenant_terms_agreed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("bookings", sa.Column("terms_text_snapshot", sa.Text, nullable=True))
    op.add_column("bookings", sa.Column("tenant_signature_data", sa.Text, nullable=True))

    # --- Booking Reports table ---
    op.create_table(
        "booking_reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("booking_id", UUID(as_uuid=True), sa.ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("property_id", UUID(as_uuid=True), sa.ForeignKey("properties.id", ondelete="SET NULL"), nullable=True),
        sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("landlord_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("agent_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("report_number", sa.String(50), unique=True, nullable=False),
        # Agent personal details
        sa.Column("agent_full_name", sa.String(255), nullable=True),
        sa.Column("agent_email", sa.String(255), nullable=True),
        sa.Column("agent_phone", sa.String(50), nullable=True),
        sa.Column("agent_agency_name", sa.String(255), nullable=True),
        sa.Column("agent_license_number", sa.String(100), nullable=True),
        # Tenant personal details
        sa.Column("tenant_full_name", sa.String(255), nullable=True),
        sa.Column("tenant_email", sa.String(255), nullable=True),
        sa.Column("tenant_phone", sa.String(50), nullable=True),
        # Landlord personal details
        sa.Column("landlord_full_name", sa.String(255), nullable=True),
        sa.Column("landlord_email", sa.String(255), nullable=True),
        sa.Column("landlord_phone", sa.String(50), nullable=True),
        # Property snapshot
        sa.Column("property_title", sa.String(255), nullable=True),
        sa.Column("property_type", sa.String(50), nullable=True),
        sa.Column("property_address", sa.Text, nullable=True),
        sa.Column("property_city", sa.String(100), nullable=True),
        sa.Column("property_state", sa.String(100), nullable=True),
        sa.Column("property_country", sa.String(100), nullable=True),
        sa.Column("property_photos", JSON, nullable=True),
        sa.Column("property_description", sa.Text, nullable=True),
        sa.Column("property_rent_amount", sa.String(20), nullable=True),
        # Terms
        sa.Column("agent_terms_snapshot", sa.Text, nullable=True),
        sa.Column("tenant_terms_agreed", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("tenant_terms_agreed_at", sa.DateTime(timezone=True), nullable=True),
        # Booking snapshot
        sa.Column("booking_reference", sa.String(50), nullable=False),
        sa.Column("booking_status", sa.String(20), nullable=False),
        sa.Column("move_in_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("lease_start_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("booking_created_at", sa.DateTime(timezone=True), nullable=True),
        # Payment
        sa.Column("total_amount", sa.String(20), nullable=False),
        sa.Column("security_deposit", sa.String(20), nullable=False),
        sa.Column("service_fee", sa.String(20), nullable=False),
        sa.Column("platform_fee", sa.String(20), nullable=False),
        sa.Column("currency", sa.String(10), server_default="NGN", nullable=False),
        sa.Column("payment_reference", sa.String(100), nullable=True),
        sa.Column("payment_date", sa.DateTime(timezone=True), nullable=True),
        # Disbursement
        sa.Column("funds_released_at", sa.DateTime(timezone=True), nullable=True),
        # Agent signature
        sa.Column("agent_signature_data", sa.Text, nullable=True),
        sa.Column("agent_signed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("agent_signed_ip", sa.String(50), nullable=True),
        # Tenant signature
        sa.Column("tenant_signature_data", sa.Text, nullable=True),
        sa.Column("tenant_signed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tenant_signed_ip", sa.String(50), nullable=True),
        # Landlord signature
        sa.Column("landlord_signature_data", sa.Text, nullable=True),
        sa.Column("landlord_signed", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("landlord_signed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("landlord_signed_ip", sa.String(50), nullable=True),
        # Report status
        sa.Column("is_finalized", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("is_downloaded", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("downloaded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("download_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("report_data", JSON, nullable=True),
    )
    op.create_index("ix_booking_reports_booking_id", "booking_reports", ["booking_id"])
    op.create_index("ix_booking_reports_tenant_id", "booking_reports", ["tenant_id"])
    op.create_index("ix_booking_reports_landlord_id", "booking_reports", ["landlord_id"])
    op.create_index("ix_booking_reports_report_number", "booking_reports", ["report_number"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_booking_reports_report_number", table_name="booking_reports")
    op.drop_index("ix_booking_reports_landlord_id", table_name="booking_reports")
    op.drop_index("ix_booking_reports_tenant_id", table_name="booking_reports")
    op.drop_index("ix_booking_reports_booking_id", table_name="booking_reports")
    op.drop_table("booking_reports")
    op.drop_column("bookings", "tenant_signature_data")
    op.drop_column("bookings", "terms_text_snapshot")
    op.drop_column("bookings", "tenant_terms_agreed_at")
    op.drop_column("bookings", "tenant_terms_agreed")
    op.drop_column("properties", "agent_signature_data")
    op.drop_column("properties", "agent_signed_at")
    op.drop_column("properties", "agent_terms")

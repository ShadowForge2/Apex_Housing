"""Add dispute_reports table

Revision ID: 017
Revises: 016
Create Date: 2026-07-23
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = '017'
down_revision = '016'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'dispute_reports',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('booking_id', UUID(as_uuid=True), sa.ForeignKey('bookings.id', ondelete='CASCADE'), nullable=False),
        sa.Column('property_id', UUID(as_uuid=True), sa.ForeignKey('properties.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reported_by_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reported_against_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('dispute_type', sa.String(50), nullable=False),
        sa.Column('severity', sa.String(20), nullable=False, server_default='medium'),
        sa.Column('status', sa.String(20), nullable=False, server_default='open'),
        sa.Column('title', sa.String(255), nullable=True),
        sa.Column('description', sa.Text, nullable=False),
        sa.Column('reported_by_name', sa.String(255), nullable=True),
        sa.Column('reported_against_name', sa.String(255), nullable=True),
        sa.Column('property_title', sa.String(255), nullable=True),
        sa.Column('booking_reference', sa.String(50), nullable=True),
        sa.Column('assigned_to', sa.String(255), nullable=True),
        sa.Column('resolution_notes', sa.Text, nullable=True),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_dispute_reports_status', 'dispute_reports', ['status'])
    op.create_index('ix_dispute_reports_booking_id', 'dispute_reports', ['booking_id'])


def downgrade():
    op.drop_index('ix_dispute_reports_booking_id')
    op.drop_index('ix_dispute_reports_status')
    op.drop_table('dispute_reports')

"""Add disputes table

Revision ID: 016
Revises: 015
Create Date: 2026-07-23
"""
from alembic import op
import sqlalchemy as sa

revision = '016'
down_revision = '015'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'disputes',
        sa.Column('id', sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('booking_id', sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey('bookings.id', ondelete='CASCADE'), nullable=False),
        sa.Column('property_id', sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey('properties.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reported_by_id', sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reported_against_id', sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('dispute_type', sa.String(50), nullable=False),
        sa.Column('severity', sa.String(20), nullable=False, server_default='medium'),
        sa.Column('status', sa.String(20), nullable=False, server_default='open'),
        sa.Column('title', sa.String(255), nullable=True),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('reported_by_name', sa.String(255), nullable=True),
        sa.Column('reported_against_name', sa.String(255), nullable=True),
        sa.Column('property_title', sa.String(255), nullable=True),
        sa.Column('booking_reference', sa.String(50), nullable=True),
        sa.Column('assigned_to', sa.String(255), nullable=True),
        sa.Column('resolution_notes', sa.Text(), nullable=True),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_disputes_booking_id', 'disputes', ['booking_id'])
    op.create_index('ix_disputes_status', 'disputes', ['status'])
    op.create_index('ix_disputes_reported_by_id', 'disputes', ['reported_by_id'])


def downgrade():
    op.drop_index('ix_disputes_reported_by_id')
    op.drop_index('ix_disputes_status')
    op.drop_index('ix_disputes_booking_id')
    op.drop_table('disputes')

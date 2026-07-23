"""Add missing message and participant columns

Revision ID: 015
Revises: 014
Create Date: 2026-07-23
"""
from alembic import op
import sqlalchemy as sa

revision = '015'
down_revision = '014'
branch_labels = None
depends_on = None


def column_exists(table, column):
    bind = op.get_bind()
    result = bind.execute(sa.text(
        f"SELECT EXISTS (SELECT 1 FROM information_schema.columns "
        f"WHERE table_name = '{table}' AND column_name = '{column}')"
    ))
    return result.scalar()


def upgrade():
    # Messages table
    if not column_exists('messages', 'message_type'):
        op.add_column('messages', sa.Column('message_type', sa.String(20), nullable=False, server_default='text'))
    if not column_exists('messages', 'is_edited'):
        op.add_column('messages', sa.Column('is_edited', sa.Boolean(), nullable=False, server_default=sa.text('false')))
    if not column_exists('messages', 'edited_at'):
        op.add_column('messages', sa.Column('edited_at', sa.DateTime(timezone=True), nullable=True))
    if not column_exists('messages', 'is_deleted'):
        op.add_column('messages', sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('false')))
    if not column_exists('messages', 'deleted_at'):
        op.add_column('messages', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))

    # Conversation participants table
    if not column_exists('conversation_participants', 'joined_at'):
        op.add_column('conversation_participants', sa.Column('joined_at', sa.DateTime(timezone=True), nullable=True))
    if not column_exists('conversation_participants', 'left_at'):
        op.add_column('conversation_participants', sa.Column('left_at', sa.DateTime(timezone=True), nullable=True))
    if not column_exists('conversation_participants', 'is_muted'):
        op.add_column('conversation_participants', sa.Column('is_muted', sa.Boolean(), nullable=False, server_default=sa.text('false')))

    # Message attachments table
    if not column_exists('message_attachments', 'thumbnail_url'):
        op.add_column('message_attachments', sa.Column('thumbnail_url', sa.String(512), nullable=True))


def downgrade():
    op.drop_column('messages', 'message_type')
    op.drop_column('messages', 'is_edited')
    op.drop_column('messages', 'edited_at')
    op.drop_column('messages', 'is_deleted')
    op.drop_column('messages', 'deleted_at')
    op.drop_column('conversation_participants', 'joined_at')
    op.drop_column('conversation_participants', 'left_at')
    op.drop_column('conversation_participants', 'is_muted')
    op.drop_column('message_attachments', 'thumbnail_url')

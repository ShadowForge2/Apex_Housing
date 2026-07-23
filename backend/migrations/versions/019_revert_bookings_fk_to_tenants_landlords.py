"""Revert bookings FKs back to tenants.id and landlords.id.

Migration 018 changed bookings.tenant_id and bookings.landlord_id FKs to
reference users.id, but the ORM relationships still target Tenant/Landlord
models. This mismatch causes SQLAlchemy mapper errors (500 on all endpoints).

Revision ID: 019
Revises: 018
"""
from alembic import op

revision = "019"
down_revision = "018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint("bookings_tenant_id_fkey", "bookings", type_="foreignkey")
    op.drop_constraint("bookings_landlord_id_fkey", "bookings", type_="foreignkey")

    op.create_foreign_key(
        "bookings_tenant_id_fkey",
        "bookings", "tenants",
        ["tenant_id"], ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "bookings_landlord_id_fkey",
        "bookings", "landlords",
        ["landlord_id"], ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint("bookings_tenant_id_fkey", "bookings", type_="foreignkey")
    op.drop_constraint("bookings_landlord_id_fkey", "bookings", type_="foreignkey")

    op.create_foreign_key(
        "bookings_tenant_id_fkey",
        "bookings", "users",
        ["tenant_id"], ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "bookings_landlord_id_fkey",
        "bookings", "users",
        ["landlord_id"], ["id"],
        ondelete="CASCADE",
    )

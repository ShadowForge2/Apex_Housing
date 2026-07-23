"""Fix bookings.tenant_id and bookings.landlord_id FKs to reference users.id.

The code stores User UUIDs in these columns (for notifications, permissions,
role-switching between tenant/landlord), but the FKs incorrectly pointed to
tenants.id / landlords.id which have their own auto-generated UUIDs.

Revision ID: 018
Revises: 017
"""
from alembic import op

revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop existing FKs
    op.drop_constraint("bookings_tenant_id_fkey", "bookings", type_="foreignkey")
    op.drop_constraint("bookings_landlord_id_fkey", "bookings", type_="foreignkey")

    # Recreate FKs pointing to users.id
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


def downgrade() -> None:
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

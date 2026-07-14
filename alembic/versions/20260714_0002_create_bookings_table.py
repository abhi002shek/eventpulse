"""create bookings table

Revision ID: 20260714_0002
Revises: 20260714_0001
Create Date: 2026-07-14 22:35:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260714_0002"
down_revision: str | None = "20260714_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "bookings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=False),
        sa.Column("customer_name", sa.String(length=120), nullable=False),
        sa.Column("customer_email", sa.String(length=320), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("quantity > 0", name="ck_bookings_quantity_positive"),
        sa.CheckConstraint(
            "status IN ('confirmed')",
            name="ck_bookings_status_supported",
        ),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    op.create_index(op.f("ix_bookings_event_id"), "bookings", ["event_id"], unique=False)
    op.create_index(op.f("ix_bookings_public_id"), "bookings", ["public_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_bookings_public_id"), table_name="bookings")
    op.drop_index(op.f("ix_bookings_event_id"), table_name="bookings")
    op.drop_table("bookings")

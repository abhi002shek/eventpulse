"""create events table

Revision ID: 20260714_0001
Revises:
Create Date: 2026-07-14 21:25:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260714_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("venue", sa.String(length=200), nullable=False),
        sa.Column("total_capacity", sa.Integer(), nullable=False),
        sa.Column("available_capacity", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("total_capacity > 0", name="ck_events_total_capacity_positive"),
        sa.CheckConstraint(
            "available_capacity >= 0",
            name="ck_events_available_capacity_non_negative",
        ),
        sa.CheckConstraint(
            "available_capacity <= total_capacity",
            name="ck_events_available_capacity_not_above_total",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    op.create_index(op.f("ix_events_public_id"), "events", ["public_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_events_public_id"), table_name="events")
    op.drop_table("events")

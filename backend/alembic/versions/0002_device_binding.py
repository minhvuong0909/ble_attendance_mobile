"""device binding for students

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-06 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '0002'
down_revision: Union[str, None] = '0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('users') as batch:
        batch.add_column(sa.Column('device_id', sa.String(length=64), nullable=True))
    op.create_table('device_change_requests',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('student_user_id', sa.String(length=36), nullable=False),
    sa.Column('new_device_id', sa.String(length=64), nullable=False),
    sa.Column('reason', sa.String(length=255), nullable=False),
    sa.Column('status', sa.Enum('pending', 'approved', 'rejected', name='devicerequeststatus', native_enum=False, length=16), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('resolved_by', sa.String(length=36), nullable=True),
    sa.Column('resolved_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['resolved_by'], ['users.id'], ),
    sa.ForeignKeyConstraint(['student_user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('device_change_requests')
    with op.batch_alter_table('users') as batch:
        batch.drop_column('device_id')

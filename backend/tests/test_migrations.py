from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect

BACKEND = Path(__file__).resolve().parents[1]


def test_upgrade_head_creates_every_table(tmp_path):
    url = f"sqlite:///{tmp_path / 'migrated.db'}"
    cfg = Config(str(BACKEND / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND / "alembic"))
    cfg.set_main_option("sqlalchemy.url", url)

    command.upgrade(cfg, "head")

    tables = set(inspect(create_engine(url)).get_table_names())
    assert {
        "users",
        "courses",
        "classes",
        "enrollments",
        "sessions",
        "detections",
        "attendance",
        "leave_requests",
        "notifications",
    } <= tables

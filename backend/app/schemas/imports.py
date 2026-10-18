from typing import Literal

from pydantic import BaseModel


class ImportRowOut(BaseModel):
    row: int
    status: Literal["created", "skipped", "error"]
    message: str


class ImportReportOut(BaseModel):
    kind: str
    dry_run: bool
    committed: bool
    total: int
    created: int
    skipped: int
    errors: int
    rows: list[ImportRowOut]

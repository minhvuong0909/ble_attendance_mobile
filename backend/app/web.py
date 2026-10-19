from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

WEB_DIST = Path(__file__).resolve().parent.parent / "web_dist"


def mount_web(app: FastAPI, directory: Path = WEB_DIST) -> bool:
    """Phục vụ bản Flutter web đã build tại /app nếu thư mục tồn tại."""
    if not (directory / "index.html").is_file():
        return False
    app.mount("/app", StaticFiles(directory=directory, html=True), name="web")
    return True

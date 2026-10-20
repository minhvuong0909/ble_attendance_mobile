from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, RedirectResponse, Response

WEB_DIST = Path(__file__).resolve().parent.parent / "web_dist"


def mount_web(app: FastAPI, directory: Path = WEB_DIST) -> bool:
    """Phục vụ bản web (React) đã build tại /app nếu thư mục tồn tại.

    Đường dẫn không phải tệp (ví dụ /app/teacher/classes/1) trả index.html để router phía client xử lý;
    tệp có đuôi mà không tồn tại thì trả 404.
    """
    root = directory.resolve()
    index = root / "index.html"
    if not index.is_file():
        return False

    @app.get("/app", include_in_schema=False)
    def web_root() -> Response:
        return RedirectResponse("/app/")

    @app.get("/app/{path:path}", include_in_schema=False)
    def web_file(path: str) -> Response:
        if path:
            candidate = (root / path).resolve()
            if root in candidate.parents and candidate.is_file():
                return FileResponse(candidate)
            if "." in path.rsplit("/", 1)[-1]:
                raise HTTPException(status_code=404)
        return FileResponse(index, headers={"Cache-Control": "no-cache"})

    return True

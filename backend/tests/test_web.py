from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.web import mount_web


def test_mount_web_serves_index_under_app(tmp_path):
    (tmp_path / "index.html").write_text("<html>hi</html>")
    (tmp_path / "main.dart.js").write_text("js")
    app = FastAPI()
    assert mount_web(app, tmp_path) is True
    client = TestClient(app)
    assert "hi" in client.get("/app/").text
    assert client.get("/app/main.dart.js").text == "js"


def test_mount_web_is_skipped_without_a_build(tmp_path):
    app = FastAPI()
    assert mount_web(app, tmp_path / "missing") is False
    assert TestClient(app).get("/app/").status_code == 404

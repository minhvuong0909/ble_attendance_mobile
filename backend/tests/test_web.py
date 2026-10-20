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


def test_deep_links_fall_back_to_index_but_missing_assets_are_404(tmp_path):
    (tmp_path / "index.html").write_text("<html>spa</html>")
    (tmp_path / "assets").mkdir()
    (tmp_path / "assets" / "a.js").write_text("js")
    app = FastAPI()
    mount_web(app, tmp_path)
    client = TestClient(app)
    assert "spa" in client.get("/app/teacher/classes/123").text
    assert "spa" in client.get("/app/admin").text
    assert client.get("/app/assets/a.js").text == "js"
    assert client.get("/app/assets/missing.js").status_code == 404
    assert client.get("/app", follow_redirects=False).status_code in (307, 308)


def test_web_cannot_read_files_outside_the_build_directory(tmp_path):
    site = tmp_path / "site"
    site.mkdir()
    (site / "index.html").write_text("<html>spa</html>")
    (tmp_path / "secret.txt").write_text("secret")
    app = FastAPI()
    mount_web(app, site)
    client = TestClient(app)
    for attempt in ("/app/../secret.txt", "/app/%2e%2e/secret.txt", "/app/..%2fsecret.txt"):
        response = client.get(attempt)
        assert "secret" not in response.text

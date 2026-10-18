from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.errors import ApiError, register_error_handlers


def test_api_error_is_rendered_as_detail_and_code():
    app = FastAPI()
    register_error_handlers(app)

    @app.get("/boom")
    def boom():
        raise ApiError(409, "something_wrong", "Có lỗi")

    response = TestClient(app).get("/boom")
    assert response.status_code == 409
    assert response.json() == {"detail": "Có lỗi", "code": "something_wrong"}


def test_api_error_forwards_headers():
    app = FastAPI()
    register_error_handlers(app)

    @app.get("/auth")
    def auth():
        raise ApiError(401, "invalid_token", "x", headers={"WWW-Authenticate": "Bearer"})

    response = TestClient(app).get("/auth")
    assert response.headers["www-authenticate"] == "Bearer"

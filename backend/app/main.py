from fastapi import FastAPI

from app.core.config import settings
from app.core.errors import register_error_handlers
from app.routers import admin as admin_router
from app.routers import auth as auth_router

app = FastAPI(title=settings.app_name)
register_error_handlers(app)
app.include_router(auth_router.router)
app.include_router(admin_router.router)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}

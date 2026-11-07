from fastapi import FastAPI

from app.core.config import settings
from app.core.errors import register_error_handlers
from app.routers import admin as admin_router
from app.routers import attendance as attendance_router
from app.routers import auth as auth_router
from app.routers import classes as classes_router
from app.routers import detections as detections_router
from app.routers import device_requests as device_requests_router
from app.routers import imports as imports_router
from app.routers import leave as leave_router
from app.routers import me as me_router
from app.routers import notifications as notifications_router
from app.routers import reports as reports_router
from app.routers import sessions as sessions_router
from app.web import mount_web

app = FastAPI(title=settings.app_name)
register_error_handlers(app)
app.include_router(auth_router.router)
app.include_router(admin_router.router)
app.include_router(device_requests_router.router)
app.include_router(imports_router.router)
app.include_router(classes_router.router)
app.include_router(sessions_router.router)
app.include_router(detections_router.router)
app.include_router(attendance_router.router)
app.include_router(notifications_router.router)
app.include_router(me_router.router)
app.include_router(reports_router.router)
app.include_router(leave_router.router)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


mount_web(app)

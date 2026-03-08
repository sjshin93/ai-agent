from fastapi import APIRouter

from app.api.v1.admin.router import router as admin_router
from app.api.v1.archive.router import router as archive_router
from app.api.v1.auth.router import router as auth_router
from app.api.v1.collection.router import router as collection_router
from app.api.v1.config.router import router as config_router
from app.api.v1.llm.router import router as llm_router
from app.api.v1.slack_notification.router import router as slack_notification_router
from app.api.v1.ssh.router import router as ssh_router

api_router = APIRouter()
api_router.include_router(admin_router, prefix="/admin", tags=["admin"])
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(config_router, prefix="/config", tags=["config"])
api_router.include_router(collection_router, prefix="/collection", tags=["collection"])
api_router.include_router(ssh_router, prefix="/ssh", tags=["ssh"])
api_router.include_router(
    slack_notification_router,
    prefix="/slack-notification",
    tags=["slack-notification"],
)
api_router.include_router(llm_router, prefix="/llm", tags=["llm"])
api_router.include_router(archive_router, prefix="/archive", tags=["archive"])

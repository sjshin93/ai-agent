import asyncio

from fastapi import FastAPI

from app.api.router import api_router
from app.core.config import settings
from app.core.session_auth import SessionAuthMiddleware
from app.core.session_state import session_manager
from app.domains.collection.service import load_collection

app = FastAPI(
    root_path="/api",
    title="MongMind",
    version=settings.version,
    description=(
        "Internal API for the MongMind platform, covering collection test, SSH, LLM, and Slack notification."
    ),
    openapi_tags=[
        {"name": "admin", "description": "Admin-only user management endpoints."},
        {"name": "config", "description": "Runtime config and session heartbeat."},
        {"name": "auth", "description": "Google/Kakao OAuth sign-in/out."},
        {"name": "collection", "description": "Collection list and execution."},
        {"name": "ssh", "description": "SSH command execution via bastion flow."},
        {"name": "llm", "description": "LLM query endpoint."},
        {"name": "slack-notification", "description": "Slack message endpoint."},
    ],
)
app.add_middleware(SessionAuthMiddleware, session_manager=session_manager)
app.include_router(api_router)
_session_cleanup_task: asyncio.Task | None = None


async def _session_cleanup_loop() -> None:
    import logging

    logger = logging.getLogger("uvicorn.error")
    interval = max(1, settings.session_cleanup_interval_seconds)
    while True:
        await asyncio.sleep(interval)
        deleted = await session_manager.delete_expired_or_revoked_sessions()
        if deleted > 0:
            logger.info("Session cleanup deleted %s rows", deleted)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.on_event("startup")
async def log_startup_settings() -> None:
    # Use Uvicorn's error logger so it always appears in container logs.
    import logging

    logger = logging.getLogger("uvicorn.error")
    logger.info(
        "Startup config: LOG_LEVEL=%s SESSION_CLEANUP_INTERVAL_SECONDS=%s SESSION_RETENTION_SECONDS=%s",
        settings.log_level,
        settings.session_cleanup_interval_seconds,
        settings.session_retention_seconds,
    )
    await session_manager.initialize()
    global _session_cleanup_task
    _session_cleanup_task = asyncio.create_task(_session_cleanup_loop())
    load_collection()


@app.on_event("shutdown")
async def close_resources() -> None:
    global _session_cleanup_task
    if _session_cleanup_task is not None:
        _session_cleanup_task.cancel()
        try:
            await _session_cleanup_task
        except asyncio.CancelledError:
            pass
        _session_cleanup_task = None
    await session_manager.close()

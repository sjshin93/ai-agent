from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.config import settings
from app.dependencies import get_session_manager
from app.core.session_manager import SessionManager
from app.domains.admin.schemas import AdminUserItem, AdminUserListResponse

router = APIRouter()


@router.get("/users", response_model=AdminUserListResponse)
async def list_users(
    request: Request,
    sessions: SessionManager = Depends(get_session_manager),
):
    session_id = request.cookies.get(settings.session_cookie_name)
    user_id = await sessions.validate_and_touch(session_id) if session_id else None
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    role = await sessions.get_user_role(str(user_id))
    if role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    rows = await sessions.list_users()
    return AdminUserListResponse(
        users=[AdminUserItem(**row) for row in rows],
    )

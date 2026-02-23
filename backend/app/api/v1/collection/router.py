import logging

from fastapi import APIRouter, HTTPException, Request

from app.core.config import settings
from app.core.http import HttpClient
from app.domains.collection.schemas import (
    CollectionExecuteRequest,
    CollectionExecuteResponse,
    CollectionItem,
    CollectionListResponse,
)
from app.domains.collection.service import (
    get_collection_item,
    list_collection_items,
    substitute,
)

router = APIRouter()
_http = HttpClient()
logger = logging.getLogger("uvicorn.error")


@router.get("/items", response_model=CollectionListResponse)
def list_items(request: Request):
    user = getattr(request.state, "username", "anonymous")
    client_ip = request.client.host if request.client else "unknown"
    items = [
        CollectionItem(
            id=item.id,
            name=item.name,
            method=item.method,
            url=item.url,
            params=item.params,
            body=item.body,
        )
        for item in list_collection_items()
    ]
    logger.info(
        "collection.items.list",
        extra={
            "event": "collection.items.list",
            "user": user,
            "ip": client_ip,
            "item_count": len(items),
        },
    )
    return CollectionListResponse(items=items)


@router.post("/execute", response_model=CollectionExecuteResponse)
async def execute_item(payload: CollectionExecuteRequest, request: Request):
    user = getattr(request.state, "username", "anonymous")
    client_ip = request.client.host if request.client else "unknown"
    item = get_collection_item(payload.id)
    if not item:
        logger.warning(
            "collection.execute.not_found",
            extra={
                "event": "collection.execute.not_found",
                "user": user,
                "ip": client_ip,
                "item_id": payload.id,
            },
        )
        raise HTTPException(status_code=404, detail="Collection item not found")

    params = dict(payload.params or {})
    url = substitute(item.url, params, item.defaults)
    body = payload.body if payload.body is not None else item.body
    if body is not None:
        body = substitute(body, params, item.defaults)

    if not url.startswith("http://") and not url.startswith("https://"):
        if not settings.collection_base_url:
            raise HTTPException(
                status_code=400,
                detail="COLLECTION_BASE_URL is required for relative URLs",
            )
        url = f"{settings.collection_base_url.rstrip('/')}/{url.lstrip('/')}"
    headers = dict(item.headers)
    if payload.access_token:
        headers.setdefault("Authorization", f"Bearer {payload.access_token}")
    if body is not None and "Content-Type" not in headers:
        headers["Content-Type"] = "application/json"

    res = await _http.request(
        item.method,
        url,
        headers=headers,
        content=body,
        verify=payload.verify_ssl,
    )
    logger.info(
        "collection.execute.done",
        extra={
            "event": "collection.execute.done",
            "user": user,
            "ip": client_ip,
            "item_id": payload.id,
            "method": item.method,
            "url": str(res.url),
            "status_code": res.status_code,
        },
    )

    response_headers = {k: v for k, v in res.headers.items()}
    return CollectionExecuteResponse(
        status_code=res.status_code,
        url=str(res.url),
        headers=response_headers,
        body=res.text,
    )

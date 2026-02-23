import logging

from app.core.config import settings
from app.core.http import HttpClient, HttpRetryConfig
from app.domains.collection.service import resolve_framework_url_for_site


class HtOauthService:
    def __init__(self) -> None:
        self._token_url = settings.oauth_token_url
        self._http = HttpClient(timeout=5, retry=HttpRetryConfig(retries=1))
        self._logger = logging.getLogger("uvicorn.error")

    async def login(
        self, username: str, password: str
    ) -> tuple[bool, str | None, str | None]:
        if not self._token_url:
            return False, "OAUTH_TOKEN_URL not configured", None

        payload = {"username": username, "password": password}
        try:
            res = await self._http.request("POST", self._token_url, json=payload)
            if res.status_code == 200:
                access_token = None
                try:
                    data = res.json()
                    if isinstance(data, dict):
                        access_token = data.get("access_token") or data.get("token")
                except ValueError:
                    access_token = None
                return True, None, access_token
            return False, f"HT OAuth failed: {res.status_code}", None
        except Exception as exc:
            return False, f"HT OAuth error: {exc}", None

    async def reboot_wallpad(
        self,
        *,
        access_token: str,
        site_id: int,
        dong: int,
        ho: int,
    ) -> tuple[bool, str | None, dict | list | str | None, str | None]:
        if not access_token:
            return False, "HT OAuth access token missing", None, "TOKEN_MISSING"
        framework_url = resolve_framework_url_for_site(site_id)
        if not framework_url:
            return (
                False,
                f"siteId {site_id} has no mapped IP in info_danji.txt",
                None,
                "SITE_MAPPING_NOT_FOUND",
            )

        url = f"{framework_url}/wallpad/reboot?access_token={access_token}"
        payload = {
            "siteId": site_id,
            "rebootType": "AKN002",
            "targetType": "AKM001",
            "threadPoolSize": 1,
            "restartWhenFail": True,
            "rebootTargetList": [{"dong": dong, "ho": ho}],
        }
        try:
            res = await self._http.request("POST", url, json=payload, verify=False)
            try:
                data = res.json()
            except ValueError:
                data = res.text
            if 200 <= res.status_code < 300:
                return True, None, data, None
            self._logger.warning(
                "ht_oauth.reboot.wallpad_response_error",
                extra={
                    "event": "ht_oauth.reboot.wallpad_response_error",
                    "site_id": site_id,
                    "dong": dong,
                    "ho": ho,
                    "status_code": res.status_code,
                },
            )
            return (
                False,
                f"Wallpad server returned error response ({res.status_code})",
                data,
                "WALLPAD_RESPONSE_ERROR",
            )
        except Exception as exc:
            self._logger.exception(
                "ht_oauth.reboot.request_failed",
                extra={
                    "event": "ht_oauth.reboot.request_failed",
                    "site_id": site_id,
                    "dong": dong,
                    "ho": ho,
                    "url": url,
                },
            )
            return (
                False,
                f"Failed to send reboot request to wallpad server: {exc}",
                None,
                "REQUEST_FAILED",
            )

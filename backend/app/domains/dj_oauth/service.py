import logging

from app.core.config import settings
from app.core.http import HttpClient, HttpRetryConfig


class DjOauthService:
    def __init__(self) -> None:
        self._url = settings.dj_oauth_url
        self._basic_user = settings.dj_oauth_basic_user
        self._basic_pass = settings.dj_oauth_basic_pass
        self._http = HttpClient(timeout=5, retry=HttpRetryConfig(retries=1))
        self._logger = logging.getLogger("uvicorn.error")

    async def login(
        self, user_id: str, password: str
    ) -> tuple[bool, str | None, str | None]:
        if not self._url:
            return False, "DJ_OAUTH_URL not configured", None
        if not self._basic_user or not self._basic_pass:
            return False, "DJ_OAUTH_BASIC credentials not configured", None

        payload = {
            "userId": user_id,
            "password": password,
            "clientType": "IPhone",
            "isHashedPwd": False,
        }
        try:
            res = await self._http.request(
                "POST",
                self._url,
                json=payload,
                auth=(self._basic_user, self._basic_pass),
            )
            self._logger.info("DJ OAuth response: status=%s", res.status_code)
            if res.status_code == 200:
                access_token = None
                try:
                    data = res.json()
                    if isinstance(data, dict):
                        access_token = data.get("accessToken") or data.get(
                            "access_token"
                        )
                        if access_token is None:
                            result_data = data.get("resultData")
                            if isinstance(result_data, dict):
                                access_token = result_data.get("accessToken")
                except ValueError:
                    access_token = None
                return True, None, access_token
            return False, f"DJ OAuth failed: {res.status_code}", None
        except Exception as exc:
            return False, f"DJ OAuth error: {exc}", None

    async def create_household_access(
        self,
        *,
        access_token: str,
        site_id: int,
        dong: str,
        ho: str,
        nickname: str,
    ) -> tuple[bool, str | None, dict | list | str | None]:
        if not settings.dj_household_url:
            return False, "DJ_HOUSEHOLD_URL not configured", None
        if not access_token:
            return False, "DJ OAuth access token missing", None

        payload = {
            "siteId": site_id,
            "dong": dong,
            "ho": ho,
            "nickname": nickname,
        }
        try:
            res = await self._http.request(
                "POST",
                settings.dj_household_url,
                json=payload,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            self._logger.info(
                "DJ household response: status=%s", res.status_code
            )
            try:
                data = res.json()
            except ValueError:
                data = res.text
            if 200 <= res.status_code < 300:
                return True, None, data
            return False, f"DJ household failed: {res.status_code}", data
        except Exception as exc:
            return False, f"DJ household error: {exc}", None

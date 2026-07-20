"""
Google OAuth 2.0 service for social login.
Handles Google Sign-In token verification and user info retrieval.
"""
import logging
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"
GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"


class GoogleOAuthService:
    def __init__(self):
        self.client_id = settings.GOOGLE_CLIENT_ID
        self.client_secret = settings.GOOGLE_CLIENT_SECRET
        self.redirect_uri = settings.GOOGLE_REDIRECT_URI

    def get_authorization_url(self, state: str = None) -> str:
        params = {
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "access_type": "offline",
            "prompt": "consent",
        }
        if state:
            params["state"] = state

        query = "&".join(f"{k}={v}" for k, v in params.items())
        return f"{GOOGLE_AUTH_URL}?{query}"

    async def exchange_code(self, code: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                GOOGLE_TOKEN_URL,
                data={
                    "code": code,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "redirect_uri": self.redirect_uri,
                    "grant_type": "authorization_code",
                },
                timeout=15,
            )
            data = response.json()
            if "access_token" not in data:
                logger.error(f"Google token exchange failed: {data}")
            return data

    async def refresh_token(self, refresh_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                GOOGLE_TOKEN_URL,
                data={
                    "refresh_token": refresh_token,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "grant_type": "refresh_token",
                },
                timeout=15,
            )
            return response.json()

    async def get_user_info(self, access_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                GOOGLE_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
                timeout=15,
            )
            data = response.json()
            if "error" in data:
                logger.error(f"Google userinfo error: {data}")
                return {}
            return {
                "google_id": data.get("id"),
                "email": data.get("email"),
                "name": data.get("name"),
                "first_name": data.get("given_name"),
                "last_name": data.get("family_name"),
                "avatar_url": data.get("picture"),
                "email_verified": data.get("verified_email", False),
            }

    async def verify_id_token(self, id_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                GOOGLE_CERTS_URL,
                timeout=15,
            )
            certs = response.json()

        try:
            from jose import jwt
            header = jwt.get_unverified_header(id_token)
            kid = header.get("kid")

            public_key = None
            for cert in certs.get("keys", []):
                if cert.get("kid") == kid:
                    public_key = cert
                    break

            if not public_key:
                logger.error("Google ID token kid not found in certs")
                return {}

            payload = jwt.decode(
                id_token,
                public_key,
                algorithms=["RS256"],
                audience=self.client_id,
            )
            return {
                "google_id": payload.get("sub"),
                "email": payload.get("email"),
                "name": payload.get("name"),
                "first_name": payload.get("given_name"),
                "last_name": payload.get("family_name"),
                "avatar_url": payload.get("picture"),
                "email_verified": payload.get("email_verified", False),
            }
        except Exception as e:
            logger.error(f"Google ID token verification failed: {e}")
            return {}


google_oauth_service = GoogleOAuthService()

"""
Supabase Storage client for file uploads (images, documents, KYC).
Uses Supabase REST API for storage operations.
"""
import logging
from typing import Optional
from uuid import uuid4

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class SupabaseStorageService:
    def __init__(self):
        self.base_url = f"{settings.SUPABASE_URL}/storage/v1"
        self.service_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY
        self.bucket = settings.SUPABASE_STORAGE_BUCKET
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
        }

    async def upload_file(
        self,
        file_bytes: bytes,
        file_name: str,
        content_type: str,
        folder: str = "uploads",
    ) -> dict:
        ext = file_name.rsplit(".", 1)[-1] if "." in file_name else "bin"
        path = f"{folder}/{uuid4().hex}.{ext}"

        headers = {**self.headers, "Content-Type": content_type}
        url = f"{self.base_url}/object/{self.bucket}/{path}"

        async with httpx.AsyncClient() as client:
            response = await client.post(
                url, content=file_bytes, headers=headers, timeout=60
            )
            if response.status_code == 200:
                public_url = f"{self.base_url}/object/public/{self.bucket}/{path}"
                return {"path": path, "url": public_url, "size": len(file_bytes)}
            else:
                logger.error(f"Supabase upload error: {response.text}")
                raise Exception(f"Upload failed: {response.status_code}")

    async def delete_file(self, paths: list[str]) -> bool:
        url = f"{self.base_url}/object/{self.bucket}"
        payload = {"prefixes": paths} if len(paths) > 1 else {"prefix": paths[0]}

        async with httpx.AsyncClient() as client:
            response = await client.delete(
                url, json=payload, headers=self.headers, timeout=30
            )
            return response.status_code == 200

    async def get_signed_url(self, path: str, expires_in: int = 3600) -> str:
        url = f"{self.base_url}/object/sign/{self.bucket}/{path}"
        payload = {"expiresIn": expires_in}

        async with httpx.AsyncClient() as client:
            response = await client.post(
                url, json=payload, headers=self.headers, timeout=30
            )
            if response.status_code == 200:
                data = response.json()
                return f"{self.base_url}{data['signedUrl']}"
            raise Exception(f"Failed to generate signed URL: {response.text}")

    async def list_files(self, folder: str = "uploads", limit: int = 100) -> list:
        url = f"{self.base_url}/object/list/{self.bucket}"
        payload = {"prefix": f"{folder}/", "limit": limit}

        async with httpx.AsyncClient() as client:
            response = await client.post(
                url, json=payload, headers=self.headers, timeout=30
            )
            if response.status_code == 200:
                return response.json().get("keys", [])
            return []

    def get_public_url(self, path: str) -> str:
        return f"{self.base_url}/object/public/{self.bucket}/{path}"

    # --- Convenience methods ---
    async def upload_property_image(self, file_bytes: bytes, property_id: str, file_name: str, content_type: str) -> dict:
        return await self.upload_file(file_bytes, file_name, content_type, folder=f"properties/{property_id}/images")

    async def upload_kyc_document(self, file_bytes: bytes, user_id: str, file_name: str, content_type: str) -> dict:
        return await self.upload_file(file_bytes, file_name, content_type, folder=f"users/{user_id}/kyc")

    async def upload_property_document(self, file_bytes: bytes, property_id: str, file_name: str, content_type: str) -> dict:
        return await self.upload_file(file_bytes, file_name, content_type, folder=f"properties/{property_id}/documents")

    async def upload_profile_picture(self, file_bytes: bytes, user_id: str, file_name: str, content_type: str) -> dict:
        return await self.upload_file(file_bytes, file_name, content_type, folder=f"users/{user_id}/profile")


supabase_storage = SupabaseStorageService()

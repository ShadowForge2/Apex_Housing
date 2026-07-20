"""
Firebase Cloud Messaging (FCM) push notification client.
Uses Firebase Admin SDK for sending push notifications to mobile devices.
"""
import logging
from typing import Optional

from app.config import settings

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _initialize_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return

    try:
        import json
        import tempfile
        import os
        import firebase_admin
        from firebase_admin import credentials

        # Try JSON env var first (for Render/cloud deployments)
        if settings.FIREBASE_CREDENTIALS_JSON:
            cred_dict = json.loads(settings.FIREBASE_CREDENTIALS_JSON)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized from env var")
            return

        # Fall back to file path (for local development)
        cred_path = settings.FIREBASE_CREDENTIALS_PATH
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized from file")
        else:
            logger.warning("Firebase credentials not configured")
    except Exception as e:
        logger.error(f"Firebase initialization failed: {e}")


class FCMService:
    def __init__(self):
        _initialize_firebase()

    async def send_to_token(
        self,
        token: str,
        title: str,
        body: str,
        data: dict = None,
        image: str = None,
        click_action: str = None,
    ) -> dict:
        try:
            from firebase_admin import messaging

            notification = messaging.Notification(title=title, body=body, image=image)
            android_config = messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    click_action=click_action,
                ),
            )
            apns_config = messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(badge=1, sound="default")
                ),
            )

            message = messaging.Message(
                notification=notification,
                android=android_config,
                apns=apns_config,
                token=token,
                data={k: str(v) for k, v in (data or {}).items()},
            )

            response = messaging.send(message)
            logger.info(f"FCM message sent: {response}")
            return {"success": True, "message_id": response}
        except Exception as e:
            logger.error(f"FCM send error: {e}")
            return {"success": False, "error": str(e)}

    async def send_to_topic(
        self,
        topic: str,
        title: str,
        body: str,
        data: dict = None,
    ) -> dict:
        try:
            from firebase_admin import messaging

            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                topic=topic,
                data={k: str(v) for k, v in (data or {}).items()},
            )

            response = messaging.send(message)
            return {"success": True, "message_id": response}
        except Exception as e:
            logger.error(f"FCM topic send error: {e}")
            return {"success": False, "error": str(e)}

    async def send_to_multiple_tokens(
        self,
        tokens: list[str],
        title: str,
        body: str,
        data: dict = None,
    ) -> dict:
        try:
            from firebase_admin import messaging

            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                tokens=tokens,
                data={k: str(v) for k, v in (data or {}).items()},
            )

            response = messaging.send_each_for_multicast(message)
            logger.info(f"FCM multicast: {response.success_count} sent, {response.failure_count} failed")
            return {
                "success": True,
                "success_count": response.success_count,
                "failure_count": response.failure_count,
            }
        except Exception as e:
            logger.error(f"FCM multicast error: {e}")
            return {"success": False, "error": str(e)}

    async def subscribe_to_topic(self, tokens: list[str], topic: str) -> dict:
        try:
            from firebase_admin import messaging
            response = messaging.subscribe_to_topic(tokens, topic)
            return {"success": True, "success_count": response.success_count}
        except Exception as e:
            logger.error(f"FCM subscribe error: {e}")
            return {"success": False, "error": str(e)}


fcm_service = FCMService()

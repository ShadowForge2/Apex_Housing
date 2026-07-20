import json
import logging
import time
import uuid
from typing import Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.config import settings

logger = logging.getLogger("app.middleware.api_logging")

SKIP_PATHS = frozenset({"/health", "/docs", "/redoc", "/openapi.json", "/favicon.ico"})


class APILoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        path = request.url.path

        if any(path.startswith(p) for p in ["/api/v1/health", "/health"]):
            return await call_next(request)

        if path in SKIP_PATHS:
            return await call_next(request)

        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        start_time = time.time()

        client_ip = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        if not client_ip:
            client_ip = request.client.host if request.client else "unknown"

        log_entry = {
            "request_id": request_id,
            "method": request.method,
            "path": path,
            "query": str(request.query_params) if request.query_params else None,
            "client_ip": client_ip,
            "user_agent": request.headers.get("user-agent", "")[:200],
        }

        if settings.LOG_REQUEST_BODY and request.method in ("POST", "PUT", "PATCH"):
            try:
                body = await request.body()
                log_entry["body_size"] = len(body)
            except Exception:
                pass

        _safe_log(logger.info, "request", log_entry)

        try:
            response = await call_next(request)
        except Exception:
            elapsed_ms = round((time.time() - start_time) * 1000, 2)
            _safe_log(logger.error, "response_error", {
                "request_id": request_id,
                "path": path,
                "elapsed_ms": elapsed_ms,
            })
            raise

        elapsed_ms = round((time.time() - start_time) * 1000, 2)
        status = response.status_code

        response.headers["X-Request-ID"] = request_id

        resp_entry = {
            "request_id": request_id,
            "method": request.method,
            "path": path,
            "status": status,
            "elapsed_ms": elapsed_ms,
        }

        if status >= 500:
            _safe_log(logger.error, "response", resp_entry)
        elif status >= 400:
            _safe_log(logger.warning, "response", resp_entry)
        else:
            _safe_log(logger.info, "response", resp_entry)

        return response


def _safe_log(log_fn: Callable, prefix: str, data: dict):
    try:
        log_fn(f"[{prefix}] {json.dumps(data, default=str)}")
    except Exception:
        try:
            log_fn(f"[{prefix}] {str(data)}")
        except Exception:
            pass

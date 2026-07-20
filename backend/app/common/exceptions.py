from typing import Any, Optional


class AppException(Exception):
    def __init__(
        self,
        message: str = "An error occurred",
        status_code: int = 500,
        errors: Optional[Any] = None,
    ):
        self.message = message
        self.status_code = status_code
        self.errors = errors
        super().__init__(self.message)


class NotFound(AppException):
    def __init__(self, message: str = "Resource not found", errors: Optional[Any] = None):
        super().__init__(message=message, status_code=404, errors=errors)


class Unauthorized(AppException):
    def __init__(self, message: str = "Unauthorized", errors: Optional[Any] = None):
        super().__init__(message=message, status_code=401, errors=errors)


class Forbidden(AppException):
    def __init__(self, message: str = "Forbidden", errors: Optional[Any] = None):
        super().__init__(message=message, status_code=403, errors=errors)


class BadRequest(AppException):
    def __init__(self, message: str = "Bad request", errors: Optional[Any] = None):
        super().__init__(message=message, status_code=400, errors=errors)


class Conflict(AppException):
    def __init__(self, message: str = "Resource already exists", errors: Optional[Any] = None):
        super().__init__(message=message, status_code=409, errors=errors)


class ValidationError(AppException):
    def __init__(self, message: str = "Validation error", errors: Optional[Any] = None):
        super().__init__(message=message, status_code=422, errors=errors)

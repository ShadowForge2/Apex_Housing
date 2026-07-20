from typing import List

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "APEX Housing"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"

    DATABASE_URL: str
    REDIS_URL: str = "redis://localhost:6379/0"

    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # --- Paystack (Payment Gateway) ---
    PAYSTACK_SECRET_KEY: str
    PAYSTACK_PUBLIC_KEY: str = ""
    PAYSTACK_WEBHOOK_SECRET: str = ""

    # Paystack fee passed to customer on deposits (1.5% capped at ₦2,000)
    PAYSTACK_FEE_PERCENT: float = 1.5
    PAYSTACK_FEE_CAP: float = 2000.0

    # Platform identifier embedded in every Paystack reference and metadata.
    # Used to distinguish APEX Housing transactions from other platforms sharing
    # the same Paystack API key.  Max 10 chars (Paystack reference limit).
    PAYSTACK_PLATFORM_ID: str = "APXHOUSING"

    # --- Supabase (Storage) ---
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_STORAGE_BUCKET: str = "apex-media"

    # --- Firebase (Push Notifications) ---
    FIREBASE_CREDENTIALS_PATH: str = "firebase_credentials.json"
    FIREBASE_PROJECT_ID: str = ""

    # --- Email (SMTP for verification) ---
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = "support@apex-housing.online"
    SMTP_FROM_NAME: str = "APEX Housing"

    # --- SendGrid (Optional Email Provider) ---
    EMAIL_PROVIDER: str = "smtp"
    SENDGRID_API_KEY: str = ""
    SENDGRID_FROM_EMAIL: str = ""

    # --- Google Maps (Geocoding + Places) ---
    GOOGLE_MAPS_API_KEY: str = ""

    # --- Sentry (Error Tracking) ---
    SENTRY_DSN: str = ""
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1

    # --- Google OAuth ---
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GOOGLE_REDIRECT_URI: str = ""  # Set in .env: https://apex-housing.online/api/v1/auth/google/callback

    # --- App Settings ---
    FRONTEND_URL: str = "https://apex-housing.online"
    CORS_ORIGINS: List[str] = [
        "https://apex-housing.online",
        "http://localhost:5173",
        "http://localhost:5174",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:5174",
    ]
    USE_SSL: bool = True
    ENVIRONMENT: str = "production"

    # --- Rate Limiting ---
    RATE_LIMIT_ENABLED: bool = True

    # --- Logging ---
    LOG_LEVEL: str = "INFO"
    LOG_REQUEST_BODY: bool = False

    # --- Media ---
    MAX_UPLOAD_SIZE_MB: int = 10
    ALLOWED_IMAGE_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]
    ALLOWED_DOCUMENT_TYPES: List[str] = ["application/pdf", "image/jpeg", "image/png"]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

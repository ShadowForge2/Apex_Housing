"""Timezone-aware UTC helpers — replaces deprecated datetime.utcnow()."""
from datetime import datetime, timezone


def utcnow() -> datetime:
    """Return the current UTC datetime (timezone-aware)."""
    return datetime.now(timezone.utc)


def utcnow_naive() -> datetime:
    """Return the current UTC datetime as a naive datetime (for DB columns without tz)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)

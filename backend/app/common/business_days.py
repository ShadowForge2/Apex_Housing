"""
Business day utility — determines if a given datetime is a Paystack business day.

Paystack processes transfers only on:
- Weekdays (Monday–Friday)
- Nigerian public holidays are NOT business days
- Transfers initiated after 2PM WAT on a business day may queue to the next business day
"""
from datetime import datetime, date, timedelta
from typing import Optional


# Nigerian public holidays for 2025 and 2026
# These are fixed + computed Islamic holidays (date shifts yearly)
NIGERIAN_HOLIDAYS_2025 = [
    date(2025, 1, 1),    # New Year's Day
    date(2025, 4, 18),   # Good Friday
    date(2025, 4, 21),   # Easter Monday
    date(2025, 5, 1),    # Workers' Day
    date(2025, 5, 29),   # Democracy Day
    date(2025, 6, 7),    # Eid al-Adha (estimated)
    date(2025, 6, 8),    # Eid al-Adha day 2 (estimated)
    date(2025, 10, 1),   # Independence Day
    date(2025, 12, 25),  # Christmas Day
    date(2025, 12, 26),  # Boxing Day
    date(2025, 3, 30),   # Eid al-Fitr (estimated)
    date(2025, 3, 31),   # Eid al-Fitr day 2 (estimated)
]

NIGERIAN_HOLIDAYS_2026 = [
    date(2026, 1, 1),    # New Year's Day
    date(2026, 4, 3),    # Good Friday
    date(2026, 4, 6),    # Easter Monday
    date(2026, 5, 1),    # Workers' Day
    date(2026, 5, 29),   # Democracy Day
    date(2026, 3, 20),   # Eid al-Fitr (estimated)
    date(2026, 3, 21),   # Eid al-Fitr day 2 (estimated)
    date(2026, 5, 27),   # Eid al-Adha (estimated)
    date(2026, 5, 28),   # Eid al-Adha day 2 (estimated)
    date(2026, 10, 1),   # Independence Day
    date(2026, 12, 25),  # Christmas Day
    date(2026, 12, 26),  # Boxing Day
]

NIGERIAN_HOLIDAYS_2027 = [
    date(2027, 1, 1),    # New Year's Day
    date(2027, 3, 26),   # Eid al-Fitr (estimated)
    date(2027, 3, 29),   # Easter Monday
    date(2027, 3, 25),   # Good Friday
    date(2027, 5, 1),    # Workers' Day
    date(2027, 5, 16),   # Eid al-Adha (estimated)
    date(2027, 5, 17),   # Eid al-Adha day 2 (estimated)
    date(2027, 5, 29),   # Democracy Day
    date(2027, 10, 1),   # Independence Day
    date(2027, 12, 25),  # Christmas Day
    date(2027, 12, 26),  # Boxing Day
]

ALL_HOLIDAYS = set(NIGERIAN_HOLIDAYS_2025 + NIGERIAN_HOLIDAYS_2026 + NIGERIAN_HOLIDAYS_2027)

# Paystack cutoff time: transfers initiated after this time queue to next business day
PAYOUT_CUTOFF_HOUR = 14  # 2:00 PM WAT (West Africa Time, UTC+1)


def is_weekend(dt: Optional[datetime] = None) -> bool:
    """Check if a date falls on Saturday or Sunday."""
    if dt is None:
        dt = datetime.utcnow()
    return dt.weekday() >= 5  # 5=Saturday, 6=Sunday


def is_public_holiday(dt: Optional[date] = None) -> bool:
    """Check if a date is a Nigerian public holiday."""
    if dt is None:
        dt = datetime.utcnow().date()
    return dt in ALL_HOLIDAYS


def is_business_day(dt: Optional[datetime] = None) -> bool:
    """Check if a datetime falls on a business day (weekday, not holiday)."""
    if dt is None:
        dt = datetime.utcnow()
    check_date = dt.date() if isinstance(dt, datetime) else dt
    return not is_weekend(dt) and not is_public_holiday(check_date)


def is_within_payout_cutoff(dt: Optional[datetime] = None) -> bool:
    """
    Check if a time is within Paystack's payout cutoff window.
    Transfers initiated before 2PM WAT on a business day are processed same day.
    After 2PM WAT, they queue to the next business day.
    """
    if dt is None:
        dt = datetime.utcnow()
    return dt.hour < PAYOUT_CUTOFF_HOUR


def get_next_business_day(dt: Optional[date] = None) -> date:
    """Get the next business day from the given date (inclusive if already a business day)."""
    if dt is None:
        dt = datetime.utcnow().date()
    if isinstance(dt, datetime):
        dt = dt.date()

    next_day = dt
    # If today is not a business day, advance to next one
    if not is_business_day(next_day):
        while not is_business_day(next_day):
            next_day += timedelta(days=1)
    return next_day


def get_next_business_datetime(dt: Optional[datetime] = None) -> datetime:
    """
    Get the next datetime when a transfer can be processed.
    - If before cutoff on a business day: returns now (same day processing)
    - If after cutoff on a business day: returns 9AM on the next business day
    - If weekend/holiday: returns 9AM on the next business day
    """
    if dt is None:
        dt = datetime.utcnow()

    if is_business_day(dt) and is_within_payout_cutoff(dt):
        return dt

    next_biz = get_next_business_day(dt.date())
    if next_biz == dt.date() and not is_within_payout_cutoff(dt):
        # Same business day but after cutoff — schedule for tomorrow 9AM
        next_biz = get_next_business_day(dt.date() + timedelta(days=1))

    return datetime.combine(next_biz, datetime.min.time().replace(hour=9))


def can_withdraw_now(dt: Optional[datetime] = None) -> bool:
    """Quick check: can a withdrawal be processed right now?"""
    if dt is None:
        dt = datetime.utcnow()
    return is_business_day(dt) and is_within_payout_cutoff(dt)


def format_next_business_day(dt: Optional[datetime] = None) -> str:
    """Human-readable message for when the next business day is."""
    next_dt = get_next_business_datetime(dt)
    return next_dt.strftime("%A, %B %d, %Y at %I:%M %p UTC")

import re
from typing import Optional


class ContentModerationResult:
    __slots__ = ("is_allowed", "reason", "matched_category")

    def __init__(self, is_allowed: bool, reason: Optional[str] = None, matched_category: Optional[str] = None):
        self.is_allowed = is_allowed
        self.reason = reason
        self.matched_category = matched_category


_PHONE_RE = re.compile(
    r"(?:\+?\d{1,4}[\s\-]?)?"
    r"(?:\(?\d{2,4}\)?[\s\-]?)"
    r"\d{3,4}[\s\-]?\d{3,4}"
)

_EMAIL_RE = re.compile(
    r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"
)

_URL_RE = re.compile(
    r"(?:https?://|www\.|ftp://)"
    r"[^\s]+",
    re.IGNORECASE,
)

_SOCIAL_HANDLE_RE = re.compile(
    r"(?:^|[\s@])"
    r"(?:"
    r"@[a-zA-Z0-9_.]{3,}"
    r"|instagram\.com/[a-zA-Z0-9_.]+"
    r"|twitter\.com/[a-zA-Z0-9_]+"
    r"|x\.com/[a-zA-Z0-9_]+"
    r"|facebook\.com/[a-zA-Z0-9_.]+"
    r"|tiktok\.com/@[a-zA-Z0-9_.]+"
    r"|snapchat\.com/add/[a-zA-Z0-9_.]+"
    r"|linkedin\.com/in/[a-zA-Z0-9_\-]+"
    r"|youtube\.com/@[a-zA-Z0-9_\-]+"
    r"|wa\.me/\d+"
    r"|t\.me/[a-zA-Z0-9_]+"
    r")",
    re.IGNORECASE,
)

_QR_RE = re.compile(
    r"(?:qr[\s]?code|scan\s+(?:me|this|my))",
    re.IGNORECASE,
)

_BANK_RE = re.compile(
    r"(?:"
    r"\b\d{10,16}\b"
    r"|(?:acc(?:ount)?[\s:]?\s*\d{6,16})"
    r"|(?:acct[\s:]?\s*\d{6,16})"
    r"|(?:sort[\s]?code[\s:]?\s*\d{6,8})"
    r"|(?:routing[\s:]?\s*\d{9})"
    r"|(?:iban[\s:]?\s*[A-Z]{2}\d{2}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{0,4})"
    r"|(?:card[\s:]?\s*\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4})"
    r")",
    re.IGNORECASE,
)

_CONTACT_PHRASES = re.compile(
    r"(?:"
    r"call\s+me\s+(?:at|on)?\s*\d"
    r"|whatsapp\s*(?:number|me|us)?\s*:?\s*\d"
    r"|my\s+(?:number|phone|line)\s+(?:is|:)?\s*[\d\+]"
    r"|reach\s+me\s+(?:at|on)?\s*[\d\+]"
    r"|text\s+me\s+(?:at|on)?\s*[\d\+]"
    r"|contact\s+(?:me|us)\s+(?:at|on)?\s*[\d\+]"
    r"|my\s+email\s+(?:is|:)?\s*\S+@\S+"
    r"|email\s+(?:me|us)\s+(?:at|:)?\s*\S+@\S+"
    r"|send\s+(?:me|us)\s+(?:an?\s+)?(?:email|mail|message)\s+(?:at|on|to)?\s*\S+@\S+"
    r"|follow\s+(?:me|us)\s+(?:on|at)\s+\w+"
    r"|add\s+(?:me|us)\s+(?:on|at)\s+\w+"
    r")",
    re.IGNORECASE,
)


def moderate_content(content: str) -> ContentModerationResult:
    text = content.strip()

    if not text:
        return ContentModerationResult(is_allowed=True)

    if _URL_RE.search(text):
        return ContentModerationResult(
            is_allowed=False,
            reason="Links and URLs are not allowed in chat. Please keep all communication on the platform.",
            matched_category="url",
        )

    if _SOCIAL_HANDLE_RE.search(text):
        return ContentModerationResult(
            is_allowed=False,
            reason="Social media handles and external profiles are not allowed in chat.",
            matched_category="social_handle",
        )

    if _EMAIL_RE.search(text):
        return ContentModerationResult(
            is_allowed=False,
            reason="Email addresses are not allowed in chat. Please keep all communication on the platform.",
            matched_category="email",
        )

    if _QR_RE.search(text):
        return ContentModerationResult(
            is_allowed=False,
            reason="QR codes cannot be shared in chat.",
            matched_category="qr_code",
        )

    if _CONTACT_PHRASES.search(text):
        return ContentModerationResult(
            is_allowed=False,
            reason="Sharing contact information is not allowed. Keep conversations on-platform for your protection.",
            matched_category="contact_info",
        )

    if _PHONE_RE.search(text):
        clean = _EMAIL_RE.sub("", text)
        clean = _URL_RE.sub("", clean)
        if _PHONE_RE.search(clean):
            return ContentModerationResult(
                is_allowed=False,
                reason="Phone numbers are not allowed in chat. Please keep all communication on the platform.",
                matched_category="phone_number",
            )

    if _BANK_RE.search(text):
        return ContentModerationResult(
            is_allowed=False,
            reason="Payment and banking details are not allowed in chat. Use the platform's secure payment system.",
            matched_category="payment_info",
        )

    return ContentModerationResult(is_allowed=True)

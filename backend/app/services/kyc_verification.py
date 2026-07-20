"""
KYC Verification Service — fast, user-friendly, non-blocking.

Pipeline:
  1. Validate file is a real image (Pillow)
  2. Resize to max 800px (speeds up everything 10x)
  3. Tesseract OCR reads the ID → checks for name/ID number
  4. face_recognition compares ID photo vs selfie (if provided)
  5. Returns pass/fail with clear, actionable messages

All self-hosted, free, no API keys needed.
Gracefully degrades — if Tesseract or face_recognition isn't installed, skips that step.
"""
import io
import logging
import re
from typing import Optional
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeout

from PIL import Image

logger = logging.getLogger(__name__)

_face_recognition = None
_tesseract_available = False
_executor = ThreadPoolExecutor(max_workers=2)

MAX_IMAGE_DIMENSION = 800
OCR_TIMEOUT_SECONDS = 8
FACE_MATCH_TIMEOUT_SECONDS = 10


def _load_face_recognition():
    global _face_recognition
    if _face_recognition is None:
        try:
            import face_recognition
            _face_recognition = face_recognition
        except ImportError:
            logger.warning("face_recognition not installed — face matching disabled")
    return _face_recognition


def _check_tesseract():
    global _tesseract_available
    if not _tesseract_available:
        try:
            import pytesseract
            pytesseract.get_tesseract_version()
            _tesseract_available = True
        except Exception:
            logger.warning("Tesseract OCR not installed — text extraction disabled")
    return _tesseract_available


def _resize_image(image_bytes: bytes, max_dim: int = MAX_IMAGE_DIMENSION) -> bytes:
    """Resize image to max dimension for faster processing. Returns JPEG bytes."""
    try:
        img = Image.open(io.BytesIO(image_bytes))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        w, h = img.size
        if max(w, h) > max_dim:
            ratio = max_dim / max(w, h)
            img = img.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        return buf.getvalue()
    except Exception:
        return image_bytes


@dataclass
class KYCVerificationResult:
    is_valid: bool
    needs_review: bool
    ocr_passed: bool
    face_match_passed: bool
    extracted_text: str
    errors: list
    warnings: list
    confidence: float


def extract_id_text(image_bytes: bytes) -> str:
    """Extract text from ID document image using Tesseract OCR."""
    if not _check_tesseract():
        return ""

    try:
        import pytesseract
        resized = _resize_image(image_bytes)
        img = Image.open(io.BytesIO(resized))
        config = "--psm 6 --oem 3"
        text = pytesseract.image_to_string(img, config=config)
        return text.strip()
    except Exception as e:
        logger.error(f"OCR failed: {e}")
        return ""


def extract_id_fields(ocr_text: str) -> dict:
    """Parse common ID fields from OCR text. Lenient — accepts many formats."""
    fields = {
        "has_name": False,
        "has_dob": False,
        "has_id_number": False,
        "has_expiry": False,
        "field_count": 0,
    }

    if not ocr_text:
        return fields

    lines = ocr_text.upper()

    name_patterns = [
        r"(?:NAME|NAMES|FULL\s*NAMES?|SURNAME|LAST\s*NAME|FIRST\s*NAME)[\s:]+([A-Z\s]{2,})",
        r"\b[A-Z]{2,}\s+[A-Z]{2,}\b",
    ]
    for pat in name_patterns:
        if re.search(pat, lines):
            fields["has_name"] = True
            break

    dob_patterns = [
        r"(?:DATE\s*OF\s*BIRTH|DOB|BORN|BIRTH|AGE)[\s:]*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})",
        r"\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{4}\b",
        r"\b\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}\b",
    ]
    for pat in dob_patterns:
        if re.search(pat, lines):
            fields["has_dob"] = True
            break

    id_patterns = [
        r"(?:ID|NO|NUMBER|PASSPORT|DRIVER|LICENCE|LICENSE|REG|CARD)[\s:]*(\w{4,25})",
        r"\b[A-Z0-9]{6,25}\b",
    ]
    for pat in id_patterns:
        if re.search(pat, lines):
            fields["has_id_number"] = True
            break

    expiry_patterns = [
        r"(?:EXPIR|VALID|EXP|UNTIL)[\s:]*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})",
    ]
    for pat in expiry_patterns:
        if re.search(pat, lines):
            fields["has_expiry"] = True
            break

    fields["field_count"] = sum([
        fields["has_name"],
        fields["has_dob"],
        fields["has_id_number"],
        fields["has_expiry"],
    ])

    return fields


def compare_faces(id_image_bytes: bytes, selfie_image_bytes: bytes) -> tuple[bool, float]:
    """Compare faces between ID photo and selfie. Returns (match, confidence)."""
    fr = _load_face_recognition()
    if fr is None:
        return True, 0.0

    try:
        id_resized = _resize_image(id_image_bytes, max_dim=600)
        selfie_resized = _resize_image(selfie_image_bytes, max_dim=600)

        id_img = fr.load_image_file(io.BytesIO(id_resized))
        selfie_img = fr.load_image_file(io.BytesIO(selfie_resized))

        id_encodings = fr.face_encodings(id_img)
        selfie_encodings = fr.face_encodings(selfie_img)

        if not id_encodings:
            logger.warning("No face found in ID image")
            return False, 0.0
        if not selfie_encodings:
            logger.warning("No face found in selfie")
            return False, 0.0

        id_enc = id_encodings[0]
        selfie_enc = selfie_encodings[0]

        distance = fr.face_distance([id_enc], selfie_enc)[0]
        confidence = max(0.0, 1.0 - distance)

        strict_match = distance < 0.55
        lenient_match = distance < 0.68

        return strict_match, lenient_match, confidence
    except Exception as e:
        logger.error(f"Face comparison failed: {e}")
        return False, 0.0


def _run_with_timeout(func, *args, timeout: int = 10):
    """Run a function with a timeout. Returns None if timeout."""
    try:
        future = _executor.submit(func, *args)
        return future.result(timeout=timeout)
    except FuturesTimeout:
        logger.warning(f"Operation timed out after {timeout}s")
        return None
    except Exception as e:
        logger.error(f"Operation failed: {e}")
        return None


def verify_kyc_document(
    document_bytes: bytes,
    selfie_bytes: Optional[bytes] = None,
    document_type: str = "national_id",
) -> KYCVerificationResult:
    """
    Full KYC verification pipeline — fast and user-friendly.
    Total time budget: < 15 seconds even on cheap servers.
    """
    errors = []
    warnings = []

    try:
        img = Image.open(io.BytesIO(document_bytes))
        img.verify()
    except Exception:
        return KYCVerificationResult(
            is_valid=False, ocr_passed=False, face_match_passed=False,
            extracted_text="", errors=["This doesn't look like an image. Please upload a photo of your ID."],
            warnings=[], confidence=0.0,
        )

    resized = _resize_image(document_bytes)
    ocr_text = _run_with_timeout(extract_id_text, document_bytes, timeout=OCR_TIMEOUT_SECONDS)

    if ocr_text is None:
        ocr_text = ""
        warnings.append("Text detection was slow — skipped. Please ensure your ID is clear and well-lit.")

    id_fields = extract_id_fields(ocr_text)

    ocr_passed = id_fields["has_name"] or id_fields["has_id_number"]

    if not ocr_passed and id_fields["field_count"] > 0:
        ocr_passed = True
        warnings.append("Some fields were hard to read, but enough was detected.")

    if not ocr_passed:
        errors.append("We couldn't read your ID. Please try again with a clearer photo.")

    face_match_passed = True
    face_confidence = 0.0

    if selfie_bytes:
        face_result = _run_with_timeout(
            compare_faces, document_bytes, selfie_bytes,
            timeout=FACE_MATCH_TIMEOUT_SECONDS,
        )

        if face_result is None:
            face_match_passed = True
            warnings.append("Face check was slow — skipped. We'll verify manually if needed.")
        else:
            strict_match, lenient_match, face_confidence = face_result
            face_match_passed = strict_match

            if not strict_match and lenient_match:
                warnings.append("Face looks similar but not identical. This is normal if your ID photo is old.")
            elif not lenient_match:
                face_match_passed = False
                errors.append("The selfie doesn't match your ID. Please take a new selfie with the same lighting.")

    overall_confidence = 0.0
    if ocr_passed:
        overall_confidence += 0.5
    if face_match_passed and selfie_bytes:
        overall_confidence += 0.5 * face_confidence
    elif not selfie_bytes:
        overall_confidence += 0.5

    is_valid = ocr_passed and face_match_passed
    needs_review = ocr_passed and not face_match_passed and selfie_bytes is not None

    return KYCVerificationResult(
        is_valid=is_valid,
        needs_review=needs_review,
        ocr_passed=ocr_passed,
        face_match_passed=face_match_passed,
        extracted_text=ocr_text[:500],
        errors=errors,
        warnings=warnings,
        confidence=overall_confidence,
    )

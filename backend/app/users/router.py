from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID, uuid4
from pydantic import BaseModel
from typing import Optional

from app.database import get_db
from app.dependencies import get_current_user, get_current_user_id, get_verified_user
from app.users.models import User
from app.users.service import UserService
from app.users.schemas import ProfileUpdateRequest, VerificationDocumentUpload, UserListResponse, SignatureSaveRequest
from app.auth.schemas import ChangePasswordRequest
from app.auth.service import verify_password, hash_password
from app.common.enums import UserRole
from app.common.response import SuccessResponse
from app.services.storage import supabase_storage

router = APIRouter(prefix="/users", tags=["Users"])


class RoleSwitchRequest(BaseModel):
    role: UserRole


class KYCSubmitRequest(BaseModel):
    document_type: str
    document_url: str
    selfie_url: str = None


@router.get("/me", response_model=SuccessResponse)
async def get_my_profile(user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    profile = await service.get_user_profile(user.id)
    return SuccessResponse(data=profile)


@router.put("/me", response_model=SuccessResponse)
async def update_my_profile(body: ProfileUpdateRequest, user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    updated = await service.update_profile(user.id, body)
    return SuccessResponse(message="Profile updated", data=updated)


@router.post("/me/profile-picture", response_model=SuccessResponse)
async def upload_profile_picture(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Max 5MB.")

    result = await supabase_storage.upload_profile_picture(
        file_bytes=content,
        user_id=str(user.id),
        file_name=file.filename or "profile.jpg",
        content_type=file.content_type,
    )

    from sqlalchemy import select as sa_select
    from app.users.models import Profile
    profile_result = await db.execute(sa_select(Profile).where(Profile.user_id == user.id))
    profile = profile_result.scalar_one_or_none()
    if profile:
        profile.profile_picture = result["url"]
    else:
        profile = Profile(id=uuid4(), user_id=user.id, profile_picture=result["url"])
        db.add(profile)

    await db.commit()

    return SuccessResponse(message="Profile picture uploaded", data={
        "profile_picture": result["url"],
    })


@router.get("/{user_id}", response_model=SuccessResponse)
async def get_user_profile(user_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    profile = await service.get_user_profile(user_id)
    return SuccessResponse(data=profile)


@router.get("/{user_id}/public", response_model=SuccessResponse)
async def get_public_profile(user_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from sqlalchemy import select as sa_select
    from app.users.models import Profile, Landlord
    from sqlalchemy import func as sa_func

    target_result = await db.execute(sa_select(User).where(User.id == user_id))
    target = target_result.scalar_one_or_none()
    if not target:
        from app.common.exceptions import NotFound
        raise NotFound("User not found")

    viewer_result = await db.execute(sa_select(User).where(User.id == user.id))
    viewer = viewer_result.scalar_one_or_none()

    is_agent_viewing_agent = (
        viewer.role in (UserRole.LANDLORD.value, UserRole.LANDLORD) and
        target.role in (UserRole.LANDLORD.value, UserRole.LANDLORD) and
        str(user_id) != str(user.id)
    )

    profile_result = await db.execute(sa_select(Profile).where(Profile.user_id == user_id))
    profile = profile_result.scalar_one_or_none()

    name = ""
    profile_picture = None
    if profile:
        name = f"{profile.first_name} {profile.last_name}".strip()
        profile_picture = profile.profile_picture

    total_properties = 0
    total_earned = 0
    if target.role in (UserRole.LANDLORD.value, UserRole.LANDLORD):
        ll_result = await db.execute(sa_select(Landlord).where(Landlord.user_id == user_id))
        ll = ll_result.scalar_one_or_none()
        if ll:
            total_properties = ll.total_properties or 0
            total_earned = ll.total_earned or 0

    avg_rating = 0.0
    rating_count = 0
    try:
        from app.reviews.models import Review
        from app.common.enums import ReviewTargetType
        rating_result = await db.execute(
            select(
                sa_func.avg(Review.rating).label("avg"),
                sa_func.count(Review.id).label("cnt"),
            ).where(
                Review.target_id == user_id,
                Review.target_type == ReviewTargetType.LANDLORD.value,
            )
        )
        row = rating_result.one_or_none()
        if row:
            avg_rating = float(row.avg) if row.avg else 0.0
            rating_count = row.cnt
    except Exception:
        pass

    if is_agent_viewing_agent:
        return SuccessResponse(data={
            "id": str(target.id),
            "name": name or target.email.split("@")[0],
            "role": target.role,
            "profile_picture": profile_picture,
            "is_verified": target.is_verified,
            "total_properties": total_properties,
            "avg_rating": round(avg_rating, 1),
            "rating_count": rating_count,
            "created_at": target.created_at.isoformat() if target.created_at else None,
        })

    return SuccessResponse(data={
        "id": str(target.id),
        "name": name or target.email.split("@")[0],
        "role": target.role,
        "profile_picture": profile_picture,
        "is_verified": target.is_verified,
        "total_properties": total_properties,
        "total_earned": total_earned,
        "avg_rating": round(avg_rating, 1),
        "rating_count": rating_count,
        "created_at": target.created_at.isoformat() if target.created_at else None,
    })


@router.get("/", response_model=SuccessResponse)
async def list_users(page: int = 1, page_size: int = 20, role: str = None, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    users = await service.list_users(page=page, page_size=page_size, role=role)
    return SuccessResponse(data=users)


ALLOWED_DOC_TYPES = {"national_id", "passport", "drivers_license", "voters_card", "nin", "permanent_resident_card"}
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "application/pdf"}
MIN_FILE_SIZE = 50 * 1024       # 50KB — real ID scans are never smaller
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
MIN_IMAGE_DIMENSION = 400        # at least 400px on shortest side


def validate_kyc_file(content: bytes, content_type: str, filename: str, document_type: str) -> list[str]:
    errors = []

    if document_type not in ALLOWED_DOC_TYPES:
        errors.append(f"Invalid document type '{document_type}'. Allowed: {', '.join(sorted(ALLOWED_DOC_TYPES))}")

    if len(content) < MIN_FILE_SIZE:
        errors.append(f"File too small ({len(content)} bytes). Minimum is 50KB — real ID scans are never smaller.")

    if len(content) > MAX_FILE_SIZE:
        errors.append(f"File too large. Maximum is 10MB.")

    if content_type and content_type not in ALLOWED_MIME_TYPES:
        errors.append(f"Invalid file type '{content_type}'. Allowed: JPEG, PNG, WebP, HEIC, PDF.")

    if content_type and content_type.startswith("image/"):
        try:
            from PIL import Image
            import io
            img = Image.open(io.BytesIO(content))
            img.verify()
            w, h = img.size
            if w < MIN_IMAGE_DIMENSION or h < MIN_IMAGE_DIMENSION:
                errors.append(f"Image too small ({w}x{h}). Minimum {MIN_IMAGE_DIMENSION}px on each side.")
        except ImportError:
            pass
        except Exception:
            errors.append("File is not a valid image.")

    return errors


@router.post("/kyc", response_model=SuccessResponse)
async def submit_kyc(
    file: UploadFile = File(...),
    selfie: UploadFile = File(None),
    document_type: str = "national_id",
    manual_review: bool = False,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not user.is_verified:
        raise HTTPException(status_code=400, detail="Please verify your email first")

    content = await file.read()
    content_type = file.content_type or ""

    errors = validate_kyc_file(content, content_type, file.filename or "", document_type)
    if errors:
        raise HTTPException(status_code=400, detail={"errors": errors})

    selfie_content = None
    if selfie:
        selfie_content = await selfie.read()
        selfie_type = selfie.content_type or "image/jpeg"
        if selfie_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(status_code=400, detail=f"Invalid selfie type '{selfie_type}'. Must be an image.")

    needs_review = manual_review
    verification = None

    if not manual_review:
        from app.services.kyc_verification import verify_kyc_document
        verification = verify_kyc_document(
            document_bytes=content,
            selfie_bytes=selfie_content,
            document_type=document_type,
        )

        if verification.errors and verification.needs_review:
            needs_review = True
        elif verification.errors and not verification.needs_review:
            needs_review = True
        elif not verification.errors and verification.confidence >= 0.5:
            needs_review = False
        else:
            needs_review = True

    try:
        id_result = await supabase_storage.upload_file(
            file_bytes=content,
            file_name=file.filename or "id_document",
            content_type=content_type,
            folder=f"users/{user.id}/kyc",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

    selfie_url = None
    if selfie_content:
        try:
            selfie_result = await supabase_storage.upload_file(
                file_bytes=selfie_content,
                file_name=selfie.filename or "selfie",
                content_type=selfie.content_type or "image/jpeg",
                folder=f"users/{user.id}/kyc",
            )
            selfie_url = selfie_result["url"]
        except Exception:
            pass

    service = UserService(db)
    result = await service.submit_kyc(
        user_id=user.id,
        document_type=document_type,
        document_url=id_result["url"],
        selfie_url=selfie_url,
        needs_review=needs_review,
    )

    message = result["message"]
    if needs_review:
        message = "Document submitted for manual review. This usually takes 24-48 hours. You'll be notified once reviewed."

    response_data = {
        "status": result["status"],
        "document_id": result.get("document_id"),
    }

    if verification:
        response_data["verification"] = {
            "ocr_passed": verification.ocr_passed,
            "face_match_passed": verification.face_match_passed,
            "confidence": round(verification.confidence, 2),
        }

    if needs_review:
        response_data["estimated_review_time"] = "24-48 hours"
        response_data["note"] = "You can continue browsing properties while your ID is being reviewed."

    return SuccessResponse(message=message, data=response_data)


@router.get("/kyc/status", response_model=SuccessResponse)
async def kyc_status(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from sqlalchemy import select as sa_select
    from app.users.models import VerificationDocument

    doc_result = await db.execute(
        sa_select(VerificationDocument).where(VerificationDocument.user_id == user.id).order_by(VerificationDocument.created_at.desc())
    )
    doc = doc_result.scalars().first()
    return SuccessResponse(data={
        "is_verified": user.is_verified,
        "status": doc.status if doc else "not_started",
        "document_type": doc.document_type if doc else None,
        "document_url": doc.document_url if doc else None,
        "rejection_reason": doc.rejection_reason if doc else None,
    })


@router.get("/me/verification-status", response_model=SuccessResponse)
async def get_verification_status(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from sqlalchemy import select as sa_select
    from app.users.models import VerificationDocument
    from app.payments.models import BankAccount
    from datetime import datetime

    kyc_verified = user.is_verified
    kyc_status = "approved" if kyc_verified else "not_started"
    kyc_rejection_reason = None

    if not kyc_verified:
        doc_result = await db.execute(
            sa_select(VerificationDocument).where(VerificationDocument.user_id == user.id).order_by(VerificationDocument.created_at.desc())
        )
        doc = doc_result.scalars().first()
        if doc:
            kyc_status = doc.status
            kyc_rejection_reason = doc.rejection_reason

    has_signature = bool(user.signature_data)

    bank_result = await db.execute(
        sa_select(BankAccount).where(BankAccount.user_id == user.id)
    )
    bank_accounts = bank_result.scalars().all()
    has_bank_account = len(bank_accounts) > 0

    all_complete = kyc_verified and has_signature and has_bank_account

    next_step = None
    if not kyc_verified:
        next_step = "kyc"
    elif not has_signature:
        next_step = "signature"
    elif not has_bank_account:
        next_step = "bank_account"

    steps_completed = sum([kyc_verified, has_signature, has_bank_account])

    return SuccessResponse(data={
        "is_fully_activated": all_complete,
        "kyc_verified": kyc_verified,
        "kyc_status": kyc_status,
        "kyc_rejection_reason": kyc_rejection_reason,
        "has_signature": has_signature,
        "has_bank_account": has_bank_account,
        "next_step": next_step,
        "steps_completed": steps_completed,
        "total_steps": 3,
        "progress_percentage": int((steps_completed / 3) * 100),
    })


@router.post("/switch-role", response_model=SuccessResponse)
async def switch_role(body: RoleSwitchRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    result = await service.switch_role(user.id, body.role)
    return SuccessResponse(message=result["message"], data={"role": result["role"]})


@router.post("/verification", response_model=SuccessResponse)
async def upload_verification(body: VerificationDocumentUpload, user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    doc = await service.upload_verification_document(user.id, body)
    return SuccessResponse(message="Document uploaded for review", data={"id": str(doc.id), "status": doc.status})

@router.get("/me/sessions", response_model=SuccessResponse)
async def list_my_sessions(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.auth.models import UserSession
    from sqlalchemy import select

    result = await db.execute(
        select(UserSession).where(
            UserSession.user_id == user.id,
            UserSession.is_active == True,
        ).order_by(UserSession.created_at.desc())
    )
    sessions = result.scalars().all()
    return SuccessResponse(data={
        "total": len(sessions),
        "sessions": [
            {
                "id": str(s.id),
                "user_agent": s.user_agent,
                "ip_address": s.ip_address,
                "created_at": s.created_at.isoformat() if s.created_at else None,
                "expires_at": s.expires_at.isoformat() if s.expires_at else None,
            }
            for s in sessions
        ],
    })

@router.delete("/me/sessions/{session_id}", response_model=SuccessResponse)
async def revoke_session(session_id: UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.auth.models import UserSession
    from sqlalchemy import select

    result = await db.execute(
        select(UserSession).where(
            UserSession.id == session_id,
            UserSession.user_id == user.id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    session.is_active = False
    await db.commit()
    return SuccessResponse(message="Session revoked")

@router.delete("/me", response_model=SuccessResponse)
async def delete_my_account(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.bookings.models import Booking
    from app.common.enums import BookingStatus
    from sqlalchemy import select

    active_booking = await db.execute(
        select(Booking).where(
            Booking.tenant_id == user.id,
            Booking.status.in_([BookingStatus.PENDING, BookingStatus.CONFIRMED, BookingStatus.ACTIVE]),
        )
    )
    if active_booking.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Cannot delete account with active bookings. Cancel or complete them first.")

    if user.role.value == "LANDLORD":
        from sqlalchemy import func as sql_func
        from app.properties.models import Property
        property_count = await db.execute(
            select(sql_func.count()).select_from(Property).where(Property.landlord_id == user.id)
        )
        if property_count.scalar() > 0:
            raise HTTPException(status_code=400, detail="Cannot delete account with properties. Delete your properties first.")

    user.is_active = False
    user.email = f"deleted_{user.id}@apex-housing.deleted"
    await db.commit()

    return SuccessResponse(message="Account deleted successfully")


@router.post("/me/change-password", response_model=SuccessResponse)
async def change_password(body: ChangePasswordRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    user.password_hash = hash_password(body.new_password)
    await db.commit()
    return SuccessResponse(message="Password changed successfully")


@router.get("/me/signature", response_model=SuccessResponse)
async def get_my_signature(user: User = Depends(get_current_user)):
    return SuccessResponse(data={
        "has_signature": user.signature_data is not None,
        "signature_data": user.signature_data,
        "signature_created_at": user.signature_created_at,
    })


@router.post("/me/signature", response_model=SuccessResponse)
async def save_my_signature(
    body: SignatureSaveRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.users.models import UserSignature
    from datetime import datetime
    import uuid as _uuid
    import base64 as _base64

    raw = body.signature_data
    if not raw:
        raise HTTPException(status_code=400, detail="Signature data is required.")

    if raw.startswith("data:"):
        parts = raw.split(",", 1)
        raw = parts[1] if len(parts) > 1 else raw

    if len(raw) < 50:
        raise HTTPException(status_code=400, detail="Invalid signature. Must be a valid base64 image (min 50 chars).")

    try:
        decoded = _base64.b64decode(raw)
        if len(decoded) < 200:
            raise HTTPException(status_code=400, detail="Signature image too small. Please draw a clearer signature.")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 signature data.")

    now = datetime.utcnow()

    old_active = await db.execute(
        select(UserSignature).where(
            UserSignature.user_id == user.id,
            UserSignature.is_active == True,
        )
    )
    for old in old_active.scalars().all():
        old.is_active = False

    sig = UserSignature(
        id=_uuid.uuid4(),
        user_id=user.id,
        signature_data=raw,
        is_active=True,
        label=body.label,
    )
    db.add(sig)

    had_signature = user.signature_data is not None
    user.signature_data = raw
    user.signature_created_at = now
    await db.commit()

    return SuccessResponse(
        message="Signature updated successfully" if had_signature else "Signature saved successfully",
        data={"id": str(sig.id), "created_at": now.isoformat()},
    )


@router.get("/me/signature/check", response_model=SuccessResponse)
async def check_signature_required(
    for_action: str = "booking",
    user: User = Depends(get_current_user),
):
    has_signature = user.signature_data is not None
    return SuccessResponse(data={
        "has_signature": has_signature,
        "requires_signature": not has_signature,
        "for_action": for_action,
        "signature_data": user.signature_data if has_signature else None,
        "signature_created_at": user.signature_created_at,
    })


@router.get("/me/signature/image", response_class=None)
async def get_my_signature_image(
    user: User = Depends(get_current_user),
):
    if not user.signature_data:
        raise HTTPException(status_code=404, detail="No signature found")

    import base64 as _base64
    from fastapi.responses import Response

    raw = user.signature_data
    if raw.startswith("data:"):
        parts = raw.split(",", 1)
        header = parts[0]
        raw = parts[1] if len(parts) > 1 else raw
        if "png" in header:
            content_type = "image/png"
        elif "jpeg" in header or "jpg" in header:
            content_type = "image/jpeg"
        elif "svg" in header:
            content_type = "image/svg+xml"
        else:
            content_type = "image/png"
    else:
        content_type = "image/png"

    image_bytes = _base64.b64decode(raw)
    return Response(content=image_bytes, media_type=content_type)


@router.post("/me/signature/upload", response_model=SuccessResponse)
async def upload_my_signature(
    file: UploadFile = File(...),
    label: str = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.users.models import UserSignature
    from datetime import datetime
    import uuid as _uuid
    import base64 as _base64

    ALLOWED_TYPES = {"image/png", "image/jpeg", "image/jpg", "image/svg+xml"}
    MAX_SIZE = 5 * 1024 * 1024

    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type '{file.content_type}'. Allowed: PNG, JPEG, SVG.",
        )

    content = await file.read()
    if len(content) < 200:
        raise HTTPException(status_code=400, detail="Signature image too small. Please draw a clearer signature.")
    if len(content) > MAX_SIZE:
        raise HTTPException(status_code=400, detail="Signature image too large. Maximum size is 5MB.")

    if file.content_type in ("image/png", "image/jpeg", "image/jpg"):
        try:
            from PIL import Image
            import io
            img = Image.open(io.BytesIO(content))
            w, h = img.size
            if w < 50 or h < 30:
                raise HTTPException(
                    status_code=400,
                    detail=f"Signature image too small ({w}x{h}px). Minimum is 50x30 pixels.",
                )
            if w > 4000 or h > 4000:
                raise HTTPException(
                    status_code=400,
                    detail=f"Signature image too large ({w}x{h}px). Maximum is 4000x4000 pixels.",
                )
        except HTTPException:
            raise
        except ImportError:
            pass
        except Exception:
            raise HTTPException(status_code=400, detail="Cannot read signature image. Please try again.")

    b64_data = _base64.b64encode(content).decode("utf-8")
    if len(b64_data) < 50:
        raise HTTPException(status_code=400, detail="Invalid signature data.")

    now = datetime.utcnow()

    old_active = await db.execute(
        select(UserSignature).where(
            UserSignature.user_id == user.id,
            UserSignature.is_active == True,
        )
    )
    for old in old_active.scalars().all():
        old.is_active = False

    sig = UserSignature(
        id=_uuid.uuid4(),
        user_id=user.id,
        signature_data=b64_data,
        is_active=True,
        label=label or file.filename,
    )
    db.add(sig)

    had_signature = user.signature_data is not None
    user.signature_data = b64_data
    user.signature_created_at = now
    await db.commit()

    return SuccessResponse(
        message="Signature updated successfully" if had_signature else "Signature saved successfully",
        data={"id": str(sig.id), "created_at": now.isoformat()},
    )


@router.delete("/me/signature", response_model=SuccessResponse)
async def delete_my_signature(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not user.signature_data:
        raise HTTPException(status_code=404, detail="No signature found")

    from app.users.models import UserSignature

    active = await db.execute(
        select(UserSignature).where(
            UserSignature.user_id == user.id,
            UserSignature.is_active == True,
        )
    )
    for sig in active.scalars().all():
        sig.is_active = False

    user.signature_data = None
    user.signature_created_at = None
    await db.commit()

    return SuccessResponse(message="Signature deleted")


@router.get("/me/signatures", response_model=SuccessResponse)
async def list_my_signatures(
    page: int = 1,
    page_size: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.users.models import UserSignature
    from sqlalchemy import func as sql_func

    count_result = await db.execute(
        select(sql_func.count()).select_from(UserSignature).where(UserSignature.user_id == user.id)
    )
    total = count_result.scalar()

    result = await db.execute(
        select(UserSignature)
        .where(UserSignature.user_id == user.id)
        .order_by(UserSignature.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    signatures = result.scalars().all()

    return SuccessResponse(data={
        "total": total,
        "signatures": signatures,
    })


# ──────────────────────────────────────────────
# User Preferences (language, theme, etc.)
# ──────────────────────────────────────────────

class UserPreferenceUpdate(BaseModel):
    language: Optional[str] = None
    theme: Optional[str] = None
    text_scale: Optional[float] = None
    currency: Optional[str] = None
    notifications_enabled: Optional[bool] = None
    biometric_enabled: Optional[bool] = None
    push_enabled: Optional[bool] = None
    email_notifications: Optional[bool] = None
    quiet_hours_start: Optional[str] = None
    quiet_hours_end: Optional[str] = None
    last_screen: Optional[str] = None
    last_scroll_position: Optional[int] = None
    draft_data: Optional[dict] = None


@router.get("/me/preferences", response_model=SuccessResponse)
async def get_my_preferences(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.users.models import UserPreference
    from sqlalchemy import select

    result = await db.execute(select(UserPreference).where(UserPreference.user_id == user.id))
    pref = result.scalar_one_or_none()

    if not pref:
        pref = UserPreference(id=uuid4(), user_id=user.id)
        db.add(pref)
        await db.commit()
        await db.refresh(pref)

    return SuccessResponse(data={
        "language": pref.language,
        "theme": pref.theme,
        "text_scale": pref.text_scale,
        "currency": pref.currency,
        "notifications_enabled": pref.notifications_enabled,
        "biometric_enabled": pref.biometric_enabled,
        "push_enabled": pref.push_enabled,
        "email_notifications": pref.email_notifications,
        "quiet_hours_start": pref.quiet_hours_start,
        "quiet_hours_end": pref.quiet_hours_end,
        "last_screen": pref.last_screen,
        "last_scroll_position": pref.last_scroll_position,
        "draft_data": pref.draft_data,
    })


@router.put("/me/preferences", response_model=SuccessResponse)
async def update_my_preferences(
    body: UserPreferenceUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.users.models import UserPreference
    from sqlalchemy import select

    result = await db.execute(select(UserPreference).where(UserPreference.user_id == user.id))
    pref = result.scalar_one_or_none()

    if not pref:
        pref = UserPreference(id=uuid4(), user_id=user.id)
        db.add(pref)

    updates = body.model_dump(exclude_none=True)
    for key, value in updates.items():
        setattr(pref, key, value)

    await db.commit()
    await db.refresh(pref)

    return SuccessResponse(message="Preferences updated", data={
        "language": pref.language,
        "theme": pref.theme,
        "text_scale": pref.text_scale,
        "currency": pref.currency,
        "notifications_enabled": pref.notifications_enabled,
        "biometric_enabled": pref.biometric_enabled,
        "push_enabled": pref.push_enabled,
        "email_notifications": pref.email_notifications,
        "quiet_hours_start": pref.quiet_hours_start,
        "quiet_hours_end": pref.quiet_hours_end,
        "last_screen": pref.last_screen,
        "last_scroll_position": pref.last_scroll_position,
        "draft_data": pref.draft_data,
    })

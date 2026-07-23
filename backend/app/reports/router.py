from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user
from app.reports.service import BookingReportService
from app.reports.schemas import BookingReportResponse, BookingReportListResponse, ReportSignRequest, DisputeCreateRequest
from app.reports.models import DisputeReport
from app.bookings.models import Booking
from app.properties.models import Property
from app.users.models import User
from app.common.response import SuccessResponse

router = APIRouter(prefix="/reports", tags=["Booking Reports"])


@router.post("/generate/{booking_id}", response_model=SuccessResponse)
async def generate_report(
    booking_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = BookingReportService(db)
    report = await service.generate_report(booking_id)
    return SuccessResponse(
        message="Booking report generated successfully. You can now download and print it.",
        data=report,
    )


@router.get("/", response_model=SuccessResponse)
async def list_reports(
    page: int = 1,
    page_size: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = BookingReportService(db)
    result = await service.list_reports(user.id, page=page, page_size=page_size)
    return SuccessResponse(data=result)


@router.post("/dispute", response_model=SuccessResponse)
async def raise_dispute(
    body: DisputeCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    valid_types = ['harassment', 'noise', 'property_damage', 'safety', 'discrimination', 'other']
    if body.dispute_type not in valid_types:
        return JSONResponse(status_code=400, content={"detail": f"Invalid dispute type. Must be one of: {', '.join(valid_types)}"})

    valid_severities = ['low', 'medium', 'high']
    if body.severity not in valid_severities:
        return JSONResponse(status_code=400, content={"detail": f"Invalid severity. Must be one of: {', '.join(valid_severities)}"})

    booking_result = await db.execute(select(Booking).where(Booking.id == body.booking_id))
    booking = booking_result.scalar_one_or_none()
    if not booking:
        return JSONResponse(status_code=404, content={"detail": "Booking not found"})

    if str(booking.tenant_id) != str(user.id):
        return JSONResponse(status_code=403, content={"detail": "You can only raise disputes for your own bookings"})

    property_title = None
    if booking.property_id:
        prop_result = await db.execute(select(Property).where(Property.id == booking.property_id))
        prop = prop_result.scalar_one_or_none()
        if prop:
            property_title = prop.title

    reported_against_name = None
    if body.reported_against_id:
        against_result = await db.execute(select(User).where(User.id == body.reported_against_id))
        against_user = against_result.scalar_one_or_none()
        if against_user:
            from app.users.models import Profile
            against_profile_result = await db.execute(select(Profile).where(Profile.user_id == against_user.id))
            against_profile = against_profile_result.scalar_one_or_none()
            if against_profile and against_profile.first_name:
                reported_against_name = f"{against_profile.first_name} {against_profile.last_name or ''}".strip()
            else:
                reported_against_name = against_user.email

    user_result = await db.execute(select(User).where(User.id == user.id))
    current_user = user_result.scalar_one_or_none()
    if current_user:
        from app.users.models import Profile
        my_profile_result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
        my_profile = my_profile_result.scalar_one_or_none()
        if my_profile and my_profile.first_name:
            reported_by_name = f"{my_profile.first_name} {my_profile.last_name or ''}".strip()
        else:
            reported_by_name = current_user.email
    else:
        reported_by_name = "Unknown"

    dispute = DisputeReport(
        booking_id=body.booking_id,
        property_id=booking.property_id,
        reported_by_id=user.id,
        reported_against_id=body.reported_against_id,
        dispute_type=body.dispute_type,
        severity=body.severity,
        status="open",
        title=body.title,
        description=body.description,
        reported_by_name=reported_by_name,
        reported_against_name=reported_against_name,
        property_title=property_title,
        booking_reference=booking.booking_reference,
    )
    db.add(dispute)

    # Mark booking as disputed
    booking.status = "disputed"
    await db.commit()
    await db.refresh(dispute)

    return JSONResponse(status_code=200, content={
        "message": "Dispute raised successfully. Our team will review it shortly.",
        "data": {
            "id": str(dispute.id),
            "status": dispute.status,
            "dispute_type": dispute.dispute_type,
            "severity": dispute.severity,
            "created_at": dispute.created_at.isoformat() if dispute.created_at else None,
        },
    })


@router.get("/{report_id}", response_model=SuccessResponse)
async def get_report(
    report_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = BookingReportService(db)
    report = await service.get_report(report_id)
    return SuccessResponse(data=report)


@router.get("/booking/{booking_id}", response_model=SuccessResponse)
async def get_report_by_booking(
    booking_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = BookingReportService(db)
    report = await service.get_report_by_booking(booking_id)
    return SuccessResponse(data=report)


@router.post("/{report_id}/sign", response_model=SuccessResponse)
async def sign_report(
    report_id: UUID,
    user: User = Depends(get_current_user),
    body: ReportSignRequest = None,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
):
    service = BookingReportService(db)
    ip = request.client.host if request and request.client else None
    sig = body.signature_data if body else None
    report = await service.sign_report(report_id, user.id, user.role, ip_address=ip, signature_data=sig)

    msg = "Report signed successfully."
    if report.is_finalized:
        msg += " All required parties have signed. Report is now FINALIZED and serves as official evidence of transaction."

    return SuccessResponse(message=msg, data=report)


@router.get("/{report_id}/download", response_model=SuccessResponse)
async def download_report(
    report_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = BookingReportService(db)
    result = await service.download_report(report_id, user.id)
    report = result["report"]
    html = result["html"]

    return SuccessResponse(
        message="Report downloaded. You can print this page or save as PDF using your browser's Print function (Ctrl+P / Cmd+P).",
        data={
            "report_number": report.report_number,
            "is_finalized": report.is_finalized,
            "download_count": report.download_count,
            "html_content": html,
        },
    )

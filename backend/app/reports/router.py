from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user
from app.reports.service import BookingReportService
from app.reports.schemas import BookingReportResponse, BookingReportListResponse, ReportSignRequest
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

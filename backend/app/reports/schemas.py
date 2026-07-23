from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class BookingReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    report_number: str
    property_title: Optional[str] = None
    property_address: Optional[str] = None
    property_photos: Optional[dict] = None
    booking_reference: str
    booking_status: str
    total_amount: str
    security_deposit: str
    service_fee: str
    currency: str
    payment_reference: Optional[str] = None
    payment_date: Optional[datetime] = None
    tenant_terms_agreed: bool
    tenant_signed_at: Optional[datetime] = None
    landlord_signed: bool
    landlord_signed_at: Optional[datetime] = None
    is_finalized: bool
    is_downloaded: bool
    download_count: int
    created_at: datetime


class BookingReportListResponse(BaseModel):
    total: int
    reports: List[BookingReportResponse]


class ReportSignRequest(BaseModel):
    signature_data: Optional[str] = None


class ReportDownloadResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    report_number: str
    html_content: str
    is_finalized: bool
    download_count: int


class DisputeCreateRequest(BaseModel):
    booking_id: UUID
    dispute_type: str
    severity: str = "medium"
    title: Optional[str] = None
    description: str
    reported_against_id: Optional[UUID] = None

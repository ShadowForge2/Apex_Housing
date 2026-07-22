from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
import secrets
import logging

from app.reports.models import BookingReport
from app.reports.schemas import BookingReportResponse
from app.common.exceptions import NotFound, BadRequest

logger = logging.getLogger(__name__)


PLATFORM_TERMS = """PLATFORM TERMS AND CONDITIONS (APEX Housing)
1. APEX Housing acts as an escrow-protected marketplace connecting tenants with property agents/landlords.
2. All payments are processed through APEX Housing's secure escrow system.
3. A 10% platform fee applies (5% tenant markup + 5% agent markdown).
4. Tenants have a 30-hour inspection window after move-in confirmation.
5. Funds are released to the agent after the inspection timer expires or tenant confirms satisfaction.
6. Disputes must be raised within the inspection window. Late disputes may not be eligible for refund.
7. APEX Housing is not a party to the tenancy agreement between tenant and agent/landlord.
8. This transaction report serves as official proof of payment and booking terms.
9. Both parties agree to APEX Housing's dispute resolution process as binding.
10. Personal data is collected for transaction verification and dispute resolution purposes only."""


def generate_report_number() -> str:
    return f"RPT-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{secrets.token_hex(4).upper()}"


def _render_signature_block(name: str, signed: bool, signed_at, signature_data: str = None) -> str:
    sig_img = ""
    if signature_data:
        sig_img = f'<img src="{signature_data}" style="max-height:60px;border:1px solid #eee;border-radius:4px;margin-top:8px;" />'
    if signed:
        ts = signed_at.strftime("%B %d, %Y at %I:%M %p") if signed_at else "N/A"
        return f'<div style="border:1px solid #ccc;padding:12px;border-radius:6px;background:#f9fff9;">{sig_img}<p style="color:#27ae60;font-weight:bold;margin:8px 0 0;">SIGNED</p><p style="font-size:11px;color:#666;">{ts}</p></div>'
    return '<div style="border:1px dashed #ccc;padding:12px;border-radius:6px;background:#fff9f9;color:#999;text-align:center;">Awaiting signature</div>'


def _build_report_html(report: BookingReport) -> str:
    photos_html = ""
    if report.property_photos and isinstance(report.property_photos, dict):
        urls = report.property_photos.get("urls", [])
        for url in urls[:6]:
            photos_html += f'<img src="{url}" style="width:30%;margin:1%;border-radius:4px;border:1px solid #ddd;" />'
    if not photos_html:
        photos_html = '<p style="color:#999;">No property photos captured</p>'

    finalized_html = '<div style="background:#27ae60;color:white;padding:10px 20px;border-radius:6px;display:inline-block;font-weight:bold;">FINALIZED - Report is now official evidence</div>' if report.is_finalized else '<div style="background:#f39c12;color:white;padding:10px 20px;border-radius:6px;display:inline-block;">PENDING - Awaiting additional signatures</div>'

    agent_sig = _render_signature_block(
        report.agent_full_name or "Agent", True,
        report.agent_signed_at, report.agent_signature_data
    )
    tenant_sig = _render_signature_block(
        report.tenant_full_name or "Tenant", True,
        report.tenant_signed_at, report.tenant_signature_data
    )
    landlord_sig = _render_signature_block(
        report.landlord_full_name or "Landlord", report.landlord_signed,
        report.landlord_signed_at, report.landlord_signature_data
    )

    terms_text = report.agent_terms_snapshot or "No terms provided"
    platform_terms_text = PLATFORM_TERMS

    ts = report.created_at.strftime("%B %d, %Y at %I:%M %p") if report.created_at else "N/A"
    html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>APEX Housing - Booking Transaction Report {report.report_number}</title>
<style>
    @media print {{
        body {{ font-size: 11pt; padding: 10px; }}
        .no-print {{ display: none; }}
        .page-break {{ page-break-before: always; }}
    }}
    body {{ font-family: 'Segoe UI', Arial, sans-serif; max-width: 850px; margin: 0 auto; padding: 30px; color: #222; line-height: 1.5; }}
    .header {{ text-align: center; border-bottom: 3px double #1a1a2e; padding-bottom: 20px; margin-bottom: 30px; }}
    .logo {{ font-size: 32px; font-weight: bold; color: #1a1a2e; letter-spacing: 2px; }}
    .subtitle {{ color: #666; margin-top: 5px; font-size: 14px; }}
    .section {{ margin-bottom: 25px; padding: 18px; border: 1px solid #ddd; border-radius: 6px; background: #fafafa; }}
    .section h3 {{ margin-top: 0; color: #1a1a2e; border-bottom: 2px solid #1a1a2e; padding-bottom: 8px; font-size: 15px; }}
    .row {{ display: flex; justify-content: space-between; margin: 6px 0; padding: 4px 0; }}
    .label {{ font-weight: bold; color: #444; min-width: 180px; }}
    .value {{ color: #222; }}
    .amount {{ font-size: 20px; font-weight: bold; color: #1a1a2e; }}
    .sig-grid {{ display: flex; gap: 15px; }}
    .sig-grid > div {{ flex: 1; }}
    .sig-grid .sig-name {{ font-weight: bold; margin-bottom: 6px; color: #1a1a2e; border-bottom: 1px solid #eee; padding-bottom: 4px; }}
    .footer {{ text-align: center; margin-top: 40px; padding-top: 20px; border-top: 3px double #1a1a2e; color: #999; font-size: 10px; }}
    .warning {{ background: #fff3cd; border: 1px solid #ffc107; padding: 14px; border-radius: 6px; margin: 20px 0; }}
    .legal {{ background: #f0f4ff; border: 1px solid #b0c4de; padding: 14px; border-radius: 6px; margin: 15px 0; font-size: 12px; }}
    .terms-box {{ background: white; border: 1px solid #ccc; padding: 14px; border-radius: 4px; max-height: 300px; overflow-y: auto; font-size: 12px; white-space: pre-wrap; line-height: 1.6; }}
    .stamp {{ border: 3px double #1a1a2e; padding: 8px 16px; display: inline-block; margin: 15px 0; font-weight: bold; color: #1a1a2e; }}
</style>
</head>
<body>

<div class="header">
    <div class="logo">APEX HOUSING</div>
    <div class="subtitle">OFFICIAL BOOKING TRANSACTION REPORT</div>
    <div style="margin-top:15px;"><span class="stamp">Report #{report.report_number}</span></div>
    <div style="color:#666;font-size:12px;margin-top:8px;">Generated: {ts} UTC</div>
    {finalized_html}
</div>

<div class="warning">
    <strong>OFFICIAL NOTICE:</strong> This document is an official transaction report generated by APEX Housing Platform.
    It contains verified data captured at the time of the booking transaction. This report serves as
    <strong>admissible evidence</strong> in courts of law, police stations, and regulatory bodies.
    Print and retain this document in a safe place.
</div>

<!-- ===== PARTIES ===== -->
<div class="section">
    <h3>PARTIES TO THIS TRANSACTION</h3>

    <div style="display:flex;gap:15px;flex-wrap:wrap;">
        <div style="flex:1;min-width:250px;border:1px solid #ddd;padding:14px;border-radius:6px;background:white;">
            <strong style="color:#1a1a2e;font-size:13px;">PARTY A - AGENT (Property Provider)</strong>
            <div class="row"><span class="label">Full Name:</span><span class="value">{report.agent_full_name or "N/A"}</span></div>
            <div class="row"><span class="label">Email:</span><span class="value">{report.agent_email or "N/A"}</span></div>
            <div class="row"><span class="label">Phone:</span><span class="value">{report.agent_phone or "N/A"}</span></div>
            <div class="row"><span class="label">Agency:</span><span class="value">{report.agent_agency_name or "N/A"}</span></div>
            <div class="row"><span class="label">License No.:</span><span class="value">{report.agent_license_number or "N/A"}</span></div>
        </div>
        <div style="flex:1;min-width:250px;border:1px solid #ddd;padding:14px;border-radius:6px;background:white;">
            <strong style="color:#1a1a2e;font-size:13px;">PARTY B - TENANT (Property Seeker)</strong>
            <div class="row"><span class="label">Full Name:</span><span class="value">{report.tenant_full_name or "N/A"}</span></div>
            <div class="row"><span class="label">Email:</span><span class="value">{report.tenant_email or "N/A"}</span></div>
            <div class="row"><span class="label">Phone:</span><span class="value">{report.tenant_phone or "N/A"}</span></div>
        </div>
        <div style="flex:1;min-width:250px;border:1px solid #ddd;padding:14px;border-radius:6px;background:white;">
            <strong style="color:#1a1a2e;font-size:13px;">PARTY C - LANDLORD (Property Owner)</strong>
            <div class="row"><span class="label">Full Name:</span><span class="value">{report.landlord_full_name or "N/A"}</span></div>
            <div class="row"><span class="label">Email:</span><span class="value">{report.landlord_email or "N/A"}</span></div>
            <div class="row"><span class="label">Phone:</span><span class="value">{report.landlord_phone or "N/A"}</span></div>
        </div>
    </div>
</div>

<!-- ===== PROPERTY ===== -->
<div class="section">
    <h3>PROPERTY DETAILS</h3>
    <div class="row"><span class="label">Property Title:</span><span class="value">{report.property_title or "N/A"}</span></div>
    <div class="row"><span class="label">Property Type:</span><span class="value">{report.property_type or "N/A"}</span></div>
    <div class="row"><span class="label">Address:</span><span class="value">{report.property_address or "N/A"}</span></div>
    <div class="row"><span class="label">City / State / Country:</span><span class="value">{report.property_city or "N/A"}, {report.property_state or "N/A"}, {report.property_country or "N/A"}</span></div>
    <div class="row"><span class="label">Listed Rent:</span><span class="value">{report.currency} {report.property_rent_amount or "N/A"}/period</span></div>
    <div style="margin-top:12px;">
        <strong>Property Photos (captured at time of booking):</strong>
        <div style="margin-top:8px;display:flex;flex-wrap:wrap;">{photos_html}</div>
    </div>
</div>

<!-- ===== BOOKING ===== -->
<div class="section">
    <h3>BOOKING DETAILS</h3>
    <div class="row"><span class="label">Booking Reference:</span><span class="value" style="font-weight:bold;font-size:14px;">{report.booking_reference}</span></div>
    <div class="row"><span class="label">Booking Status:</span><span class="value">{report.booking_status}</span></div>
    <div class="row"><span class="label">Move-In Date:</span><span class="value">{report.move_in_date.strftime("%B %d, %Y") if report.move_in_date else "N/A"}</span></div>
    <div class="row"><span class="label">Lease Start:</span><span class="value">{report.lease_start_date.strftime("%B %d, %Y") if report.lease_start_date else "N/A"}</span></div>
    <div class="row"><span class="label">Booking Created:</span><span class="value">{report.booking_created_at.strftime("%B %d, %Y at %I:%M %p") if report.booking_created_at else "N/A"}</span></div>
    <div class="row"><span class="label">Terms Agreed:</span><span class="value">{"Yes - by Tenant at " + report.tenant_terms_agreed_at.strftime("%B %d, %Y %I:%M %p") if report.tenant_terms_agreed_at else "No"}</span></div>
</div>

<!-- ===== PAYMENT ===== -->
<div class="section">
    <h3>PAYMENT RECEIPT</h3>
    <div class="row"><span class="label">Total Amount Paid:</span><span class="value amount">{report.currency} {report.total_amount}</span></div>
    <div class="row"><span class="label">Security Deposit:</span><span class="value">{report.currency} {report.security_deposit}</span></div>
    <div class="row"><span class="label">Service Fee:</span><span class="value">{report.currency} {report.service_fee}</span></div>
    <div class="row"><span class="label">Platform Fee (10%):</span><span class="value">{report.currency} {report.platform_fee}</span></div>
    <div class="row"><span class="label">Payment Reference:</span><span class="value">{report.payment_reference or "N/A"}</span></div>
    <div class="row"><span class="label">Payment Date:</span><span class="value">{report.payment_date.strftime("%B %d, %Y at %I:%M %p") if report.payment_date else "N/A"}</span></div>
</div>

<!-- ===== DISBURSEMENT ===== -->
<div class="section">
    <h3>FUND DISBURSEMENT RECORD</h3>
    <div class="row"><span class="label">Agent/Landlord Received Funds:</span><span class="value" style="font-weight:bold;color:#27ae60;">{report.funds_released_at.strftime("%B %d, %Y at %I:%M %p") + " UTC" if report.funds_released_at else "PENDING"}</span></div>
    <div class="row"><span class="label">Amount Disbursed:</span><span class="value amount">{report.currency} {report.total_amount}</span></div>
    <div class="row"><span class="label">Payment Method:</span><span class="value">APEX Housing Escrow</span></div>
    <div class="row"><span class="label">Platform Fee Retained:</span><span class="value">{report.currency} {report.platform_fee}</span></div>
    <p style="font-size:11px;color:#666;margin-top:10px;">This section records the exact date and time when the escrow funds were released from the platform's protection to the agent/landlord's wallet. This timestamp serves as proof of payment disbursement.</p>
</div>

<!-- ===== TERMS ===== -->
<div class="section page-break">
    <h3>TERMS AND CONDITIONS</h3>
    <div class="legal">
        <strong>Agent's Terms for this Property:</strong>
        <div class="terms-box">{terms_text}</div>
    </div>
    <div class="legal">
        <strong>Platform Terms (APEX Housing):</strong>
        <div class="terms-box">{platform_terms_text}</div>
    </div>
</div>

<!-- ===== SIGNATURES ===== -->
<div class="section page-break">
    <h3>PARTY SIGNATURES</h3>
    <p style="font-size:12px;color:#666;margin:0 0 15px;">By signing below, each party acknowledges they have read, understood, and agreed to the above terms and conditions. These signatures are legally binding and serve as evidence of agreement to the terms of this transaction.</p>
    <div class="sig-grid">
        <div>
            <div class="sig-name">Agent (Party A)</div>
            <p style="font-size:11px;color:#666;margin:2px 0;">{report.agent_full_name or ""}</p>
            {agent_sig}
        </div>
        <div>
            <div class="sig-name">Tenant (Party B)</div>
            <p style="font-size:11px;color:#666;margin:2px 0;">{report.tenant_full_name or ""}</p>
            {tenant_sig}
        </div>
        <div>
            <div class="sig-name">Landlord (Party C)</div>
            <p style="font-size:11px;color:#666;margin:2px 0;">{report.landlord_full_name or ""}</p>
            {landlord_sig}
        </div>
    </div>
</div>

<!-- ===== PROOF ===== -->
<div class="section">
    <h3>DOCUMENT AUTHENTICITY</h3>
    <p style="font-size:12px;">This report was generated by the APEX Housing platform and contains an immutable, time-stamped snapshot of the complete booking transaction. All data, signatures, and terms were captured at the time of each action and cannot be altered after recording.</p>
    <div class="row"><span class="label">Report ID:</span><span class="value" style="font-family:monospace;">{report.id}</span></div>
    <div class="row"><span class="label">Report Number:</span><span class="value" style="font-weight:bold;">{report.report_number}</span></div>
    <div class="row"><span class="label">Generated:</span><span class="value">{ts} UTC</span></div>
    <div class="row"><span class="label">Downloaded:</span><span class="value">{report.download_count} time(s)</span></div>
    <div class="row"><span class="label">Status:</span><span class="value">{"FINALIZED" if report.is_finalized else "PENDING SIGNATURES"}</span></div>
</div>

<div class="footer">
    <p><strong>APEX HOUSING</strong> - Official Transaction Report</p>
    <p>This document is generated by APEX Housing Platform and may be used as evidence in courts, police stations, or regulatory bodies.</p>
    <p>For verification, contact: support@apexhousing.com | Report ID: {report.report_number}</p>
    <p>&copy; {datetime.now(timezone.utc).year} APEX Housing. All rights reserved.</p>
</div>

</body>
</html>"""
    return html


class BookingReportService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def generate_report(self, booking_id: UUID, escrow_id: UUID = None) -> BookingReport:
        """Generate a complete booking report with all data snapshot."""
        from app.bookings.models import Booking
        from app.properties.models import Property, PropertyImage, PropertyLocation, PropertyPricing
        from app.payments.models import Transaction
        from app.escrow.models import EscrowTransaction
        from app.users.models import User, Profile, Agent, Tenant as TenantModel, Landlord as LandlordModel

        existing = await self.db.execute(
            select(BookingReport).where(BookingReport.booking_id == booking_id)
        )
        if existing.scalar_one_or_none():
            raise BadRequest("Report already exists for this booking")

        booking_result = await self.db.execute(select(Booking).where(Booking.id == booking_id))
        booking = booking_result.scalar_one_or_none()
        if not booking:
            raise NotFound("Booking not found")

        # --- Snapshot agent personal details ---
        agent_name = agent_email = agent_phone = agent_agency = agent_license = None
        if booking.agent_id:
            agent_user = await self.db.execute(select(User).where(User.id == booking.agent_id))
            agent_u = agent_user.scalar_one_or_none()
            if agent_u:
                agent_email = agent_u.email
                prof = await self.db.execute(select(Profile).where(Profile.user_id == agent_u.id))
                prof_obj = prof.scalar_one_or_none()
                if prof_obj:
                    agent_name = f"{prof_obj.first_name or ''} {prof_obj.last_name or ''}".strip()
                ag = await self.db.execute(select(Agent).where(Agent.user_id == agent_u.id))
                ag_obj = ag.scalar_one_or_none()
                if ag_obj:
                    agent_agency = ag_obj.agency_name
                    agent_license = ag_obj.license_number

        # --- Snapshot tenant personal details ---
        tenant_name = tenant_email = tenant_phone = None
        tenant_user = await self.db.execute(select(User).where(User.id == booking.tenant_id))
        tenant_u = tenant_user.scalar_one_or_none()
        if tenant_u:
            tenant_email = tenant_u.email
            prof = await self.db.execute(select(Profile).where(Profile.user_id == tenant_u.id))
            prof_obj = prof.scalar_one_or_none()
            if prof_obj:
                tenant_name = f"{prof_obj.first_name or ''} {prof_obj.last_name or ''}".strip()

        # --- Snapshot landlord personal details ---
        landlord_name = landlord_email = landlord_phone = None
        landlord_user = await self.db.execute(select(User).where(User.id == booking.landlord_id))
        landlord_u = landlord_user.scalar_one_or_none()
        if landlord_u:
            landlord_email = landlord_u.email
            prof = await self.db.execute(select(Profile).where(Profile.user_id == landlord_u.id))
            prof_obj = prof.scalar_one_or_none()
            if prof_obj:
                landlord_name = f"{prof_obj.first_name or ''} {prof_obj.last_name or ''}".strip()

        # --- Snapshot property data ---
        prop_title = prop_type = prop_address = prop_city = prop_state = prop_country = prop_desc = prop_rent = None
        agent_terms_snap = None
        agent_sig_data = agent_signed_at_val = None
        prop_photos = None

        prop_result = await self.db.execute(select(Property).where(Property.id == booking.property_id))
        prop = prop_result.scalar_one_or_none()
        if prop:
            prop_title = prop.title
            prop_type = prop.property_type
            prop_desc = prop.description
            agent_terms_snap = prop.agent_terms
            agent_sig_data = prop.agent_signature_data
            agent_signed_at_val = prop.agent_signed_at

            loc_result = await self.db.execute(
                select(PropertyLocation).where(PropertyLocation.property_id == prop.id)
            )
            loc = loc_result.scalar_one_or_none()
            if loc:
                prop_address = loc.address
                prop_city = loc.city
                prop_state = loc.state
                prop_country = loc.country

            img_result = await self.db.execute(
                select(PropertyImage).where(PropertyImage.property_id == prop.id).order_by(PropertyImage.sort_order)
            )
            images = img_result.scalars().all()
            prop_photos = {"urls": [img.url for img in images], "count": len(images)}

            price_result = await self.db.execute(
                select(PropertyPricing).where(PropertyPricing.property_id == prop.id)
            )
            pricing = price_result.scalar_one_or_none()
            if pricing:
                prop_rent = str(pricing.rent_amount)

        # --- Snapshot payment data ---
        tx_result = await self.db.execute(
            select(Transaction).where(
                Transaction.booking_id == booking_id,
                Transaction.status == "SUCCESS",
            ).order_by(Transaction.created_at.desc())
        )
        transaction = tx_result.scalar_one_or_none()

        total = str(booking.total_amount) if booking.total_amount else "0.00"
        deposit = str(booking.security_deposit) if booking.security_deposit else "0.00"
        fee = str(booking.service_fee) if booking.service_fee else "0.00"
        platform_fee = str(round(float(total) * 0.10, 2)) if booking.total_amount else "0.00"

        # Lookup escrow for disbursement timestamp
        funds_released_at_val = None
        if escrow_id:
            escrow_result = await self.db.execute(select(EscrowTransaction).where(EscrowTransaction.id == escrow_id))
            escrow = escrow_result.scalar_one_or_none()
            if escrow:
                funds_released_at_val = escrow.hold_released_at

        report = BookingReport(
            id=uuid4(),
            booking_id=booking.id,
            property_id=booking.property_id,
            tenant_id=booking.tenant_id,
            landlord_id=booking.landlord_id,
            agent_id=booking.agent_id,
            report_number=generate_report_number(),
            # Agent details
            agent_full_name=agent_name,
            agent_email=agent_email,
            agent_phone=agent_phone,
            agent_agency_name=agent_agency,
            agent_license_number=agent_license,
            # Tenant details
            tenant_full_name=tenant_name,
            tenant_email=tenant_email,
            tenant_phone=tenant_phone,
            # Landlord details
            landlord_full_name=landlord_name,
            landlord_email=landlord_email,
            landlord_phone=landlord_phone,
            # Property
            property_title=prop_title,
            property_type=prop_type,
            property_address=prop_address,
            property_city=prop_city,
            property_state=prop_state,
            property_country=prop_country,
            property_photos=prop_photos,
            property_description=prop_desc,
            property_rent_amount=prop_rent,
            # Terms
            agent_terms_snapshot=agent_terms_snap,
            tenant_terms_agreed=booking.tenant_terms_agreed,
            tenant_terms_agreed_at=booking.tenant_terms_agreed_at,
            # Booking
            booking_reference=booking.booking_reference,
            booking_status=booking.status.value if hasattr(booking.status, 'value') else str(booking.status),
            move_in_date=booking.move_in_date,
            lease_start_date=booking.lease_start_date,
            booking_created_at=booking.created_at,
            # Payment
            total_amount=total,
            security_deposit=deposit,
            service_fee=fee,
            platform_fee=platform_fee,
            currency="NGN",
            payment_reference=transaction.reference if transaction else None,
            payment_date=transaction.created_at if transaction else None,
            # Disbursement
            funds_released_at=funds_released_at_val,
            # Agent signature (from listing)
            agent_signature_data=agent_sig_data,
            agent_signed_at=agent_signed_at_val,
            # Tenant signature (from booking)
            tenant_signature_data=booking.tenant_signature_data,
            tenant_signed_at=booking.tenant_terms_agreed_at,
            tenant_signed_ip=None,
            report_data={
                "booking_id": str(booking.id),
                "property_id": str(booking.property_id),
                "generated_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        self.db.add(report)
        await self.db.commit()
        await self.db.refresh(report)

        logger.info(f"Booking report {report.report_number} generated for booking {booking.booking_reference}")
        return report

    async def get_report(self, report_id: UUID) -> BookingReport:
        result = await self.db.execute(select(BookingReport).where(BookingReport.id == report_id))
        report = result.scalar_one_or_none()
        if not report:
            raise NotFound("Report not found")
        return report

    async def get_report_by_booking(self, booking_id: UUID) -> BookingReport:
        result = await self.db.execute(select(BookingReport).where(BookingReport.booking_id == booking_id))
        report = result.scalar_one_or_none()
        if not report:
            raise NotFound("Report not found for this booking")
        return report

    async def sign_report(self, report_id: UUID, user_id: UUID, role: str, ip_address: str = None, signature_data: str = None) -> BookingReport:
        report = await self.get_report(report_id)

        if role == "LANDLORD":
            if report.landlord_id != user_id:
                raise BadRequest("Only the landlord can sign as landlord")
            if report.landlord_signed:
                raise BadRequest("Landlord has already signed")
            report.landlord_signed = True
            report.landlord_signed_at = datetime.now(timezone.utc)
            report.landlord_signed_ip = ip_address
            report.landlord_signature_data = signature_data or report.landlord_signature_data
        else:
            raise BadRequest("Agent and tenant signatures are captured at listing/booking time respectively")

        if report.agent_signed_at and report.tenant_signed_at and report.landlord_signed:
            report.is_finalized = True

        await self.db.commit()
        await self.db.refresh(report)
        return report

    async def download_report(self, report_id: UUID, user_id: UUID) -> dict:
        report = await self.get_report(report_id)
        if user_id not in (report.tenant_id, report.landlord_id, report.agent_id):
            raise BadRequest("Not authorized to download this report")
        report.is_downloaded = True
        report.downloaded_at = datetime.now(timezone.utc)
        report.download_count += 1
        await self.db.commit()
        html = _build_report_html(report)
        return {"report": report, "html": html}

    async def list_reports(self, user_id: UUID, page: int = 1, page_size: int = 20) -> dict:
        from sqlalchemy import func as sql_func
        query = select(BookingReport).where(
            (BookingReport.tenant_id == user_id) |
            (BookingReport.landlord_id == user_id) |
            (BookingReport.agent_id == user_id)
        )
        count_result = await self.db.execute(select(sql_func.count()).select_from(query.subquery()))
        total = count_result.scalar()
        query = query.offset((page - 1) * page_size).limit(page_size).order_by(BookingReport.created_at.desc())
        result = await self.db.execute(query)
        return {"total": total, "reports": result.scalars().all()}

"""
APEX Housing branded email templates.
All emails are wrapped with the platform splash screen header.
Matches the website/app purple theme (#8B5CF6).
"""
import html
from typing import Optional

# Brand colors — matching website/app theme
PRIMARY_COLOR = "#8B5CF6"       # APEX purple
PRIMARY_DARK = "#7C3AED"        # Darker purple for gradients
PRIMARY_LIGHT = "#A78BFA"       # Lighter purple accent
ACCENT_COLOR = "#8B5CF6"        # Purple accent
SUCCESS_COLOR = "#10B981"       # Green
WARNING_COLOR = "#F59E0B"       # Amber
ERROR_COLOR = "#EF4444"         # Red
LIGHT_BG = "#F9FAFB"            # Light gray background
CONTENT_BG = "#FFFFFF"          # White content area
TEXT_COLOR = "#1F2937"          # Dark gray text
MUTED_COLOR = "#6B7280"         # Gray muted text
WHITE = "#FFFFFF"
BORDER_COLOR = "#E5E7EB"        # Light border

LOGO_URL = "https://apex-housing.online/apex-logo.png"


def _brand_header() -> str:
    """Purple gradient header with logo and tagline — matches website style."""
    return f"""
    <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, {PRIMARY_DARK} 0%, {PRIMARY_COLOR} 50%, {PRIMARY_LIGHT} 100%); border-radius: 16px 16px 0 0;">
        <tr>
            <td style="padding: 40px 30px 35px; text-align: center;">
                <table cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                    <tr>
                        <td style="padding-right: 12px; vertical-align: middle;">
                            <img src="{LOGO_URL}" alt="APEX" width="44" height="44" style="border-radius: 10px; display: block;" />
                        </td>
                        <td style="vertical-align: middle;">
                            <h1 style="color: {WHITE}; font-size: 26px; font-weight: 700; margin: 0; letter-spacing: 0.5px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                                APEX<span style="color: rgba(255,255,255,0.8); font-weight: 300;">Housing</span>
                            </h1>
                        </td>
                    </tr>
                </table>
                <p style="color: rgba(255,255,255,0.75); font-size: 13px; margin: 14px 0 0; letter-spacing: 0.5px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                    Rent Smarter. Connect Securely. Live Better.
                </p>
            </td>
        </tr>
    </table>
    """


def _brand_footer() -> str:
    """Standard email footer with links."""
    return f"""
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {LIGHT_BG}; border-radius: 0 0 16px 16px; border-top: 1px solid {BORDER_COLOR};">
        <tr>
            <td style="padding: 25px 30px; text-align: center;">
                <p style="color: {TEXT_COLOR}; font-size: 14px; font-weight: 600; margin: 0 0 6px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                    APEX Housing
                </p>
                <p style="color: {MUTED_COLOR}; font-size: 12px; margin: 0 0 12px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                    Nigeria's most trusted rental platform
                </p>
                <table cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                    <tr>
                        <td style="padding: 0 8px;">
                            <a href="https://apex-housing.online" style="color: {PRIMARY_COLOR}; font-size: 12px; text-decoration: none; font-family: 'Helvetica Neue', Arial, sans-serif;">Website</a>
                        </td>
                        <td style="color: {BORDER_COLOR}; padding: 0 4px;">|</td>
                        <td style="padding: 0 8px;">
                            <a href="https://apex-housing.online/#faq" style="color: {PRIMARY_COLOR}; font-size: 12px; text-decoration: none; font-family: 'Helvetica Neue', Arial, sans-serif;">Help Center</a>
                        </td>
                        <td style="color: {BORDER_COLOR}; padding: 0 4px;">|</td>
                        <td style="padding: 0 8px;">
                            <a href="mailto:support@apex-housing.online" style="color: {PRIMARY_COLOR}; font-size: 12px; text-decoration: none; font-family: 'Helvetica Neue', Arial, sans-serif;">Contact Us</a>
                        </td>
                    </tr>
                </table>
                <p style="color: {MUTED_COLOR}; font-size: 11px; margin: 16px 0 0; font-family: 'Helvetica Neue', Arial, sans-serif;">
                    This email was sent to you because of your activity on APEX Housing.<br>
                    &copy; 2026 APEX Housing. All rights reserved.
                </p>
            </td>
        </tr>
    </table>
    """


def _content_body(content_html: str) -> str:
    """Wrap content in a styled body section."""
    return f"""
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {CONTENT_BG};">
        <tr>
            <td style="padding: 40px 35px; font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 15px; color: {TEXT_COLOR}; line-height: 1.7;">
                {content_html}
            </td>
        </tr>
    </table>
    """


def wrap_email(content_html: str) -> str:
    """Wrap any content with APEX Housing branding (header + footer)."""
    return f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
    </head>
    <body style="margin: 0; padding: 0; background-color: {LIGHT_BG}; font-family: 'Helvetica Neue', Arial, sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {LIGHT_BG};">
            <tr>
                <td align="center" style="padding: 30px 15px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 600px; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(139,92,246,0.10);">
                        {_brand_header()}
                        {_content_body(content_html)}
                        {_brand_footer()}
                    </table>
                </td>
            </tr>
        </table>
    </body>
    </html>
    """


def otp_email(otp: str, purpose: str = "verification") -> str:
    safe_purpose = html.escape(purpose)
    content = f"""
    <h2 style="color: {TEXT_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Your {safe_purpose.title()} Code</h2>
    <p style="margin: 0 0 24px; color: {TEXT_COLOR};">Use the code below to complete your {safe_purpose}:</p>
    <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
            <td style="background: linear-gradient(135deg, #F5F3FF, #EDE9FE); padding: 24px; text-align: center; border-radius: 12px; border: 2px solid {PRIMARY_LIGHT};">
                <span style="font-size: 40px; font-weight: 700; letter-spacing: 12px; color: {PRIMARY_COLOR}; font-family: 'Courier New', monospace;">
                    {otp}
                </span>
            </td>
        </tr>
    </table>
    <p style="color: {MUTED_COLOR}; margin: 24px 0 0; font-size: 13px; text-align: center;">
        This code expires in <strong style="color: {TEXT_COLOR};">10 minutes</strong>. Do not share it with anyone.
    </p>
    """
    return wrap_email(content)


def welcome_email(name: str) -> str:
    safe_name = html.escape(name)
    content = f"""
    <h2 style="color: {TEXT_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Welcome to APEX Housing, {safe_name}!</h2>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">Your account has been created successfully. You're now part of Nigeria's most trusted property rental platform.</p>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR}; font-weight: 600;">Here's what you can do:</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 24px; background-color: #F5F3FF; border-radius: 12px; border: 1px solid {PRIMARY_LIGHT};">
        <tr>
            <td style="padding: 20px 24px;">
                <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td width="30" style="vertical-align: top; padding: 6px 0;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background-color: {PRIMARY_COLOR}; color: white; font-size: 12px; text-align: center; line-height: 22px;">&#10003;</div>
                        </td>
                        <td style="padding: 6px 0 6px 12px; color: {TEXT_COLOR};">Browse verified properties across Nigeria</td>
                    </tr>
                    <tr>
                        <td width="30" style="vertical-align: top; padding: 6px 0;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background-color: {PRIMARY_COLOR}; color: white; font-size: 12px; text-align: center; line-height: 22px;">&#10003;</div>
                        </td>
                        <td style="padding: 6px 0 6px 12px; color: {TEXT_COLOR};">Book properties with secure escrow protection</td>
                    </tr>
                    <tr>
                        <td width="30" style="vertical-align: top; padding: 6px 0;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background-color: {PRIMARY_COLOR}; color: white; font-size: 12px; text-align: center; line-height: 22px;">&#10003;</div>
                        </td>
                        <td style="padding: 6px 0 6px 12px; color: {TEXT_COLOR};">Communicate directly with agents and landlords</td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def booking_confirmed_email(booking_ref: str, property_title: str) -> str:
    safe_title = html.escape(property_title)
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Booking Confirmed</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #ECFDF5; border-radius: 12px; border: 1px solid #A7F3D0;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Booking Reference</p>
                <p style="margin: 0; font-size: 20px; font-weight: 700; color: {TEXT_COLOR}; font-family: 'Courier New', monospace;">{html.escape(booking_ref)}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your booking for <strong>{safe_title}</strong> has been confirmed and payment verified.</p>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">Your private conversation with the agent is now open. You can communicate freely through the app.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def payment_receipt_email(amount: float, reference: str, receipt_url: Optional[str] = None) -> str:
    receipt_link = ""
    if receipt_url:
        receipt_link = f"""
        <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
                <td>
                    <a href="{receipt_url}" style="display: inline-block; background: linear-gradient(135deg, {PRIMARY_COLOR}, {PRIMARY_DARK}); color: {WHITE};
                       padding: 12px 28px; text-decoration: none; border-radius: 10px; font-weight: 600; font-size: 14px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                        Download Receipt
                    </a>
                </td>
            </tr>
        </table>
        """

    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Payment Confirmed</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #ECFDF5; border-radius: 12px; border: 1px solid #A7F3D0;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Amount Paid</p>
                <p style="margin: 0 0 12px; font-size: 28px; font-weight: 700; color: {SUCCESS_COLOR};">&#8358;{amount:,.2f}</p>
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Reference</p>
                <p style="margin: 0; font-size: 14px; font-weight: 600; color: {TEXT_COLOR};">{reference}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 16px; color: {TEXT_COLOR};">Your payment has been received and verified. The funds are now held securely in escrow.</p>
    {receipt_link}
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def escrow_release_email(amount: float, property_title: str) -> str:
    safe_title = html.escape(property_title)
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Funds Released</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #ECFDF5; border-radius: 12px; border: 1px solid #A7F3D0;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Amount Released</p>
                <p style="margin: 0 0 12px; font-size: 28px; font-weight: 700; color: {SUCCESS_COLOR};">&#8358;{amount:,.2f}</p>
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Property</p>
                <p style="margin: 0; font-size: 14px; font-weight: 600; color: {TEXT_COLOR};">{safe_title}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Escrow funds have been released to your wallet. The funds will be available for withdrawal shortly.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def password_reset_email(reset_link: str) -> str:
    content = f"""
    <h2 style="color: {TEXT_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Password Reset</h2>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">You requested a password reset. Click the button below to set a new password:</p>
    <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
            <td>
                <a href="{reset_link}" style="display: inline-block; background: linear-gradient(135deg, {PRIMARY_COLOR}, {PRIMARY_DARK}); color: {WHITE};
                   padding: 14px 32px; text-decoration: none; border-radius: 10px; font-weight: 600; font-size: 15px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                    Reset Password
                </a>
            </td>
        </tr>
    </table>
    <p style="color: {MUTED_COLOR}; margin: 24px 0 0; font-size: 13px;">This link expires in <strong style="color: {TEXT_COLOR};">1 hour</strong>. If you didn't request this, ignore this email.</p>
    """
    return wrap_email(content)


def booking_cancelled_email(booking_ref: str, property_title: str, reason: str) -> str:
    safe_title = html.escape(property_title)
    safe_reason = html.escape(reason)
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Booking Cancelled</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #FEF2F2; border-radius: 12px; border: 1px solid #FECACA;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Booking Reference</p>
                <p style="margin: 0; font-size: 18px; font-weight: 700; color: {TEXT_COLOR};">{html.escape(booking_ref)}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your booking for <strong>{safe_title}</strong> has been cancelled.</p>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};"><strong>Reason:</strong> {safe_reason}</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def dispute_opened_email(dispute_id: str, escrow_id: str) -> str:
    content = f"""
    <h2 style="color: {WARNING_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">New Dispute Opened</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #FFFBEB; border-radius: 12px; border: 1px solid #FDE68A;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Escrow Reference</p>
                <p style="margin: 0; font-size: 14px; font-weight: 600; color: {TEXT_COLOR};">{escrow_id}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">A dispute has been opened for your booking. Our team will review and resolve this promptly.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def dispute_resolved_email(resolution: str) -> str:
    safe_resolution = html.escape(resolution)
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Dispute Resolved</h2>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your dispute has been reviewed and resolved.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #ECFDF5; border-radius: 12px; border: 1px solid #A7F3D0;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Resolution</p>
                <p style="margin: 0; font-size: 14px; font-weight: 600; color: {TEXT_COLOR};">{safe_resolution}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def move_in_reminder_email(property_title: str, hours_remaining: int) -> str:
    safe_title = html.escape(property_title)
    content = f"""
    <h2 style="color: {WARNING_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Escrow Timer Reminder</h2>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your escrow protection for <strong>{safe_title}</strong> expires in <strong>{hours_remaining} hours</strong>.</p>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">If you are satisfied with the property, please confirm now. Otherwise, the funds will be automatically released to the landlord.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def report_ready_email(property_title: str, report_number: str) -> str:
    safe_title = html.escape(property_title)
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Booking Report Ready</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #F5F3FF; border-radius: 12px; border: 1px solid {PRIMARY_LIGHT};">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Report Number</p>
                <p style="margin: 0; font-size: 14px; font-weight: 600; color: {TEXT_COLOR};">{html.escape(report_number)}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your official booking report for <strong>{safe_title}</strong> is ready. This report contains all transaction details, signatures, and serves as your legal proof of transaction.</p>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};"><strong>Important:</strong> Download and print this report from your report history at any time.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def refund_processed_email(amount: float, status_msg: str) -> str:
    safe_status = html.escape(status_msg)
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Refund Processed</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #ECFDF5; border-radius: 12px; border: 1px solid #A7F3D0;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Refund Amount</p>
                <p style="margin: 0; font-size: 28px; font-weight: 700; color: {SUCCESS_COLOR};">&#8358;{amount:,.2f}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your refund has been processed. {safe_status}</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def property_approved_email(property_title: str) -> str:
    safe_title = html.escape(property_title)
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Property Approved</h2>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">Your property <strong>{safe_title}</strong> has been approved and is now live on APEX Housing.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def property_submitted_email(property_title: str) -> str:
    safe_title = html.escape(property_title)
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Property Listing Submitted</h2>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">Your property <strong>{safe_title}</strong> has been successfully submitted and is pending review.</p>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">Our team will review your listing and notify you once it is approved and published on the marketplace.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def property_rejected_email(property_title: str, reason: str = "") -> str:
    safe_title = html.escape(property_title)
    safe_reason = html.escape(reason) if reason else ""
    reason_html = f"<p style='margin: 0 0 12px; color: {TEXT_COLOR};'><strong>Reason:</strong> {safe_reason}</p>" if reason else ""
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Property Not Approved</h2>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your property <strong>{safe_title}</strong> was not approved.</p>
    {reason_html}
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def kyc_approved_email() -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Identity Verified</h2>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">Your identity verification has been approved. You now have full access to all APEX Housing features.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def kyc_rejected_email(reason: str = "") -> str:
    safe_reason = html.escape(reason) if reason else ""
    reason_html = f"<p style='margin: 0 0 12px; color: {TEXT_COLOR};'><strong>Reason:</strong> {safe_reason}</p>" if reason else ""
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">Verification Not Approved</h2>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">Your identity verification was not approved. Please review and resubmit.</p>
    {reason_html}
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def admin_dispute_alert_email(escrow_id: str) -> str:
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">New Dispute Requires Review</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #FEF2F2; border-radius: 12px; border: 1px solid #FECACA;">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Escrow ID</p>
                <p style="margin: 0; font-size: 14px; font-weight: 600; color: {TEXT_COLOR};">{escrow_id}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};">A dispute has been opened. Please review and resolve this dispute in the admin dashboard.</p>
    <p style="margin: 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def admin_invite_email(invited_by: str = "Super Admin") -> str:
    safe_by = html.escape(invited_by)
    content = f"""
    <h2 style="color: {TEXT_COLOR}; margin: 0 0 12px; font-size: 22px; font-weight: 600;">You've Been Invited to APEX Housing Admin</h2>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR};"><strong>{safe_by}</strong> has invited you to join the APEX Housing admin team.</p>
    <p style="margin: 0 0 20px; color: {TEXT_COLOR};">You now have access to the admin dashboard where you can manage properties, users, bookings, and disputes.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #F5F3FF; border-radius: 12px; border: 1px solid {PRIMARY_LIGHT};">
        <tr>
            <td style="padding: 18px 22px;">
                <p style="margin: 0 0 4px; font-size: 12px; color: {MUTED_COLOR}; text-transform: uppercase; letter-spacing: 0.5px;">Your Role</p>
                <p style="margin: 0; font-size: 18px; font-weight: 700; color: {PRIMARY_COLOR};">Admin</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px; color: {TEXT_COLOR}; font-weight: 600;">Next Steps:</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 24px;">
        <tr>
            <td width="30" style="vertical-align: top; padding: 6px 0;">
                <div style="width: 22px; height: 22px; border-radius: 50%; background-color: {PRIMARY_COLOR}; color: white; font-size: 12px; text-align: center; line-height: 22px;">1</div>
            </td>
            <td style="padding: 6px 0 6px 12px; color: {TEXT_COLOR};">Download the APEX Housing Admin app</td>
        </tr>
        <tr>
            <td width="30" style="vertical-align: top; padding: 6px 0;">
                <div style="width: 22px; height: 22px; border-radius: 50%; background-color: {PRIMARY_COLOR}; color: white; font-size: 12px; text-align: center; line-height: 22px;">2</div>
            </td>
            <td style="padding: 6px 0 6px 12px; color: {TEXT_COLOR};">Tap <strong>"Request Access"</strong> and enter this email address</td>
        </tr>
        <tr>
            <td width="30" style="vertical-align: top; padding: 6px 0;">
                <div style="width: 22px; height: 22px; border-radius: 50%; background-color: {PRIMARY_COLOR}; color: white; font-size: 12px; text-align: center; line-height: 22px;">3</div>
            </td>
            <td style="padding: 6px 0 6px 12px; color: {TEXT_COLOR};">Verify with the OTP sent to this email and set your password</td>
        </tr>
    </table>
    <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
            <td>
                <a href="https://www.apex-housing.online/apex-admin.apk" style="display: inline-block; background: linear-gradient(135deg, {PRIMARY_COLOR}, {PRIMARY_DARK}); color: {WHITE};
                   padding: 14px 32px; text-decoration: none; border-radius: 10px; font-weight: 600; font-size: 15px; font-family: 'Helvetica Neue', Arial, sans-serif;">
                    Download Admin App
                </a>
            </td>
        </tr>
    </table>
    <p style="color: {MUTED_COLOR}; margin: 20px 0 0; font-size: 13px;">If the button doesn't work, visit <strong>apex-housing.online</strong> to download the admin app.</p>
    <p style="margin: 20px 0 0; color: {TEXT_COLOR};">Best regards,<br><strong style="color: {PRIMARY_COLOR};">The APEX Housing Team</strong></p>
    """
    return wrap_email(content)

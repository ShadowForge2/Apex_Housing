"""
APEX Housing branded email templates.
All emails are wrapped with the platform splash screen header.
"""
from typing import Optional

# Brand colors
PRIMARY_COLOR = "#1a1a2e"
ACCENT_COLOR = "#e94560"
SUCCESS_COLOR = "#27ae60"
WARNING_COLOR = "#f39c12"
ERROR_COLOR = "#c0392b"
LIGHT_BG = "#f8f9fa"
TEXT_COLOR = "#333333"
MUTED_COLOR = "#666666"
WHITE = "#ffffff"

LOGO_URL = "https://res.cloudinary.com/your-cloud-name/image/upload/apex_housing_logo.png"
# Fallback: use text-based logo if image URL not configured
LOGO_TEXT = "APEX Housing"


def _brand_header() -> str:
    """Splash screen header with logo and tagline."""
    return f"""
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {PRIMARY_COLOR}; border-radius: 12px 12px 0 0;">
        <tr>
            <td style="padding: 40px 30px 30px; text-align: center;">
                <h1 style="color: {WHITE}; font-size: 28px; font-weight: 800; margin: 0; letter-spacing: 1px;">
                    APEX Housing
                </h1>
                <p style="color: rgba(255,255,255,0.7); font-size: 13px; margin: 8px 0 0; letter-spacing: 0.5px;">
                    Secure. Trusted. Transparent.
                </p>
            </td>
        </tr>
    </table>
    """


def _brand_footer() -> str:
    """Standard email footer."""
    return f"""
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {LIGHT_BG}; border-radius: 0 0 12px 12px; border-top: 1px solid #e0e0e0;">
        <tr>
            <td style="padding: 25px 30px; text-align: center;">
                <p style="color: {MUTED_COLOR}; font-size: 12px; margin: 0 0 8px;">
                    APEX Housing &mdash; Secure Property Transactions
                </p>
                <p style="color: {MUTED_COLOR}; font-size: 11px; margin: 0 0 8px;">
                    This email was sent to you because of your activity on APEX Housing.
                </p>
                <p style="color: {MUTED_COLOR}; font-size: 11px; margin: 0;">
                    &copy; 2026 APEX Housing. All rights reserved.
                </p>
            </td>
        </tr>
    </table>
    """


def _content_body(content_html: str) -> str:
    """Wrap content in a styled body section."""
    return f"""
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {WHITE};">
        <tr>
            <td style="padding: 35px 30px; font-family: Arial, Helvetica, sans-serif; font-size: 15px; color: {TEXT_COLOR}; line-height: 1.6;">
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
    <body style="margin: 0; padding: 0; background-color: {LIGHT_BG}; font-family: Arial, Helvetica, sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {LIGHT_BG};">
            <tr>
                <td align="center" style="padding: 30px 15px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 600px; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.08);">
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
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 15px; font-size: 22px;">Your {purpose.title()} Code</h2>
    <p style="margin: 0 0 20px;">Use the code below to complete your {purpose}:</p>
    <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
            <td style="background-color: {LIGHT_BG}; padding: 20px; text-align: center; border-radius: 8px; border: 1px solid #e0e0e0;">
                <span style="font-size: 36px; font-weight: bold; letter-spacing: 10px; color: {PRIMARY_COLOR}; font-family: 'Courier New', monospace;">
                    {otp}
                </span>
            </td>
        </tr>
    </table>
    <p style="color: {MUTED_COLOR}; margin: 20px 0 0; font-size: 13px;">
        This code expires in <strong>10 minutes</strong>. Do not share it with anyone.
    </p>
    """
    return wrap_email(content)


def welcome_email(name: str) -> str:
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 15px; font-size: 22px;">Welcome to APEX Housing, {name}!</h2>
    <p style="margin: 0 0 12px;">Your account has been created successfully. You're now part of Nigeria's most trusted property rental platform.</p>
    <p style="margin: 0 0 12px;">Here's what you can do:</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 10px 0 20px;">
        <tr>
            <td style="padding: 8px 0; vertical-align: top;">&#10003;</td>
            <td style="padding: 8px 0 8px 10px;">Browse verified properties across Nigeria</td>
        </tr>
        <tr>
            <td style="padding: 8px 0; vertical-align: top;">&#10003;</td>
            <td style="padding: 8px 0 8px 10px;">Book properties with secure escrow protection</td>
        </tr>
        <tr>
            <td style="padding: 8px 0; vertical-align: top;">&#10003;</td>
            <td style="padding: 8px 0 8px 10px;">Communicate directly with agents and landlords</td>
        </tr>
    </table>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def booking_confirmed_email(booking_ref: str, property_title: str) -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Booking Confirmed</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {SUCCESS_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Booking Reference</p>
                <p style="margin: 0; font-size: 18px; font-weight: bold; color: {PRIMARY_COLOR};">{booking_ref}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">Your booking for <strong>{property_title}</strong> has been confirmed and payment verified.</p>
    <p style="margin: 0 0 12px;">Your private conversation with the agent is now open. You can communicate freely through the app.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def payment_receipt_email(amount: float, reference: str, receipt_url: Optional[str] = None) -> str:
    receipt_link = ""
    if receipt_url:
        receipt_link = f"""
        <a href="{receipt_url}" style="display: inline-block; background-color: {PRIMARY_COLOR}; color: {WHITE};
           padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 10px 0;">
            Download Receipt
        </a>
        """

    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Payment Confirmed</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {SUCCESS_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Amount Paid</p>
                <p style="margin: 0 0 10px; font-size: 24px; font-weight: bold; color: {SUCCESS_COLOR};">&curren;{amount:,.2f} NGN</p>
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Reference</p>
                <p style="margin: 0; font-size: 14px; font-weight: bold; color: {PRIMARY_COLOR};">{reference}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">Your payment has been received and verified. The funds are now held securely in escrow.</p>
    {receipt_link}
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def escrow_release_email(amount: float, property_title: str) -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Funds Released</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {SUCCESS_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Amount Released</p>
                <p style="margin: 0 0 10px; font-size: 24px; font-weight: bold; color: {SUCCESS_COLOR};">&curren;{amount:,.2f} NGN</p>
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Property</p>
                <p style="margin: 0; font-size: 14px; font-weight: bold; color: {PRIMARY_COLOR};">{property_title}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">Escrow funds have been released to your wallet. The funds will be available for withdrawal shortly.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def password_reset_email(reset_link: str) -> str:
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 15px; font-size: 22px;">Password Reset</h2>
    <p style="margin: 0 0 12px;">You requested a password reset. Click the button below to set a new password:</p>
    <a href="{reset_link}" style="display: inline-block; background-color: {ACCENT_COLOR}; color: {WHITE};
       padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 10px 0 20px;">
        Reset Password
    </a>
    <p style="color: {MUTED_COLOR}; margin: 0; font-size: 13px;">This link expires in <strong>1 hour</strong>. If you didn't request this, ignore this email.</p>
    """
    return wrap_email(content)


def booking_cancelled_email(booking_ref: str, property_title: str, reason: str) -> str:
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 15px; font-size: 22px;">Booking Cancelled</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #fdf2f2; border-radius: 8px; border-left: 4px solid {ERROR_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Booking Reference</p>
                <p style="margin: 0; font-size: 16px; font-weight: bold; color: {PRIMARY_COLOR};">{booking_ref}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">Your booking for <strong>{property_title}</strong> has been cancelled.</p>
    <p style="margin: 0 0 12px;"><strong>Reason:</strong> {reason}</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def dispute_opened_email(dispute_id: str, escrow_id: str) -> str:
    content = f"""
    <h2 style="color: {WARNING_COLOR}; margin: 0 0 15px; font-size: 22px;">New Dispute Opened</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #fef9e7; border-radius: 8px; border-left: 4px solid {WARNING_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Escrow Reference</p>
                <p style="margin: 0; font-size: 14px; font-weight: bold; color: {PRIMARY_COLOR};">{escrow_id}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">A dispute has been opened for your booking. Our team will review and resolve this promptly.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def dispute_resolved_email(resolution: str) -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Dispute Resolved</h2>
    <p style="margin: 0 0 12px;">Your dispute has been reviewed and resolved.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {SUCCESS_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Resolution</p>
                <p style="margin: 0; font-size: 14px; font-weight: bold; color: {PRIMARY_COLOR};">{resolution}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def move_in_reminder_email(property_title: str, hours_remaining: int) -> str:
    content = f"""
    <h2 style="color: {WARNING_COLOR}; margin: 0 0 15px; font-size: 22px;">Escrow Timer Reminder</h2>
    <p style="margin: 0 0 12px;">Your escrow protection for <strong>{property_title}</strong> expires in <strong>{hours_remaining} hours</strong>.</p>
    <p style="margin: 0 0 12px;">If you are satisfied with the property, please confirm now. Otherwise, the funds will be automatically released to the landlord.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def report_ready_email(property_title: str, report_number: str) -> str:
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 15px; font-size: 22px;">Booking Report Ready</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {PRIMARY_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Report Number</p>
                <p style="margin: 0; font-size: 14px; font-weight: bold; color: {PRIMARY_COLOR};">{report_number}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">Your official booking report for <strong>{property_title}</strong> is ready. This report contains all transaction details, signatures, and serves as your legal proof of transaction.</p>
    <p style="margin: 0;"><strong>Important:</strong> Download and print this report from your report history at any time.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def refund_processed_email(amount: float, status_msg: str) -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Refund Processed</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {SUCCESS_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Refund Amount</p>
                <p style="margin: 0; font-size: 24px; font-weight: bold; color: {SUCCESS_COLOR};">&curren;{amount:,.2f} NGN</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">Your refund has been processed. {status_msg}</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def property_approved_email(property_title: str) -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Property Approved</h2>
    <p style="margin: 0 0 12px;">Your property <strong>{property_title}</strong> has been approved and is now live on APEX Housing.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def property_rejected_email(property_title: str, reason: str = "") -> str:
    reason_html = f"<p style='margin: 0 0 12px;'><strong>Reason:</strong> {reason}</p>" if reason else ""
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 15px; font-size: 22px;">Property Not Approved</h2>
    <p style="margin: 0 0 12px;">Your property <strong>{property_title}</strong> was not approved.</p>
    {reason_html}
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def kyc_approved_email() -> str:
    content = f"""
    <h2 style="color: {SUCCESS_COLOR}; margin: 0 0 15px; font-size: 22px;">Identity Verified</h2>
    <p style="margin: 0 0 12px;">Your identity verification has been approved. You now have full access to all APEX Housing features.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def kyc_rejected_email(reason: str = "") -> str:
    reason_html = f"<p style='margin: 0 0 12px;'><strong>Reason:</strong> {reason}</p>" if reason else ""
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 15px; font-size: 22px;">Verification Not Approved</h2>
    <p style="margin: 0 0 12px;">Your identity verification was not approved. Please review and resubmit.</p>
    {reason_html}
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def admin_dispute_alert_email(escrow_id: str) -> str:
    content = f"""
    <h2 style="color: {ERROR_COLOR}; margin: 0 0 15px; font-size: 22px;">New Dispute Requires Review</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 0 0 20px; background-color: #fdf2f2; border-radius: 8px; border-left: 4px solid {ERROR_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Escrow ID</p>
                <p style="margin: 0; font-size: 14px; font-weight: bold; color: {PRIMARY_COLOR};">{escrow_id}</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">A dispute has been opened. Please review and resolve this dispute in the admin dashboard.</p>
    <p style="margin: 0;"><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)


def admin_invite_email(invited_by: str = "Super Admin") -> str:
    content = f"""
    <h2 style="color: {PRIMARY_COLOR}; margin: 0 0 15px; font-size: 22px;">You've Been Invited to APEX Housing Admin</h2>
    <p style="margin: 0 0 12px;">{invited_by} has invited you to join the APEX Housing admin team.</p>
    <p style="margin: 0 0 12px;">You now have access to the admin dashboard where you can manage properties, users, bookings, and disputes.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin: 20px 0; background-color: {LIGHT_BG}; border-radius: 8px; border-left: 4px solid {PRIMARY_COLOR};">
        <tr>
            <td style="padding: 15px 20px;">
                <p style="margin: 0 0 5px; font-size: 13px; color: {MUTED_COLOR};">Your Role</p>
                <p style="margin: 0; font-size: 16px; font-weight: bold; color: {PRIMARY_COLOR};">Admin</p>
            </td>
        </tr>
    </table>
    <p style="margin: 0 0 12px;">To get started, please sign in using your email and set up your password via the forgot password option.</p>
    <p style="margin: 0;">Best regards,<br><strong>The APEX Housing Team</strong></p>
    """
    return wrap_email(content)

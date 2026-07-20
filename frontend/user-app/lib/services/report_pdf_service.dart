import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ReportPdfService {
  static Future<File> generatePdf(Map<String, dynamic> report) async {
    final pdf = pw.Document();
    final items = (report['items'] as List).cast<Map<String, dynamic>>();

    final brandColor = PdfColor.fromHex('#1A5276');
    final brandLight = PdfColor.fromHex('#D4E6F1');
    final successColor = PdfColor.fromHex('#27AE60');
    final errorColor = PdfColor.fromHex('#E74C3C');
    final grayColor = PdfColor.fromHex('#7F8C8D');
    final darkText = PdfColor.fromHex('#2C3E50');
    final lightGray = PdfColor.fromHex('#F2F3F4');

    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontSemiBold = pw.Font.helveticaBold();
    final fontItalic = pw.Font.helveticaOblique();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 50, 40, 60),
        header: (context) => _buildHeader(report, brandColor, brandLight, fontBold, font, grayColor, darkText),
        footer: (context) => _buildFooter(report, grayColor, font),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildRecipientBlock(report, font, fontBold, darkText, grayColor),
          pw.SizedBox(height: 16),
          _buildSubjectLine(report, fontBold, brandColor, darkText),
          pw.SizedBox(height: 14),
          _buildLandlordAffidavit(report, font, fontBold, fontItalic, darkText, brandColor),
          pw.SizedBox(height: 14),
          _buildPropertyDescription(report, font, fontBold, darkText, brandColor, grayColor, lightGray),
          pw.SizedBox(height: 14),
          _buildTenancyTerms(report, font, fontBold, darkText, brandColor),
          pw.SizedBox(height: 14),
          _buildTenantAffidavit(report, font, fontBold, fontItalic, darkText, brandColor),
          pw.SizedBox(height: 14),
          _buildInspectionChecklist(items, font, fontBold, darkText, brandColor, successColor, errorColor, lightGray),
          pw.SizedBox(height: 14),
          _buildPaymentDetails(report, font, fontBold, darkText, brandColor, lightGray, grayColor),
          pw.SizedBox(height: 14),
          _buildSignatures(report, font, fontBold, darkText, grayColor),
          pw.SizedBox(height: 16),
          _buildClosingClause(font, fontItalic, darkText, grayColor),
          pw.SizedBox(height: 20),
          _buildWitnessBlock(font, fontBold, darkText, grayColor),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = (report['title'] as String).replaceAll(' ', '_');
    final fileName = '${report['id']}_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file;
  }

  // ─── HEADER ────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    Map<String, dynamic> report,
    PdfColor brandColor,
    PdfColor brandLight,
    pw.Font fontBold,
    pw.Font font,
    PdfColor grayColor,
    PdfColor darkText,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: brandColor, width: 2.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('APEX HOUSING', style: pw.TextStyle(font: fontBold, fontSize: 22, color: brandColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Short-Term Rental & Property Management Platform', style: pw.TextStyle(font: font, fontSize: 9, color: grayColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('www.apex-housing.online | support@apex-housing.online', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Lagos, Nigeria | RC: 1234567', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(color: brandColor, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(report['id'] as String, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#FFFFFF'))),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Date: ${report['date']}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: darkText)),
                  pw.SizedBox(height: 2),
                  pw.Text('Ref: ${report['booking_reference']}', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── RECIPIENT BLOCK ───────────────────────────────────────
  static pw.Widget _buildRecipientBlock(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    PdfColor darkText,
    PdfColor grayColor,
  ) {
    final landlord = report['landlord_name'] ?? 'N/A';
    final tenant = report['tenant_name'] ?? 'N/A';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('TENANCY & PROPERTY REPORT', style: pw.TextStyle(font: fontBold, fontSize: 13, color: darkText)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('LANDLORD:', style: pw.TextStyle(font: fontBold, fontSize: 9, color: grayColor)),
                  pw.SizedBox(height: 1),
                  pw.Text(landlord, style: pw.TextStyle(font: fontBold, fontSize: 11, color: darkText)),
                  pw.Text('ID: ${report['landlord_id'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TENANT:', style: pw.TextStyle(font: fontBold, fontSize: 9, color: grayColor)),
                  pw.SizedBox(height: 1),
                  pw.Text(tenant, style: pw.TextStyle(font: fontBold, fontSize: 11, color: darkText)),
                  pw.Text('ID: ${report['tenant_id'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── SUBJECT LINE ──────────────────────────────────────────
  static pw.Widget _buildSubjectLine(
    Map<String, dynamic> report,
    pw.Font fontBold,
    PdfColor brandColor,
    PdfColor darkText,
  ) {
    final type = (report['type'] as String).toUpperCase();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: brandColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SUBJECT: ${report['title']}', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#FFFFFF'))),
          pw.SizedBox(height: 2),
          pw.Text('Type: $type | Status: ${report['status'].toString().toUpperCase()}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#FFFFFF').withAlpha(200))),
        ],
      ),
    );
  }

  // ─── LANDLORD AFFIDAVIT ────────────────────────────────────
  static pw.Widget _buildLandlordAffidavit(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    PdfColor darkText,
    PdfColor brandColor,
  ) {
    final landlord = report['landlord_name'] ?? 'N/A';
    final tenant = report['tenant_name'] ?? 'N/A';
    final propType = report['property_type'] ?? 'N/A';
    final propAddr = report['property_address'] ?? 'N/A';
    final checkIn = report['check_in_date'] ?? 'N/A';
    final checkOut = report['check_out_date'] ?? 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 4, height: 16, color: brandColor),
            pw.SizedBox(width: 8),
            pw.Text('LANDLORD\'S AFFIDAVIT', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandColor)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 10, color: darkText, lineSpacing: 5),
          text: 'I, $landlord (Landlord ID: ${report['landlord_id'] ?? 'N/A'}), do hereby solemnly swear and affirm that I am the lawful owner/authorized agent of the property described herein. I voluntarily rented out the $propType located at $propAddr through the APEX Housing platform to $tenant (Tenant ID: ${report['tenant_id'] ?? 'N/A'}).',
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 10, color: darkText, lineSpacing: 5),
          text: 'I further affirm that the tenant is expected to check in on $checkIn and the tenancy is scheduled to end on $checkOut. I vouch that the property is in a habitable condition and meets all safety and livability standards as required by law. I have not entered into any conflicting agreement regarding this property for the stated period.',
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 10, color: darkText, lineSpacing: 5),
          text: 'I accept responsibility for the maintenance of the property during the tenancy period and shall ensure timely resolution of any structural or systemic issues that may arise.',
        ),
      ],
    );
  }

  // ─── PROPERTY DESCRIPTION ──────────────────────────────────
  static pw.Widget _buildPropertyDescription(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    PdfColor darkText,
    PdfColor brandColor,
    PdfColor grayColor,
    PdfColor lightGray,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 4, height: 16, color: brandColor),
            pw.SizedBox(width: 8),
            pw.Text('PROPERTY DESCRIPTION', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandColor)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightGray,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: brandColor, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _propInfoRow('Type', report['property_type'] ?? 'N/A', font, fontBold, darkText, grayColor),
              _propInfoRow('Address', report['property_address'] ?? 'N/A', font, fontBold, darkText, grayColor),
              pw.SizedBox(height: 6),
              pw.Text('Description:', style: pw.TextStyle(font: fontBold, fontSize: 9, color: grayColor)),
              pw.SizedBox(height: 3),
              pw.Text(report['property_description'] ?? 'N/A', style: pw.TextStyle(font: font, fontSize: 9.5, color: darkText, lineSpacing: 4.5)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _propInfoRow(String label, String value, pw.Font font, pw.Font fontBold, PdfColor darkText, PdfColor grayColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text('$label:', style: pw.TextStyle(font: fontBold, fontSize: 9, color: grayColor)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9.5, color: darkText)),
          ),
        ],
      ),
    );
  }

  // ─── TENANCY TERMS ────────────────────────────────────────
  static pw.Widget _buildTenancyTerms(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    PdfColor darkText,
    PdfColor brandColor,
  ) {
    final checkIn = report['check_in_date'] ?? 'N/A';
    final checkOut = report['check_out_date'] ?? 'N/A';
    final amount = report['amount_paid'] ?? 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 4, height: 16, color: brandColor),
            pw.SizedBox(width: 8),
            pw.Text('TENANCY TERMS', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandColor)),
          ],
        ),
        pw.SizedBox(height: 8),
        _buildTermsTable([
          ['Move-In Date', checkIn],
          ['Move-Out Date', checkOut],
          ['Total Amount', amount],
          ['Payment Method', report['payment_method'] ?? 'N/A'],
          ['Booking Ref', report['booking_reference'] ?? 'N/A'],
        ], font, fontBold, brandColor, darkText),
      ],
    );
  }

  // ─── TENANT AFFIDAVIT ──────────────────────────────────────
  static pw.Widget _buildTenantAffidavit(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    PdfColor darkText,
    PdfColor brandColor,
  ) {
    final tenant = report['tenant_name'] ?? 'N/A';
    final landlord = report['landlord_name'] ?? 'N/A';
    final propType = report['property_type'] ?? 'N/A';
    final propAddr = report['property_address'] ?? 'N/A';
    final checkIn = report['check_in_date'] ?? 'N/A';
    final checkOut = report['check_out_date'] ?? 'N/A';
    final amount = report['amount_paid'] ?? 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 4, height: 16, color: brandColor),
            pw.SizedBox(width: 8),
            pw.Text('TENANT\'S AFFIDAVIT', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandColor)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 10, color: darkText, lineSpacing: 5),
          text: 'I, $tenant (Tenant ID: ${report['tenant_id'] ?? 'N/A'}), do hereby solemnly swear and affirm that I have inspected the $propType located at $propAddr and find it satisfactory for my occupancy.',
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 10, color: darkText, lineSpacing: 5),
          text: 'I vouch that I shall occupy the property from $checkIn to $checkOut and shall pay the total sum of $amount as agreed. I accept the property in its current condition and acknowledge receipt of all applicable keys and access credentials.',
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 10, color: darkText, lineSpacing: 5),
          text: 'I further affirm that I shall use the property solely for residential purposes, maintain it in good condition, and comply with all terms of the tenancy agreement as facilitated through the APEX Housing platform. I shall vacate the property by $checkOut unless a renewal agreement is reached.',
        ),
      ],
    );
  }

  // ─── INSPECTION CHECKLIST ──────────────────────────────────
  static pw.Widget _buildInspectionChecklist(
    List<Map<String, dynamic>> items,
    pw.Font font,
    pw.Font fontBold,
    PdfColor darkText,
    PdfColor brandColor,
    PdfColor successColor,
    PdfColor errorColor,
    PdfColor lightGray,
  ) {
    final passedCount = items.where((i) => i['status'] == 'passed').length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pw.Container(width: 4, height: 16, color: brandColor),
                pw.SizedBox(width: 8),
                pw.Text('INSPECTION CHECKLIST', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandColor)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: passedCount == items.length ? PdfColor.fromHex('#D5F5E3') : PdfColor.fromHex('#FADBD8'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                '$passedCount/${items.length} Passed',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: passedCount == items.length ? successColor : errorColor),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        _buildChecklistTable(items, font, fontBold, brandColor, darkText, successColor, errorColor),
      ],
    );
  }

  // ─── PAYMENT DETAILS ───────────────────────────────────────
  static pw.Widget _buildPaymentDetails(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    PdfColor darkText,
    PdfColor brandColor,
    PdfColor lightGray,
    PdfColor grayColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 4, height: 16, color: brandColor),
            pw.SizedBox(width: 8),
            pw.Text('PAYMENT DETAILS', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandColor)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightGray,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              _payRow('Amount Paid', report['amount_paid'] ?? 'N/A', font, fontBold, darkText, grayColor, isHighlight: true),
              _payRow('Payment Date', report['payment_date'] ?? 'N/A', font, fontBold, darkText, grayColor),
              _payRow('Disbursement Date', report['disbursement_date'] ?? 'N/A', font, fontBold, darkText, grayColor),
              _payRow('Payment Method', report['payment_method'] ?? 'N/A', font, fontBold, darkText, grayColor),
              _payRow('Booking Reference', report['booking_reference'] ?? 'N/A', font, fontBold, darkText, grayColor),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 9, color: grayColor, lineSpacing: 4),
          text: 'Note: Payment was processed through the APEX Housing escrow system. Funds are released to the landlord upon successful move-in confirmation or as per the agreed disbursement schedule.',
        ),
      ],
    );
  }

  static pw.Widget _payRow(String label, String value, pw.Font font, pw.Font fontBold, PdfColor darkText, PdfColor grayColor, {bool isHighlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9.5, color: grayColor)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: isHighlight ? 11 : 10,
                color: isHighlight ? PdfColor.fromHex('#27AE60') : darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SIGNATURES ────────────────────────────────────────────
  static pw.Widget _buildSignatures(
    Map<String, dynamic> report,
    pw.Font font,
    pw.Font fontBold,
    PdfColor darkText,
    PdfColor grayColor,
  ) {
    final landlord = report['landlord_name'] ?? 'N/A';
    final tenant = report['tenant_name'] ?? 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('SIGNATURES & ACKNOWLEDGMENT', style: pw.TextStyle(font: fontBold, fontSize: 11, color: darkText)),
        pw.SizedBox(height: 4),
        pw.Text(
          'By signing below, both parties acknowledge and agree to all terms stated in this report.',
          style: pw.TextStyle(font: font, fontSize: 9, color: grayColor),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('LANDLORD', style: pw.TextStyle(font: fontBold, fontSize: 9, color: grayColor)),
                  pw.SizedBox(height: 30),
                  pw.Container(width: 200, height: 1, color: grayColor),
                  pw.SizedBox(height: 4),
                  pw.Text(landlord, style: pw.TextStyle(font: fontBold, fontSize: 10, color: darkText)),
                  pw.Text('(Digital Signature via APEX)', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Date: ____________________', style: pw.TextStyle(font: font, fontSize: 9, color: grayColor)),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TENANT', style: pw.TextStyle(font: fontBold, fontSize: 9, color: grayColor)),
                  pw.SizedBox(height: 30),
                  pw.Container(width: 200, height: 1, color: grayColor),
                  pw.SizedBox(height: 4),
                  pw.Text(tenant, style: pw.TextStyle(font: fontBold, fontSize: 10, color: darkText)),
                  pw.Text('(Digital Signature via APEX)', style: pw.TextStyle(font: font, fontSize: 8, color: grayColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Date: ____________________', style: pw.TextStyle(font: font, fontSize: 9, color: grayColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── CLOSING CLAUSE ────────────────────────────────────────
  static pw.Widget _buildClosingClause(pw.Font font, pw.Font fontItalic, PdfColor darkText, PdfColor grayColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(font: font, fontSize: 10, color: darkText)),
        pw.SizedBox(height: 6),
        pw.Paragraph(
          style: pw.TextStyle(font: font, fontSize: 8.5, color: grayColor, lineSpacing: 4),
          text: 'This report is generated by APEX Housing and serves as an official record of the tenancy transaction. Both parties agree that this document, together with the APEX Housing Terms of Service, constitutes the binding agreement for the property described herein. Any disputes arising from this tenancy shall be resolved through the APEX Housing dispute resolution system or applicable Nigerian law. This report is digitally generated and does not require a physical stamp to be valid.',
        ),
      ],
    );
  }

  // ─── WITNESS BLOCK ─────────────────────────────────────────
  static pw.Widget _buildWitnessBlock(pw.Font font, pw.Font fontBold, PdfColor darkText, PdfColor grayColor) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: grayColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('WITNESS / PLATFORM ATTESTATION', style: pw.TextStyle(font: fontBold, fontSize: 9, color: darkText)),
          pw.SizedBox(height: 4),
          pw.Text(
            'This document was electronically generated and verified by the APEX Housing platform. The identities of both parties have been verified through the platform\'s KYC process.',
            style: pw.TextStyle(font: font, fontSize: 8, color: grayColor, lineSpacing: 4),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Platform Witness:', style: pw.TextStyle(font: fontBold, fontSize: 8, color: grayColor)),
                  pw.SizedBox(height: 20),
                  pw.Container(width: 140, height: 1, color: grayColor),
                  pw.SizedBox(height: 3),
                  pw.Text('APEX Housing Ltd.', style: pw.TextStyle(font: fontBold, fontSize: 9, color: darkText)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Authorized Signatory:', style: pw.TextStyle(font: fontBold, fontSize: 8, color: grayColor)),
                  pw.SizedBox(height: 20),
                  pw.Container(width: 140, height: 1, color: grayColor),
                  pw.SizedBox(height: 3),
                  pw.Text('________________________', style: pw.TextStyle(font: font, fontSize: 9, color: grayColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────
  static pw.Widget _buildFooter(Map<String, dynamic> report, PdfColor grayColor, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: grayColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('APEX Housing | ${report['id']}', style: pw.TextStyle(font: font, fontSize: 7, color: grayColor)),
          pw.Text('Page ${1}', style: pw.TextStyle(font: font, fontSize: 7, color: grayColor)),
          pw.Text('CONFIDENTIAL — For Authorized Parties Only', style: pw.TextStyle(font: font, fontSize: 7, color: grayColor)),
        ],
      ),
    );
  }

  // ─── CUSTOM TABLES ─────────────────────────────────────────
  static pw.Widget _buildTermsTable(List<List<String>> data, pw.Font font, pw.Font fontBold, PdfColor brandColor, PdfColor darkText) {
    return pw.Table(
      columnWidths: {0: const pw.FixedColumnWidth(140), 1: const pw.FlexColumnWidth()},
      border: pw.TableBorder.all(color: PdfColor.fromHex('#D5D8DC'), width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: brandColor),
          children: [
            _tableCell('Term', fontBold, PdfColor.fromHex('#FFFFFF'), isHeader: true),
            _tableCell('Details', fontBold, PdfColor.fromHex('#FFFFFF'), isHeader: true),
          ],
        ),
        ...data.map((row) => pw.TableRow(
          children: [
            _tableCell(row[0], font, PdfColor.fromHex('#7F8C8D')),
            _tableCell(row[1], fontBold, darkText),
          ],
        )),
      ],
    );
  }

  static pw.Widget _buildChecklistTable(List<Map<String, dynamic>> items, pw.Font font, pw.Font fontBold, PdfColor brandColor, PdfColor darkText, PdfColor successColor, PdfColor errorColor) {
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(), 1: const pw.FixedColumnWidth(80)},
      border: pw.TableBorder.all(color: PdfColor.fromHex('#D5D8DC'), width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: brandColor),
          children: [
            _tableCell('Checklist Item', fontBold, PdfColor.fromHex('#FFFFFF'), isHeader: true),
            _tableCell('Status', fontBold, PdfColor.fromHex('#FFFFFF'), isHeader: true),
          ],
        ),
        ...items.map((item) {
          final passed = item['status'] == 'passed';
          return pw.TableRow(
            children: [
              _tableCell(item['label'] as String, font, darkText),
              _tableCell(
                passed ? 'PASSED' : 'FAILED',
                fontBold,
                passed ? successColor : errorColor,
                bgColor: passed ? PdfColor.fromHex('#D5F5E3') : PdfColor.fromHex('#FADBD8'),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(String text, pw.Font font, PdfColor textColor, {bool isHeader = false, PdfColor? bgColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: bgColor,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: isHeader ? 9 : 9.5, color: textColor),
      ),
    );
  }
}

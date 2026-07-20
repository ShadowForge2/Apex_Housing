import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/report_pdf_service.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({super.key, required this.report});

  Map<String, dynamic> get _r {
    final r = Map<String, dynamic>.from(report);
    r['title'] ??= r['report_number'] ?? 'Report';
    r['property'] ??= r['property_title'] ?? 'Property';
    r['date'] ??= (r['created_at'] as String?)?.substring(0, 10) ?? '—';
    r['amount'] ??= '${r['currency'] ?? 'NGN'} ${r['total_amount'] ?? '0'}';
    r['status'] ??= r['booking_status'] ?? 'pending';
    r['id'] ??= r['report_number'] ?? '';
    r['landlord_name'] ??= 'N/A';
    r['tenant_name'] ??= 'N/A';
    r['landlord_id'] ??= '';
    r['tenant_id'] ??= '';
    r['items'] ??= [];
    r['payment_method'] ??= 'Escrow';
    r['booking_reference'] ??= r['booking_reference'] ?? '';
    r['service_fee'] ??= r['service_fee'] ?? '0';
    r['security_deposit'] ??= r['security_deposit'] ?? '0';
    r['check_in_date'] ??= '—';
    r['check_out_date'] ??= '—';
    r['agent_name'] ??= '';
    r['agent_license'] ??= '';
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final r = _r;
    final items = (r['items'] as List).cast<Map<String, dynamic>>();
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text(_r['id'] as String),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 22),
            onPressed: () => _downloadReport(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildPartiesSection(context),
            const SizedBox(height: 20),
            _buildSummary(context),
            const SizedBox(height: 20),
            _buildLandlordAffidavit(context),
            const SizedBox(height: 20),
            _buildPropertyDescription(context),
            const SizedBox(height: 20),
            _buildTenancyTerms(context),
            const SizedBox(height: 20),
            _buildChecklist(context, items),
            const SizedBox(height: 20),
            _buildTenantAffidavit(context),
            const SizedBox(height: 20),
            _buildPaymentDetails(context),
            const SizedBox(height: 20),
            _buildSignatures(context),
            const SizedBox(height: 20),
            _buildInfoSection(context),
            const SizedBox(height: 24),
            _buildDownloadButton(context),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context) async {
    showApexLoading(context, duration: const Duration(seconds: 1), label: 'Generating PDF...');
    await Future.delayed(const Duration(seconds: 1));
    try {
      final file = await ReportPdfService.generatePdf(report);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to: ${file.path}'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 16, color: AppColors.primary.withValues(alpha: 0.3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_reportIcon(), color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_r['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(_r['property'] as String, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _tag(_r['date'] as String),
              const SizedBox(width: 8),
              _tag(_r['amount'] as String),
              const SizedBox(width: 8),
              _tag(_r['status'].toString().toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
    );
  }

  Widget _buildPartiesSection(BuildContext context) {
    final tc = context.colors;
    final landlord = _r['landlord_name'] ?? 'N/A';
    final tenant = _r['tenant_name'] ?? 'N/A';
    final isNARole = tenant == 'N/A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PARTIES INVOLVED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.hint)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _partyCard(
                  context,
                  icon: Icons.person_rounded,
                  label: 'LANDLORD',
                  name: landlord,
                  id: _r['landlord_id'] ?? 'N/A',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _partyCard(
                  context,
                  icon: isNARole ? Icons.person_off_rounded : Icons.person_rounded,
                  label: 'TENANT',
                  name: tenant,
                  id: _r['tenant_id'] ?? 'N/A',
                  color: isNARole ? tc.hint : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partyCard(BuildContext context, {required IconData icon, required String label, required String name, required String id, required Color color}) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tc.text)),
          const SizedBox(height: 2),
          Text(id, style: TextStyle(fontSize: 10, color: tc.hint, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final tc = context.colors;
    return _sectionCard(
      context,
      title: 'SUMMARY',
      child: Text(_r['summary'] as String, style: TextStyle(fontSize: 14, color: tc.text, height: 1.6)),
    );
  }

  Widget _buildLandlordAffidavit(BuildContext context) {
    final tc = context.colors;
    final landlord = _r['landlord_name'] ?? 'N/A';
    final tenant = _r['tenant_name'] ?? 'N/A';
    final propType = _r['property_type'] ?? 'N/A';
    final propAddr = _r['property_address'] ?? 'N/A';
    final checkIn = _r['check_in_date'] ?? 'N/A';
    final checkOut = _r['check_out_date'] ?? 'N/A';

    return _sectionCard(
      context,
      title: "LANDLORD'S AFFIDAVIT",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'I, $landlord (Landlord ID: ${_r['landlord_id'] ?? 'N/A'}), do hereby solemnly swear and affirm that I am the lawful owner/authorized agent of the property described herein. I voluntarily rented out the $propType located at $propAddr through the APEX Housing platform to $tenant (Tenant ID: ${_r['tenant_id'] ?? 'N/A'}).',
            style: TextStyle(fontSize: 13, color: tc.text, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            'I further affirm that the tenant is expected to check in on $checkIn and the tenancy is scheduled to end on $checkOut. I vouch that the property is in a habitable condition and meets all safety and livability standards as required by law.',
            style: TextStyle(fontSize: 13, color: tc.text, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            'I accept responsibility for the maintenance of the property during the tenancy period and shall ensure timely resolution of any structural or systemic issues that may arise.',
            style: TextStyle(fontSize: 13, color: tc.text, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyDescription(BuildContext context) {
    final tc = context.colors;
    return _sectionCard(
      context,
      title: 'PROPERTY DESCRIPTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Type', _r['property_type'] ?? 'N/A', tc),
          _detailRow('Address', _r['property_address'] ?? 'N/A', tc),
          const SizedBox(height: 10),
          Text(_r['property_description'] ?? 'N/A', style: TextStyle(fontSize: 13, color: tc.text, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildTenancyTerms(BuildContext context) {
    final tc = context.colors;
    return _sectionCard(
      context,
      title: 'TENANCY TERMS',
      child: Column(
        children: [
          _detailRow('Move-In Date', _r['check_in_date'] ?? 'N/A', tc),
          _detailRow('Move-Out Date', _r['check_out_date'] ?? 'N/A', tc),
          _detailRow('Total Amount', _r['amount_paid'] ?? 'N/A', tc, isHighlight: true),
          _detailRow('Payment Method', _r['payment_method'] ?? 'N/A', tc),
          _detailRow('Booking Reference', _r['booking_reference'] ?? 'N/A', tc),
        ],
      ),
    );
  }

  Widget _buildChecklist(BuildContext context, List<Map<String, dynamic>> items) {
    final tc = context.colors;
    final passedCount = items.where((i) => i['status'] == 'passed').length;

    return _sectionCard(
      context,
      title: 'INSPECTION CHECKLIST',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (passedCount == items.length ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '$passedCount/${items.length} Passed',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: passedCount == items.length ? AppColors.success : AppColors.error),
        ),
      ),
      child: Column(
        children: items.map((item) {
          final passed = item['status'] == 'passed';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (passed ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    passed ? Icons.check_rounded : Icons.close_rounded,
                    size: 16,
                    color: passed ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item['label'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: tc.text)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (passed ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    passed ? 'Passed' : 'Failed',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: passed ? AppColors.success : AppColors.error),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTenantAffidavit(BuildContext context) {
    final tc = context.colors;
    final tenant = _r['tenant_name'] ?? 'N/A';
    final propType = _r['property_type'] ?? 'N/A';
    final propAddr = _r['property_address'] ?? 'N/A';
    final checkIn = _r['check_in_date'] ?? 'N/A';
    final checkOut = _r['check_out_date'] ?? 'N/A';
    final amount = _r['amount_paid'] ?? 'N/A';

    return _sectionCard(
      context,
      title: "TENANT'S AFFIDAVIT",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'I, $tenant (Tenant ID: ${_r['tenant_id'] ?? 'N/A'}), do hereby solemnly swear and affirm that I have inspected the $propType located at $propAddr and find it satisfactory for my occupancy.',
            style: TextStyle(fontSize: 13, color: tc.text, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            'I vouch that I shall occupy the property from $checkIn to $checkOut and shall pay the total sum of $amount as agreed. I accept the property in its current condition and acknowledge receipt of all applicable keys and access credentials.',
            style: TextStyle(fontSize: 13, color: tc.text, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            'I further affirm that I shall use the property solely for residential purposes, maintain it in good condition, and comply with all terms of the tenancy agreement as facilitated through the APEX Housing platform.',
            style: TextStyle(fontSize: 13, color: tc.text, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(BuildContext context) {
    final tc = context.colors;
    return _sectionCard(
      context,
      title: 'PAYMENT DETAILS',
      child: Column(
        children: [
          _detailRow('Amount Paid', _r['amount_paid'] ?? 'N/A', tc, isHighlight: true),
          _detailRow('Payment Date', _r['payment_date'] ?? 'N/A', tc),
          _detailRow('Disbursement Date', _r['disbursement_date'] ?? 'N/A', tc),
          _detailRow('Payment Method', _r['payment_method'] ?? 'N/A', tc),
          _detailRow('Booking Reference', _r['booking_reference'] ?? 'N/A', tc),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Payment was processed through the APEX Housing escrow system. Funds are released to the landlord upon successful move-in confirmation or as per the agreed disbursement schedule.',
              style: TextStyle(fontSize: 11, color: AppColors.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatures(BuildContext context) {
    final tc = context.colors;
    final landlord = _r['landlord_name'] ?? 'N/A';
    final tenant = _r['tenant_name'] ?? 'N/A';

    return _sectionCard(
      context,
      title: 'SIGNATURES & ACKNOWLEDGMENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By signing below, both parties acknowledge and agree to all terms stated in this report.',
            style: TextStyle(fontSize: 12, color: tc.hint),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _signatureBlock(landlord, 'Landlord', tc),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _signatureBlock(tenant, 'Tenant', tc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signatureBlock(String name, String role, ThemeColors tc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tc.hint)),
        const SizedBox(height: 24),
        Container(width: double.infinity, height: 1, color: tc.border),
        const SizedBox(height: 6),
        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tc.text)),
        Text('Digital Signature via APEX', style: TextStyle(fontSize: 10, color: tc.hint)),
        const SizedBox(height: 4),
        Text('Date: ____________________', style: TextStyle(fontSize: 11, color: tc.hint)),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final tc = context.colors;
    return _sectionCard(
      context,
      title: 'REPORT INFORMATION',
      child: Column(
        children: [
          _detailRow('Report ID', _r['id'] as String, tc),
          _detailRow('Type', (_r['type'] as String).toUpperCase(), tc),
          _detailRow('Date Generated', _r['date'] as String, tc),
          _detailRow('Property', _r['property'] as String, tc),
          _detailRow('Amount', _r['amount'] as String, tc, isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _downloadReport(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [BoxShadow(blurRadius: 12, color: AppColors.primary.withValues(alpha: 0.3))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Download Report as PDF', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── SHARED SECTION CARD ───────────────────────────────────
  Widget _sectionCard(BuildContext context, {required String title, required Widget child, Widget? trailing}) {
    final tc = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tc.hint)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeColors tc, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: tc.hint)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHighlight ? AppColors.success : tc.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _reportIcon() {
    switch (_r['type']) {
      case 'inspection': return Icons.search_rounded;
      case 'move-in': return Icons.login_rounded;
      case 'maintenance': return Icons.build_rounded;
      case 'listing': return Icons.home_work_rounded;
      case 'earnings': return Icons.payments_rounded;
      default: return Icons.assessment_rounded;
    }
  }
}

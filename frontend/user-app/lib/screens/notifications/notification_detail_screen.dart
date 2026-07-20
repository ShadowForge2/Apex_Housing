import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../services/report_service.dart';
import '../../widgets/loading_overlay.dart';
import 'report_detail_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  final String type;
  final String title;
  final String message;
  final String time;
  final bool hasReport;
  final String? reportId;

  const NotificationDetailScreen({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    this.hasReport = false,
    this.reportId,
  });

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  ReportModel? _report;
  bool _isLoadingReport = false;

  @override
  void initState() {
    super.initState();
    if (widget.hasReport && widget.reportId != null) _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoadingReport = true);
    try {
      final report = await ReportService().getReport(widget.reportId!);
      if (mounted) setState(() => _report = report);
    } catch (e) {
      debugPrint('Failed to load report: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Notification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _typeColor(tc).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(_typeIcon(), size: 30, color: _typeColor(tc)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tc.text),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor(tc).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  _typeLabel(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _typeColor(tc)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(widget.time, style: TextStyle(fontSize: 13, color: tc.hint)),
            ),
            const SizedBox(height: 24),
            Container(
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
                  Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.hint)),
                  const SizedBox(height: 12),
                  Text(widget.message, style: TextStyle(fontSize: 15, color: tc.text, height: 1.6)),
                ],
              ),
            ),
            if (widget.hasReport && widget.reportId != null) ...[
              const SizedBox(height: 20),
              _buildReportCard(context),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context) {
    final tc = context.colors;
    if (_isLoadingReport) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(color: AppColors.primary),
      ));
    }
    if (_report == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showApexLoadingThen(
          context,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailScreen(report: _report!.toMap()))),
          duration: const Duration(milliseconds: 800),
        );
      },
      child: Container(
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.assessment_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_report!.reportNumber ?? 'Report', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(_report!.propertyTitle ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _reportTag(_report!.createdAt != null ? _report!.createdAt!.substring(0, 10) : ''),
                        const SizedBox(width: 8),
                        _reportTag(_report!.totalAmount ?? ''),
                      ],
                    ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('View & Download Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
    );
  }

  Color _typeColor(ThemeColors tc) {
    switch (widget.type) {
      case 'booking': return AppColors.primary;
      case 'payment': return AppColors.success;
      case 'message': return AppColors.primaryLight;
      case 'maintenance': return AppColors.warning;
      case 'review': return AppColors.rating;
      case 'system': return AppColors.success;
      default: return tc.subtitle;
    }
  }

  IconData _typeIcon() {
    switch (widget.type) {
      case 'booking': return Icons.calendar_today_rounded;
      case 'payment': return Icons.payments_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      case 'maintenance': return Icons.build_rounded;
      case 'review': return Icons.star_rounded;
      case 'system': return Icons.shield_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _typeLabel() {
    switch (widget.type) {
      case 'booking': return 'Booking';
      case 'payment': return 'Payment';
      case 'message': return 'Message';
      case 'maintenance': return 'Maintenance';
      case 'review': return 'Review';
      case 'system': return 'System';
      default: return 'Notification';
    }
  }
}

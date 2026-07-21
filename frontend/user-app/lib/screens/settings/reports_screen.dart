import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../services/report_service.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/loading_overlay.dart';
import '../notifications/report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();
  List<ReportModel> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final reports = await _reportService.listReports();
      if (mounted) setState(() { _reports = reports; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('My Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: ApexLoading())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text('Unable to connect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.subtitle)),
                      const SizedBox(height: 4),
                      const Text('Check your connection and try again', style: TextStyle(fontSize: 13, color: AppColors.hint)),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _loadReports, child: const Text('Retry')),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(color: tc.surface, shape: BoxShape.circle),
                            child: Icon(Icons.assessment_outlined, size: 36, color: tc.hint),
                          ),
                          const SizedBox(height: 20),
                          Text('No reports yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: tc.text)),
                          const SizedBox(height: 6),
                          Text('Reports will appear here after inspections', style: TextStyle(fontSize: 14, color: tc.subtitle)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _ReportTicket(
                          report: _reports[i],
                          onTap: () {
                            showApexLoadingThen(
                              context,
                              () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ReportDetailScreen(report: _reports[i].toMap()),
                              )),
                              duration: const Duration(milliseconds: 800),
                            );
                          },
                          onDownload: () => _downloadReport(_reports[i]),
                        ),
                      ),
                    ),
    );
  }

  Future<void> _downloadReport(ReportModel report) async {
    showApexLoading(context, duration: const Duration(seconds: 1), label: 'Downloading report...');
    try {
      final html = await _reportService.downloadReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report downloaded'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _ReportTicket extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _ReportTicket({required this.report, required this.onTap, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assessment_rounded, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.reportNumber ?? report.propertyTitle ?? 'Report',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tc.text)),
                      const SizedBox(height: 2),
                      Text(report.propertyTitle ?? 'Property Report',
                          style: TextStyle(fontSize: 12, color: tc.subtitle), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: tc.hint),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _chip(report.createdAt?.substring(0, 10) ?? '—', tc),
                const SizedBox(width: 6),
                _chip('${report.currency ?? 'NGN'} ${report.totalAmount ?? '0'}', tc),
                const SizedBox(width: 6),
                if (report.isFinalized)
                  _chip('Finalized', tc)
                else
                  _chip(report.bookingStatus ?? 'Pending', tc),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDownload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Download', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tc.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tc.subtitle)),
    );
  }
}

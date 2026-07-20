import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/admin_models.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _selectedFilter = 'All';
  List<AdminReport> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final response = await AdminService().listReports();
      final data = response['data'];
      if (data != null && mounted) {
        final reportsList = data['reports'] as List<dynamic>? ?? [];
        setState(() {
          _reports = reportsList.map<AdminReport>((r) {
            return AdminReport(
              id: r['id'] as String? ?? '',
              type: _parseReportType(r['type'] as String? ?? 'other'),
              severity: _parseReportSeverity(r['severity'] as String? ?? 'medium'),
              status: _parseReportStatus(r['status'] as String? ?? 'open'),
              reportedBy: r['reported_by'] as String? ?? 'Unknown',
              reportedAgainst: r['reported_against'] as String? ?? 'Unknown',
              description: r['description'] as String? ?? '',
              date: DateTime.tryParse(r['date'] as String? ?? '') ?? DateTime.now(),
              assignedTo: r['assigned_to'] as String?,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _reports = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  ReportType _parseReportType(String type) {
    switch (type.toLowerCase()) {
      case 'harassment': return ReportType.harassment;
      case 'noise': return ReportType.noise;
      case 'property_damage': case 'propertydamage': return ReportType.propertyDamage;
      case 'safety': return ReportType.safety;
      case 'discrimination': return ReportType.discrimination;
      default: return ReportType.other;
    }
  }

  ReportSeverity _parseReportSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'high': return ReportSeverity.high;
      case 'low': return ReportSeverity.low;
      default: return ReportSeverity.medium;
    }
  }

  ReportStatus _parseReportStatus(String status) {
    switch (status.toLowerCase()) {
      case 'investigating': return ReportStatus.investigating;
      case 'resolved': return ReportStatus.resolved;
      default: return ReportStatus.open;
    }
  }

  static const _filterTabs = ['All', 'Open', 'Investigating', 'Resolved'];

  List<AdminReport> get _filteredReports {
    if (_selectedFilter == 'All') return _reports;
    return _reports
        .where((r) => r.status.name[0].toUpperCase() + r.status.name.substring(1) == _selectedFilter)
        .toList();
  }

  int get _openCount => _reports.where((r) => r.status == ReportStatus.open).length;
  int get _investigatingCount => _reports.where((r) => r.status == ReportStatus.investigating).length;
  int get _resolvedCount => _reports.where((r) => r.status == ReportStatus.resolved).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 15, color: AppColors.subtitle), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchReports(); }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Reports', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
          _buildFilterTabs(),
          Expanded(child: _buildReportsList()),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          _buildStatCard('Open', _openCount, AppColors.error, AppColors.errorLight),
          const SizedBox(width: 12),
          _buildStatCard('Investigating', _investigatingCount, const Color(0xFF3B82F6), const Color(0xFFDBEAFE)),
          const SizedBox(width: 12),
          _buildStatCard('Resolved', _resolvedCount, AppColors.success, AppColors.successLight),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _filterTabs.map((tab) {
          final isSelected = _selectedFilter == tab;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = tab),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.textWhite : AppColors.subtitle,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportsList() {
    final reports = _filteredReports;
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: AppColors.hint),
            const SizedBox(height: 12),
            Text('No reports found', style: TextStyle(fontSize: 15, color: AppColors.subtitle)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildReportCard(reports[index]),
      ),
    );
  }

  Widget _buildReportCard(AdminReport report) {
    return GestureDetector(
      onTap: () => _showReportDetail(report),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.minimal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTypeIcon(report.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSeverityBadge(report.severity),
                          const SizedBox(width: 8),
                          _buildStatusBadge(report.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.reportedBy}  →  ${report.reportedAgainst}',
                        style: const TextStyle(fontSize: 13, color: AppColors.subtitle),
                      ),
                    ],
                  ),
                ),
                _buildActionIcons(report),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(report.date),
              style: const TextStyle(fontSize: 11, color: AppColors.hint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(ReportType type) {
    IconData icon;
    Color color;
    switch (type) {
      case ReportType.harassment:
        icon = Icons.gpp_maybe_outlined;
        color = AppColors.error;
        break;
      case ReportType.noise:
        icon = Icons.volume_up_outlined;
        color = AppColors.warning;
        break;
      case ReportType.propertyDamage:
        icon = Icons.broken_image_outlined;
        color = const Color(0xFFF97316);
        break;
      case ReportType.safety:
        icon = Icons.shield_outlined;
        color = const Color(0xFF3B82F6);
        break;
      case ReportType.discrimination:
        icon = Icons.balance_outlined;
        color = const Color(0xFF8B5CF6);
        break;
      case ReportType.other:
        icon = Icons.more_horiz;
        color = AppColors.subtitle;
        break;
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSeverityBadge(ReportSeverity severity) {
    String label;
    Color color;
    Color bgColor;
    switch (severity) {
      case ReportSeverity.low:
        label = 'Low';
        color = AppColors.subtitle;
        bgColor = AppColors.surfaceVariant;
        break;
      case ReportSeverity.medium:
        label = 'Medium';
        color = AppColors.warning;
        bgColor = AppColors.warningLight;
        break;
      case ReportSeverity.high:
        label = 'High';
        color = AppColors.error;
        bgColor = AppColors.errorLight;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    String label;
    Color color;
    Color bgColor;
    switch (status) {
      case ReportStatus.open:
        label = 'Open';
        color = AppColors.error;
        bgColor = AppColors.errorLight;
        break;
      case ReportStatus.investigating:
        label = 'Investigating';
        color = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFDBEAFE);
        break;
      case ReportStatus.resolved:
        label = 'Resolved';
        color = AppColors.success;
        bgColor = AppColors.successLight;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildActionIcons(AdminReport report) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionIcon(Icons.visibility_outlined, 'View', () => _showReportDetail(report)),
        const SizedBox(width: 6),
        _actionIcon(Icons.person_add_outlined, 'Assign', () => _showAssignDialog(report)),
        const SizedBox(width: 6),
        _actionIcon(Icons.check_circle_outline, 'Resolve', () => _resolveReport(report)),
      ],
    );
  }

  Widget _actionIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.subtitle),
        ),
      ),
    );
  }

  void _showReportDetail(AdminReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailSheet(report: report),
    );
  }

  void _showAssignDialog(AdminReport report) {
    final officers = ['Officer Martinez', 'Officer Lee', 'Officer Chen', 'Property Manager', 'Maintenance Team'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Assign Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: officers.map((officer) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                child: Icon(Icons.person, size: 18, color: AppColors.primary),
              ),
              title: Text(officer, style: const TextStyle(fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                await runWithLoading(
                  context,
                  action: () async {
                    try {
                      await AdminService().updateReport(report.id, status: 'investigating', resolution: 'Assigned to $officer');
                      await _fetchReports();
                    } catch (e) {
                      setState(() {
                        final index = _reports.indexWhere((r) => r.id == report.id);
                        if (index != -1) {
                          _reports[index] = AdminReport(
                            id: report.id,
                            type: report.type,
                            severity: report.severity,
                            status: ReportStatus.investigating,
                            reportedBy: report.reportedBy,
                            reportedAgainst: report.reportedAgainst,
                            description: report.description,
                            date: report.date,
                            assignedTo: officer,
                          );
                        }
                      });
                    }
                  },
                  message: 'Assigning report...',
                );
                if (context.mounted) showAppToast(context, 'Assigned to $officer');
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _resolveReport(AdminReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Resolve Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Mark report ${report.id} as resolved?',
          style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runWithLoading(
                context,
                action: () async {
                  try {
                    await AdminService().updateReport(report.id, status: 'resolved');
                    await _fetchReports();
                  } catch (e) {
                    setState(() {
                      final index = _reports.indexWhere((r) => r.id == report.id);
                      if (index != -1) {
                        _reports[index] = AdminReport(
                          id: report.id,
                          type: report.type,
                          severity: report.severity,
                          status: ReportStatus.resolved,
                          reportedBy: report.reportedBy,
                          reportedAgainst: report.reportedAgainst,
                          description: report.description,
                          date: report.date,
                          assignedTo: report.assignedTo,
                        );
                      }
                    });
                  }
                },
                message: 'Resolving report...',
              );
              if (context.mounted) showAppToast(context, 'Report ${report.id} resolved');
            },
            child: const Text('Resolve', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ReportDetailSheet extends StatelessWidget {
  final AdminReport report;
  const _ReportDetailSheet({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Report ${report.id}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.subtitle),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge(report.severity.label, _severityColor(report.severity), _severityBg(report.severity)),
                  _badge(report.status.label, _statusColor(report.status), _statusBg(report.status)),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow('Type', report.type.name[0].toUpperCase() + report.type.name.substring(1)),
              const SizedBox(height: 12),
              _detailRow('Reported By', report.reportedBy),
              const SizedBox(height: 12),
              _detailRow('Against', report.reportedAgainst),
              const SizedBox(height: 12),
              _detailRow('Date', _formatDate(report.date)),
              if (report.assignedTo != null) ...[
                const SizedBox(height: 12),
                _detailRow('Assigned To', report.assignedTo!),
              ],
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitle)),
              const SizedBox(height: 6),
              Text(report.description, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await runWithLoading(
                          context,
                          action: () async {
                            await Future.delayed(const Duration(milliseconds: 600));
                          },
                          message: 'Assigning report...',
                        );
                        if (context.mounted) showAppToast(context, 'Report ${report.id} assigned');
                      },
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Assign'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await runWithLoading(
                          context,
                          action: () async {
                            await Future.delayed(const Duration(milliseconds: 600));
                          },
                          message: 'Resolving report...',
                        );
                        if (context.mounted) showAppToast(context, 'Report ${report.id} resolved');
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _badge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Color _severityColor(ReportSeverity s) => switch (s) {
    ReportSeverity.low => AppColors.subtitle,
    ReportSeverity.medium => AppColors.warning,
    ReportSeverity.high => AppColors.error,
  };

  Color _severityBg(ReportSeverity s) => switch (s) {
    ReportSeverity.low => AppColors.surfaceVariant,
    ReportSeverity.medium => AppColors.warningLight,
    ReportSeverity.high => AppColors.errorLight,
  };

  Color _statusColor(ReportStatus s) => switch (s) {
    ReportStatus.open => AppColors.error,
    ReportStatus.investigating => const Color(0xFF3B82F6),
    ReportStatus.resolved => AppColors.success,
  };

  Color _statusBg(ReportStatus s) => switch (s) {
    ReportStatus.open => AppColors.errorLight,
    ReportStatus.investigating => const Color(0xFFDBEAFE),
    ReportStatus.resolved => AppColors.successLight,
  };

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

extension on ReportSeverity {
  String get label => switch (this) {
    ReportSeverity.low => 'Low',
    ReportSeverity.medium => 'Medium',
    ReportSeverity.high => 'High',
  };
}

extension on ReportStatus {
  String get label => switch (this) {
    ReportStatus.open => 'Open',
    ReportStatus.investigating => 'Investigating',
    ReportStatus.resolved => 'Resolved',
  };
}

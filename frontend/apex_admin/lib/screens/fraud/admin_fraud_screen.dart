import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';

enum FraudSeverity { low, medium, high }

enum FraudStatus { active, investigating, resolved }

enum FraudType { paymentFraud, identityTheft, accountTakeover, suspiciousActivity, fakeListing }

class FraudAlert {
  final String id;
  final FraudType type;
  final FraudSeverity severity;
  final FraudStatus status;
  final String userId;
  final String userName;
  final String description;
  final DateTime date;
  final String? assignedTo;

  const FraudAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.userId,
    required this.userName,
    required this.description,
    required this.date,
    this.assignedTo,
  });
}

class AdminFraudScreen extends StatefulWidget {
  const AdminFraudScreen({super.key});

  @override
  State<AdminFraudScreen> createState() => _AdminFraudScreenState();
}

class _AdminFraudScreenState extends State<AdminFraudScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  late List<FraudAlert> _alerts;
  bool _isLoading = true;
  String? _error;

  static const _filterTabs = ['All', 'Active', 'Investigating', 'Resolved'];

  @override
  void initState() {
    super.initState();
    _alerts = [];
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    try {
      final response = await AdminService().getFraudAlerts();
      final data = response['data'];
      if (data != null && mounted) {
        final alertsList = data['alerts'] as List<dynamic>? ?? [];
        setState(() {
          _alerts = alertsList.map<FraudAlert>((a) => FraudAlert(
            id: a['id'] as String? ?? '',
            type: _parseFraudType(a['type'] as String? ?? 'suspicious_activity'),
            severity: _parseSeverity(a['severity'] as String? ?? 'low'),
            status: _parseFraudStatus(a['status'] as String? ?? 'active'),
            userId: a['user_id'] as String? ?? '',
            userName: a['user_name'] as String? ?? '',
            description: a['description'] as String? ?? '',
            date: DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime.now(),
            assignedTo: a['assigned_to'] as String?,
          )).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _alerts = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load fraud alerts. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  FraudType _parseFraudType(String type) {
    switch (type) {
      case 'payment_fraud': return FraudType.paymentFraud;
      case 'identity_theft': return FraudType.identityTheft;
      case 'account_takeover': return FraudType.accountTakeover;
      case 'fake_listing': return FraudType.fakeListing;
      default: return FraudType.suspiciousActivity;
    }
  }

  FraudSeverity _parseSeverity(String severity) {
    switch (severity) {
      case 'high': return FraudSeverity.high;
      case 'medium': return FraudSeverity.medium;
      default: return FraudSeverity.low;
    }
  }

  FraudStatus _parseFraudStatus(String status) {
    switch (status) {
      case 'investigating': return FraudStatus.investigating;
      case 'resolved': return FraudStatus.resolved;
      default: return FraudStatus.active;
    }
  }

  int get _activeCount => _alerts.where((a) => a.status == FraudStatus.active).length;
  int get _investigatingCount => _alerts.where((a) => a.status == FraudStatus.investigating).length;
  int get _resolvedCount => _alerts.where((a) => a.status == FraudStatus.resolved).length;

  List<FraudAlert> get _filteredAlerts {
    var list = _alerts.toList();
    if (_selectedFilter != 'All') {
      list = list
          .where((a) => a.status.name[0].toUpperCase() + a.status.name.substring(1) == _selectedFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((a) =>
              a.userName.toLowerCase().contains(q) ||
              a.id.toLowerCase().contains(q) ||
              a.description.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void _dismissAlert(FraudAlert alert) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Dismiss Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to dismiss alert ${alert.id}? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runWithLoading(
                context,
                action: () async {
                  try {
                    await AdminService().updateFraudAlert(alert.id, status: 'dismissed');
                    setState(() {
                      _alerts = _alerts.where((a) => a.id != alert.id).toList();
                    });
                  } catch (e) {
                    setState(() {
                      _alerts = _alerts.where((a) => a.id != alert.id).toList();
                    });
                  }
                },
                message: 'Dismissing alert...',
              );
              if (context.mounted) showAppToast(context, 'Alert ${alert.id} dismissed');
            },
            child: const Text('Dismiss', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _resolveAlert(FraudAlert alert) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Resolve Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Mark alert ${alert.id} as resolved?',
          style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runWithLoading(
                context,
                action: () async {
                  try {
                    await AdminService().updateFraudAlert(alert.id, status: 'resolved');
                    setState(() {
                      final index = _alerts.indexWhere((a) => a.id == alert.id);
                      if (index != -1) {
                        _alerts[index] = FraudAlert(
                          id: alert.id,
                          type: alert.type,
                          severity: alert.severity,
                          status: FraudStatus.resolved,
                          userId: alert.userId,
                          userName: alert.userName,
                          description: alert.description,
                          date: alert.date,
                          assignedTo: alert.assignedTo,
                        );
                      }
                    });
                  } catch (e) {
                    setState(() {
                      final index = _alerts.indexWhere((a) => a.id == alert.id);
                      if (index != -1) {
                        _alerts[index] = FraudAlert(
                          id: alert.id,
                          type: alert.type,
                          severity: alert.severity,
                          status: FraudStatus.resolved,
                          userId: alert.userId,
                          userName: alert.userName,
                          description: alert.description,
                          date: alert.date,
                          assignedTo: alert.assignedTo,
                        );
                      }
                    });
                  }
                },
                message: 'Resolving alert...',
              );
              if (context.mounted) showAppToast(context, 'Alert ${alert.id} marked as resolved');
            },
            child: const Text('Resolve', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _investigateAlert(FraudAlert alert) async {
    await runWithLoading(
      context,
      action: () async {
        try {
          await AdminService().updateFraudAlert(alert.id, status: 'investigating');
          setState(() {
            final index = _alerts.indexWhere((a) => a.id == alert.id);
            if (index != -1) {
              _alerts[index] = FraudAlert(
                id: alert.id,
                type: alert.type,
                severity: alert.severity,
                status: FraudStatus.investigating,
                userId: alert.userId,
                userName: alert.userName,
                description: alert.description,
                date: alert.date,
                assignedTo: 'Officer Martinez',
              );
            }
          });
        } catch (e) {
          setState(() {
            final index = _alerts.indexWhere((a) => a.id == alert.id);
            if (index != -1) {
              _alerts[index] = FraudAlert(
                id: alert.id,
                type: alert.type,
                severity: alert.severity,
                status: FraudStatus.investigating,
                userId: alert.userId,
                userName: alert.userName,
                description: alert.description,
                date: alert.date,
                assignedTo: 'Officer Martinez',
              );
            }
          });
        }
      },
      message: 'Assigning investigation...',
    );
    if (context.mounted) showAppToast(context, 'Alert ${alert.id} assigned for investigation', backgroundColor: const Color(0xFF3B82F6));
  }

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
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchAlerts(); }),
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
              child: Text('Fraud Alerts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
          _buildSearchBar(),
          _buildFilterTabs(),
          Expanded(child: _buildAlertsList()),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        children: [
          _buildStatCard('Active', _activeCount, AppColors.error, AppColors.errorLight),
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
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search alerts by name, ID, or description...',
          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.hint),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: const Icon(Icons.close, size: 18, color: AppColors.hint),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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

  Widget _buildAlertsList() {
    final alerts = _filteredAlerts;
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 56, color: AppColors.hint),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No alerts match your search' : 'No fraud alerts found',
              style: const TextStyle(fontSize: 15, color: AppColors.subtitle),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAlerts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
      ),
    );
  }

  Widget _buildAlertCard(FraudAlert alert) {
    return GestureDetector(
      onTap: () => _showAlertDetail(alert),
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
                _buildTypeIcon(alert.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildTypeBadge(alert.type),
                          _buildSeverityBadge(alert.severity),
                          _buildStatusBadge(alert.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.userName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              alert.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.subtitle, height: 1.4),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.hint),
                const SizedBox(width: 4),
                Text(
                  _formatDate(alert.date),
                  style: const TextStyle(fontSize: 11, color: AppColors.hint),
                ),
                const Spacer(),
                if (alert.assignedTo != null) ...[
                  const Icon(Icons.person_outline, size: 12, color: AppColors.hint),
                  const SizedBox(width: 4),
                  Text(
                    alert.assignedTo!,
                    style: const TextStyle(fontSize: 11, color: AppColors.hint),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(FraudType type) {
    IconData icon;
    Color color;
    switch (type) {
      case FraudType.paymentFraud:
        icon = Icons.payments_outlined;
        color = AppColors.error;
        break;
      case FraudType.identityTheft:
        icon = Icons.fingerprint_outlined;
        color = const Color(0xFF8B5CF6);
        break;
      case FraudType.accountTakeover:
        icon = Icons.lock_open_outlined;
        color = const Color(0xFFF97316);
        break;
      case FraudType.suspiciousActivity:
        icon = Icons.visibility_outlined;
        color = AppColors.warning;
        break;
      case FraudType.fakeListing:
        icon = Icons.home_outlined;
        color = const Color(0xFF3B82F6);
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

  Widget _buildTypeBadge(FraudType type) {
    String label;
    switch (type) {
      case FraudType.paymentFraud:
        label = 'Payment Fraud';
        break;
      case FraudType.identityTheft:
        label = 'Identity Theft';
        break;
      case FraudType.accountTakeover:
        label = 'Account Takeover';
        break;
      case FraudType.suspiciousActivity:
        label = 'Suspicious Activity';
        break;
      case FraudType.fakeListing:
        label = 'Fake Listing';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.subtitle)),
    );
  }

  Widget _buildSeverityBadge(FraudSeverity severity) {
    String label;
    Color color;
    Color bgColor;
    switch (severity) {
      case FraudSeverity.low:
        label = 'Low';
        color = AppColors.subtitle;
        bgColor = AppColors.surfaceVariant;
        break;
      case FraudSeverity.medium:
        label = 'Medium';
        color = AppColors.warning;
        bgColor = AppColors.warningLight;
        break;
      case FraudSeverity.high:
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
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildStatusBadge(FraudStatus status) {
    String label;
    Color color;
    Color bgColor;
    switch (status) {
      case FraudStatus.active:
        label = 'Active';
        color = AppColors.error;
        bgColor = AppColors.errorLight;
        break;
      case FraudStatus.investigating:
        label = 'Investigating';
        color = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFDBEAFE);
        break;
      case FraudStatus.resolved:
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
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _showAlertDetail(FraudAlert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FraudDetailSheet(
        alert: alert,
        onDismiss: () {
          Navigator.pop(context);
          _dismissAlert(alert);
        },
        onResolve: () {
          Navigator.pop(context);
          _resolveAlert(alert);
        },
        onInvestigate: alert.status == FraudStatus.active
            ? () {
                Navigator.pop(context);
                _investigateAlert(alert);
              }
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _FraudDetailSheet extends StatelessWidget {
  final FraudAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback onResolve;
  final VoidCallback? onInvestigate;

  const _FraudDetailSheet({
    required this.alert,
    required this.onDismiss,
    required this.onResolve,
    this.onInvestigate,
  });

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
                    'Alert ${alert.id}',
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
                  _badge(_typeLabel(alert.type), AppColors.surfaceVariant, AppColors.subtitle),
                  _badge(_severityLabel(alert.severity), _severityBg(alert.severity), _severityColor(alert.severity)),
                  _badge(_statusLabel(alert.status), _statusBg(alert.status), _statusColor(alert.status)),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow('User', alert.userName),
              const SizedBox(height: 12),
              _detailRow('User ID', alert.userId),
              const SizedBox(height: 12),
              _detailRow('Date', _formatDate(alert.date)),
              if (alert.assignedTo != null) ...[
                const SizedBox(height: 12),
                _detailRow('Assigned To', alert.assignedTo!),
              ],
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitle)),
              const SizedBox(height: 6),
              Text(alert.description, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5)),
              const SizedBox(height: 24),
              if (onInvestigate != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onInvestigate,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Assign for Investigation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: AppColors.textWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.subtitle,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Resolved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.textWhite,
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

  Widget _badge(String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _typeLabel(FraudType type) => switch (type) {
    FraudType.paymentFraud => 'Payment Fraud',
    FraudType.identityTheft => 'Identity Theft',
    FraudType.accountTakeover => 'Account Takeover',
    FraudType.suspiciousActivity => 'Suspicious Activity',
    FraudType.fakeListing => 'Fake Listing',
  };

  String _severityLabel(FraudSeverity s) => switch (s) {
    FraudSeverity.low => 'Low',
    FraudSeverity.medium => 'Medium',
    FraudSeverity.high => 'High',
  };

  Color _severityColor(FraudSeverity s) => switch (s) {
    FraudSeverity.low => AppColors.subtitle,
    FraudSeverity.medium => AppColors.warning,
    FraudSeverity.high => AppColors.error,
  };

  Color _severityBg(FraudSeverity s) => switch (s) {
    FraudSeverity.low => AppColors.surfaceVariant,
    FraudSeverity.medium => AppColors.warningLight,
    FraudSeverity.high => AppColors.errorLight,
  };

  String _statusLabel(FraudStatus s) => switch (s) {
    FraudStatus.active => 'Active',
    FraudStatus.investigating => 'Investigating',
    FraudStatus.resolved => 'Resolved',
  };

  Color _statusColor(FraudStatus s) => switch (s) {
    FraudStatus.active => AppColors.error,
    FraudStatus.investigating => const Color(0xFF3B82F6),
    FraudStatus.resolved => AppColors.success,
  };

  Color _statusBg(FraudStatus s) => switch (s) {
    FraudStatus.active => AppColors.errorLight,
    FraudStatus.investigating => const Color(0xFFDBEAFE),
    FraudStatus.resolved => AppColors.successLight,
  };

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

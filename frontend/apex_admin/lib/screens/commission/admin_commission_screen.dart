import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_commission_service.dart';


enum CommissionRole { platform, agent, landlord }
enum CommissionStatus { active, inactive }

class CommissionRule {
  final String id;
  final CommissionRole role;
  final double percentage;
  final String description;
  final CommissionStatus status;
  const CommissionRule({
    required this.id,
    required this.role,
    required this.percentage,
    required this.description,
    required this.status,
  });
}

class CommissionLog {
  final String id;
  final String bookingRef;
  final CommissionRole role;
  final double amount;
  final double percentage;
  final bool isPaid;
  final DateTime date;
  const CommissionLog({
    required this.id,
    required this.bookingRef,
    required this.role,
    required this.amount,
    required this.percentage,
    required this.isPaid,
    required this.date,
  });
}

class AdminCommissionScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminCommissionScreen({super.key, this.isSuperAdmin = false});

  @override
  State<AdminCommissionScreen> createState() => _AdminCommissionScreenState();
}

class _AdminCommissionScreenState extends State<AdminCommissionScreen> {
  int _selectedFilter = 0;
  static const _filters = ['All', 'Platform', 'Agent', 'Pending'];
  bool _isLoading = true;
  String? _error;

  List<CommissionRule> _commissionRules = [];
  List<CommissionLog> _commissionLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchCommissionData();
  }

  Future<void> _fetchCommissionData() async {
    try {
      final results = await Future.wait([
        AdminCommissionService().listCommissionRules(),
        AdminCommissionService().getCommissionLogs(),
      ]);
      
      final rulesResponse = results[0];
      final logsResponse = results[1];
      
      if (mounted) {
        final rulesData = rulesResponse['data'];
        final logsData = logsResponse['data'];
        
        setState(() {
          if (rulesData != null) {
            final rulesList = rulesData['rules'] as List<dynamic>? ?? [];
            _commissionRules = rulesList.map<CommissionRule>((r) => CommissionRule(
              id: r['id'] as String? ?? '',
              role: _parseCommissionRole(r['role'] as String? ?? 'platform'),
              percentage: (r['rate'] as num?)?.toDouble() ?? 0.0,
              description: r['name'] as String? ?? '',
              status: (r['is_active'] as bool? ?? true) ? CommissionStatus.active : CommissionStatus.inactive,
            )).toList();
          } else {
            _commissionRules = [];
          }
          
          if (logsData != null) {
            final logsList = logsData['logs'] as List<dynamic>? ?? [];
            _commissionLogs = logsList.map<CommissionLog>((l) => CommissionLog(
              id: l['id'] as String? ?? '',
              bookingRef: l['booking_ref'] as String? ?? '',
              role: _parseCommissionRole(l['role'] as String? ?? 'platform'),
              amount: (l['amount'] as num?)?.toDouble() ?? 0.0,
              percentage: (l['percentage'] as num?)?.toDouble() ?? 0.0,
              isPaid: l['is_paid'] as bool? ?? false,
              date: DateTime.tryParse(l['date'] as String? ?? '') ?? DateTime.now(),
            )).toList();
          } else {
            _commissionLogs = [];
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load commission data. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  CommissionRole _parseCommissionRole(String role) {
    switch (role.toLowerCase()) {
      case 'agent': return CommissionRole.agent;
      case 'landlord': return CommissionRole.landlord;
      default: return CommissionRole.platform;
    }
  }

  bool get _isSuperAdmin => widget.isSuperAdmin;

  List<CommissionLog> get _filteredLogs {
    if (_selectedFilter == 0) return _commissionLogs;
    if (_selectedFilter == 1) return _commissionLogs.where((l) => l.role == CommissionRole.platform).toList();
    if (_selectedFilter == 2) return _commissionLogs.where((l) => l.role == CommissionRole.agent).toList();
    if (_selectedFilter == 3) return _commissionLogs.where((l) => !l.isPaid).toList();
    return _commissionLogs;
  }

  double get _totalRevenue => _commissionLogs.fold(0.0, (s, l) => s + l.amount);
  double get _paidRevenue => _commissionLogs.where((l) => l.isPaid).fold(0.0, (s, l) => s + l.amount);
  double get _pendingRevenue => _commissionLogs.where((l) => !l.isPaid).fold(0.0, (s, l) => s + l.amount);
  double get _agentPayouts => _commissionLogs.where((l) => l.role == CommissionRole.agent).fold(0.0, (s, l) => s + l.amount);

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _roleLabel(CommissionRole r) => switch (r) {
    CommissionRole.platform => 'Platform',
    CommissionRole.agent => 'Agent',
    CommissionRole.landlord => 'Landlord',
  };

  Color _roleColor(CommissionRole r) => switch (r) {
    CommissionRole.platform => AppColors.primary,
    CommissionRole.agent => AppColors.warning,
    CommissionRole.landlord => AppColors.success,
  };

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
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchCommissionData(); }),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: Text('Commission Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 16),
            _buildRevenueSummary(),
            _buildRulesSection(),
            _buildLogsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueSummary() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _summaryCard('Total Revenue', '₦${_fmt(_totalRevenue)}', Icons.trending_up, AppColors.primary),
          const SizedBox(width: 10),
          _summaryCard('Paid', '₦${_fmt(_paidRevenue)}', Icons.check_circle_outline, AppColors.success),
          const SizedBox(width: 10),
          _summaryCard('Pending', '₦${_fmt(_pendingRevenue)}', Icons.schedule, AppColors.warning),
          const SizedBox(width: 10),
          _summaryCard('Agent Payouts', '₦${_fmt(_agentPayouts)}', Icons.person_outline, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.subtitle), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Commission Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Opacity(
                opacity: _isSuperAdmin ? 1.0 : 0.5,
                child: OutlinedButton.icon(
                  onPressed: _isSuperAdmin ? _showAddRuleDialog : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(_isSuperAdmin ? 'Add Rule' : 'Add Rule (Super Admin Only)', style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isSuperAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only Super Admin can add, edit, or toggle commission rules.',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ..._commissionRules.map((rule) => _buildRuleCard(rule)),
        ],
      ),
    );
  }

  Widget _buildRuleCard(CommissionRule rule) {
    final color = _roleColor(rule.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.minimal,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.percent, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${rule.percentage}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(_roleLabel(rule.role), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rule.status == CommissionStatus.active ? AppColors.successLight : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              rule.status == CommissionStatus.active ? 'Active' : 'Inactive',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: rule.status == CommissionStatus.active ? AppColors.success : AppColors.subtitle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(rule.description, style: const TextStyle(fontSize: 12, color: AppColors.subtitle), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Opacity(
            opacity: _isSuperAdmin ? 1.0 : 0.4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn(Icons.edit_outlined, AppColors.primary, _isSuperAdmin
                    ? () => _showEditRuleDialog(rule)
                    : () {
                        showAppToast(context, 'Only Super Admin can edit commission rules', backgroundColor: AppColors.error);
                      }),
                const SizedBox(width: 6),
                _actionBtn(
                  rule.status == CommissionStatus.active ? Icons.pause_outlined : Icons.play_arrow_outlined,
                  rule.status == CommissionStatus.active ? AppColors.warning : AppColors.success,
                  _isSuperAdmin
                      ? () {
                          final isActive = rule.status == CommissionStatus.active;
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              title: Text(
                                isActive ? 'Deactivate Rule' : 'Activate Rule',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              content: Text(
                                '${isActive ? 'Deactivate' : 'Activate'} commission rule: ${rule.description}?',
                                style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      final index = _commissionRules.indexWhere((r) => r.description == rule.description);
                                      if (index != -1) {
                                        _commissionRules[index] = CommissionRule(
                                          id: rule.id,
                                          percentage: rule.percentage,
                                          role: rule.role,
                                          status: rule.status == CommissionStatus.active
                                              ? CommissionStatus.inactive
                                              : CommissionStatus.active,
                                          description: rule.description,
                                        );
                                      }
                                    });
                                    showAppToast(context, 'Rule ${rule.description} ${isActive ? "deactivated" : "activated"}');
                                  },
                                  child: Text(
                                    isActive ? 'Deactivate' : 'Activate',
                                    style: TextStyle(
                                      color: isActive ? AppColors.warning : AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      : () {
                          showAppToast(context, 'Only Super Admin can toggle commission rules', backgroundColor: AppColors.error);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildLogsSection() {
    final logs = _filteredLogs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = _selectedFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(_filters[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.textWhite : AppColors.subtitle)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            const Center(child: Text('No logs found', style: TextStyle(color: AppColors.hint)))
          else
            ...logs.map((log) => _buildLogCard(log)),
        ],
      ),
    );
  }

  Widget _buildLogCard(CommissionLog log) {
    final color = _roleColor(log.role);
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[log.date.month]} ${log.date.day}, ${log.date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.receipt_outlined, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(log.bookingRef, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(_roleLabel(log.role), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${log.percentage}% of booking  ·  $dateStr', style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₦${_fmt(log.amount)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: log.isPaid ? AppColors.success : AppColors.warning)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: log.isPaid ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  log.isPaid ? 'Paid' : 'Pending',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: log.isPaid ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog() {
    final pctCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    CommissionRole selectedRole = CommissionRole.platform;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Add Commission Rule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CommissionRole>(
                value: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                items: CommissionRole.values.map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r)))).toList(),
                onChanged: (v) => setDialogState(() => selectedRole = v ?? selectedRole),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pctCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Percentage',
                  suffixText: '%',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await runWithLoading(
                  context,
                  action: () async {
                    try {
                      await AdminCommissionService().createCommissionRule(
                        name: descCtrl.text,
                        percentage: double.tryParse(pctCtrl.text) ?? 0.0,
                        roleType: 'platform',
                      );
                      await _fetchCommissionData();
                    } catch (e) {
                      // Use local state as fallback
                    }
                  },
                  message: 'Adding rule...',
                );
                if (context.mounted) showAppToast(context, 'Commission rule added successfully');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Add', style: TextStyle(color: AppColors.textWhite)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRuleDialog(CommissionRule rule) {
    final pctCtrl = TextEditingController(text: rule.percentage.toString());
    final descCtrl = TextEditingController(text: rule.description);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Edit Commission Rule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pctCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Percentage',
                suffixText: '%',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await runWithLoading(
                  context,
                  action: () async {
                    try {
                      await AdminCommissionService().updateCommissionRule(
                        rule.id,
                        name: descCtrl.text,
                        percentage: double.tryParse(pctCtrl.text),
                      );
                      await _fetchCommissionData();
                    } catch (e) {
                      // Use local state as fallback
                    }
                  },
                  message: 'Saving changes...',
                );
                if (context.mounted) showAppToast(context, 'Commission rule updated successfully');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save', style: TextStyle(color: AppColors.textWhite)),
            ),
        ],
      ),
    );
  }
}

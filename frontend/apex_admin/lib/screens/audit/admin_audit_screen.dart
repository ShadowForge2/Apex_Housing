import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_service.dart';

enum AuditAction { userAction, propertyAction, financialAction, systemAction }

class AuditLogEntry {
  final String id;
  final AuditAction category;
  final String adminName;
  final String action;
  final String target;
  final DateTime timestamp;
  final String ipAddress;
  final String? details;

  const AuditLogEntry({
    required this.id,
    required this.category,
    required this.adminName,
    required this.action,
    required this.target,
    required this.timestamp,
    required this.ipAddress,
    this.details,
  });
}

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  AuditAction? _selectedFilter;
  List<AuditLogEntry> _auditLogs = [];
  bool _isLoading = true;
  String? _error;

  final Map<AuditAction, String> _filterLabels = {
    AuditAction.userAction: 'User Actions',
    AuditAction.propertyAction: 'Property Actions',
    AuditAction.financialAction: 'Financial Actions',
    AuditAction.systemAction: 'System Actions',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAuditLogs();
  }

  Future<void> _fetchAuditLogs() async {
    try {
      final response = await AdminService().listAuditLogs();
      final data = response['data'];
      if (data != null && mounted) {
        final logsList = data['logs'] as List<dynamic>? ?? [];
        setState(() {
          _auditLogs = logsList.map<AuditLogEntry>((l) => AuditLogEntry(
            id: l['id'] as String? ?? '',
            category: _parseAuditAction(l['category'] as String? ?? 'system'),
            adminName: l['admin_name'] as String? ?? '',
            action: l['action'] as String? ?? '',
            target: l['target'] as String? ?? '',
            timestamp: DateTime.tryParse(l['timestamp'] as String? ?? '') ?? DateTime.now(),
            ipAddress: l['ip_address'] as String? ?? '',
            details: l['details'] as String?,
          )).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _auditLogs = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load audit logs. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  AuditAction _parseAuditAction(String action) {
    switch (action.toLowerCase()) {
      case 'user': return AuditAction.userAction;
      case 'property': return AuditAction.propertyAction;
      case 'financial': return AuditAction.financialAction;
      default: return AuditAction.systemAction;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AuditLogEntry> get _filteredLogs {
    return _auditLogs.where((log) {
      final matchesSearch = _searchQuery.isEmpty ||
          log.adminName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.target.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == null || log.category == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  List<AuditLogEntry> get _adminActions => _filteredLogs.where((l) => l.category != AuditAction.systemAction).toList();
  List<AuditLogEntry> get _systemLogs => _filteredLogs.where((l) => l.category == AuditAction.systemAction).toList();

  IconData _iconForCategory(AuditAction action) {
    switch (action) {
      case AuditAction.userAction:
        return Icons.person_outline;
      case AuditAction.propertyAction:
        return Icons.home_outlined;
      case AuditAction.financialAction:
        return Icons.account_balance_wallet_outlined;
      case AuditAction.systemAction:
        return Icons.settings_outlined;
    }
  }

  Color _colorForCategory(AuditAction action) {
    switch (action) {
      case AuditAction.userAction:
        return AppColors.info;
      case AuditAction.propertyAction:
        return AppColors.warning;
      case AuditAction.financialAction:
        return AppColors.success;
      case AuditAction.systemAction:
        return AppColors.secondary;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $ampm';
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
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchAuditLogs(); }),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLogList(_adminActions),
                  _buildLogList(_systemLogs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadow.minimal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Audit Logs',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Track all admin and system actions for accountability',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: 'Admin Actions (${_adminActions.length})'),
              Tab(text: 'System Logs (${_systemLogs.length})'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by admin, action, or target...',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textHint, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: AppRadius.smAll,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.smAll,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.smAll,
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPill('All', _selectedFilter == null, () {
              setState(() => _selectedFilter = null);
            }),
            const SizedBox(width: AppSpacing.sm),
            ..._filterLabels.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _buildPill(
                  entry.value,
                  _selectedFilter == entry.key,
                  () => setState(() => _selectedFilter = entry.key),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected ? AppShadow.minimal : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.textWhite : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLogList(List<AuditLogEntry> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: AppColors.textHint),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No audit logs found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Try adjusting your filters or search query',
                style: TextStyle(fontSize: 13, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAuditLogs,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxl),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final log = logs[index];
        final color = _colorForCategory(log.category);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdAll,
            boxShadow: AppShadow.minimal,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(_iconForCategory(log.category), color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.action,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _buildCategoryBadge(log.category),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'By ${log.adminName}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.target,
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (log.details != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: AppRadius.xsAll,
                        ),
                        child: Text(
                          log.details!,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimestamp(log.timestamp),
                              style: TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language, size: 12, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(
                              log.ipAddress,
                              style: TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _buildCategoryBadge(AuditAction action) {
    final color = _colorForCategory(action);
    final label = _filterLabels[action] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

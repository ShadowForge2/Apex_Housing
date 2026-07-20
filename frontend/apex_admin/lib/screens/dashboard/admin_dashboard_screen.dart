import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onViewAllActivity;
  const AdminDashboardScreen({super.key, this.onViewAllActivity});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboardResponse? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await AdminService().getDashboard();
      if (mounted) {
        setState(() {
          _dashboard = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load dashboard', style: TextStyle(fontSize: 16, color: AppColors.subtitle)),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.hint)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _isLoading = true; _error = null; });
                  _fetchDashboard();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WelcomeHeader(),
              const SizedBox(height: AppSpacing.xxl),
              _StatsGrid(dashboard: _dashboard!),
              const SizedBox(height: AppSpacing.xxl),
              _RevenueOverview(dashboard: _dashboard!),
              const SizedBox(height: AppSpacing.xxl),
              _PlatformHealthCards(dashboard: _dashboard!),
              const SizedBox(height: AppSpacing.xxl),
              _RecentActivityFeed(dashboard: _dashboard!, onViewAll: widget.onViewAllActivity),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final days = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];
    final dateStr = '${days[now.weekday]}, ${months[now.month]} ${now.day}, ${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, Admin',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          dateStr,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AdminDashboardResponse dashboard;
  const _StatsGrid({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final stats = <Map<String, dynamic>>[
      {'label': 'Total Users', 'value': _fmt(dashboard.totalUsers), 'icon': Icons.people_outline, 'color': AppColors.statUsers},
      {'label': 'Landlords', 'value': _fmt(dashboard.totalLandlords), 'icon': Icons.home_work_outlined, 'color': AppColors.statLandlords},
      {'label': 'Tenants', 'value': _fmt(dashboard.totalTenants), 'icon': Icons.person_outline, 'color': AppColors.statTenants},
      {'label': 'Properties', 'value': _fmt(dashboard.totalProperties), 'icon': Icons.apartment_outlined, 'color': AppColors.statProperties},
      {'label': 'Active Bookings', 'value': _fmt(dashboard.activeBookings), 'icon': Icons.calendar_month_outlined, 'color': AppColors.statBookings},
      {'label': 'Revenue', 'value': '₦${_fmtRevenue(dashboard.totalRevenue)}', 'icon': Icons.account_balance_wallet_outlined, 'color': AppColors.statRevenue},
      {'label': 'KYC Pending', 'value': _fmt(dashboard.pendingKyc), 'icon': Icons.verified_user_outlined, 'color': AppColors.statKyc},
      {'label': 'Disputes', 'value': _fmt(dashboard.openDisputes), 'icon': Icons.gavel_outlined, 'color': AppColors.statDisputes},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.4,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _StatCard(
              label: stat['label'] as String,
              value: stat['value'] as String,
              color: stat['color'] as Color,
              icon: stat['icon'] as IconData,
            );
          },
        );
      },
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  static String _fmtRevenue(double n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueOverview extends StatelessWidget {
  final AdminDashboardResponse dashboard;
  const _RevenueOverview({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final data = dashboard.monthlyRevenue;
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlAll,
        ),
        child: const Center(
          child: Text('No revenue data yet', style: TextStyle(color: AppColors.subtitle)),
        ),
      );
    }

    final maxRevenue = data
        .map((e) => e['revenue'] as double)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  '₦${dashboard.totalRevenue.toStringAsFixed(0)} total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (index) {
                final item = data[index];
                final revenue = item['revenue'] as double;
                final fraction = maxRevenue > 0 ? revenue / maxRevenue : 0.0;
                final month = item['month'] as String;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₦${_RevenueOverview._fmt(revenue)}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 3),
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            constraints: const BoxConstraints(minHeight: 4),
                            height: (180 - 50) * fraction,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.sm),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          month,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textHint,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _PlatformHealthCards extends StatelessWidget {
  final AdminDashboardResponse dashboard;
  const _PlatformHealthCards({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final occupancyRate = dashboard.totalProperties > 0
        ? ((dashboard.activeBookings / dashboard.totalProperties) * 100).clamp(0, 100)
        : 0.0;
    final avgBookings = dashboard.totalUsers > 0
        ? dashboard.totalBookings / dashboard.totalUsers
        : 0.0;

    final health = <Map<String, dynamic>>[
      {'label': 'Total Bookings', 'value': dashboard.totalBookings.toString(), 'icon': Icons.home_rounded, 'color': AppColors.success},
      {'label': 'Active Escrows', 'value': dashboard.activeEscrowsCount.toString(), 'icon': Icons.access_time_rounded, 'color': AppColors.info},
      {'label': 'Revenue', 'value': '₦${_fmtRevenue(dashboard.totalRevenue)}', 'icon': Icons.account_balance_wallet_rounded, 'color': AppColors.primary},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return isWide
            ? Row(
                children: List.generate(health.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : AppSpacing.sm,
                        right: index == health.length - 1 ? 0 : AppSpacing.sm,
                      ),
                      child: _HealthCard(
                        label: health[index]['label'] as String,
                        value: health[index]['value'] as String,
                        icon: health[index]['icon'] as IconData,
                        color: health[index]['color'] as Color,
                      ),
                    ),
                  );
                }),
              )
            : Column(
                children: List.generate(health.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < health.length - 1 ? AppSpacing.md : 0,
                    ),
                    child: _HealthCard(
                      label: health[index]['label'] as String,
                      value: health[index]['value'] as String,
                      icon: health[index]['icon'] as IconData,
                      color: health[index]['color'] as Color,
                    ),
                  );
                }),
              );
      },
    );
  }

  static String _fmtRevenue(double n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityFeed extends StatelessWidget {
  final AdminDashboardResponse dashboard;
  final VoidCallback? onViewAll;
  const _RecentActivityFeed({required this.dashboard, this.onViewAll});

  static const Map<String, IconData> _actionIcons = {
    'approve_property': Icons.check_circle_outline,
    'reject_property': Icons.cancel_outlined,
    'suspend_user': Icons.block,
    'activate_user': Icons.person_add_outlined,
    'invite_admin': Icons.admin_panel_settings_outlined,
    'approve_kyc': Icons.verified_outlined,
    'reject_kyc': Icons.gpp_bad_outlined,
    'resolve_dispute': Icons.gavel_outlined,
    'update_settings': Icons.settings_outlined,
    'create_fraud_alert': Icons.warning_amber_outlined,
  };

  static const Map<String, Color> _actionColors = {
    'approve_property': AppColors.success,
    'reject_property': AppColors.error,
    'suspend_user': AppColors.error,
    'activate_user': AppColors.success,
    'invite_admin': AppColors.info,
    'approve_kyc': AppColors.success,
    'reject_kyc': AppColors.warning,
    'resolve_dispute': AppColors.primary,
    'update_settings': AppColors.info,
    'create_fraud_alert': AppColors.error,
  };

  String _formatAction(String action) {
    return action
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatTimeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activities = dashboard.recentActivity;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text('No recent activity', style: TextStyle(color: AppColors.hint)),
              ),
            )
          else
            ...List.generate(activities.length, (index) {
              final activity = activities[index];
              final action = activity['action'] as String? ?? '';
              final resourceType = activity['resource_type'] as String? ?? '';
              final createdAt = activity['created_at'] as String?;
              final isLast = index == activities.length - 1;

              final icon = _actionIcons[action] ?? Icons.circle_outlined;
              final color = _actionColors[action] ?? AppColors.hint;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: isLast
                    ? null
                    : const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.divider,
                            width: 1,
                          ),
                        ),
                      ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatAction(action)} ${resourceType}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeAgo(createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

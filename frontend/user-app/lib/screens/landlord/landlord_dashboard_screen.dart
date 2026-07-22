import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/landlord_service.dart';
import '../../services/property_service.dart';
import '../../services/booking_service.dart';
import '../../services/user_service.dart';
import '../notifications/notifications_screen.dart';
import 'analytics_screen.dart';
import 'earnings_screen.dart';
import 'tenants_screen.dart';


class LandlordDashboardScreen extends StatefulWidget {
  const LandlordDashboardScreen({super.key});

  @override
  State<LandlordDashboardScreen> createState() => _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  DashboardStats? _stats;
  UserProfile? _profile;
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        LandlordService().getDashboardStats(),
        BookingService().listBookings(),
        UserService().getMyProfile(),
      ]);

      final stats = results[0] as DashboardStats;
      final bookings = results[1] as List<BookingModel>;
      final profile = results[2] as UserProfile;

      final recentBookings = bookings.length > 5 ? bookings.sublist(0, 5) : bookings;
      final activity = recentBookings.map((b) {
        String type;
        String status;
        switch (b.status) {
          case 'confirmed':
            type = 'booking';
            status = 'confirmed';
            break;
          case 'pending':
            type = 'booking';
            status = 'pending';
            break;
          case 'completed':
            type = 'booking';
            status = 'completed';
            break;
          default:
            type = 'booking';
            status = 'pending';
        }
        return {
          'type': type,
          'message': 'Booking #${b.id.substring(0, b.id.length > 8 ? 8 : b.id.length)} — ${b.status ?? 'unknown'}',
          'time': b.createdAt ?? 'Recently',
          'status': status,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _stats = stats;
          _profile = profile;
          _recentActivity = activity;
          _isLoading = false;
        });
      }
    } catch (e) {
      final msg = e.toString();
      final isForbidden = msg.contains('403') || msg.contains('Forbidden') || msg.contains('permission');
      if (mounted) {
        setState(() {
          _error = isForbidden ? 'landlord_required' : msg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: const ApexLoading(),
            ))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error == 'landlord_required' ? Icons.person_add_outlined : Icons.wifi_off_rounded,
                          size: 48,
                          color: _error == 'landlord_required' ? AppColors.primary : AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error == 'landlord_required' ? 'Landlord account required' : 'Unable to connect',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _error == 'landlord_required'
                              ? 'Go to Profile and switch to Landlord mode to access this dashboard.'
                              : 'Check your connection and try again',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.hint, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildStatsGrid(),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Quick Actions'),
                        const SizedBox(height: 14),
                        _buildQuickActions(context),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Recent Activity'),
                        const SizedBox(height: 14),
                        _buildActivityFeed(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final firstName = _profile?.firstName ?? '';
    final lastName = _profile?.lastName ?? '';
    final displayName = '$firstName $lastName'.trim();
    final initials = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Text(initials.isNotEmpty ? initials.toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName.isNotEmpty ? displayName : 'Landlord', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text('Landlord Dashboard', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showApexLoadingThen(context, () => Navigator.pushNamed(context, '/add-property')),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: const Icon(Icons.add_home_outlined, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              showApexLoadingThen(context, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              });
            },
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(Icons.notifications_none, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _stats;
    final statItems = [
      {'label': 'Total Revenue', 'value': '₦${_formatRevenue(stats?.totalRevenue)}', 'change': ''},
      {'label': 'Occupancy', 'value': '${stats?.activeBookings ?? 0} Active', 'change': ''},
      {'label': 'Active Listings', 'value': '${stats?.totalProperties ?? 0}', 'change': ''},
      {'label': 'Pending Requests', 'value': '${stats?.pendingApplications ?? 0}', 'change': ''},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.55,
        ),
        itemCount: statItems.length,
        itemBuilder: (_, i) {
          final stat = statItems[i];
          final color = _statColor(i);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadow.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statIcon(i), size: 18, color: color),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat['value'] as String,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(stat['label'] as String,
                            style: const TextStyle(fontSize: 12, color: AppColors.subtitle)),
                        if ((stat['change'] as String).isNotEmpty) ...[
                          const Spacer(),
                          Text(stat['change'] as String,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatRevenue(double? revenue) {
    if (revenue == null) return '0';
    if (revenue >= 1000000) return '${(revenue / 1000000).toStringAsFixed(1)}M';
    if (revenue >= 1000) return '${(revenue / 1000).toStringAsFixed(0)}K';
    return revenue.toStringAsFixed(0);
  }

  Color _statColor(int i) {
    const colors = [AppColors.success, AppColors.primary, AppColors.warning, AppColors.error];
    return colors[i % colors.length];
  }

  IconData _statIcon(int i) {
    const icons = [Icons.trending_up_rounded, Icons.apartment_rounded, Icons.home_work_outlined, Icons.pending_outlined];
    return icons[i % icons.length];
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.add_home_outlined, 'label': 'Add Listing', 'color': AppColors.primary},
      {'icon': Icons.person_add_outlined, 'label': 'View Tenants', 'color': AppColors.success},
      {'icon': Icons.payments_outlined, 'label': 'Earnings', 'color': AppColors.warning},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'color': AppColors.error},
    ];
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: () {
              showApexLoadingThen(context, () {
                switch (i) {
                  case 0:
                    Navigator.pushNamed(context, '/add-property');
                    break;
                  case 1:
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantsScreen()));
                    break;
                  case 2:
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                    break;
                  case 3:
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
                    break;
                }
              });
            },
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadow.soft,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (a['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(a['label'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
    );
  }

  Widget _buildActivityFeed() {
    final activities = _recentActivity;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: activities.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No recent activity', style: TextStyle(color: AppColors.subtitle, fontSize: 14)),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 60, color: AppColors.border),
                itemBuilder: (_, i) {
                  final a = activities[i];
                  final statusColor = _activityStatusColor(a['status'] as String);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_activityIcon(a['type'] as String), size: 20, color: statusColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['message'] as String,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text(a['time'] as String,
                                  style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Color _activityStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.subtitle;
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.calendar_today_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'tenant':
        return Icons.person_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'review':
        return Icons.star_rounded;
      default:
        return Icons.circle;
    }
  }
}

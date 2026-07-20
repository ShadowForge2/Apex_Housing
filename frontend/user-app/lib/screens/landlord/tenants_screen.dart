import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/booking_service.dart';
import '../../services/property_service.dart';
import '../messages/chat_detail_screen.dart';
import '../profile/public_profile_screen.dart';
import 'tenant_detail_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  int _tab = 0;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _activeTenants = [];
  List<Map<String, dynamic>> _applications = [];

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
      final bookings = await BookingService().listBookings();
      final propertyService = PropertyService();

      final activeTenants = <Map<String, dynamic>>[];
      final applications = <Map<String, dynamic>>[];

      for (final booking in bookings) {
        final propertyName = booking.propertyId != null
            ? await _getPropertyTitle(propertyService, booking.propertyId!)
            : 'Unknown Property';

        final initials = booking.userId != null && booking.userId!.length >= 2
            ? booking.userId!.substring(0, 2).toUpperCase()
            : '??';

        final tenantData = {
          'name': 'Tenant ${booking.userId?.substring(0, booking.userId!.length > 8 ? 8 : booking.userId!.length) ?? 'Unknown'}',
          'property': propertyName,
          'rent': 0,
          'status': booking.status == 'confirmed' ? 'active' : 'notice',
          'leaseEnd': booking.moveInDate ?? 'N/A',
          'avatar': initials,
          'userId': booking.userId ?? '',
          'bookingId': booking.id,
        };

        if (booking.status == 'confirmed' || booking.status == 'active') {
          activeTenants.add(tenantData);
        } else if (booking.status == 'pending') {
          applications.add({
            'name': 'Applicant ${booking.userId?.substring(0, booking.userId!.length > 8 ? 8 : booking.userId!.length) ?? 'Unknown'}',
            'property': propertyName,
            'date': booking.createdAt ?? 'Recently',
            'avatar': initials,
          });
        }
      }

      if (mounted) {
        setState(() {
          _activeTenants = activeTenants;
          _applications = applications;
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

  Future<String> _getPropertyTitle(PropertyService propertyService, String propertyId) async {
    try {
      final property = await propertyService.getProperty(propertyId);
      return property.title;
    } catch (_) {
      return 'Property #$propertyId';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('Tenants', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4, decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.subtitle,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero,
                onTap: (i) => setState(() => _tab = i),
                tabs: const [
                  Tab(text: 'Active Tenants'),
                  Tab(text: 'Applications'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: ApexLoading())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subtitle)),
                            const SizedBox(height: 16),
                            TextButton(onPressed: _loadData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _tab == 0 ? _buildActiveTenants() : _buildApplications(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTenants() {
    final tenants = _activeTenants;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: tenants.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                        child: const Icon(Icons.person_outline, size: 32, color: AppColors.hint),
                      ),
                      const SizedBox(height: 16),
                      const Text('No active tenants', style: TextStyle(color: AppColors.subtitle, fontSize: 15, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              itemCount: tenants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = tenants[i];
                final statusColor = t['status'] == 'active' ? AppColors.success : AppColors.warning;
                final statusLabel = t['status'] == 'active' ? 'Active' : 'Notice Period';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadow.soft,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(
                                name: t['name'] as String,
                                initials: t['avatar'] as String,
                                role: 'Tenant',
                                userId: t['userId'] as String? ?? '',
                                city: (t['property'] as String).contains(' in ')
                                    ? (t['property'] as String).split(' in ').last
                                    : t['property'] as String,
                                isOnline: t['status'] == 'active',
                              ),
                            )),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.lightPurple,
                              child: Text(t['avatar'] as String,
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15, decoration: TextDecoration.none)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name'] as String,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, decoration: TextDecoration.none)),
                                const SizedBox(height: 2),
                                Text(t['property'] as String,
                                    style: const TextStyle(fontSize: 13, color: AppColors.subtitle, decoration: TextDecoration.none)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(statusLabel,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor, decoration: TextDecoration.none)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            _tenantDetail('Monthly Rent', '₦${(t['rent'] as int).toString().replaceAll(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), ',')}'),
                            const SizedBox(width: 20),
                            _tenantDetail('Lease Ends', t['leaseEnd'] as String),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(name: t['name'] as String),
                              )),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: const Text('Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text, decoration: TextDecoration.none)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => TenantDetailScreen(
                                  name: t['name'] as String,
                                  property: t['property'] as String,
                                  rent: t['rent'] as int,
                                  leaseEnd: t['leaseEnd'] as String,
                                  status: t['status'] as String,
                                  avatar: t['avatar'] as String,
                                ),
                              )),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: const Text('View Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.none)),
                              ),
                            ),
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

  Widget _tenantDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.hint, decoration: TextDecoration.none)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, decoration: TextDecoration.none)),
      ],
    );
  }

  Widget _buildApplications() {
    final apps = _applications;
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: const Icon(Icons.inbox_outlined, size: 32, color: AppColors.hint),
            ),
            const SizedBox(height: 16),
            const Text('No pending applications', style: TextStyle(color: AppColors.subtitle, fontSize: 15, decoration: TextDecoration.none)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      itemCount: apps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final a = apps[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(a['avatar'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, decoration: TextDecoration.none)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['name'] as String,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, decoration: TextDecoration.none)),
                        const SizedBox(height: 2),
                        Text(a['property'] as String,
                            style: const TextStyle(fontSize: 13, color: AppColors.subtitle, decoration: TextDecoration.none)),
                      ],
                    ),
                  ),
                  Text(a['date'] as String,
                      style: const TextStyle(fontSize: 12, color: AppColors.hint, decoration: TextDecoration.none)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showApexLoading(context, duration: const Duration(seconds: 1), label: 'Declining...'),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error, decoration: TextDecoration.none)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showApexLoading(context, duration: const Duration(seconds: 1), label: 'Accepting...'),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.none)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

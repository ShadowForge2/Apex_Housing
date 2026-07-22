import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/admin_models.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';
import '../../services/exceptions.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  int _selectedTab = 0;
  final _tabs = const ['All', 'Tenants', 'Landlords', 'Suspended'];
  late List<AdminUser> _users;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _users = [];
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await AdminService().listUsers();
      final data = response['data'];
      if (data != null && mounted) {
        final usersList = data['users'] as List<dynamic>? ?? [];
        setState(() {
          _users = usersList.map<AdminUser>((u) {
            final firstName = u['first_name'] as String? ?? '';
            final lastName = u['last_name'] as String? ?? '';
            final initials = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');
            return AdminUser(
              name: '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : u['email'] as String? ?? 'Unknown',
              email: u['email'] as String? ?? '',
              id: u['id'] as String? ?? '',
              role: u['role'] as String? ?? 'Tenant',
              status: u['status'] as String? ?? 'Active',
              phone: u['phone'] as String? ?? '',
              city: u['city'] as String? ?? '',
              joinDate: u['created_at'] as String? ?? '',
              totalBookings: u['total_bookings'] as int? ?? 0,
              avatar: initials.isNotEmpty ? initials.toUpperCase() : (u['email'] as String? ?? 'U').substring(0, 2).toUpperCase(),
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _users = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<AdminUser> get _filteredUsers {
    var users = _users;
    if (_searchQuery.isNotEmpty) {
      users = users
          .where(
            (u) =>
                u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                u.id.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    switch (_selectedTab) {
      case 1:
        return users.where((u) => u.role == 'Tenant').toList();
      case 2:
        return users.where((u) => u.role == 'Landlord').toList();
      case 3:
        return users.where((u) => u.status == 'Suspended').toList();
      default:
        return users;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Users',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    decoration: TextDecoration.none,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search users by name, email or ID...',
                    hintStyle: const TextStyle(
                      color: AppColors.hint,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.hint,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.hint),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isSelected = _selectedTab == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.textWhite : AppColors.subtitle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? Center(
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
                                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchUsers(); }),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredUsers.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _fetchUsers,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                itemCount: _filteredUsers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => _buildUserCard(_filteredUsers[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline, size: 32, color: AppColors.hint),
          ),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.subtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(fontSize: 13, color: AppColors.hint),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AdminUser user) {
    final statusColor = _statusColor(user.status);
    final statusBg = _statusBg(user.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.lightPurple,
                child: Text(
                  user.avatar,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.subtitle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                _infoChip(Icons.badge_outlined, user.id),
                const SizedBox(width: 12),
                _infoChip(Icons.person_outline, user.role),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    user.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.hint),
              const SizedBox(width: 5),
              Text(
                user.joinDate,
                style: const TextStyle(fontSize: 12, color: AppColors.hint),
              ),
              const Spacer(),
              _actionIcon(
                Icons.visibility_outlined,
                AppColors.primary,
                () => _showUserDetail(user),
              ),
              const SizedBox(width: 8),
              _actionIcon(
                user.status == 'Suspended'
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
                user.status == 'Suspended' ? AppColors.success : AppColors.warning,
                () => _toggleUserStatus(user),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.hint),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
        ),
      ],
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.success;
      case 'Suspended':
        return AppColors.error;
      case 'Pending':
        return AppColors.warning;
      default:
        return AppColors.subtitle;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Active':
        return AppColors.successLight;
      case 'Suspended':
        return AppColors.errorLight;
      case 'Pending':
        return AppColors.warningLight;
      default:
        return AppColors.surface;
    }
  }

  void _showUserDetail(AdminUser user) {
    final statusColor = _statusColor(user.status);
    final statusBg = _statusBg(user.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.lightPurple,
                  child: Text(
                    user.avatar,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.email,
                  style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    user.status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'User Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              _detailRow(Icons.badge_outlined, 'User ID', user.id),
              _detailRow(Icons.person_outline, 'Role', user.role),
              _detailRow(Icons.phone_outlined, 'Phone', user.phone),
              _detailRow(Icons.location_city_outlined, 'City', user.city),
              _detailRow(Icons.calendar_today_outlined, 'Joined', user.joinDate),
              _detailRow(Icons.receipt_long_outlined, 'Bookings', '${user.totalBookings}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _toggleUserStatus(user);
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: user.status == 'Suspended'
                              ? AppColors.success
                              : AppColors.warning,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.status == 'Suspended' ? 'Unsuspend' : 'Suspend',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textWhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.hint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppColors.hint),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserStatus(AdminUser user) {
    final isSuspending = user.status != 'Suspended';
    if (isSuspending) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text('Suspend User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Text(
            'Are you sure you want to suspend ${user.name}? They will lose access to the platform.',
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
                _applyUserStatus(user, 'Suspended');
              },
              child: const Text('Suspend', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text('Unsuspend User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Text(
            'Are you sure you want to unsuspend ${user.name}? They will regain access to the platform.',
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
                _applyUserStatus(user, 'Active');
              },
              child: const Text('Unsuspend', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
  }

void _applyUserStatus(AdminUser user, String newStatus) async {
  await runWithLoading(
    context,
    action: () async {
      try {
        if (newStatus == 'Active') {
          await AdminService().activateUser(user.id);
        } else {
          await AdminService().suspendUser(user.id);
        }
        setState(() {
          final index = _users.indexWhere((u) => u.id == user.id);
          if (index != -1) {
            _users[index] = AdminUser(
              name: user.name,
              email: user.email,
              id: user.id,
              role: user.role,
              status: newStatus,
              phone: user.phone,
              city: user.city,
              joinDate: user.joinDate,
              totalBookings: user.totalBookings,
              avatar: user.avatar,
            );
          }
        });
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: ${e.toString()}'), backgroundColor: AppColors.error),
          );
        }
      }
    },
    message: newStatus == 'Active' ? 'Unsuspending user...' : 'Suspending user...',
  );
  if (context.mounted) {
    showAppToast(
      context,
      '${user.name} ${newStatus == "Active" ? "activated" : "suspended"}',
      backgroundColor: newStatus == 'Active' ? AppColors.success : AppColors.warning,
    );
  }
}
}

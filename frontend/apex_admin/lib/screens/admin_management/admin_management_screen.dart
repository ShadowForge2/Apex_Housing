import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';
import '../../services/exceptions.dart';

enum AdminRole { superAdmin, admin }

enum AdminTeamStatus { active, suspended }

class AdminTeamMember {
  final String name;
  final String email;
  final String id;
  final AdminRole role;
  final AdminTeamStatus status;
  final DateTime? lastActive;
  final String avatar;

  const AdminTeamMember({
    required this.name,
    required this.email,
    required this.id,
    required this.role,
    required this.status,
    this.lastActive,
    required this.avatar,
  });
}

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  String _searchQuery = '';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  AdminRole _inviteRole = AdminRole.admin;
  AdminRole _changeRoleTarget = AdminRole.admin;
  bool _isLoading = true;

  final List<AdminTeamMember> _admins = [];

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    try {
      final response = await AdminService().listAdmins();
      final data = response['data'];
      if (data != null && mounted) {
        final adminsList = data['admins'] as List<dynamic>? ?? [];
        setState(() {
          _admins.clear();
          for (final a in adminsList) {
            final name = a['name'] as String? ?? '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
            final avatarParts = name.split(' ');
            final avatar = avatarParts.length >= 2
                ? '${avatarParts[0][0]}${avatarParts[1][0]}'
                : name.substring(0, name.length.clamp(0, 2));

            final bool isSuper = a['is_super_admin'] == true;

            _admins.add(AdminTeamMember(
              name: name,
              email: a['email'] as String? ?? '',
              id: a['id'] as String? ?? '',
              role: isSuper ? AdminRole.superAdmin : _parseAdminRole(a['role'] as String? ?? 'admin'),
              status: (a['is_active'] == true)
                  ? AdminTeamStatus.active
                  : AdminTeamStatus.suspended,
              avatar: avatar.toUpperCase(),
            ));
          }
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _admins.addAll([
              const AdminTeamMember(name: 'Adaeze Okonkwo', email: 'adaeze.okonkwo@apex.ng', id: 'ADM-001', role: AdminRole.superAdmin, status: AdminTeamStatus.active, avatar: 'AO'),
              const AdminTeamMember(name: 'Chukwuemeka Nwosu', email: 'chukwuemeka.n@apex.ng', id: 'ADM-002', role: AdminRole.admin, status: AdminTeamStatus.active, avatar: 'CN'),
              const AdminTeamMember(name: 'Folake Adeyemi', email: 'folake.adeyemi@apex.ng', id: 'ADM-003', role: AdminRole.admin, status: AdminTeamStatus.suspended, avatar: 'FA'),
            ]);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _admins.addAll([
            const AdminTeamMember(name: 'Adaeze Okonkwo', email: 'adaeze.okonkwo@apex.ng', id: 'ADM-001', role: AdminRole.superAdmin, status: AdminTeamStatus.active, avatar: 'AO'),
            const AdminTeamMember(name: 'Chukwuemeka Nwosu', email: 'chukwuemeka.n@apex.ng', id: 'ADM-002', role: AdminRole.admin, status: AdminTeamStatus.active, avatar: 'CN'),
          ]);
          _isLoading = false;
        });
      }
    }
  }

  AdminRole _parseAdminRole(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin': case 'superadmin': return AdminRole.superAdmin;
      default: return AdminRole.admin;
    }
  }

  List<AdminTeamMember> get _filteredAdmins {
    if (_searchQuery.isEmpty) return _admins;
    return _admins
        .where(
          (a) =>
              a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.id.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  int get _totalCount => _admins.length;
  int get _activeCount => _admins.where((a) => a.status == AdminTeamStatus.active).length;
  int get _suspendedCount => _admins.where((a) => a.status == AdminTeamStatus.suspended).length;

  String _roleLabel(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.admin:
        return 'Admin';
    }
  }

  String _statusLabel(AdminTeamStatus status) {
    switch (status) {
      case AdminTeamStatus.active:
        return 'Active';
      case AdminTeamStatus.suspended:
        return 'Suspended';
    }
  }

  Color _statusColor(AdminTeamStatus status) {
    switch (status) {
      case AdminTeamStatus.active:
        return AppColors.success;
      case AdminTeamStatus.suspended:
        return AppColors.error;
    }
  }

  Color _statusBg(AdminTeamStatus status) {
    switch (status) {
      case AdminTeamStatus.active:
        return AppColors.successLight;
      case AdminTeamStatus.suspended:
        return AppColors.errorLight;
    }
  }

  Color _roleColor(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return AppColors.primary;
      case AdminRole.admin:
        return AppColors.secondary;
    }
  }

  Color _roleBg(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return AppColors.infoLight;
      case AdminRole.admin:
        return AppColors.lightPurple;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Admin Team',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showInviteDialog,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_outlined, size: 17, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Invite Admin',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsRow(),
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
                    hintText: 'Search admins by name, email or ID...',
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
            Expanded(
              child: _filteredAdmins.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _filteredAdmins.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _buildAdminCard(_filteredAdmins[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _statCard('Total Admins', _totalCount.toString(), AppColors.primary, AppColors.infoLight),
          const SizedBox(width: 10),
          _statCard('Active', _activeCount.toString(), AppColors.success, AppColors.successLight),
          const SizedBox(width: 10),
          _statCard('Suspended', _suspendedCount.toString(), AppColors.error, AppColors.errorLight),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
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
            child: const Icon(Icons.admin_panel_settings_outlined, size: 32, color: AppColors.hint),
          ),
          const SizedBox(height: 16),
          const Text(
            'No admins found',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.subtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search or invite a new admin',
            style: TextStyle(fontSize: 13, color: AppColors.hint),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(AdminTeamMember admin) {
    final statusColor = _statusColor(admin.status);
    final statusBg = _statusBg(admin.status);
    final roleColor = _roleColor(admin.role);
    final roleBg = _roleBg(admin.role);
    final isSuperAdmin = admin.role == AdminRole.superAdmin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleBg,
                child: Text(
                  admin.avatar,
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSuperAdmin) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 16, color: AppColors.primary),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            admin.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            _statusLabel(admin.status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      admin.email,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _roleLabel(admin.role),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.badge_outlined, size: 13, color: AppColors.hint),
                const SizedBox(width: 4),
                Text(
                  admin.id,
                  style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
                ),
                const Spacer(),
                const Icon(Icons.access_time, size: 13, color: AppColors.hint),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!isSuperAdmin)
            Row(
              children: [
                _actionButton(
                  Icons.admin_panel_settings_outlined,
                  'Edit Role',
                  AppColors.primary,
                  () => _showChangeRoleDialog(admin),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  admin.status == AdminTeamStatus.suspended
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                  admin.status == AdminTeamStatus.suspended ? 'Unsuspend' : 'Suspend',
                  admin.status == AdminTeamStatus.suspended ? AppColors.success : AppColors.warning,
                  () => _toggleSuspend(admin),
                ),
                const Spacer(),
                _actionButton(
                  Icons.person_remove_outlined,
                  'Remove',
                  AppColors.error,
                  () => _showRemoveDialog(admin),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap, {
    bool disabled = false,
  }) {
    if (disabled) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    _nameController.clear();
    _emailController.clear();
    _messageController.clear();
    _inviteRole = AdminRole.admin;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, size: 22, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Invite Admin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField('Full Name', _nameController, Icons.person_outline),
                const SizedBox(height: 12),
                _dialogField('Email Address', _emailController, Icons.email_outlined),
                const SizedBox(height: 12),
                const Text(
                  'Role',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtitle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                    child: DropdownButtonHideUnderline(
                    child: DropdownButton<AdminRole>(
                      value: _inviteRole,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      items: const [
                        DropdownMenuItem(value: AdminRole.admin, child: Text('Admin')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => _inviteRole = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Message (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtitle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: const InputDecoration(
                      hintText: 'Add a personal message...',
                      hintStyle: TextStyle(color: AppColors.hint, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
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
                      final roleStr = _inviteRole == AdminRole.superAdmin ? 'SUPER_ADMIN' : 'ADMIN';
                      await AdminService().inviteAdmin(_emailController.text.trim(), role: roleStr);
                      await _fetchAdmins();
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                        );
                      }
                    } catch (e) {
                      // Use local state as fallback
                    }
                  },
                  message: 'Sending invite...',
                );
                if (context.mounted) showAppToast(context, 'Admin invite sent successfully');
              },
              child: const Text(
                'Send Invite',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.subtitle,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: AppColors.hint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showChangeRoleDialog(AdminTeamMember admin) {
    _changeRoleTarget = admin.role;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text(
            'Change Role',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update role for ${admin.name}',
                style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
              ),
              const SizedBox(height: 16),
              const Text(
                'New Role',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtitle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                  child: DropdownButtonHideUnderline(
                  child: DropdownButton<AdminRole>(
                    value: _changeRoleTarget,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    items: const [
                      DropdownMenuItem(value: AdminRole.admin, child: Text('Admin')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => _changeRoleTarget = v);
                    },
                  ),
                ),
              ),
            ],
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
                      final roleStr = _changeRoleTarget == AdminRole.superAdmin ? 'SUPER_ADMIN' : _changeRoleTarget == AdminRole.admin ? 'ADMIN' : 'VIEWER';
                      await AdminService().updateAdminRole(admin.id, role: roleStr);
                      await _fetchAdmins();
                    } catch (e) {
                      // Fallback to local state
                    }
                  },
                  message: 'Updating role...',
                );
                if (context.mounted) showAppToast(context, 'Role updated for ${admin.name}');
              },
              child: const Text(
                'Update',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(AdminTeamMember admin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 22, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              'Remove Admin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${admin.name} from the admin team? '
          'They will lose all access immediately.',
          style: const TextStyle(fontSize: 14, color: AppColors.subtitle, height: 1.5),
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
                    await AdminService().removeAdmin(admin.id);
                    await _fetchAdmins();
                  } catch (e) {
                    // Fallback to local state
                    setState(() {
                      _admins.removeWhere((a) => a.id == admin.id);
                    });
                  }
                },
                message: 'Removing admin...',
              );
              if (context.mounted) showAppToast(context, '${admin.name} has been removed');
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _toggleSuspend(AdminTeamMember admin) {
    final isSuspending = admin.status == AdminTeamStatus.active;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          isSuspending ? 'Suspend Admin' : 'Unsuspend Admin',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isSuspending
              ? 'Are you sure you want to suspend ${admin.name}? They will lose admin access.'
              : 'Are you sure you want to unsuspend ${admin.name}? They will regain admin access.',
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
                    if (isSuspending) {
                      await AdminService().suspendUser(admin.id);
                    } else {
                      await AdminService().activateUser(admin.id);
                    }
                    setState(() {
                      final index = _admins.indexOf(admin);
                      if (index != -1) {
                        final current = _admins[index];
                        _admins[index] = AdminTeamMember(
                          name: current.name,
                          email: current.email,
                          id: current.id,
                          role: current.role,
                          status: isSuspending
                              ? AdminTeamStatus.suspended
                              : AdminTeamStatus.active,
                          lastActive: current.lastActive,
                          avatar: current.avatar,
                        );
                      }
                    });
                  } catch (e) {
                    if (mounted) {
                      showAppToast(context, 'Failed: $e', backgroundColor: AppColors.error);
                    }
                  }
                },
                message: isSuspending ? 'Suspending admin...' : 'Unsuspending admin...',
              );
              if (context.mounted) {
                showAppToast(
                  context,
                  '${admin.name} ${isSuspending ? "suspended" : "unsuspended"}',
                  backgroundColor: isSuspending ? AppColors.warning : AppColors.success,
                );
              }
            },
            child: Text(
              isSuspending ? 'Suspend' : 'Unsuspend',
              style: TextStyle(
                color: isSuspending ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

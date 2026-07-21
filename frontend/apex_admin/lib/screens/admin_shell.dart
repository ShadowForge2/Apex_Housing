import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/token_storage.dart';
import '../services/admin_service.dart';
import '../utils/loading_overlay.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'users/admin_users_screen.dart';
import 'properties/admin_properties_screen.dart';
import 'bookings/admin_bookings_screen.dart';
import 'transactions/admin_transactions_screen.dart';
import 'kyc/admin_kyc_screen.dart';
import 'reports/admin_reports_screen.dart';
import 'fraud/admin_fraud_screen.dart';
import 'audit/admin_audit_screen.dart';
import 'commission/admin_commission_screen.dart';
import 'analytics/admin_analytics_screen.dart';
import 'admin_management/admin_management_screen.dart';
import 'notifications/admin_notifications_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'chat/admin_live_chat_screen.dart';
import 'chat/admin_group_chat_screen.dart';
import 'chat/admin_group_manage_screen.dart';

class AdminShell extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminShell({
    super.key,
    required this.onLogout,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  bool _sidebarOpen = false;
  String _currentAdminRole = 'Super Admin';
  bool _isSuperAdmin = true;
  String _adminName = '';
  String _adminInitial = 'A';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadUnreadCount();
  }

  Future<void> _loadAdminInfo() async {
    final role = await TokenStorage().getUserRole();
    final name = await TokenStorage().getUserName();
    final isSuperAdmin = await TokenStorage().getIsSuperAdmin();
    if (mounted) {
      setState(() {
        _currentAdminRole = role ?? 'Super Admin';
        _isSuperAdmin = isSuperAdmin;
        _adminName = name ?? '';
        _adminInitial = _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A';
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final service = AdminService();
      final result = await service.getNotifications(page: 1, pageSize: 1);
      if (mounted) {
        setState(() => _unreadCount = result['data']?['unread_count'] ?? 0);
      }
    } catch (_) {}
  }

  static const List<_NavItem> _navItems = [
    _NavItem('Dashboard', Icons.dashboard_rounded),
    _NavItem('Users', Icons.people_outline_rounded),
    _NavItem('Properties', Icons.home_work_outlined),
    _NavItem('Bookings', Icons.receipt_long_outlined),
    _NavItem('Transactions', Icons.payments_outlined),
    _NavItem('KYC Review', Icons.verified_user_outlined),
    _NavItem('Reports', Icons.flag_outlined),
    _NavItem('Fraud Alerts', Icons.shield_outlined),
    _NavItem('Audit Logs', Icons.history_rounded),
    _NavItem('Commission', Icons.account_balance_outlined),
    _NavItem('Analytics', Icons.analytics_outlined),
    _NavItem('Admin Team', Icons.admin_panel_settings_outlined),
    _NavItem('Admin Chat', Icons.forum_rounded),
    _NavItem('Notifications', Icons.notifications_none_outlined),
    _NavItem('Live Chat', Icons.chat_bubble_outline_rounded),
    _NavItem('Settings', Icons.settings_outlined),
  ];

  static const Color _sidebarBg = Color(0xFF1E293B);
  static const Color _sidebarHover = Color(0xFF334155);
  static const double _sidebarWidth = 260.0;

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return AdminDashboardScreen(
          onViewAllActivity: () => setState(() => _selectedIndex = 8),
        );
      case 1:
        return const AdminUsersScreen();
      case 2:
        return const AdminPropertiesScreen();
      case 3:
        return const AdminBookingsScreen();
      case 4:
        return AdminTransactionsScreen(
          isSuperAdmin: _isSuperAdmin,
        );
      case 5:
        return const AdminKycScreen();
      case 6:
        return const AdminReportsScreen();
      case 7:
        return const AdminFraudScreen();
      case 8:
        return const AdminAuditScreen();
      case 9:
        return AdminCommissionScreen(
          isSuperAdmin: _isSuperAdmin,
        );
      case 10:
        return const AdminAnalyticsScreen();
      case 11:
        return const AdminManagementScreen();
      case 12:
        return AdminGroupChatScreen(
          onManageGroup: () => _showGroupManageSheet(),
        );
      case 13:
        return const AdminNotificationsScreen();
      case 14:
        return const AdminLiveChatScreen();
      case 15:
        return AdminSettingsScreen(
          isSuperAdmin: _isSuperAdmin,
        );
      default:
        return const AdminDashboardScreen();
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
  }

  void _selectIndex(int index) {
    setState(() {
      _selectedIndex = index;
      _sidebarOpen = false;
    });
    if (index != 13) _loadUnreadCount();
  }

  void _showGroupManageSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminGroupManageScreen(
          currentAdminId: '',
          onMembersChanged: (members) {},
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Logout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 14, color: AppColors.subtitle),
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
                action: () async { widget.onLogout(); },
                message: 'Logging out...',
              );
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopHeader(),
              Expanded(
                child: Container(
                  color: AppColors.background,
                  child: _buildCurrentScreen(),
                ),
              ),
            ],
          ),
          if (_sidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _sidebarOpen = false),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _sidebarOpen ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            left: _sidebarOpen ? 0 : -_sidebarWidth,
            top: 0,
            bottom: 0,
            width: _sidebarWidth,
            child: Material(
              elevation: 16,
              child: _buildSidebar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: _sidebarBg,
      child: Column(
        children: [
          _buildLogo(),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;
                return _buildNavItem(item, index, isSelected);
              },
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'APEX Housing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleSidebar,
            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectIndex(index),
          hoverColor: _sidebarHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : Colors.white54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showLogoutDialog(),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
                SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: Colors.white38, size: 20),
                SizedBox(width: 12),
                Text(
                  'Help & Support',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      height: 64 + topPadding,
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleSidebar,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.menu_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              _navItems[_selectedIndex].label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              _selectIndex(13);
              setState(() => _unreadCount = 0);
            },
            child: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.notifications_outlined,
                  color: AppColors.textSecondary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _adminInitial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem(this.label, this.icon);
}

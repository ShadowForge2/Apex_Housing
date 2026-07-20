import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _total = 0;
  int _unreadCount = 0;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final result = await _adminService.getNotifications(page: _page);
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final items = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        setState(() {
          if (_page == 1) {
            _notifications = items;
          } else {
            _notifications.addAll(items);
          }
          _total = data['total'] ?? 0;
          _unreadCount = data['unread_count'] ?? 0;
          _hasMore = _notifications.length < _total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _adminService.markAllNotificationsRead();
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to mark all read: $e');
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _adminService.markNotificationRead(id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          _notifications[idx]['is_read'] = true;
          _unreadCount = (_unreadCount - 1).clamp(0, 999);
        }
      });
    } catch (e) {
      debugPrint('Failed to mark read: $e');
    }
  }

  IconData _getNotificationIcon(String type) {
    if (type.contains('complaint') || type.contains('dispute')) return Icons.flag_outlined;
    if (type.contains('booking') || type.contains('escrow')) return Icons.receipt_long_outlined;
    if (type.contains('kyc') || type.contains('verification')) return Icons.verified_user_outlined;
    if (type.contains('payment') || type.contains('transaction')) return Icons.payments_outlined;
    if (type.contains('user') || type.contains('signup')) return Icons.person_add_outlined;
    if (type.contains('property')) return Icons.home_work_outlined;
    if (type.contains('admin_group_chat')) return Icons.forum_rounded;
    if (type.contains('complaint_message')) return Icons.chat_bubble_outline_rounded;
    return Icons.notifications_outlined;
  }

  Color _getNotificationColor(String type) {
    if (type.contains('complaint') || type.contains('dispute')) return AppColors.error;
    if (type.contains('kyc') || type.contains('verification')) return AppColors.warning;
    if (type.contains('payment') || type.contains('transaction')) return AppColors.success;
    if (type.contains('admin_group_chat') || type.contains('complaint_message')) return AppColors.primary;
    return AppColors.subtitle;
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.subtitle.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No notifications yet', style: TextStyle(fontSize: 16, color: AppColors.subtitle)),
                      const SizedBox(height: 8),
                      const Text(
                        'Notifications about platform activity will appear here',
                        style: TextStyle(fontSize: 13, color: AppColors.hint),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    _page = 1;
                    await _loadNotifications();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        _page++;
                        _loadNotifications();
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return _buildNotificationTile(_notifications[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final id = notification['id'] ?? '';
    final title = notification['title'] ?? '';
    final body = notification['body'] ?? '';
    final notificationType = notification['notification_type'] ?? '';
    final isRead = notification['is_read'] == true;
    final createdAt = notification['created_at'];
    final icon = _getNotificationIcon(notificationType);
    final color = _getNotificationColor(notificationType);

    return InkWell(
      onTap: () {
        if (!isRead) _markRead(id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isRead ? null : AppColors.primary.withValues(alpha: 0.03),
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
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 13, color: AppColors.subtitle, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.hint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

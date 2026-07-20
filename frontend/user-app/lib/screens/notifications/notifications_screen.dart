import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/notification_service.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await NotificationService().listNotifications();
      if (mounted) setState(() { _notifications = notifications; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService().markAllRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) => NotificationModel(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            read: true,
            createdAt: n.createdAt,
          )).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _markRead(NotificationModel notification) async {
    if (notification.read == true) return;
    try {
      await NotificationService().markRead(notification.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) => n.id == notification.id
            ? NotificationModel(
                id: n.id,
                title: n.title,
                message: n.message,
                type: n.type,
                read: true,
                createdAt: n.createdAt,
              )
            : n
          ).toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _notifications.isEmpty ? null : () {
              showApexLoadingThen(context, _markAllRead, label: 'Marking read...');
            },
            child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: ApexLoading())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: tc.surface, shape: BoxShape.circle),
                        child: Icon(Icons.notifications_none_rounded, size: 36, color: tc.hint),
                      ),
                      const SizedBox(height: 20),
                      Text('No notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: tc.text)),
                      const SizedBox(height: 6),
                      Text('You\'re all caught up!', style: TextStyle(fontSize: 14, color: tc.subtitle)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: tc.border),
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    final unread = !(n.read ?? true);
                    return _NotificationTile(
                      type: n.type ?? 'system',
                      title: n.title ?? '',
                      message: n.message ?? '',
                      time: _formatTime(n.createdAt),
                      unread: unread,
                      onTap: () {
                        _markRead(n);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationDetailScreen(
                              type: n.type ?? 'system',
                              title: n.title ?? '',
                              message: n.message ?? '',
                              time: _formatTime(n.createdAt),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return dateTime;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final String type;
  final String title;
  final String message;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.unread,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: unread ? tc.surfaceVariant.withValues(alpha: 0.3) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _typeColor(tc).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(), size: 20, color: _typeColor(tc)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: TextStyle(fontSize: 15, fontWeight: unread ? FontWeight.w700 : FontWeight.w600, color: tc.text)),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(time, style: TextStyle(fontSize: 12, color: tc.hint)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: tc.hint),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(ThemeColors tc) {
    switch (type) {
      case 'booking': return AppColors.primary;
      case 'payment': return AppColors.success;
      case 'message': return AppColors.primaryLight;
      case 'maintenance': return AppColors.warning;
      case 'review': return AppColors.rating;
      case 'system': return AppColors.success;
      default: return tc.subtitle;
    }
  }

  IconData _typeIcon() {
    switch (type) {
      case 'booking': return Icons.calendar_today_rounded;
      case 'payment': return Icons.payments_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      case 'maintenance': return Icons.build_rounded;
      case 'review': return Icons.star_rounded;
      case 'system': return Icons.shield_rounded;
      default: return Icons.notifications_rounded;
    }
  }
}

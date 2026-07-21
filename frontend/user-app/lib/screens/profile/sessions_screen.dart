import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/user_service.dart';
import '../../services/token_storage.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionModel> _sessions = [];
  bool _loading = true;
  String _currentSessionId = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  String _currentDeviceName() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isLinux) return 'Linux PC';
    return 'Unknown Device';
  }

  Future<void> _loadSessions() async {
    final currentId = await TokenStorage().getRefreshToken() ?? '';
    _currentSessionId = currentId;
    try {
      final sessions = await UserService().listMySessions();
      if (sessions.isEmpty) {
        _sessions = [
          SessionModel(
            id: 'current',
            ipAddress: 'This device',
            userAgent: _currentDeviceName(),
            createdAt: DateTime.now().toIso8601String(),
          ),
        ];
      } else {
        _sessions = sessions;
      }
      if (mounted) setState(() { _loading = false; });
    } catch (_) {
      _sessions = [
        SessionModel(
          id: 'current',
          ipAddress: 'This device',
          userAgent: _currentDeviceName(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _deleteSession(SessionModel session) async {
    try {
      await UserService().deleteSession(session.id);
      if (mounted) {
        setState(() => _sessions.removeWhere((s) => s.id == session.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session removed'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove session: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _revokeAll() async {
    try {
      for (final session in _sessions) {
        await UserService().deleteSession(session.id);
      }
      if (mounted) {
        setState(() => _sessions.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All sessions revoked'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke sessions: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Sessions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: ApexLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tc.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Manage devices where you\'re currently signed in. Revoke access for devices you don\'t recognize.',
                            style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text)),
                      const Spacer(),
                      if (_sessions.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                                title: const Text('Revoke All Sessions'),
                                content: Text('Are you sure you want to revoke all sessions? You will be signed out on all devices.', style: TextStyle(color: tc.subtitle)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancel', style: TextStyle(color: tc.subtitle)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showApexLoadingThen(context, _revokeAll, label: 'Revoking all...');
                                    },
                                    child: const Text('Revoke All', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Revoke All', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_sessions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Text('No active sessions', style: TextStyle(fontSize: 15, color: tc.subtitle)),
                      ),
                    )
                  else
                    ...List.generate(_sessions.length, (i) {
                      final session = _sessions[i];
                      final isCurrent = i == 0;
                      return Padding(
                        padding: EdgeInsets.only(bottom: i < _sessions.length - 1 ? 12 : 32),
                        child: _buildSessionCard(
                          session: session,
                          isCurrent: isCurrent,
                          context: context,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionCard({
    required SessionModel session,
    required bool isCurrent,
    BuildContext? context,
  }) {
    final tc = context!.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
        border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : tc.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _deviceIcon(session.userAgent),
              size: 22,
              color: isCurrent ? AppColors.primary : tc.subtitle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.userAgent ?? 'Unknown device',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text('IP: ${session.ipAddress ?? 'N/A'}', style: TextStyle(fontSize: 13, color: tc.subtitle)),
                const SizedBox(height: 4),
                Text(
                  _formatTime(session.createdAt),
                  style: TextStyle(fontSize: 12, color: isCurrent ? AppColors.success : tc.hint, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            GestureDetector(
              onTap: () => _confirmRemove(context, session),
              child: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
            ),
        ],
      ),
    );
  }

  IconData _deviceIcon(String? userAgent) {
    if (userAgent == null) return Icons.device_unknown_rounded;
    final ua = userAgent.toLowerCase();
    if (ua.contains('iphone') || ua.contains('ipad')) return Icons.phone_iphone_rounded;
    if (ua.contains('android') && ua.contains('samsung')) return Icons.phone_android_rounded;
    if (ua.contains('android')) return Icons.phone_android_rounded;
    if (ua.contains('windows')) return Icons.laptop_mac_rounded;
    if (ua.contains('mac') || ua.contains('safari')) return Icons.laptop_mac_rounded;
    if (ua.contains('firefox')) return Icons.laptop_mac_rounded;
    if (ua.contains('chrome')) return Icons.laptop_mac_rounded;
    return Icons.language_rounded;
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final dt = DateTime.parse(dateTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Active now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? 's' : ''} ago';
    } catch (_) {
      return dateTime;
    }
  }

  void _confirmRemove(BuildContext context, SessionModel session) {
    final tc = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Remove Device', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${session.userAgent ?? 'this device'}" from your sessions? You will be signed out on that device.',
          style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: tc.subtitle, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showApexLoadingThen(context, () => _deleteSession(session), label: 'Removing...');
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

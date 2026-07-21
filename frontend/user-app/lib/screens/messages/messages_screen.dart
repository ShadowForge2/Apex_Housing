import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/message_service.dart';
import '../profile/public_profile_screen.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messageService = MessageService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _messageService.listConversationsRaw();
      if (mounted) {
        setState(() {
          _conversations = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  void _showLockedDialog(ThemeColors tc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tc.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_rounded, color: AppColors.warning, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Chat Locked', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tc.text)),
            const SizedBox(height: 8),
            Text(
              'This conversation has been completed and is now locked. You can view the history but cannot send new messages.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tc.subtitle),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions(BuildContext context, String name, String userId, String role, bool isOnline) {
    final tc = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: tc.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary,
              child: Text(name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tc.text)),
            const SizedBox(height: 4),
            if (role.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: role.toUpperCase() == 'LANDLORD' ? AppColors.primary.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role.toUpperCase() == 'LANDLORD' ? 'Agent' : 'Tenant',
                    style: TextStyle(fontSize: 12, color: role.toUpperCase() == 'LANDLORD' ? AppColors.primary : AppColors.success, fontWeight: FontWeight.w600)),
              ),
            if (isOnline) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Online', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _sheetOption(
              context,
              icon: Icons.person_outline_rounded,
              title: 'View Profile',
              subtitle: 'See public profile',
              tc: tc,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(
                    name: name,
                    initials: name.isNotEmpty ? name[0] : '?',
                    role: role,
                    userId: userId,
                    isOnline: isOnline,
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption(BuildContext context, {required IconData icon, required String title, required String subtitle, required ThemeColors tc, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tc.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: tc.subtitle)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: tc.hint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Text('Messages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: tc.card,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(blurRadius: 15, color: tc.shadow)],
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Icon(Icons.search, color: tc.hint),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(border: InputBorder.none, hintText: 'Search conversations...', hintStyle: TextStyle(color: tc.hint)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: ApexLoading())
              : _error != null
                  ? _buildErrorState(tc)
                  : _conversations.isEmpty
                      ? _buildEmptyState(tc)
                      : RefreshIndicator(
                          onRefresh: _fetchConversations,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: tc.border),
                            itemBuilder: (_, i) {
                              final c = _conversations[i];
                              final participants = c['participants'] as List? ?? [];
                              final other = participants.isNotEmpty ? participants[0] : {};
                              final name = other['name'] ?? 'Unknown';
                              final userId = other['id'] ?? '';
                              final role = other['role'] ?? '';
                              final lastMsg = c['last_message'] ?? '';
                              final unread = c['unread_count'] ?? 0;
                              final timeStr = _formatTime(c['last_message_at']);
                              final isActive = c['is_active'] as bool? ?? true;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: isActive
                                      ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatDetailScreen(
                                              name: name,
                                              conversationId: c['id'] ?? '',
                                              otherUserId: userId,
                                              otherUserRole: role,
                                              isActive: isActive,
                                              conversationType: c['conversation_type']?.toString() ?? 'direct',
                                            ),
                                          ),
                                        ).then((_) => _fetchConversations())
                                      : () => _showLockedDialog(tc),
                                  leading: GestureDetector(
                                    onTap: () => _showProfileOptions(context, name, userId, role, false),
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: AppColors.primary,
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                          ),
                                        ),
                                        if (!isActive)
                                          Positioned(
                                            bottom: 0, right: 0,
                                            child: Container(
                                              width: 20, height: 20,
                                              decoration: BoxDecoration(
                                                color: AppColors.warning,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: tc.background, width: 2),
                                              ),
                                              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(name, style: TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 15,
                                          color: isActive ? tc.text : tc.subtitle,
                                        )),
                                      ),
                                      if (!isActive)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('Locked', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.warning)),
                                        ),
                                      if (role.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: role.toUpperCase() == 'LANDLORD' ? AppColors.primary.withOpacity(0.08) : AppColors.success.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            role.toUpperCase() == 'LANDLORD' ? 'Agent' : 'Tenant',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: role.toUpperCase() == 'LANDLORD' ? AppColors.primary : AppColors.success),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      isActive ? lastMsg : 'This conversation has been completed',
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: tc.hint, fontStyle: isActive ? FontStyle.normal : FontStyle.italic),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(timeStr, style: TextStyle(fontSize: 11, color: tc.hint)),
                                      const SizedBox(height: 6),
                                      if (unread > 0 && isActive)
                                        Container(
                                          width: 22, height: 22,
                                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                          child: Center(child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeColors tc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: tc.surface, shape: BoxShape.circle), child: Icon(Icons.chat_bubble_outline, size: 32, color: tc.hint)),
          const SizedBox(height: 16),
          Text('No conversations yet', style: TextStyle(color: tc.subtitle, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Start a conversation from a property listing', style: TextStyle(color: tc.hint, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeColors tc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 32, color: AppColors.error)),
            const SizedBox(height: 16),
            Text('Unable to connect', style: TextStyle(color: tc.subtitle, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Check your connection and try again', style: TextStyle(color: tc.hint, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _fetchConversations,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

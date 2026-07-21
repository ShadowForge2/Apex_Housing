import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../services/message_service.dart';
import '../../services/token_storage.dart';
import '../profile/public_profile_screen.dart';
import '../../widgets/apex_loading.dart';

enum MessageStatus { sent, delivered, read }

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String conversationId;
  final String otherUserId;
  final String otherUserRole;
  final bool isActive;
  final String conversationType;
  const ChatDetailScreen({
    super.key,
    required this.name,
    this.conversationId = '',
    this.otherUserId = '',
    this.otherUserRole = '',
    this.isActive = true,
    this.conversationType = 'direct',
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messageService = MessageService();
  late List<Map<String, dynamic>> _messages;
  bool _isLoadingMessages = false;

  bool get _isLocked => !widget.isActive;
  bool get _isAdminGroup => widget.conversationType == 'admin_group';

  @override
  void initState() {
    super.initState();
    _messages = [];
    _controller.addListener(() => setState(() {}));
    if (widget.conversationId.isNotEmpty) {
      _fetchMessages();
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoadingMessages = true);
    try {
      final currentUserId = await TokenStorage().getUserId();
      final models = await _messageService.getMessages(widget.conversationId);
      _messages = models.map((m) => {
        'id': m.id,
        'text': m.content ?? '',
        'isMe': m.senderId == currentUserId,
        'time': m.createdAt ?? '',
        'status': MessageStatus.read,
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load messages. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMessages = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();
    setState(() {
      _messages.add({'text': text, 'isMe': true, 'time': 'Now', 'status': MessageStatus.sent});
    });
    _scrollToBottom();

    if (widget.conversationId.isNotEmpty) {
      try {
        final sent = await _messageService.sendMessage(
          conversationId: widget.conversationId,
          content: text,
        );
        setState(() {
          final lastIdx = _messages.length - 1;
          _messages[lastIdx] = {..._messages[lastIdx], 'id': sent.id};
        });
        _progressTick();
      } catch (e) {
        if (mounted) {
          setState(() {
            final lastIdx = _messages.length - 1;
            _messages[lastIdx] = {..._messages[lastIdx], 'status': null, 'error': true};
          });
          final msg = e.toString();
          if (msg.contains('not allowed') || msg.contains('blocked') || msg.contains('prohibited')) {
            _showModerationWarning(msg);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send message')),
            );
          }
        }
      }
    }
  }

  void _showModerationWarning(String reason) {
    final tc = context.colors;
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
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.block_rounded, color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Message Blocked', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tc.text)),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tc.subtitle),
            ),
            const SizedBox(height: 8),
            Text(
              'All communication must stay on-platform for your protection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tc.hint),
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

  void _progressTick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _messages.last = {..._messages.last, 'status': MessageStatus.delivered});
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messages.last = {..._messages.last, 'status': MessageStatus.read});
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  PopupMenuItem<String> _popupItem(IconData icon, String text, ThemeColors tc) {
    return PopupMenuItem(value: text.toLowerCase(), child: Row(children: [
      Icon(icon, size: 18, color: tc.text), const SizedBox(width: 12),
      Text(text, style: TextStyle(fontSize: 14, color: tc.text)),
    ]));
  }

  void _showProfileOptions(BuildContext context) {
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: tc.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36, backgroundColor: AppColors.primary,
              child: Text(widget.name[0], style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            Text(widget.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tc.text)),
            const SizedBox(height: 4),
            Text(
              widget.otherUserRole.toUpperCase() == 'LANDLORD' ? 'Agent' : 'Tenant',
              style: TextStyle(fontSize: 13, color: tc.subtitle),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(
                    name: widget.name,
                    initials: widget.name.isNotEmpty ? widget.name[0] : '?',
                    role: widget.otherUserRole,
                    userId: widget.otherUserId,
                    isOnline: false,
                  ),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: tc.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person_outline_rounded, size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('View Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
                        const SizedBox(height: 2),
                        Text('See full public profile', style: TextStyle(fontSize: 12, color: tc.subtitle)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 22, color: tc.hint),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showProfileOptions(context),
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.primary,
              child: Text(widget.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tc.text)),
              if (_isLocked)
                const Text('Chat locked', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w400))
              else
                const Text('Online', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w400)),
            ]),
          ]),
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: tc.text), onPressed: () => Navigator.pop(context)),
        actions: [
          if (!_isLocked)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 22, color: tc.text),
              onSelected: (v) {
                if (v == 'report') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported')));
                if (v == 'block') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blocked')));
                if (v == 'mute') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted')));
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: tc.card, elevation: 6,
              itemBuilder: (_) => [
                _popupItem(Icons.flag_rounded, 'Report', tc),
                _popupItem(Icons.block_rounded, 'Block', tc),
                _popupItem(Icons.notifications_off_rounded, 'Mute', tc),
              ],
            ),
        ],
      ),
      body: Column(children: [
        if (_isLocked) _buildLockedBanner(tc),
        Expanded(child: _isLoadingMessages
            ? const Center(child: ApexLoading())
            : _messages.isEmpty
                ? _buildEmptyMessages(tc)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isMe = m['isMe'] as bool;
                      final status = m['status'] as MessageStatus?;
                      return _buildBubble(m['text'] as String, isMe, m['time'] as String, status);
                    },
                  )),
        if (!_isLocked) _buildInputBar(tc),
      ]),
    );
  }

  Widget _buildLockedBanner(ThemeColors tc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.2), width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This conversation has been completed and is locked. You can view the history for reference.',
              style: TextStyle(fontSize: 13, color: AppColors.warning.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages(ThemeColors tc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: tc.hint),
          const SizedBox(height: 12),
          Text(
            _isLocked ? 'No messages in this conversation' : 'No messages yet',
            style: TextStyle(color: tc.subtitle, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _isLocked ? 'History will appear here' : 'Send a message to start the conversation',
            style: TextStyle(color: tc.hint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isMe, String time, MessageStatus? status) {
    final tc = context.colors;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : tc.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 6), bottomRight: Radius.circular(isMe ? 6 : 20),
          ),
          boxShadow: [BoxShadow(blurRadius: 8, color: tc.shadow)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : tc.text, height: 1.4)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withValues(alpha: 0.7) : tc.hint)),
            if (isMe && status != null) ...[const SizedBox(width: 4), _buildTick(status)],
          ]),
        ]),
      ),
    );
  }

  Widget _buildTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:    return const Icon(Icons.check_rounded, size: 11, color: Color(0xFFB0B0B0));
      case MessageStatus.delivered: return const Icon(Icons.done_all_rounded, size: 11, color: Color(0xFFB0B0B0));
      case MessageStatus.read:    return const Icon(Icons.done_all_rounded, size: 11, color: Color(0xFF3B82F6));
    }
  }

  Widget _buildInputBar(ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(color: tc.background, border: Border(top: BorderSide(color: tc.border, width: 0.5))),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(color: tc.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _isAdminGroup ? 'Type a message...' : 'Type a message...',
                hintStyle: TextStyle(color: tc.hint, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

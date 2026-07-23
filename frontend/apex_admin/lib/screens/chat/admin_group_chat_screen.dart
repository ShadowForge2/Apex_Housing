import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_service.dart';
import '../../services/token_storage.dart';

class AdminGroupChatScreen extends StatefulWidget {
  final VoidCallback? onManageGroup;

  const AdminGroupChatScreen({
    super.key,
    this.onManageGroup,
  });

  @override
  State<AdminGroupChatScreen> createState() => _AdminGroupChatScreenState();
}

class _AdminGroupChatScreenState extends State<AdminGroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AdminService _adminService = AdminService();
  final TokenStorage _storage = TokenStorage();

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRefreshing = false;
  String _conversationId = '';
  String _currentUserId = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _currentUserId = (await _storage.getUserId()) ?? '';
    try {
      final chatResult = await _adminService.getAdminGroupChat();
      final data = chatResult['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _conversationId = data['conversation_id'] ?? '';
          _members = List<Map<String, dynamic>>.from(data['members'] ?? []);
          _isLoading = false;
        });
        _loadMessages();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final result = await _adminService.getAdminGroupChatMessages();
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final msgs = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        setState(() => _messages = msgs.reversed.toList());
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Failed to load messages: $e');
    }
  }

  Future<void> _refreshMessages() async {
    if (_conversationId.isEmpty || _isRefreshing || _isSending) return;
    _isRefreshing = true;
    try {
      final result = await _adminService.getAdminGroupChatMessages();
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final msgs = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        if (msgs.length != _messages.length) {
          setState(() => _messages = msgs.reversed.toList());
        }
      }
    } catch (_) {
    } finally {
      _isRefreshing = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final sentAt = DateTime.now().toIso8601String();
    setState(() {
      _isSending = true;
      _messages.add({
        'id': tempId,
        'content': text,
        'sender_id': _currentUserId,
        'sender_name': _getMyName(),
        'created_at': sentAt,
      });
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final result = await _adminService.sendGroupChatMessage(text);
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) {
            _messages[idx] = {
              'id': data['id'],
              'content': data['content'],
              'sender_id': data['sender_id'],
              'sender_name': _getMyName(),
              'created_at': data['created_at'],
            };
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['id'] == tempId));
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _getMyName() {
    final me = _members.where((m) => m['id'] == _currentUserId).toList();
    if (me.isNotEmpty) return me[0]['name'] ?? 'Admin';
    return 'Admin';
  }

  bool _isMe(String senderId) => senderId == _currentUserId;

  Map<String, dynamic> _getMember(String senderId) {
    final matches = _members.where((m) => m['id'] == senderId).toList();
    return matches.isNotEmpty ? matches[0] : {'name': 'Unknown', 'is_super_admin': false};
  }

  void _showMembersPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.xsAll,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Group Members (${_members.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _members.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isCurrentUser = member['id'] == _currentUserId;
                        final isSuperAdmin = member['is_super_admin'] == true;
                        final name = member['name'] ?? 'Unknown';
                        final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: AppRadius.mdAll,
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: (isSuperAdmin ? AppColors.primary : AppColors.subtitle).withValues(alpha: 0.15),
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSuperAdmin ? AppColors.primary : AppColors.subtitle,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.surface, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 6),
                                          const Text(
                                            '(You)',
                                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isSuperAdmin ? AppColors.primary : AppColors.subtitle).withValues(alpha: 0.1),
                                        borderRadius: AppRadius.xsAll,
                                      ),
                                      child: Text(
                                        isSuperAdmin ? 'Super Admin' : 'Admin',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isSuperAdmin ? AppColors.primary : AppColors.subtitle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.smAll,
          ),
          child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 22),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Team Chat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            GestureDetector(
              onTap: _showMembersPanel,
              child: Text(
                '${_members.length} members',
                style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onManageGroup,
            icon: const Icon(Icons.settings_rounded, color: AppColors.subtitle, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.border.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('No messages yet', style: TextStyle(fontSize: 14, color: AppColors.hint)),
                            const SizedBox(height: 4),
                            const Text('Start the conversation', style: TextStyle(fontSize: 12, color: AppColors.border)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderId = msg['sender_id'] ?? '';
                          final isMeFlag = _isMe(senderId);
                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              _buildMessageBubble(msg, isMeFlag),
                            ],
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 14, color: AppColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.hint),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isSending ? AppColors.hint : AppColors.primary,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final senderId = msg['sender_id'] ?? '';
    final member = _getMember(senderId);
    final name = msg['sender_name'] ?? member['name'] ?? 'Unknown';
    final content = msg['content'] ?? '';
    final createdAt = msg['created_at'];
    final isSuperAdmin = member['is_super_admin'] == true;

    DateTime? timestamp;
    if (createdAt != null) {
      try {
        timestamp = DateTime.parse(createdAt);
      } catch (_) {}
    }
    final timeStr = timestamp != null
        ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
        : '';

    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: (isSuperAdmin ? AppColors.primary : AppColors.subtitle).withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSuperAdmin ? AppColors.primary : AppColors.subtitle,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Container(
            margin: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : AppColors.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 12),
              ),
              boxShadow: AppShadow.minimal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                      if (isSuperAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: AppRadius.xsAll,
                          ),
                          child: const Text(
                            'Super Admin',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  content,
                  style: TextStyle(fontSize: 14, color: isMe ? Colors.white : AppColors.text, height: 1.4),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.hint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}

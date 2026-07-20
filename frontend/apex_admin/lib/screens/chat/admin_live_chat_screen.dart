import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_service.dart';
import '../../services/token_storage.dart';

class AdminLiveChatScreen extends StatefulWidget {
  const AdminLiveChatScreen({super.key});

  @override
  State<AdminLiveChatScreen> createState() => _AdminLiveChatScreenState();
}

class _AdminLiveChatScreenState extends State<AdminLiveChatScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  final TokenStorage _storage = TokenStorage();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String _currentUserId = '';

  final List<String> _filterOptions = ['All', 'Unread', 'Complaint'];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    _currentUserId = (await _storage.getUserId()) ?? '';
    try {
      final result = await _adminService.getConversations();
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final convs = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
        setState(() {
          _conversations = convs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalUnread => _conversations.fold<int>(0, (sum, c) => sum + ((c['unread_count'] ?? 0) as int));
  int get _unreadCount => _conversations.where((c) => ((c['unread_count'] ?? 0) as int) > 0).length;

  List<Map<String, dynamic>> get _filteredConversations {
    List<Map<String, dynamic>> list = List.from(_conversations);

    if (_selectedFilter == 'Unread') {
      list = list.where((c) => ((c['unread_count'] ?? 0) as int) > 0).toList();
    } else if (_selectedFilter == 'Complaint') {
      list = list.where((c) {
        final lastMsg = (c['last_message'] ?? '').toString();
        return lastMsg.toUpperCase().contains('COMPLAINT');
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final participants = c['participants'] as List<dynamic>? ?? [];
        final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
        final matchesParticipants = participants.any((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          return name.contains(q);
        });
        return matchesParticipants || lastMsg.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      final aTime = a['last_message_at'] ?? '';
      final bTime = b['last_message_at'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });
    return list;
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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return '';
    }
  }

  void _openConversation(Map<String, dynamic> conversation) async {
    final convId = conversation['id'];
    if (convId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatDetailScreen(
          conversationId: convId,
          conversation: conversation,
          currentUserId: _currentUserId,
        ),
      ),
    );
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Chat',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_conversations.length} conversations \u00b7 $_totalUnread unread',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.subtitle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgAll,
                  boxShadow: AppShadow.minimal,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.hint),
                    prefixIcon: const Icon(Icons.search, color: AppColors.hint, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.hint),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: AppRadius.lgAll, borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterOptions.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.subtitle,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.smAll,
                          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _filteredConversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.subtitle.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  'No conversations found',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.subtitle),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _loadConversations,
                            child: ListView.separated(
                              itemCount: _filteredConversations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return _buildConversationCard(_filteredConversations[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conv) {
    final participants = conv['participants'] as List<dynamic>? ?? [];
    final firstParticipant = participants.isNotEmpty ? participants[0] : null;
    final userName = firstParticipant?['name'] ?? 'Unknown';
    final userRole = firstParticipant?['role'] ?? 'User';
    final lastMessage = conv['last_message'] ?? '';
    final unreadCount = conv['unread_count'] ?? 0;
    final lastMessageAt = conv['last_message_at'];

    final initials = userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final isComplaint = lastMessage.toString().toUpperCase().contains('COMPLAINT');

    return GestureDetector(
      onTap: () => _openConversation(conv),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          boxShadow: AppShadow.minimal,
          border: unreadCount > 0
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isComplaint ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isComplaint ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
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
                          userName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isComplaint)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppRadius.xsAll,
                          ),
                          child: const Text(
                            'Complaint',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (userRole == 'LANDLORD' ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                      borderRadius: AppRadius.xsAll,
                    ),
                    child: Text(
                      userRole,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: userRole == 'LANDLORD' ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lastMessage,
                    style: const TextStyle(fontSize: 13, color: AppColors.subtitle, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatTime(lastMessageAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.hint),
                      ),
                      const Spacer(),
                      if (unreadCount > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
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

class _ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> conversation;
  final String currentUserId;

  const _ChatDetailScreen({
    required this.conversationId,
    required this.conversation,
    required this.currentUserId,
  });

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final result = await _adminService.getConversationMessages(widget.conversationId);
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final msgs = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshMessages() async {
    try {
      final result = await _adminService.getConversationMessages(widget.conversationId);
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        final msgs = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        if (msgs.length != _messages.length) {
          setState(() => _messages = msgs);
        }
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScrollController.hasClients) {
        _listScrollController.animateTo(
          _listScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputController.clear();

    try {
      await _adminService.sendMessage(widget.conversationId, text);
      await _refreshMessages();
    } catch (e) {
      if (mounted) {
        _inputController.text = text;
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

  String _formatMessageTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.conversation['participants'] as List<dynamic>? ?? [];
    final firstParticipant = participants.isNotEmpty ? participants[0] : null;
    final userName = firstParticipant?['name'] ?? 'Unknown';
    final userRole = firstParticipant?['role'] ?? 'User';
    final initials = userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  Text(
                    userRole,
                    style: const TextStyle(fontSize: 11, color: AppColors.hint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final senderId = msg['sender_id'] ?? '';
                      final isMe = senderId == widget.currentUserId;
                      final content = msg['content'] ?? '';
                      final createdAt = msg['created_at'];
                      final senderName = msg['sender_name'] ?? (isMe ? 'Admin' : 'User');
                      final showHeader = index == 0 || _messages[index - 1]['sender_id'] != senderId;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            top: showHeader ? 12 : 4,
                            left: isMe ? 60 : 0,
                            right: isMe ? 0 : 60,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    senderName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtitle),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? AppColors.primary : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 14),
                                  ),
                                  boxShadow: AppShadow.minimal,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe ? Colors.white : AppColors.text,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatMessageTime(createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.hint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
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
                        color: AppColors.surfaceVariant,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(fontSize: 14),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.hint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 18),
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
}

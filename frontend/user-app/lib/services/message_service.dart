import 'api_client.dart';

class ConversationModel {
  final String id;
  final List<String>? participantIds;
  final String? lastMessage;
  final String? lastMessageAt;
  final int? unreadCount;
  final String? createdAt;
  final bool isActive;
  final String conversationType;

  ConversationModel({
    required this.id,
    this.participantIds,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount,
    this.createdAt,
    this.isActive = true,
    this.conversationType = 'direct',
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id']?.toString() ?? '',
      participantIds: (json['participant_ids'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at']?.toString(),
      unreadCount: json['unread_count'] as int?,
      createdAt: json['created_at']?.toString(),
      isActive: json['is_active'] ?? true,
      conversationType: json['conversation_type']?.toString() ?? 'direct',
    );
  }
}

class MessageModel {
  final String id;
  final String? conversationId;
  final String? senderId;
  final String? content;
  final String? createdAt;
  final bool? read;

  MessageModel({
    required this.id,
    this.conversationId,
    this.senderId,
    this.content,
    this.createdAt,
    this.read,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString(),
      senderId: json['sender_id']?.toString(),
      content: json['content']?.toString(),
      createdAt: json['created_at']?.toString(),
      read: json['read'] as bool?,
    );
  }
}

class MessageService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Map<String, dynamic>>> listConversationsRaw() async {
    final response = await _client.get('/messages/conversations');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map && data['conversations'] is List) {
      return (data['conversations'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<ConversationModel>> listConversations() async {
    final response = await _client.get('/messages/conversations');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map && data['conversations'] is List) {
      return (data['conversations'] as List)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<MessageModel>> getMessages(String conversationId) async {
    final response =
        await _client.get('/messages/conversations/$conversationId/messages');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map && data['messages'] is List) {
      return (data['messages'] as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final response = await _client.post(
      '/messages/messages',
      data: {
        'conversation_id': conversationId,
        'content': content,
      },
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return MessageModel.fromJson(data);
  }

  Future<ConversationModel> createConversation({
    required List<String> participantIds,
  }) async {
    final response = await _client.post(
      '/messages/conversations',
      data: {
        'participant_ids': participantIds,
      },
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return ConversationModel.fromJson(data);
  }
}

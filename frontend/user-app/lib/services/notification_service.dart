import 'api_client.dart';

class NotificationModel {
  final String id;
  final String? title;
  final String? message;
  final String? type;
  final bool? read;
  final String? createdAt;

  NotificationModel({
    required this.id,
    this.title,
    this.message,
    this.type,
    this.read,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      type: json['type']?.toString(),
      read: json['read'] as bool?,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool inAppEnabled;

  NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.inAppEnabled,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['push_enabled'] ?? true,
      emailEnabled: json['email_enabled'] ?? true,
      inAppEnabled: json['in_app_enabled'] ?? true,
    );
  }
}

class NotificationService {
  final ApiClient _client = ApiClient.instance;

  Future<NotificationPreferences> getPreferences() async {
    final response = await _client.get('/notifications/preferences');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return NotificationPreferences.fromJson(data);
    }
    return NotificationPreferences(pushEnabled: true, emailEnabled: true, inAppEnabled: true);
  }

  Future<void> updatePreferences({bool? pushEnabled, bool? emailEnabled, bool? inAppEnabled}) async {
    final payload = <String, dynamic>{};
    if (pushEnabled != null) payload['push_enabled'] = pushEnabled;
    if (emailEnabled != null) payload['email_enabled'] = emailEnabled;
    if (inAppEnabled != null) payload['in_app_enabled'] = inAppEnabled;
    await _client.put('/notifications/preferences', data: payload);
  }

  Future<List<NotificationModel>> listNotifications({int page = 1}) async {
    final response = await _client.get(
      '/notifications/',
      queryParameters: {'page': page},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> markRead(String notificationId) async {
    await _client.put('/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _client.put('/notifications/read-all');
  }
}

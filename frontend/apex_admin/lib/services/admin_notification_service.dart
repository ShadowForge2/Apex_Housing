import 'package:dio/dio.dart';
import 'api_client.dart';
import 'exceptions.dart';

class AdminNotificationService {
  final ApiClient _client = ApiClient.instance;

  Map<String, dynamic> _parseResponse(Response response) {
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['message'] as String? ?? 'Operation failed',
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  Future<Map<String, dynamic>> listNotifications({int page = 1}) async {
    final response =
        await _client.get('/notifications/', queryParameters: {'page': page});
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> markRead(String notificationId) async {
    final response = await _client.put('/notifications/$notificationId/read');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> markAllRead() async {
    final response = await _client.put('/notifications/read-all');
    return _parseResponse(response);
  }
}

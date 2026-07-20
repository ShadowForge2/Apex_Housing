import 'package:dio/dio.dart';
import 'api_client.dart';
import 'exceptions.dart';

class AdminAnalyticsService {
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

  Future<Map<String, dynamic>> getOverview() async {
    final response = await _client.get('/admin/analytics/overview');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getActivity() async {
    final response = await _client.get('/admin/analytics/activity');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getSearchAnalytics() async {
    final response = await _client.get('/admin/analytics/searches');
    return _parseResponse(response);
  }
}

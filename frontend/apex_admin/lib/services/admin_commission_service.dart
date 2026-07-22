import 'package:dio/dio.dart';
import 'api_client.dart';
import 'exceptions.dart';

class AdminCommissionService {
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

  Future<Map<String, dynamic>> getRevenueSummary() async {
    final response = await _client.get('/admin/commission/revenue');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getCommissionLogs() async {
    final response = await _client.get('/admin/commission/logs');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getPlatformDeductions() async {
    final response = await _client.get('/admin/commission/platform-deductions');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> listCommissionRules() async {
    final response = await _client.get('/admin/commission/rules');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> createCommissionRule({
    required String name,
    required double percentage,
    required String roleType,
  }) async {
    final response = await _client.post('/admin/commission/rules', data: {
      'name': name,
      'percentage': percentage,
      'role_type': roleType,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> updateCommissionRule(
    String ruleId, {
    String? name,
    double? percentage,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (percentage != null) data['percentage'] = percentage;
    final response =
        await _client.put('/admin/commission/rules/$ruleId', data: data);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> deleteCommissionRule(String ruleId) async {
    final response = await _client.delete('/admin/commission/rules/$ruleId');
    return _parseResponse(response);
  }
}

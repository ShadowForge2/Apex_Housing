import 'package:dio/dio.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'exceptions.dart';

class AdminAuthService {
  final ApiClient _client = ApiClient.instance;
  final TokenStorage _storage = TokenStorage();

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

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final result = _parseResponse(response);
    final data = result['data'] as Map<String, dynamic>;

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw ApiException(message: 'Invalid login response: missing tokens');
    }

    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      await _storage.saveUser(
        id: user['id'] as String? ?? '',
        email: user['email'] as String? ?? email,
        role: user['role'] as String? ?? 'ADMIN',
        name: user['name'] as String? ??
            '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
        isSuperAdmin: data['is_super_admin'] as bool? ?? false,
      );
    } else {
      await _storage.saveUser(
        id: data['user_id'] as String? ?? '',
        email: email,
        role: 'ADMIN',
        isSuperAdmin: data['is_super_admin'] as bool? ?? false,
      );
    }

    return result;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _client.post('/auth/register', data: {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'role': 'ADMIN',
    });

    final result = _parseResponse(response);
    final data = result['data'] as Map<String, dynamic>;

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken != null && refreshToken != null) {
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        await _storage.saveUser(
          id: user['id'] as String? ?? '',
          email: user['email'] as String? ?? email,
          role: user['role'] as String? ?? 'ADMIN',
          name: '${firstName} ${lastName}',
          isSuperAdmin: data['is_super_admin'] as bool? ?? false,
        );
      } else {
        await _storage.saveUser(
          id: data['user_id'] as String? ?? '',
          email: email,
          role: 'ADMIN',
          name: '$firstName $lastName',
          isSuperAdmin: data['is_super_admin'] as bool? ?? false,
        );
      }
    }

    return result;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      await _client.post('/auth/logout', data: {
        if (refreshToken != null) 'refresh_token': refreshToken,
      });
    } catch (e) {
      // Clear tokens even if the server call fails
    } finally {
      await _storage.clearAll();
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final rt = await _storage.getRefreshToken();
    if (rt == null) {
      throw ApiException(message: 'No refresh token available');
    }

    final response = await _client.post('/auth/refresh', data: {
      'refresh_token': rt,
    });

    final result = _parseResponse(response);
    final data = result['data'] as Map<String, dynamic>;

    final accessToken = data['access_token'] as String?;
    final newRefreshToken = data['refresh_token'] as String?;

    if (accessToken != null && newRefreshToken != null) {
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
    }

    return result;
  }

  Future<Map<String, dynamic>> sendOtp({required String email, String purpose = 'verify'}) async {
    final response = await _client.post('/auth/send-otp', data: {
      'email': email,
      'purpose': purpose,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
  }) async {
    final response = await _client.post('/auth/verify-otp', data: {
      'email': email,
      'code': code,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    final response = await _client.post('/auth/password-reset/request', data: {
      'email': email,
    });
    return _parseResponse(response);
  }
}

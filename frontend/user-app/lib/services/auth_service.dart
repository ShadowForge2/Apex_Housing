import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'exceptions.dart';

class AuthService {
  final ApiClient _client = ApiClient.instance;
  final TokenStorage _storage = TokenStorage();

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String role,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _client.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'role': role,
        'first_name': firstName,
        'last_name': lastName,
      },
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken != null && refreshToken != null) {
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _storage.saveUser(
        id: data['user_id'] as String? ?? '',
        email: email,
        role: role,
        name: '$firstName $lastName'.trim(),
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

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
          role: user['role'] as String? ?? 'TENANT',
          name: '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
        );
      } else {
        await _storage.saveUser(
          id: data['user_id'] as String? ?? '',
          email: email,
          role: 'TENANT',
        );
      }
    }

    return data;
  }

  Future<Map<String, dynamic>> sendOtp({
    required String email,
    String purpose = 'verify',
  }) async {
    final response = await _client.post(
      '/auth/send-otp',
      data: {
        'email': email,
        'purpose': purpose,
      },
    );

    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> verifyOtp({
    String? email,
    required String code,
    String purpose = 'verify',
  }) async {
    final responseData = <String, dynamic>{
      'code': code,
      'purpose': purpose,
    };
    if (email != null) {
      responseData['email'] = email;
    }

    final response = await _client.post(
      '/auth/verify-otp',
      data: responseData,
    );

    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    final response = await _client.post(
      '/auth/password-reset/request',
      data: {'email': email},
    );

    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    final response = await _client.post(
      '/auth/password-reset/confirm',
      data: {
        'token': token,
        'new_password': newPassword,
      },
    );

    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final rt = await _storage.getRefreshToken();
    if (rt == null) {
      throw ApiException(message: 'No refresh token available');
    }

    final response = await _client.post(
      '/auth/refresh',
      data: {'refresh_token': rt},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken != null && refreshToken != null) {
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: '731881455826-i0hcol5ribhciar8bo0k8fpmmuf6oiv0.apps.googleusercontent.com',
    );

    await googleSignIn.signOut();
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      throw ApiException(message: 'Google sign-in was cancelled');
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw ApiException(message: 'Failed to get Google ID token');
    }

    final response = await _client.post(
      '/auth/google/verify-id-token',
      data: {'id_token': idToken},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

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
          email: user['email'] as String? ?? account.email,
          role: user['role'] as String? ?? 'TENANT',
          name: '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
        );
      }
    }

    return data;
  }

  Future<void> logout({required String refreshToken}) async {
    try {
      await _client.post(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } catch (_) {
    } finally {
      await _storage.clearAll();
    }
  }
}

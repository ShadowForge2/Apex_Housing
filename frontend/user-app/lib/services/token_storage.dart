import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyUserEmail = 'user_email';
  static const _keyUserRole = 'user_role';
  static const _keyUserName = 'user_name';
  static const _keyLastActiveRole = 'last_active_role';
  static const _keyInitialRole = 'initial_role';
  static const _biometricEnabledKey = 'biometricEnabled';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<void> saveUser({
    required String id,
    required String email,
    required String role,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, id);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserRole, role);
    if (name != null) {
      await prefs.setString(_keyUserName, name);
    }

    final existingInitial = prefs.getString(_keyInitialRole);
    if (existingInitial == null) {
      await prefs.setString(_keyInitialRole, role);
    }
    await prefs.setString(_keyLastActiveRole, role);
  }

  Future<void> saveLastActiveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastActiveRole, role);
  }

  Future<String?> getLastActiveRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastActiveRole);
  }

  Future<String?> getInitialRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyInitialRole);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _keyRefreshToken);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    return !(await isTokenExpired());
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyLastActiveRole);
    await prefs.remove(_keyInitialRole);
    await clearBiometric();
  }

  // Biometric credential storage (secure — stores refresh token, never password)
  Future<void> setBiometricEnabled({required String email, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, true);
    await _secureStorage.write(key: 'biometric_email', value: email);
    await _secureStorage.write(key: 'biometric_refresh_token', value: refreshToken);
  }

  Future<void> clearBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricEnabledKey);
    await _secureStorage.delete(key: 'biometric_email');
    await _secureStorage.delete(key: 'biometric_refresh_token');
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<String?> getBiometricEmail() async {
    return _secureStorage.read(key: 'biometric_email');
  }

  Future<String?> getBiometricRefreshToken() async {
    return _secureStorage.read(key: 'biometric_refresh_token');
  }

  Future<bool> isTokenExpired() async {
    final token = await getAccessToken();
    if (token == null) return true;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(decoded) as Map<String, dynamic>;

      if (!payloadMap.containsKey('exp')) return true;

      final exp = payloadMap['exp'] as int;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }
}

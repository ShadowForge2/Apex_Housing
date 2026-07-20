import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _userIdKey = 'userId';
  static const String _userEmailKey = 'userEmail';
  static const String _userRoleKey = 'userRole';
  static const String _userNameKey = 'userName';
  static const String _isSuperAdminKey = 'isSuperAdmin';
  static const String _biometricEnabledKey = 'biometricEnabled';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveUser({
    required String id,
    required String email,
    required String role,
    String? name,
    bool isSuperAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userRoleKey, role);
    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }
    await prefs.setBool(_isSuperAdminKey, isSuperAdmin);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<bool> getIsSuperAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSuperAdminKey) ?? false;
  }

  Future<void> setBiometricEnabled({required String email, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, true);
    await _secureStorage.write(key: 'admin_biometric_email', value: email);
    await _secureStorage.write(key: 'admin_biometric_refresh_token', value: refreshToken);
  }

  Future<void> clearBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricEnabledKey);
    await _secureStorage.delete(key: 'admin_biometric_email');
    await _secureStorage.delete(key: 'admin_biometric_refresh_token');
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<String?> getBiometricEmail() async {
    return _secureStorage.read(key: 'admin_biometric_email');
  }

  Future<String?> getBiometricRefreshToken() async {
    return _secureStorage.read(key: 'admin_biometric_refresh_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    if (token == null) return false;
    return !isTokenExpiredFromToken(token);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_isSuperAdminKey);
    await clearBiometric();
  }

  bool isTokenExpiredFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;

      if (!payloadMap.containsKey('exp')) return true;

      final exp = payloadMap['exp'] as int;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      return true;
    }
  }

  Future<bool> isTokenExpired() async {
    final token = await getAccessToken();
    if (token == null) return true;
    return isTokenExpiredFromToken(token);
  }
}

import 'package:flutter/foundation.dart';

class ApiConfig {
  // Use --dart-define=BASE_URL=https://apex-housing-api.onrender.com at build time.
  // In debug mode, falls back to localhost for local development.
  static const String _envBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      final url = _envBaseUrl;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw Exception(
          'Invalid BASE_URL: "$url". Must start with http:// or https://',
        );
      }
      if (kReleaseMode && url.startsWith('http://')) {
        throw Exception(
          'Insecure BASE_URL "$url" is not allowed in release builds. Use https://',
        );
      }
      return url;
    }

    // Debug builds: allow localhost for development convenience
    assert(
      () {
        return true;
      }(),
      'BASE_URL must be set via --dart-define=BASE_URL=... for release builds',
    );
    return 'http://localhost:8099';
  }

  static const String apiPrefix = '/api/v1';

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const Duration timeout = Duration(seconds: 30);

  static String get apiUrl => '$baseUrl$apiPrefix';
}

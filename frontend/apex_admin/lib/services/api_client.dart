import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_config.dart';
import 'exceptions.dart';
import 'token_storage.dart';

class SecurityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = base64Encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));

    options.headers['X-Request-Timestamp'] = timestamp;
    options.headers['X-Request-Nonce'] = nonce;
    options.headers['X-App-Platform'] = Platform.operatingSystem;
    options.headers['X-App-Version'] = '1.0.0';
    options.headers['X-App-Type'] = 'admin';

    if (kDebugMode) {
      options.headers['X-Debug-Mode'] = 'true';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.badCertificate) {
      debugPrint('[SECURITY] SSL certificate verification failed for ${err.requestOptions.uri}');
    }
    handler.next(err);
  }
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;

  late final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();
  Completer<bool>? _refreshCompleter;
  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiUrl,
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(SecurityInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.path != '/auth/refresh') {
            final refreshed = await _attemptTokenRefresh();
            if (refreshed) {
              final newToken = await _tokenStorage.getAccessToken();
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newToken';
              try {
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (_) {
                await _tokenStorage.clearAll();
                handler.next(error);
                return;
              }
            } else {
              await _tokenStorage.clearAll();
              _navigateToLogin();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  void _navigateToLogin() {
    final nav = _navigatorKey?.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<bool> _attemptTokenRefresh() async {
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      _refreshCompleter!.complete(false);
      _refreshCompleter = null;
      return false;
    }

    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiConfig.apiUrl,
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        headers: {'Content-Type': 'application/json'},
      ));
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          await _tokenStorage.saveTokens(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String,
          );
          _refreshCompleter!.complete(true);
          return true;
        }
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  void _handleError(DioException error) {
    String message;
    Map<String, dynamic>? errors;

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final body = error.response!.data;

      if (body is Map<String, dynamic>) {
        message = body['message'] as String? ?? body['detail'] as String? ?? 'An error occurred';
        errors = body['errors'] as Map<String, dynamic>?;
      } else {
        message = 'An error occurred';
      }

      throw ApiException(
        statusCode: statusCode,
        message: message,
        errors: errors,
      );
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Please check your network.';
      throw ApiException(message: message);
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'No internet connection.';
      throw ApiException(message: message);
    } else {
      message = 'An unexpected error occurred: ${error.message}';
      throw ApiException(message: message);
    }
  }

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.get(path, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.post(path, data: data, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response;
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response;
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_config.dart';
import 'token_storage.dart';
import 'exceptions.dart';

class SecurityInterceptor extends Interceptor {
  final _random = Random.secure();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = base64Encode(List<int>.generate(16, (_) => _random.nextInt(256)));

    options.headers['X-Request-Timestamp'] = timestamp;
    options.headers['X-Request-Nonce'] = nonce;
    if (!kIsWeb) {
      options.headers['X-App-Platform'] = Platform.operatingSystem;
    }
    options.headers['X-App-Version'] = '1.0.0';

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
  ApiClient._();

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  late final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();
  Completer<bool>? _refreshCompleter;
  GlobalKey<NavigatorState>? _navigatorKey;

  Dio get dio => _dio;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  ApiClient init() {
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
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    return this;
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        err.requestOptions.path != '/auth/refresh') {
      final refreshed = await _attemptTokenRefresh();
      if (refreshed) {
        final token = await _tokenStorage.getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await _dio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (_) {
          await _tokenStorage.clearAll();
          handler.next(err);
          return;
        }
      } else {
        await _tokenStorage.clearAll();
        _navigateToLogin();
      }
    }

    handler.next(err);
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
      final refreshDio = Dio(
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

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Response _handleResponse(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic> && body['success'] == false) {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['message']?.toString() ?? 'Unknown error',
        errors: body['errors'] as Map<String, dynamic>?,
      );
    }
    return response;
  }

  ApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out. Please check your internet.',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'No internet connection. Please try again.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        String message = 'Server error occurred.';
        Map<String, dynamic>? errors;
        if (body is Map<String, dynamic>) {
          message = body['message']?.toString() ?? message;
          errors = body['errors'] as Map<String, dynamic>?;
        }
        return ApiException(
          statusCode: statusCode,
          message: message,
          errors: errors,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');
      default:
        return ApiException(
          message: e.message ?? 'An unexpected error occurred.',
        );
    }
  }
}

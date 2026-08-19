import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/session_store.dart';
import '../constants/api_constants.dart';
import '../utils/debug_performance_logger.dart';

class ApiClient {
  final Dio dio;
  final Dio _refreshDio;
  final SessionStore sessionStore;

  Future<String>? _refreshFuture;

  ApiClient({Dio? dio, Dio? refreshDio, SessionStore? sessionStore})
    : dio = dio ?? Dio(_baseOptions()),
      _refreshDio = refreshDio ?? Dio(_baseOptions()),
      sessionStore = sessionStore ?? SessionStore() {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _handleRequest,
        onResponse: _handleResponse,
        onError: _handleError,
      ),
    );
  }

  static BaseOptions _baseOptions() {
    return BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      receiveTimeout: const Duration(seconds: 15),
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestStopwatch = Stopwatch()..start();
    options.extra['_perf_stopwatch'] = requestStopwatch;

    await sessionStore.initialize();
    final isRefreshRequest = options.path.endsWith(ApiConstants.refresh);
    final token = sessionStore.accessToken;
    if (!isRefreshRequest && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }

    if (kDebugMode) {
      final path = options.uri.path.isEmpty ? options.path : options.uri.path;
      DebugPerformanceLogger.log(
        'api',
        '${options.method.toUpperCase()} $path started',
      );
    }
    handler.next(options);
  }

  void _handleResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final requestStopwatch =
        response.requestOptions.extra.remove('_perf_stopwatch') as Stopwatch?;
    requestStopwatch?.stop();

    if (kDebugMode) {
      final path = response.requestOptions.uri.path.isEmpty
          ? response.requestOptions.path
          : response.requestOptions.uri.path;
      final elapsedMs = requestStopwatch?.elapsedMilliseconds;
      DebugPerformanceLogger.log(
        'api',
        '${response.requestOptions.method.toUpperCase()} '
            '$path -> ${response.statusCode ?? '-'}'
            '${elapsedMs == null ? '' : ' in ${elapsedMs}ms'}',
      );
    }

    handler.next(response);
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final requestStopwatch =
        request.extra.remove('_perf_stopwatch') as Stopwatch?;
    requestStopwatch?.stop();

    _logError(error, requestStopwatch?.elapsedMilliseconds);

    final isUnauthorized = error.response?.statusCode == 401;
    final isRefreshRequest = request.path.endsWith(ApiConstants.refresh);
    final wasRetried = request.extra['authRetried'] == true;
    if (!isUnauthorized || isRefreshRequest || wasRetried) {
      handler.next(error);
      return;
    }

    try {
      final accessToken = await (_refreshFuture ??= _refreshAccessToken());
      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'Bearer $accessToken';
      handler.resolve(await dio.fetch<dynamic>(request));
    } catch (_) {
      await sessionStore.expireSessionOnce();
      handler.next(error);
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String> _refreshAccessToken() async {
    await sessionStore.initialize();
    final refreshToken = sessionStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Missing refresh token.');
    }

    final response = await _refreshDio.post<dynamic>(
      ApiConstants.refresh,
      data: <String, dynamic>{'refresh_token': refreshToken},
      options: Options(
        headers: const <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    final rawData = response.data;
    if (rawData is! Map) {
      throw const FormatException('Invalid refresh response.');
    }

    final tokenPair = SessionTokenPair.fromAuthResponse(
      Map<String, dynamic>.from(rawData),
    );
    await sessionStore.saveTokenPair(tokenPair);
    return tokenPair.accessToken;
  }

  void _logError(DioException error, int? elapsedMilliseconds) {
    if (!kDebugMode) return;

    final path = error.requestOptions.uri.path.isEmpty
        ? error.requestOptions.path
        : error.requestOptions.uri.path;
    DebugPerformanceLogger.log(
      'api',
      '${error.requestOptions.method.toUpperCase()} '
          '$path -> ${error.response?.statusCode ?? 'error'}'
          '${elapsedMilliseconds == null ? '' : ' in ${elapsedMilliseconds}ms'}'
          ' | ${error.type.name}',
    );
  }

  void primeStoredTokenRead() {
    sessionStore.initialize();
  }
}

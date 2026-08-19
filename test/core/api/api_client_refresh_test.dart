import 'dart:convert';
import 'dart:typed_data';

import 'package:app_aila/core/api/api_client.dart';
import 'package:app_aila/core/auth/session_store.dart';
import 'package:app_aila/core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySessionStorage implements SessionStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

typedef _ResponseFactory = Future<ResponseBody> Function(RequestOptions);

class _DynamicAdapter implements HttpClientAdapter {
  final _ResponseFactory responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  _DynamicAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );
}

SessionTokenPair _oldPair() {
  return SessionTokenPair(
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
    accessTokenExpiresAt: DateTime.utc(2026, 7, 5),
    refreshTokenExpiresAt: DateTime.utc(2030, 8, 4),
  );
}

Map<String, dynamic> _newPairResponse() => <String, dynamic>{
  'access_token': 'new-access',
  'refresh_token': 'new-refresh',
  'access_token_expires_at': '2030-07-05T13:00:00.000Z',
  'refresh_token_expires_at': '2030-08-04T12:30:00.000Z',
};

Future<SessionStore> _sessionStore() async {
  final store = SessionStore(storage: _MemorySessionStorage());
  await store.saveTokenPair(_oldPair());
  return store;
}

void main() {
  test(
    'concurrent 401 responses share one refresh and retry both requests',
    () async {
      final store = await _sessionStore();
      final protectedAttempts = <String, int>{};
      final apiAdapter = _DynamicAdapter((request) async {
        protectedAttempts.update(
          request.path,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final authorization = request.headers['Authorization'];
        if (authorization == 'Bearer new-access') {
          return _jsonResponse(200, <String, dynamic>{'ok': true});
        }
        return _jsonResponse(401, <String, dynamic>{'message': 'expired'});
      });
      var refreshCalls = 0;
      final refreshAdapter = _DynamicAdapter((request) async {
        refreshCalls++;
        expect(request.path, ApiConstants.refresh);
        expect(request.headers, isNot(contains('Authorization')));
        expect(request.data, <String, dynamic>{'refresh_token': 'old-refresh'});
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonResponse(200, _newPairResponse());
      });
      final apiDio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = apiAdapter;
      final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = refreshAdapter;
      final client = ApiClient(
        dio: apiDio,
        refreshDio: refreshDio,
        sessionStore: store,
      );

      final responses = await Future.wait(<Future<Response<dynamic>>>[
        client.dio.get<dynamic>('/protected/one'),
        client.dio.get<dynamic>('/protected/two'),
      ]);

      expect(responses.map((response) => response.statusCode), <int?>[
        200,
        200,
      ]);
      expect(refreshCalls, 1);
      expect(protectedAttempts, <String, int>{
        '/protected/one': 2,
        '/protected/two': 2,
      });
      expect(store.accessToken, 'new-access');
      expect(store.refreshToken, 'new-refresh');
    },
  );

  test('refresh failure expires a concurrent session only once', () async {
    final store = await _sessionStore();
    var expirationCalls = 0;
    store.setExpirationHandler(() async => expirationCalls++);
    final apiAdapter = _DynamicAdapter(
      (_) async => _jsonResponse(401, <String, dynamic>{'message': 'expired'}),
    );
    var refreshCalls = 0;
    final refreshAdapter = _DynamicAdapter((_) async {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _jsonResponse(401, <String, dynamic>{
        'code': 'refresh_token_reused',
      });
    });
    final client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = apiAdapter,
      refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = refreshAdapter,
      sessionStore: store,
    );

    final failures = await Future.wait(<Future<DioException>>[
      client.dio
          .get<dynamic>('/protected/one')
          .then<DioException>((_) => throw StateError('Expected 401'))
          .catchError((Object error) => error as DioException),
      client.dio
          .get<dynamic>('/protected/two')
          .then<DioException>((_) => throw StateError('Expected 401'))
          .catchError((Object error) => error as DioException),
    ]);

    expect(failures, everyElement(isA<DioException>()));
    expect(refreshCalls, 1);
    expect(expirationCalls, 1);
    expect(store.hasSession, isFalse);
  });

  test(
    'a retried request that still returns 401 does not refresh in a loop',
    () async {
      final store = await _sessionStore();
      var refreshCalls = 0;
      final client = ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = _DynamicAdapter(
            (_) async => _jsonResponse(401, <String, dynamic>{}),
          ),
        refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = _DynamicAdapter((_) async {
            refreshCalls++;
            return _jsonResponse(200, _newPairResponse());
          }),
        sessionStore: store,
      );

      await expectLater(
        client.dio.get<dynamic>('/always-unauthorized'),
        throwsA(isA<DioException>()),
      );

      expect(refreshCalls, 1);
    },
  );
}

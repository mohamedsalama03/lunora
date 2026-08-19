import 'package:app_aila/core/api/api_client.dart';
import 'package:app_aila/core/api/auth_repository.dart';
import 'package:app_aila/core/auth/session_store.dart';
import 'package:app_aila/core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/queue_http_adapter.dart';

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

void main() {
  test(
    'deleteAccount sends DELETE to the authenticated account endpoint',
    () async {
      final adapter = QueueHttpAdapter([
        (_) => (statusCode: 200, body: <String, dynamic>{'message': 'deleted'}),
      ]);
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
        ..httpClientAdapter = adapter;
      final sessionStore = SessionStore(storage: _MemorySessionStorage());
      final repository = AuthRepository(
        apiClient: ApiClient(dio: dio, sessionStore: sessionStore),
      );

      await repository.deleteAccount(password: 'Secret123!');

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, ApiConstants.deleteAccount);
      expect(adapter.requests.single.data, <String, dynamic>{
        'password': 'Secret123!',
      });
    },
  );
}

import 'dart:convert';

import 'package:app_aila/core/auth/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySessionStorage implements SessionStorage {
  final Map<String, String> values = <String, String>{};
  int writes = 0;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }
}

SessionTokenPair _pair({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
}) {
  return SessionTokenPair(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: DateTime.utc(2030, 1, 1),
    refreshTokenExpiresAt: DateTime.utc(2030, 2, 1),
  );
}

void main() {
  test('stores the complete token pair as one secure-storage record', () async {
    final storage = _MemorySessionStorage();
    final store = SessionStore(storage: storage);

    await store.saveTokenPair(_pair());

    expect(storage.writes, 1);
    expect(storage.values.keys, contains(SessionStore.sessionKey));
    final saved = jsonDecode(storage.values[SessionStore.sessionKey]!) as Map;
    expect(saved['access_token'], 'access-1');
    expect(saved['refresh_token'], 'refresh-1');
    expect(storage.values, isNot(contains(SessionStore.legacyAccessTokenKey)));
  });

  test('restores a valid pair and removes an expired pair', () async {
    final storage = _MemorySessionStorage();
    storage.values[SessionStore.sessionKey] = jsonEncode(_pair().toJson());

    final validStore = SessionStore(storage: storage);
    await validStore.initialize();
    expect(validStore.hasSession, isTrue);

    storage.values[SessionStore.sessionKey] = jsonEncode(
      SessionTokenPair(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        accessTokenExpiresAt: DateTime.utc(2020),
        refreshTokenExpiresAt: DateTime.utc(2020, 2),
      ).toJson(),
    );
    final expiredStore = SessionStore(storage: storage);
    await expiredStore.initialize();

    expect(expiredStore.hasSession, isFalse);
    expect(storage.values, isNot(contains(SessionStore.sessionKey)));
  });

  test(
    'keeps a legacy access token until reauthentication is required',
    () async {
      final storage = _MemorySessionStorage()
        ..values[SessionStore.legacyAccessTokenKey] = 'legacy-access';
      final store = SessionStore(storage: storage);

      await store.initialize();

      expect(store.accessToken, 'legacy-access');
      expect(store.refreshToken, isEmpty);
    },
  );

  test('concurrent expiration calls clear and notify only once', () async {
    final storage = _MemorySessionStorage();
    final store = SessionStore(storage: storage);
    await store.saveTokenPair(_pair());
    var expirationCalls = 0;
    store.setExpirationHandler(() async {
      expirationCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    await Future.wait(<Future<void>>[
      store.expireSessionOnce(),
      store.expireSessionOnce(),
      store.expireSessionOnce(),
    ]);

    expect(store.hasSession, isFalse);
    expect(expirationCalls, 1);
  });

  test('rejects an incomplete authentication response', () {
    expect(
      () => SessionTokenPair.fromAuthResponse(<String, dynamic>{
        'access_token': 'access-only',
      }),
      throwsFormatException,
    );
  });
}

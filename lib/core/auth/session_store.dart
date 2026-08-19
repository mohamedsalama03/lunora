import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureSessionStorage implements SessionStorage {
  final FlutterSecureStorage storage;

  const SecureSessionStorage({this.storage = const FlutterSecureStorage()});

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class SessionTokenPair {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  const SessionTokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  factory SessionTokenPair.fromAuthResponse(Map<String, dynamic> data) {
    final accessToken = data['access_token']?.toString().trim() ?? '';
    final refreshToken = data['refresh_token']?.toString().trim() ?? '';
    final accessExpiresAt = DateTime.tryParse(
      data['access_token_expires_at']?.toString() ?? '',
    );
    final refreshExpiresAt = DateTime.tryParse(
      data['refresh_token_expires_at']?.toString() ?? '',
    );

    if (accessToken.isEmpty ||
        refreshToken.isEmpty ||
        accessExpiresAt == null ||
        refreshExpiresAt == null) {
      throw const FormatException('Invalid token-pair response.');
    }

    return SessionTokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessExpiresAt.toUtc(),
      refreshTokenExpiresAt: refreshExpiresAt.toUtc(),
    );
  }

  factory SessionTokenPair.fromJson(Map<String, dynamic> json) {
    return SessionTokenPair.fromAuthResponse(<String, dynamic>{
      'access_token': json['access_token'],
      'refresh_token': json['refresh_token'],
      'access_token_expires_at': json['access_token_expires_at'],
      'refresh_token_expires_at': json['refresh_token_expires_at'],
    });
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_token_expires_at': accessTokenExpiresAt.toUtc().toIso8601String(),
    'refresh_token_expires_at': refreshTokenExpiresAt.toUtc().toIso8601String(),
  };
}

class SessionStore {
  static const String sessionKey = 'auth_session_v2';
  static const String legacyAccessTokenKey = 'auth_token';

  final SessionStorage storage;

  SessionTokenPair? _tokenPair;
  Future<void>? _initializationFuture;
  Future<void>? _expirationFuture;
  Future<void> Function()? _onSessionExpired;

  SessionStore({SessionStorage? storage})
    : storage = storage ?? const SecureSessionStorage();

  SessionTokenPair? get tokenPair => _tokenPair;
  String? get accessToken => _tokenPair?.accessToken;
  String? get refreshToken => _tokenPair?.refreshToken;
  bool get hasSession => _tokenPair != null;

  Future<void> initialize() {
    return _initializationFuture ??= _initializeInternal();
  }

  void setExpirationHandler(Future<void> Function() handler) {
    _onSessionExpired = handler;
  }

  void clearExpirationHandler(Future<void> Function() handler) {
    if (_onSessionExpired == handler) {
      _onSessionExpired = null;
    }
  }

  Future<void> saveTokenPair(SessionTokenPair tokenPair) async {
    final encoded = jsonEncode(tokenPair.toJson());
    await storage.write(sessionKey, encoded);
    _tokenPair = tokenPair;
    try {
      await storage.delete(legacyAccessTokenKey);
    } catch (_) {
      // The atomic v2 record is already saved and remains the source of truth.
    }
  }

  Future<void> clear() async {
    _tokenPair = null;
    await Future.wait(<Future<void>>[
      storage.delete(sessionKey),
      storage.delete(legacyAccessTokenKey),
    ]);
  }

  Future<void> expireSessionOnce() {
    final existing = _expirationFuture;
    if (existing != null) return existing;

    final future = _expireSession();
    _expirationFuture = future;
    return future.whenComplete(() {
      if (identical(_expirationFuture, future)) {
        _expirationFuture = null;
      }
    });
  }

  Future<void> _initializeInternal() async {
    final rawSession = await storage.read(sessionKey);
    if (rawSession != null && rawSession.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSession);
        if (decoded is Map) {
          final pair = SessionTokenPair.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (pair.refreshTokenExpiresAt.isAfter(DateTime.now().toUtc())) {
            _tokenPair = pair;
            return;
          }
        }
      } catch (_) {
        // Corrupt or incomplete sessions are removed below.
      }
      await clear();
      return;
    }

    // Older app versions stored only the access token. It remains usable until
    // the first 401, after which the user must authenticate to obtain a pair.
    final legacyAccessToken = await storage.read(legacyAccessTokenKey);
    if (legacyAccessToken != null && legacyAccessToken.trim().isNotEmpty) {
      _tokenPair = SessionTokenPair(
        accessToken: legacyAccessToken.trim(),
        refreshToken: '',
        accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        refreshTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
      );
    }
  }

  Future<void> _expireSession() async {
    if (_tokenPair == null) return;
    await clear();
    await _onSessionExpired?.call();
  }
}

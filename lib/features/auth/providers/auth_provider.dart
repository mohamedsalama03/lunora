import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/auth_repository.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/models/user_model.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/utils/debug_performance_logger.dart';

class AuthProvider extends ChangeNotifier {
  static const String _cachedUserKey = 'cached_auth_user';

  final AuthRepository authRepository;
  final PushNotificationService pushNotificationService;

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitDone = false;
  bool _isRefreshingCurrentUser = false;
  Future<void>? _initFuture;
  Future<void>? _currentUserRefreshFuture;
  late final Future<void> Function() _sessionExpirationHandler;

  AuthProvider({
    required this.authRepository,
    required this.pushNotificationService,
  }) {
    _sessionExpirationHandler = _handleExpiredSession;
    sessionStore.setExpirationHandler(_sessionExpirationHandler);
  }

  SessionStore get sessionStore => authRepository.apiClient.sessionStore;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => sessionStore.hasSession;
  bool get isInitDone => _isInitDone;
  bool get isRefreshingCurrentUser => _isRefreshingCurrentUser;
  AuthRepository get repository => authRepository;

  Future<void> initAuth() async {
    _initFuture ??= _initAuthInternal();
    return _initFuture!;
  }

  Future<void> waitForInitialization() {
    return _initFuture ?? Future<void>.value();
  }

  Future<void> waitForCurrentUserRefresh() {
    return _currentUserRefreshFuture ?? Future<void>.value();
  }

  Future<void> _initAuthInternal() async {
    final stopwatch = Stopwatch()..start();
    DebugPerformanceLogger.log('startup', 'AuthProvider.initAuth started');

    final storageStopwatch = Stopwatch()..start();
    await sessionStore.initialize();
    storageStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'AuthProvider.initAuth storage read',
      storageStopwatch,
      extra: isAuthenticated ? 'token=found' : 'token=missing',
    );

    if (!isAuthenticated) {
      await _clearCachedUser();
      _isInitDone = true;
      stopwatch.stop();
      DebugPerformanceLogger.logElapsed(
        'startup',
        'AuthProvider.initAuth completed',
        stopwatch,
        extra: 'guest',
      );
      notifyListeners();
      return;
    }

    final cachedUserStopwatch = Stopwatch()..start();
    _user = await _loadCachedUser();
    cachedUserStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'AuthProvider.initAuth cached user read',
      cachedUserStopwatch,
      extra: _user == null ? 'user=missing' : 'user=found',
    );

    _isInitDone = true;
    notifyListeners();

    _currentUserRefreshFuture = _refreshCurrentUser();
    unawaited(_currentUserRefreshFuture!);

    stopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'AuthProvider.initAuth completed',
      stopwatch,
      extra: _user == null ? 'authenticated_no_cache' : 'authenticated_cached',
    );
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final data = await authRepository.login(email: email, password: password);
      await _handleAuthSuccess(data);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
    String name,
    String email,
    String? phone,
    String password,
    String passwordConfirmation,
  ) async {
    _setLoading(true);
    try {
      final data = await authRepository.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      await _handleAuthSuccess(data);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      if (isAuthenticated) {
        await pushNotificationService.unregisterCurrentDeviceToken();
        await authRepository.logout();
      }
    } catch (_) {
      // Ignore remote logout failures and clear session locally.
    } finally {
      _user = null;
      await sessionStore.clear();
      await _clearCachedUser();
      await pushNotificationService.clearSessionState();
      _setLoading(false);
    }
  }

  Future<void> deleteAccount({required String password}) async {
    _setLoading(true);
    try {
      await pushNotificationService.unregisterCurrentDeviceToken();
      await authRepository.deleteAccount(password: password);

      _user = null;
      await sessionStore.clear();
      await _clearCachedUser();
      await pushNotificationService.clearSessionState();
    } finally {
      _setLoading(false);
    }
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    unawaited(_cacheUser(updatedUser));
    notifyListeners();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> data) async {
    final tokenPair = SessionTokenPair.fromAuthResponse(data);
    final rawUser = data['user'];
    final authenticatedUser = rawUser is Map
        ? UserModel.fromJson(Map<String, dynamic>.from(rawUser))
        : null;

    await sessionStore.saveTokenPair(tokenPair);
    _user = authenticatedUser;

    if (_user != null) {
      await _cacheUser(_user!);
    }

    if (_user != null) {
      unawaited(pushNotificationService.onAuthenticated(_user!.id.toString()));
    }

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _refreshCurrentUser() async {
    _isRefreshingCurrentUser = true;
    notifyListeners();

    try {
      final meStopwatch = Stopwatch()..start();
      final freshUser = await authRepository.getCurrentUser();
      meStopwatch.stop();
      DebugPerformanceLogger.logElapsed(
        'startup',
        'AuthProvider.initAuth getCurrentUser',
        meStopwatch,
      );

      _user = freshUser;
      await _cacheUser(freshUser);

      unawaited(
        pushNotificationService.onAuthenticated(freshUser.id.toString()),
      );
    } catch (_) {
      await sessionStore.expireSessionOnce();
    } finally {
      _isRefreshingCurrentUser = false;
      notifyListeners();
    }
  }

  Future<UserModel?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString(_cachedUserKey);
      if (rawUser == null || rawUser.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(rawUser);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return UserModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }

  Future<void> _handleExpiredSession() async {
    _user = null;
    await _clearCachedUser();
    await pushNotificationService.clearSessionState();
    notifyListeners();
  }

  @override
  void dispose() {
    sessionStore.clearExpirationHandler(_sessionExpirationHandler);
    super.dispose();
  }
}

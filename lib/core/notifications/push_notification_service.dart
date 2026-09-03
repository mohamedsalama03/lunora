import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/notifications/models/app_notification_item.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../../features/notifications/repositories/notifications_api_repository.dart';
import '../../features/notifications/repositories/notifications_storage.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/profile/screens/orders_screen.dart' as profile_orders;
import '../../features/wallet/screens/wallet_screen.dart' as wallet;
import '../navigation/app_navigator.dart';
import '../navigation/app_shell_controller.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../utils/debug_performance_logger.dart';
import 'firebase_runtime_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await PushNotificationService.ensureFirebaseInitialized();

  final scope =
      await NotificationsStorage.getActiveUserScope() ??
      NotificationsStorage.guestScope;

  await NotificationsStorage.upsertNotification(
    scope: scope,
    item: AppNotificationItem.fromRemoteMessage(message),
  );
}

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService({
    required NotificationsApiRepository notificationsApiRepository,
    required NotificationsProvider notificationsProvider,
    required AppShellController shellController,
  }) : _notificationsApiRepository = notificationsApiRepository,
       _notificationsProvider = notificationsProvider,
       _shellController = shellController;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for transactional and order update notifications.',
        importance: Importance.max,
      );
  static const Duration _foregroundDuplicateWindow = Duration(seconds: 8);
  static const Duration _appleTokenRetryDelay = Duration(milliseconds: 500);
  static const int _appleTokenMaxAttempts = 20;
  static const String _globalTopic = 'global';

  final NotificationsApiRepository _notificationsApiRepository;
  final NotificationsProvider _notificationsProvider;
  final AppShellController _shellController;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;

  final Set<String> _handledTapIds = <String>{};
  final Map<String, DateTime> _recentForegroundNotificationKeys =
      <String, DateTime>{};

  bool _initialized = false;
  bool _firebaseReady = false;
  bool _isAuthenticated = false;
  bool _refreshNotificationStateOnResume = false;
  String? _currentUserScope;
  String? _currentFcmToken;
  String? _registeredTokenForSession;
  AppNotificationItem? _pendingNavigationItem;
  bool _globalTopicSubscribed = false;

  bool get isFirebaseReady => _firebaseReady;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      final runtimeOptions = FirebaseRuntimeOptions.currentPlatform;
      if (runtimeOptions == null) {
        return false;
      }

      try {
        await Firebase.initializeApp(options: runtimeOptions);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    DebugPerformanceLogger.log(
      'startup',
      'PushNotificationService.initialize started',
    );

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final firebaseStopwatch = Stopwatch()..start();
    _firebaseReady = await ensureFirebaseInitialized();
    firebaseStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'PushNotificationService.ensureFirebaseInitialized',
      firebaseStopwatch,
      extra: 'firebaseReady=$_firebaseReady',
    );

    if (!_firebaseReady) {
      _notificationsProvider.updatePushState(
        pushAvailable: false,
        permissionGranted: false,
        tokenSynced: false,
        requiresSystemSettings: false,
        statusMessage:
            'إعدادات Firebase غير مضافة داخل التطبيق. فعّلها قبل اختبار الإشعارات.',
      );
      stopwatch.stop();
      DebugPerformanceLogger.logElapsed(
        'startup',
        'PushNotificationService.initialize completed',
        stopwatch,
        extra: 'firebaseReady=false',
      );
      return;
    }

    final localNotificationsStopwatch = Stopwatch()..start();
    await _initializeLocalNotifications();
    localNotificationsStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'PushNotificationService._initializeLocalNotifications',
      localNotificationsStopwatch,
    );

    final messagingConfigStopwatch = Stopwatch()..start();
    await _messaging.setAutoInitEnabled(true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    messagingConfigStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'PushNotificationService.messagingConfig',
      messagingConfigStopwatch,
    );

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
    );
    _onMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _onMessageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );

    if (!_isAuthenticated) {
      await _notificationsProvider.setUserScope(
        NotificationsStorage.guestScope,
      );
      await refreshPermissionStatusAndSyncToken();
    }

    final initialMessageStopwatch = Stopwatch()..start();
    final initialMessage = await _messaging.getInitialMessage();
    initialMessageStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'PushNotificationService.getInitialMessage',
      initialMessageStopwatch,
      extra: initialMessage == null ? 'empty' : 'received',
    );
    if (initialMessage != null) {
      final item = await _storeMessage(initialMessage, unread: true);
      _pendingNavigationItem = item;
    }

    stopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'PushNotificationService.initialize completed',
      stopwatch,
      extra: 'firebaseReady=true',
    );
  }

  Future<void> onAuthenticated(String userScope) async {
    _isAuthenticated = true;
    _currentUserScope = userScope.trim();
    _registeredTokenForSession = null;
    _shellController.goHome();

    await _notificationsProvider.setUserScope(_currentUserScope);
    await initialize();

    if (!_firebaseReady) {
      return;
    }

    await requestPermissionAndSyncToken();
  }

  Future<void> unregisterCurrentDeviceToken() async {
    if (!_firebaseReady || !_isAuthenticated) {
      return;
    }

    final token = _currentFcmToken ?? await _getFcmTokenWhenReady();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _notificationsApiRepository.unregisterDeviceToken(token);
      _registeredTokenForSession = null;
    } catch (_) {
      // Best effort: logout should not fail because unregister failed.
    }
  }

  Future<void> clearSessionState() async {
    _isAuthenticated = false;
    _refreshNotificationStateOnResume = false;
    _currentUserScope = null;
    _currentFcmToken = null;
    _registeredTokenForSession = null;
    _pendingNavigationItem = null;
    _recentForegroundNotificationKeys.clear();
    _shellController.reset();
    await _notificationsProvider.setUserScope(NotificationsStorage.guestScope);
    _notificationsProvider.resetPushState();

    if (_firebaseReady) {
      await refreshPermissionStatusAndSyncToken();
    }
  }

  Future<void> onShellReady() async {
    await _processPendingNavigation();
  }

  Future<void> requestPermissionAndSyncToken() async {
    if (!_firebaseReady) {
      return;
    }

    final androidLocalNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidLocalNotifications?.requestNotificationsPermission();

    final notificationSettings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _syncTokenFromSettings(notificationSettings);
  }

  Future<void> refreshPermissionStatusAndSyncToken() async {
    if (!_firebaseReady) {
      return;
    }

    final notificationSettings = await _messaging.getNotificationSettings();
    await _syncTokenFromSettings(notificationSettings);
  }

  Future<void> openSystemNotificationSettings() async {
    _refreshNotificationStateOnResume = true;

    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } catch (_) {
      await AppSettings.openAppSettings();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_refreshNotificationStateOnResume) {
      return;
    }

    _refreshNotificationStateOnResume = false;
    unawaited(refreshPermissionStatusAndSyncToken());
  }

  Future<void> openNotificationItem(AppNotificationItem item) async {
    await _notificationsProvider.markAsRead(item.id);
    await _routeFromNotification(item);
  }

  Future<void> sendTestNotification() async {
    await _notificationsApiRepository.sendTestNotification(
      title: 'Hello from LUNORA',
      body: 'This is a test notification.',
      data: const {'type': 'test_notification', 'screen': 'notifications'},
    );
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _tokenRefreshSubscription?.cancel();
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedSubscription?.cancel();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }

        final raw = jsonDecode(payload);
        if (raw is! Map<String, dynamic>) {
          return;
        }

        final item = AppNotificationItem.fromJson(raw);
        await _notificationsProvider.addNotification(
          item.copyWith(source: AppNotificationSource.local),
        );
        await _handleTappedNotification(item);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _syncTokenFromSettings(
    NotificationSettings notificationSettings, {
    String? previousTokenHint,
  }) async {
    final permissionGranted =
        notificationSettings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        notificationSettings.authorizationStatus ==
            AuthorizationStatus.provisional;
    final requiresSystemSettings =
        notificationSettings.authorizationStatus == AuthorizationStatus.denied;

    _notificationsProvider.updatePushState(
      pushAvailable: true,
      permissionGranted: permissionGranted,
      tokenSynced: false,
      requiresSystemSettings: requiresSystemSettings,
      statusMessage: permissionGranted
          ? 'تم تفعيل الإشعارات على هذا الجهاز.'
          : requiresSystemSettings
          ? 'تم رفض الإشعارات من النظام. افتح إعدادات الجهاز ثم فعّل الإشعارات لهذا التطبيق.'
          : 'الإشعارات غير مفعلة على هذا الجهاز.',
    );

    if (!permissionGranted) {
      return;
    }

    final previousToken = previousTokenHint ?? _currentFcmToken;
    final token = await _getFcmTokenWhenReady();
    _currentFcmToken = token;
    if (kDebugMode) {
      debugPrint('FCM token obtained: ${token != null && token.isNotEmpty}');
    }

    if (token == null || token.isEmpty) {
      _notificationsProvider.updatePushState(
        pushAvailable: true,
        permissionGranted: true,
        tokenSynced: false,
        requiresSystemSettings: false,
        statusMessage: 'تعذر الحصول على FCM token من Firebase.',
      );
      return;
    }

    if (_isAuthenticated &&
        previousToken != null &&
        previousToken.isNotEmpty &&
        previousToken != token) {
      await _unregisterStaleDeviceToken(previousToken);
    }

    final globalTopicReady = await _ensureGlobalTopicSubscription();

    if (!_isAuthenticated) {
      _notificationsProvider.updatePushState(
        pushAvailable: true,
        permissionGranted: true,
        tokenSynced: globalTopicReady,
        requiresSystemSettings: false,
        statusMessage: globalTopicReady
            ? 'تم تفعيل الإشعارات العامة على هذا الجهاز.'
            : 'تم تفعيل الإذن لكن تعذر الاشتراك في الإشعارات العامة الآن.',
      );
      return;
    }

    if (_registeredTokenForSession == token) {
      _notificationsProvider.updatePushState(
        pushAvailable: true,
        permissionGranted: true,
        tokenSynced: globalTopicReady,
        requiresSystemSettings: false,
        statusMessage: globalTopicReady
            ? 'تمت مزامنة الجهاز مع الإشعارات.'
            : 'تم ربط الجهاز بالحساب، لكن تعذر الاشتراك في الإشعارات العامة الآن.',
      );
      return;
    }

    try {
      await _notificationsApiRepository.registerDeviceToken(
        token: token,
        platform: _platformKey,
        deviceName: await _deviceName(),
        appVersion: await _appVersion(),
      );
      if (kDebugMode) {
        debugPrint('FCM token synced to backend successfully.');
      }

      _registeredTokenForSession = token;
      _notificationsProvider.updatePushState(
        pushAvailable: true,
        permissionGranted: true,
        tokenSynced: globalTopicReady,
        requiresSystemSettings: false,
        statusMessage: globalTopicReady
            ? 'تمت مزامنة الجهاز مع الإشعارات.'
            : 'تم ربط الجهاز بالحساب، لكن تعذر الاشتراك في الإشعارات العامة الآن.',
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('FCM token sync to backend failed.');
      }
      _notificationsProvider.updatePushState(
        pushAvailable: true,
        permissionGranted: true,
        tokenSynced: false,
        requiresSystemSettings: false,
        statusMessage: 'تم تفعيل الإذن لكن تعذر ربط الجهاز مع الخادم الآن.',
      );
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    final previousToken = _currentFcmToken;
    _currentFcmToken = token;
    _registeredTokenForSession = null;
    _globalTopicSubscribed = false;

    if (!_firebaseReady) {
      return;
    }

    final notificationSettings = await _messaging.getNotificationSettings();
    await _syncTokenFromSettings(
      notificationSettings,
      previousTokenHint: previousToken,
    );
  }

  Future<String?> _getFcmTokenWhenReady() async {
    if (!kIsWeb && Platform.isIOS) {
      for (var attempt = 0; attempt < _appleTokenMaxAttempts; attempt++) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            break;
          }
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Unable to read APNs token: $error');
          }
        }

        if (attempt == _appleTokenMaxAttempts - 1) {
          if (kDebugMode) {
            debugPrint('APNs token was not available before the timeout.');
          }
          return null;
        }

        await Future<void>.delayed(_appleTokenRetryDelay);
      }
    }

    try {
      return await _messaging.getToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to obtain FCM token: $error');
      }
      return null;
    }
  }

  Future<bool> _ensureGlobalTopicSubscription() async {
    if (!_firebaseReady || _globalTopicSubscribed || kIsWeb) {
      return _globalTopicSubscribed;
    }

    try {
      await _messaging.subscribeToTopic(_globalTopic);
      _globalTopicSubscribed = true;
      if (kDebugMode) {
        debugPrint('Subscribed to FCM topic: $_globalTopic');
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Failed to subscribe to FCM topic: $_globalTopic');
      }
    }

    return _globalTopicSubscribed;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final item = await _storeMessage(message, unread: true);
    if (item.title.isEmpty && item.body.isEmpty) {
      return;
    }

    if (_shouldSkipDuplicateForegroundNotification(item)) {
      return;
    }

    await _showLocalNotification(item);
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final item = await _storeMessage(message, unread: true);
    await _handleTappedNotification(item);
  }

  Future<AppNotificationItem> _storeMessage(
    RemoteMessage message, {
    required bool unread,
  }) async {
    final item = AppNotificationItem.fromRemoteMessage(message, unread: unread);
    await _notificationsProvider.addNotification(item);
    return item;
  }

  Future<void> _showLocalNotification(AppNotificationItem item) async {
    await _localNotifications.show(
      id: item.id.hashCode,
      title: item.title,
      body: item.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: 'ic_notification',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(item.toJson()),
    );
  }

  Future<void> _unregisterStaleDeviceToken(String token) async {
    try {
      await _notificationsApiRepository.unregisterDeviceToken(token);
      if (kDebugMode) {
        debugPrint('Previous FCM token removed from backend.');
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Failed to remove previous FCM token from backend.');
      }
    }
  }

  bool _shouldSkipDuplicateForegroundNotification(AppNotificationItem item) {
    final now = DateTime.now();
    _recentForegroundNotificationKeys.removeWhere(
      (_, seenAt) => now.difference(seenAt) > _foregroundDuplicateWindow,
    );

    final key = _foregroundNotificationKey(item);
    final previousSeenAt = _recentForegroundNotificationKeys[key];
    _recentForegroundNotificationKeys[key] = now;

    return previousSeenAt != null &&
        now.difference(previousSeenAt) <= _foregroundDuplicateWindow;
  }

  String _foregroundNotificationKey(AppNotificationItem item) {
    return <String>[
      item.data['notification_id']?.trim() ?? '',
      item.type,
      item.screen,
      item.data['order_number']?.trim() ?? '',
      item.title.trim(),
      item.body.trim(),
    ].join('|').toLowerCase();
  }

  Future<void> _handleTappedNotification(AppNotificationItem item) async {
    if (_handledTapIds.contains(item.id)) {
      return;
    }

    _handledTapIds.add(item.id);

    if (!_isAuthenticated || AppNavigator.state == null) {
      _pendingNavigationItem = item;
      return;
    }

    await _notificationsProvider.markAsRead(item.id);
    await _routeFromNotification(item);
  }

  Future<void> _processPendingNavigation() async {
    if (!_isAuthenticated || AppNavigator.state == null) {
      return;
    }

    final item = _pendingNavigationItem;
    if (item == null) {
      return;
    }

    _pendingNavigationItem = null;
    await _notificationsProvider.markAsRead(item.id);
    await _routeFromNotification(item);
  }

  Future<void> _routeFromNotification(AppNotificationItem item) async {
    final screen = item.screen;
    if (screen == 'notifications' || screen.isEmpty) {
      AppNavigator.popToRoot();
      AppNavigator.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }

    final navigatorState = AppNavigator.state;
    if (navigatorState == null) {
      _pendingNavigationItem = item;
      return;
    }

    AppNavigator.popToRoot();

    switch (screen) {
      case 'order_details':
        final orderNumber = item.data['order_number']?.trim();
        if (orderNumber == null || orderNumber.isEmpty) {
          AppNavigator.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
          return;
        }

        await navigatorState.push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(orderNumber: orderNumber),
          ),
        );
        return;

      case 'orders':
        await navigatorState.push(
          MaterialPageRoute<void>(
            builder: (_) => const profile_orders.OrdersScreen(),
          ),
        );
        return;

      case 'wallet':
        await navigatorState.push(
          MaterialPageRoute<void>(builder: (_) => const wallet.WalletScreen()),
        );
        return;

      default:
        AppNavigator.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        return;
    }
  }

  Future<String?> _deviceName() async {
    if (kIsWeb) {
      return 'flutter-web';
    }

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      }

      if (Platform.isIOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        return info.name.trim().isNotEmpty
            ? info.name.trim()
            : info.utsname.machine;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String> _appVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  String get _platformKey {
    if (kIsWeb) {
      return 'web';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    return 'android';
  }
}

import 'package:flutter/material.dart';

import '../models/app_notification_item.dart';
import '../repositories/notifications_storage.dart';

class NotificationsProvider extends ChangeNotifier {
  List<AppNotificationItem> _items = <AppNotificationItem>[];
  String? _userScope;
  bool _isLoaded = false;
  bool _pushAvailable = false;
  bool _permissionGranted = false;
  bool _tokenSynced = false;
  bool _requiresSystemSettings = false;
  String? _statusMessage;

  List<AppNotificationItem> get items => _items;
  String? get userScope => _userScope;
  bool get isLoaded => _isLoaded;
  bool get pushAvailable => _pushAvailable;
  bool get permissionGranted => _permissionGranted;
  bool get tokenSynced => _tokenSynced;
  bool get requiresSystemSettings => _requiresSystemSettings;
  String? get statusMessage => _statusMessage;

  int get unreadCount => _items.where((item) => item.unread).length;

  Future<void> setUserScope(String? scope) async {
    final normalizedScope = scope?.trim();

    if (_userScope == normalizedScope && _isLoaded) {
      return;
    }

    _userScope = normalizedScope;
    await NotificationsStorage.setActiveUserScope(normalizedScope);

    if (normalizedScope == null || normalizedScope.isEmpty) {
      _items = <AppNotificationItem>[];
      _isLoaded = true;
      notifyListeners();
      return;
    }

    _items = await NotificationsStorage.loadInbox(normalizedScope);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> reload() async {
    if (_userScope == null || _userScope!.isEmpty) {
      _items = <AppNotificationItem>[];
      _isLoaded = true;
      notifyListeners();
      return;
    }

    _items = await NotificationsStorage.loadInbox(_userScope!);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addNotification(AppNotificationItem item) async {
    if (_userScope == null || _userScope!.isEmpty) {
      return;
    }

    _items = await NotificationsStorage.upsertNotification(
      scope: _userScope!,
      item: item,
    );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    if (_userScope == null || _userScope!.isEmpty) {
      return;
    }

    _items = await NotificationsStorage.markAsRead(scope: _userScope!, id: id);
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    if (_userScope == null || _userScope!.isEmpty) {
      return;
    }

    _items = await NotificationsStorage.markAllAsRead(_userScope!);
    notifyListeners();
  }

  void updatePushState({
    bool? pushAvailable,
    bool? permissionGranted,
    bool? tokenSynced,
    bool? requiresSystemSettings,
    String? statusMessage,
  }) {
    _pushAvailable = pushAvailable ?? _pushAvailable;
    _permissionGranted = permissionGranted ?? _permissionGranted;
    _tokenSynced = tokenSynced ?? _tokenSynced;
    _requiresSystemSettings = requiresSystemSettings ?? _requiresSystemSettings;
    _statusMessage = statusMessage;
    notifyListeners();
  }

  void resetPushState() {
    _pushAvailable = false;
    _permissionGranted = false;
    _tokenSynced = false;
    _requiresSystemSettings = false;
    _statusMessage = null;
    notifyListeners();
  }
}

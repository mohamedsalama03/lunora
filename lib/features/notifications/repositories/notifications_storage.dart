import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification_item.dart';

class NotificationsStorage {
  static const String guestScope = 'guest_global';
  static const String _activeUserScopeKey =
      'notifications_active_user_scope_v1';
  static const int _maxItems = 60;

  static Future<void> setActiveUserScope(String? scope) async {
    final prefs = await SharedPreferences.getInstance();

    if (scope == null || scope.trim().isEmpty) {
      await prefs.remove(_activeUserScopeKey);
      return;
    }

    await prefs.setString(_activeUserScopeKey, scope.trim());
  }

  static Future<String?> getActiveUserScope() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = prefs.getString(_activeUserScopeKey)?.trim();

    if (scope == null || scope.isEmpty) {
      return null;
    }

    return scope;
  }

  static Future<List<AppNotificationItem>> loadInbox(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_inboxKey(scope)) ?? <String>[];

    return items
        .map(
          (item) => AppNotificationItem.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  static Future<List<AppNotificationItem>> upsertNotification({
    required String scope,
    required AppNotificationItem item,
  }) async {
    final items = await loadInbox(scope);
    final existingIndex = items.indexWhere(
      (current) =>
          current.id == item.id ||
          (item.remoteMessageId != null &&
              item.remoteMessageId!.isNotEmpty &&
              current.remoteMessageId == item.remoteMessageId),
    );

    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      items[existingIndex] = item.copyWith(
        unread: existing.unread || item.unread,
      );
    } else {
      items.insert(0, item);
    }

    items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }

    await _saveInbox(scope, items);

    return items;
  }

  static Future<List<AppNotificationItem>> markAsRead({
    required String scope,
    required String id,
  }) async {
    final items = await loadInbox(scope);
    final updated = items
        .map((item) => item.id == id ? item.copyWith(unread: false) : item)
        .toList();

    await _saveInbox(scope, updated);

    return updated;
  }

  static Future<List<AppNotificationItem>> markAllAsRead(String scope) async {
    final items = await loadInbox(scope);
    final updated = items.map((item) => item.copyWith(unread: false)).toList();

    await _saveInbox(scope, updated);

    return updated;
  }

  static Future<void> clearScope(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inboxKey(scope));
  }

  static Future<void> _saveInbox(
    String scope,
    List<AppNotificationItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _inboxKey(scope),
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static String _inboxKey(String scope) => 'notifications_inbox_v1_$scope';
}

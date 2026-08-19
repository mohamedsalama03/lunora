import 'package:firebase_messaging/firebase_messaging.dart';

enum AppNotificationSource { remote, local }

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    required this.unread,
    required this.source,
    this.remoteMessageId,
  });

  final String id;
  final String title;
  final String body;
  final Map<String, String> data;
  final DateTime receivedAt;
  final bool unread;
  final AppNotificationSource source;
  final String? remoteMessageId;

  String get type => data['type']?.trim() ?? '';

  String get screen => data['screen']?.trim() ?? '';

  factory AppNotificationItem.fromRemoteMessage(
    RemoteMessage message, {
    bool unread = true,
  }) {
    final normalizedData = message.data.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final title =
        (message.notification?.title ?? normalizedData['title'] ?? 'إشعار جديد')
            .trim();
    final body = (message.notification?.body ?? normalizedData['body'] ?? '')
        .trim();
    final receivedAt = message.sentTime ?? DateTime.now();

    return AppNotificationItem(
      id: _buildId(
        remoteMessageId: message.messageId,
        title: title,
        body: body,
        receivedAt: receivedAt,
        data: normalizedData,
      ),
      remoteMessageId: message.messageId,
      title: title,
      body: body,
      data: normalizedData,
      receivedAt: receivedAt,
      unread: unread,
      source: AppNotificationSource.remote,
    );
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final normalizedData = <String, String>{};

    if (rawData is Map) {
      for (final entry in rawData.entries) {
        normalizedData[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }

    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      remoteMessageId: json['remote_message_id']?.toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      data: normalizedData,
      receivedAt:
          DateTime.tryParse((json['received_at'] ?? '').toString()) ??
          DateTime.now(),
      unread: json['unread'] == true || json['unread'] == 1,
      source: (json['source'] ?? 'remote').toString() == 'local'
          ? AppNotificationSource.local
          : AppNotificationSource.remote,
    );
  }

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, String>? data,
    DateTime? receivedAt,
    bool? unread,
    AppNotificationSource? source,
    String? remoteMessageId,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      receivedAt: receivedAt ?? this.receivedAt,
      unread: unread ?? this.unread,
      source: source ?? this.source,
      remoteMessageId: remoteMessageId ?? this.remoteMessageId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'remote_message_id': remoteMessageId,
      'title': title,
      'body': body,
      'data': data,
      'received_at': receivedAt.toIso8601String(),
      'unread': unread,
      'source': source.name,
    };
  }

  static String _buildId({
    required String? remoteMessageId,
    required String title,
    required String body,
    required DateTime receivedAt,
    required Map<String, String> data,
  }) {
    final base = remoteMessageId?.trim().isNotEmpty == true
        ? remoteMessageId!.trim()
        : '${receivedAt.microsecondsSinceEpoch}|${data['type'] ?? ''}|${data['screen'] ?? ''}|$title|$body';

    return base.replaceAll(RegExp(r'\s+'), '_');
  }
}

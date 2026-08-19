import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

class NotificationsApiRepository {
  NotificationsApiRepository({required this.dio});

  final Dio dio;

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    await dio.post(
      ApiConstants.deviceToken,
      data: {
        'token': token,
        'platform': platform,
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'device_name': deviceName.trim(),
        if (appVersion != null && appVersion.trim().isNotEmpty)
          'app_version': appVersion.trim(),
      },
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await dio.delete(ApiConstants.deviceToken, data: {'token': token});
  }

  Future<void> sendTestNotification({
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    await dio.post(
      ApiConstants.notificationsTest,
      data: {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
        if (data != null && data.isNotEmpty) 'data': data,
      },
    );
  }
}

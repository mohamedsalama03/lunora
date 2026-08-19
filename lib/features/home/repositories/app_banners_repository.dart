import 'package:dio/dio.dart';

import '../../../core/models/app_banner_model.dart';

class AppBannersRepository {
  AppBannersRepository({required this.dio});

  final Dio dio;

  Future<List<AppBannerItem>> fetchBanners() async {
    final response = await dio.get(
      '/api/flutter/app-banners',
      options: Options(
        headers: const <String, String>{'Accept': 'application/json'},
      ),
    );

    final payload = AppBannersResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );

    return payload.data;
  }
}

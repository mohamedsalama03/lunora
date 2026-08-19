import 'package:dio/dio.dart';

class OffersRepository {
  final Dio dio;

  OffersRepository({required this.dio});

  Future<Map<String, dynamic>> fetchOffers({String? token}) async {
    final response = await dio.get(
      '/api/flutter/offers',
      options: Options(
        headers: token == null
            ? null
            : <String, String>{'Authorization': 'Bearer $token'},
      ),
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}

import 'package:dio/dio.dart';
import '../models/logo_model.dart';
import '../constants/api_constants.dart';

class LogoService {
  static const String _logoEndpoint = '/api/flutter/logo';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );

  Future<LogoModel> fetchLogo() async {
    final response = await _dio.get(_logoEndpoint);
    return LogoModel.fromJson(response.data as Map<String, dynamic>);
  }
}

import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/address_model.dart';

class AddressRepository {
  final ApiClient _client;

  AddressRepository(this._client);

  // ── Map Config ──────────────────────────────────────────────────────────────

  /// GET /api/flutter/addresses/map-config
  Future<MapConfig> fetchMapConfig() async {
    try {
      final response = await _client.dio.get(ApiConstants.addressMapConfig);
      return MapConfig.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر تحميل إعدادات الخريطة');
    }
  }

  // ── CRUD العناوين ────────────────────────────────────────────────────────────

  /// GET /api/flutter/addresses
  Future<List<AddressModel>> fetchAddresses() async {
    try {
      final response = await _client.dio.get(ApiConstants.addresses);
      final data = response.data['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر تحميل العناوين');
    }
  }

  /// POST /api/flutter/addresses
  Future<AddressModel> createAddress(Map<String, dynamic> body) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.addresses,
        data: body,
      );
      return AddressModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر حفظ العنوان');
    }
  }

  /// PUT /api/flutter/addresses/{id}
  Future<AddressModel> updateAddress(int id, Map<String, dynamic> body) async {
    try {
      final response = await _client.dio.put(
        '${ApiConstants.addresses}/$id',
        data: body,
      );
      return AddressModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر تحديث العنوان');
    }
  }

  /// DELETE /api/flutter/addresses/{id}
  Future<void> deleteAddress(int id) async {
    try {
      await _client.dio.delete('${ApiConstants.addresses}/$id');
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر حذف العنوان');
    }
  }

  /// POST /api/flutter/addresses/{id}/set-default
  Future<void> setDefaultAddress(int id) async {
    try {
      await _client.dio.post('${ApiConstants.addresses}/$id/set-default');
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر تعيين العنوان الافتراضي');
    }
  }

  // ── Routes ──────────────────────────────────────────────────────────────────

  /// POST /api/flutter/routes/estimate
  Future<RouteEstimateResult> estimateRoute({
    required AddressLocation origin,
    required AddressLocation destination,
    String vehicleType = 'car',
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.routeEstimate,
        data: {
          'origin': origin.toJson(),
          'destination': destination.toJson(),
          'vehicle_type': vehicleType,
        },
      );
      return RouteEstimateResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e, 'تعذر حساب المسافة');
    }
  }

  // ── Error Handler ────────────────────────────────────────────────────────────

  String _handleError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      return (data['message'] as String?) ??
          (data['error'] as String?) ??
          fallback;
    }
    return fallback;
  }
}

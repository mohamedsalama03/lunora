import 'package:dio/dio.dart';

import '../../../core/config/maps_api_key.dart';

/// خدمة Geocoding مباشرة عبر Google Geocoding API
/// يُستخدم للـ Reverse Geocoding (إحداثيات → عنوان)
class GeocodingService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  static String get _apiKey => MapsApiKey.current;

  final Dio _dio;

  GeocodingService() : _dio = Dio();

  /// تحويل إحداثيات إلى عنوان مقروء
  Future<GeocodingResult?> reverseGeocode(
    double lat,
    double lng, {
    String language = 'ar',
  }) async {
    if (_apiKey.isEmpty) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: {
          'latlng': '$lat,$lng',
          'language': language,
          'key': _apiKey,
        },
      );

      final data = response.data;
      if (data == null) return null;

      final status = data['status'] as String?;
      if (status != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      return GeocodingResult.fromJson(first);
    } catch (_) {
      return null;
    }
  }
}

/// نتيجة Geocoding لعنوان واحد
class GeocodingResult {
  final String formattedAddress;
  final String placeId;
  final String street;
  final String city;
  final String country;
  final String postalCode;

  const GeocodingResult({
    required this.formattedAddress,
    required this.placeId,
    required this.street,
    required this.city,
    required this.country,
    required this.postalCode,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    final components =
        (json['address_components'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    String extract(String type) {
      final match = components.firstWhere(
        (c) => (c['types'] as List<dynamic>).contains(type),
        orElse: () => <String, dynamic>{},
      );
      return (match['long_name'] as String?) ?? '';
    }

    final route = extract('route');
    final streetNumber = extract('street_number');
    final street = [streetNumber, route].where((s) => s.isNotEmpty).join(' ');

    return GeocodingResult(
      formattedAddress: json['formatted_address'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
      street: street,
      city: extract('locality').isNotEmpty
          ? extract('locality')
          : extract('administrative_area_level_1'),
      country: extract('country'),
      postalCode: extract('postal_code'),
    );
  }
}

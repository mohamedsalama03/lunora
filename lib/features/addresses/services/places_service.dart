import 'package:dio/dio.dart';

import '../../../core/config/maps_api_key.dart';

/// خدمة Google Places Autocomplete عبر HTTP مباشرة
/// لا تحتاج إلى SDK خارجي — تعمل بنفس المفتاح المضبوط في AndroidManifest / Info.plist
class PlacesService {
  static const String _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  // (للاستدعاء الداخلي Server/Browser key نفس) Android SDK key نستخدم
  static String get _apiKey => MapsApiKey.current;

  final Dio _dio;

  PlacesService() : _dio = Dio();

  /// بحث نصي بـ autocomplete مقيّد بليبيا
  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    if (_apiKey.isEmpty) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _autocompleteUrl,
        queryParameters: {
          'input': input,
          'components': 'country:LY',
          'language': 'ar',
          'key': _apiKey,
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') return [];
      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return predictions
          .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// جلب تفاصيل مكان بـ placeId
  Future<PlaceDetails?> getDetails(String placeId) async {
    if (_apiKey.isEmpty) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _detailsUrl,
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry,formatted_address,name,address_components',
          'language': 'ar',
          'key': _apiKey,
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') return null;
      return PlaceDetails.fromJson(data['result'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// اقتراح autocomplete
class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String description;

  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.description,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured =
        json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlacePrediction(
      placeId: json['place_id'] as String? ?? '',
      mainText: structured['main_text'] as String? ?? '',
      secondaryText: structured['secondary_text'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

/// تفاصيل مكان (موقع + عنوان)
class PlaceDetails {
  final double lat;
  final double lng;
  final String formattedAddress;
  final String name;

  const PlaceDetails({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
    required this.name,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    return PlaceDetails(
      lat: (location['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0.0,
      formattedAddress: json['formatted_address'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

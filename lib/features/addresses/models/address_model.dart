import 'dart:math' as math;

class AddressLocation {
  final double lat;
  final double lng;

  const AddressLocation({required this.lat, required this.lng});

  factory AddressLocation.fromJson(Map<String, dynamic> json) {
    return AddressLocation(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  bool get hasUsableCoordinates {
    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }
}

class AddressModel {
  final int id;
  final String label;
  final String fullName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String country;
  final String? postalCode;
  final String formattedAddress;
  final String? placeId;
  final AddressLocation location;
  final String? notes;
  final bool isDefault;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const AddressModel({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    required this.country,
    this.postalCode,
    required this.formattedAddress,
    this.placeId,
    required this.location,
    this.notes,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      addressLine1: json['address_line1'] as String? ?? '',
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'Libya',
      postalCode: json['postal_code'] as String?,
      formattedAddress: json['formatted_address'] as String? ?? '',
      placeId: json['place_id'] as String?,
      location: json['location'] != null
          ? AddressLocation.fromJson(json['location'] as Map<String, dynamic>)
          : const AddressLocation(lat: 0, lng: 0),
      notes: json['notes'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  AddressModel copyWith({bool? isDefault, String? label, String? notes}) {
    return AddressModel(
      id: id,
      label: label ?? this.label,
      fullName: fullName,
      phone: phone,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
      formattedAddress: formattedAddress,
      placeId: placeId,
      location: location,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class SupportedCity {
  final String name;
  final double shippingCost;
  final AddressLocation location;

  const SupportedCity({
    required this.name,
    required this.shippingCost,
    required this.location,
  });

  factory SupportedCity.fromJson(Map<String, dynamic> json) {
    return SupportedCity(
      name: json['name'] as String? ?? '',
      shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] != null
          ? AddressLocation.fromJson(json['location'] as Map<String, dynamic>)
          : const AddressLocation(lat: 0, lng: 0),
    );
  }
}

class MapConfigValidation {
  final List<String> requiredFields;
  final String phoneRegex;
  final bool supportsFormattedAddress;
  final bool supportsPlaceId;

  const MapConfigValidation({
    required this.requiredFields,
    required this.phoneRegex,
    required this.supportsFormattedAddress,
    required this.supportsPlaceId,
  });

  factory MapConfigValidation.fromJson(Map<String, dynamic> json) {
    return MapConfigValidation(
      requiredFields:
          (json['required_fields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      phoneRegex: json['phone_regex'] as String? ?? r'^09\d{8}$',
      supportsFormattedAddress:
          json['supports_formatted_address'] as bool? ?? true,
      supportsPlaceId: json['supports_place_id'] as bool? ?? true,
    );
  }
}

class MapConfig {
  final String mapProvider;
  final AddressLocation defaultCenter;
  final AddressLocation storeLocation;
  final AddressModel? defaultAddress;
  final List<SupportedCity> supportedCities;
  final MapConfigValidation validation;
  final bool requiresSupportedCity;
  final double misrataBoundaryKm;
  final String defaultCountry;

  const MapConfig({
    required this.mapProvider,
    required this.defaultCenter,
    required this.storeLocation,
    this.defaultAddress,
    required this.supportedCities,
    required this.validation,
    required this.requiresSupportedCity,
    required this.misrataBoundaryKm,
    required this.defaultCountry,
  });

  factory MapConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final checkout = data['checkout'] as Map<String, dynamic>? ?? {};
    final defaults = data['defaults'] as Map<String, dynamic>? ?? {};

    return MapConfig(
      mapProvider: data['map_provider'] as String? ?? 'google_maps',
      defaultCenter: AddressLocation.fromJson(
        data['default_center'] as Map<String, dynamic>? ?? {},
      ),
      storeLocation: AddressLocation.fromJson(
        data['store_location'] as Map<String, dynamic>? ?? {},
      ),
      defaultAddress: data['default_address'] != null
          ? AddressModel.fromJson(
              data['default_address'] as Map<String, dynamic>,
            )
          : null,
      supportedCities:
          (data['supported_cities'] as List<dynamic>?)
              ?.map((e) => SupportedCity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      validation: data['validation'] != null
          ? MapConfigValidation.fromJson(
              data['validation'] as Map<String, dynamic>,
            )
          : const MapConfigValidation(
              requiredFields: ['latitude', 'longitude', 'city'],
              phoneRegex: r'^09\d{8}$',
              supportsFormattedAddress: true,
              supportsPlaceId: true,
            ),
      requiresSupportedCity:
          checkout['requires_supported_city'] as bool? ?? true,
      misrataBoundaryKm:
          (checkout['misrata_boundary_km'] as num?)?.toDouble() ?? 35.0,
      defaultCountry: defaults['country'] as String? ?? 'Libya',
    );
  }

  SupportedCity? findCity(String name) {
    final normalizedCandidate = _normalizeCityCandidate(name);
    if (normalizedCandidate.isEmpty) return null;

    final aliasCandidate = _romanizedAlias(normalizedCandidate);

    for (final city in supportedCities) {
      final normalizedCity = _normalizeCityCandidate(city.name);
      final aliasCity = _romanizedAlias(normalizedCity);

      if (normalizedCity == normalizedCandidate ||
          (aliasCandidate.isNotEmpty && aliasCity == aliasCandidate)) {
        return city;
      }

      final hasPartialMatch =
          normalizedCity.contains(normalizedCandidate) ||
          normalizedCandidate.contains(normalizedCity) ||
          (aliasCandidate.isNotEmpty &&
              (aliasCity.contains(aliasCandidate) ||
                  aliasCandidate.contains(aliasCity)));

      if (hasPartialMatch) {
        return city;
      }
    }

    return null;
  }

  SupportedCity? findSupportedCity(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final matched = findCity(candidate ?? '');
      if (matched != null) {
        return matched;
      }
    }

    return null;
  }

  SupportedCity? get misrataCity => findCity('مصراتة');

  bool isInsideMisrataBoundary({
    required double lat,
    required double lng,
    String detectedCity = '',
  }) {
    final misrata = misrataCity;

    final normalizedDetectedCity = _normalizeCityCandidate(detectedCity);
    final normalizedMisrata = misrata != null
        ? _normalizeCityCandidate(misrata.name)
        : _normalizeCityCandidate('مصراتة');
    final detectedAlias = _romanizedAlias(normalizedDetectedCity);
    final misrataAlias = _romanizedAlias(normalizedMisrata);

    if (normalizedDetectedCity.isNotEmpty &&
        (normalizedDetectedCity == normalizedMisrata ||
            normalizedDetectedCity.contains(normalizedMisrata) ||
            normalizedMisrata.contains(normalizedDetectedCity) ||
            (detectedAlias.isNotEmpty &&
                (detectedAlias == misrataAlias ||
                    detectedAlias.contains(misrataAlias) ||
                    misrataAlias.contains(detectedAlias))))) {
      return true;
    }

    AddressLocation? referenceLocation;
    if (misrata != null && misrata.location.hasUsableCoordinates) {
      referenceLocation = misrata.location;
    } else if (storeLocation.hasUsableCoordinates) {
      referenceLocation = storeLocation;
    } else if (defaultCenter.hasUsableCoordinates) {
      referenceLocation = defaultCenter;
    }

    if (referenceLocation == null) {
      return false;
    }

    return _haversineKilometers(
          lat,
          lng,
          referenceLocation.lat,
          referenceLocation.lng,
        ) <=
        math.max(1, misrataBoundaryKm);
  }

  String _normalizeCityCandidate(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[\u0623\u0625\u0622\u0671]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[ىي]'), 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(
          RegExp(
            r'\b(مدينة|مدينه|بلدية|بلديه|محافظة|محافظه|ولاية|ولايه|منطقة|منطقه|شعبية|شعبيه|حي)\b',
            unicode: true,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
  }

  String _romanizedAlias(String normalizedValue) {
    switch (normalizedValue) {
      case 'misrata':
      case 'musrata':
      case 'misurata':
        return 'misrata';
      case 'مصراته':
        return 'misrata';
      default:
        return normalizedValue;
    }
  }

  double _haversineKilometers(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(toLat - fromLat);
    final dLng = _degreesToRadians(toLng - fromLng);
    final startLat = _degreesToRadians(fromLat);
    final endLat = _degreesToRadians(toLat);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(startLat) *
            math.cos(endLat);

    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

class RouteEstimateResult {
  final double distanceKm;
  final int durationMinutes;
  final String distanceText;
  final String durationText;
  final String? polyline;

  const RouteEstimateResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
    this.polyline,
  });

  factory RouteEstimateResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return RouteEstimateResult(
      distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: data['duration_minutes'] as int? ?? 0,
      distanceText: data['distance_text'] as String? ?? '',
      durationText: data['duration_text'] as String? ?? '',
      polyline: data['polyline'] as String?,
    );
  }
}

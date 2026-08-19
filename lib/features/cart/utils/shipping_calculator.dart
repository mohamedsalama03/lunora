import '../../addresses/models/address_model.dart';
import '../../orders/models/order_model.dart';

/// منطق حساب رسوم التوصيل المشترك بين صفحة السلة وصفحة الدفع (checkout).
///
/// يحسب التكلفة اعتماداً على العنوان المحدد:
/// - داخل مصراتة: تكلفة أساسية + تكلفة لكل كيلومتر حسب المسافة المُقدَّرة.
/// - المدن المدعومة الأخرى: التكلفة الثابتة من الـ lookups.
/// - غير ذلك: غير مدعوم (0).
class ShippingCalculator {
  const ShippingCalculator._();

  static const double misrataBaseShippingCost = 5.0;
  static const double misrataCostPerKm = 1.0;

  static double calculate({
    required AddressModel? address,
    required MapConfig? mapConfig,
    required OrdersLookups? lookups,
    required RouteEstimateResult? routeEstimate,
  }) {
    if (address == null) {
      return 0.0;
    }

    if (isInsideMisrata(address: address, mapConfig: mapConfig)) {
      final distanceKm = routeEstimate?.distanceKm ?? 0.0;
      return misrataBaseShippingCost + (distanceKm * misrataCostPerKm);
    }

    return _shippingLookup(address: address, lookups: lookups)?.shippingCost ??
        0.0;
  }

  static bool hasSupportedShipping({
    required AddressModel? address,
    required MapConfig? mapConfig,
    required OrdersLookups? lookups,
  }) {
    if (address == null) {
      return false;
    }

    return isInsideMisrata(address: address, mapConfig: mapConfig) ||
        _shippingLookup(address: address, lookups: lookups) != null;
  }

  static bool isInsideMisrata({
    required AddressModel address,
    required MapConfig? mapConfig,
  }) {
    final city = address.city.trim();

    if (mapConfig != null && address.location.hasUsableCoordinates) {
      return mapConfig.isInsideMisrataBoundary(
        lat: address.location.lat,
        lng: address.location.lng,
        detectedCity: city,
      );
    }

    return _isMisrataCityName(city);
  }

  static ShippingCityLookup? _shippingLookup({
    required AddressModel address,
    required OrdersLookups? lookups,
  }) {
    final selectedCity = address.city.trim();
    final shippingCities = lookups?.shippingCities;
    if (selectedCity.isEmpty ||
        shippingCities == null ||
        shippingCities.isEmpty) {
      return null;
    }

    for (final city in shippingCities) {
      if (_isSameCityName(city.name, selectedCity)) {
        return city;
      }
    }

    return null;
  }

  static bool _isMisrataCityName(String value) {
    final normalized = _normalizeCityName(value);
    final misrata = _normalizeCityName('مصراتة');
    return normalized == 'misrata' ||
        normalized == 'musrata' ||
        normalized == 'misurata' ||
        normalized == misrata ||
        normalized.contains(misrata);
  }

  static bool _isSameCityName(String left, String right) {
    final normalizedLeft = _normalizeCityName(left);
    final normalizedRight = _normalizeCityName(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return false;
    }

    return normalizedLeft == normalizedRight ||
        normalizedLeft.contains(normalizedRight) ||
        normalizedRight.contains(normalizedLeft);
  }

  static String _normalizeCityName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[ً-ٰٟـ]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[ىي]'), 'ي')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// النص المعروض في ملخص التوصيل، مطابق لسلوك صفحة الدفع.
  static String summaryValue({
    required bool hasSelectedAddress,
    required bool hasSupportedShipping,
    required bool isEstimating,
    required double shippingCost,
  }) {
    if (!hasSelectedAddress) {
      return 'اختر عنوان التوصيل أولاً';
    }

    if (isEstimating) {
      return 'جاري حساب المسافة';
    }

    if (!hasSupportedShipping) {
      return 'هذه المدينة غير مدعومة';
    }

    return formatShippingMoney(shippingCost);
  }

  static String formatShippingMoney(double value) {
    if (value <= 0) return 'مجاني';
    return '${value.round()} د.ل';
  }
}

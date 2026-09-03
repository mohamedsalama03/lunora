import 'category_model.dart'; // مسار مسبق لموديل الفئة

class ProductModel {
  final int id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? thumbnail;
  final PricingModel pricing;
  final StockModel stock;
  final RatingModel rating;
  final bool isFeatured;
  final CategoryModel? category;
  final BrandModel? brand;
  final OptionsModel? options;

  // الحقول التفصيلية (قد تكون null في قائمة المنتجات، وموجودة في التفاصيل)
  final String? description;
  final String? ingredients;
  final String? usageInstructions;
  final String? sku;
  final String? weight;
  final String? dimensions;
  final List<String>? tags;
  final List<ImageModel>? images;
  final List<VariantModel>? variants;

  ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    this.shortDescription,
    this.thumbnail,
    required this.pricing,
    required this.stock,
    required this.rating,
    this.isFeatured = false,
    this.category,
    this.brand,
    this.options,
    this.description,
    this.ingredients,
    this.usageInstructions,
    this.sku,
    this.weight,
    this.dimensions,
    this.tags,
    this.images,
    this.variants,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = _asMapOrNull(json['category']);
    final brand = _asMapOrNull(json['brand']);
    final options = _asMapOrNull(json['options']);

    return ProductModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      slug: _asString(json['slug']),
      shortDescription: _asNullableString(json['short_description']),
      thumbnail: _asNullableString(json['thumbnail']),
      pricing: PricingModel.fromJson(_asMap(json['pricing'])),
      stock: StockModel.fromJson(_asMap(json['stock'])),
      rating: RatingModel.fromJson(_asMap(json['rating'])),
      isFeatured: _asBool(json['is_featured']),
      category: category == null ? null : CategoryModel.fromJson(category),
      brand: brand == null ? null : BrandModel.fromJson(brand),
      options: options == null ? null : OptionsModel.fromJson(options),
      description: _asNullableString(json['description']),
      ingredients: _asNullableText(json['ingredients']),
      usageInstructions: _asNullableText(
        json['usage_instructions'] ?? json['usage'] ?? json['how_to_use'],
      ),
      sku: _asNullableString(json['sku']),
      weight: _asNullableString(json['weight']),
      dimensions: _asNullableString(json['dimensions']),
      tags: json['tags'] == null ? null : _asStringList(json['tags']),
      images: json['images'] == null
          ? null
          : _asList(json['images'])
                .whereType<Map>()
                .map((i) => ImageModel.fromJson(Map<String, dynamic>.from(i)))
                .where((image) => image.url.isNotEmpty)
                .toList(),
      variants: json['variants'] == null
          ? null
          : _asList(json['variants'])
                .whereType<Map>()
                .map((v) => VariantModel.fromJson(Map<String, dynamic>.from(v)))
                .toList(),
    );
  }

  bool get hasVariantOptions =>
      (options?.colors.isNotEmpty ?? false) ||
      (options?.sizes.isNotEmpty ?? false);

  bool get hasLoadedVariants => variants != null && variants!.isNotEmpty;

  bool get hasPurchasableVariant =>
      variants?.any((variant) => variant.isAvailable) ?? false;

  bool get hasPendingVariantStock =>
      stock.isAvailable && !hasLoadedVariants && hasVariantOptions;

  bool get isPurchasable =>
      stock.isAvailable && (!hasLoadedVariants || hasPurchasableVariant);

  int get maxPurchasableQuantity {
    if (!stock.isAvailable) {
      return 0;
    }

    var maxVariantQuantity = 0;
    for (final variant in variants ?? const <VariantModel>[]) {
      if (variant.maxPurchasableQuantity > maxVariantQuantity) {
        maxVariantQuantity = variant.maxPurchasableQuantity;
      }
    }

    return maxVariantQuantity > 0
        ? maxVariantQuantity
        : stock.maxPurchasableQuantity;
  }
}

class PricingModel {
  final double price;
  final double? salePrice;
  final double effectivePrice;
  final bool isOnSale;
  final int discountPercentage;

  PricingModel({
    required this.price,
    this.salePrice,
    required this.effectivePrice,
    this.isOnSale = false,
    this.discountPercentage = 0,
  });

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      price: _asDouble(json['price']),
      salePrice: _asNullableDouble(json['sale_price']),
      effectivePrice: _asDouble(json['effective_price']),
      isOnSale: _asBool(json['is_on_sale']),
      discountPercentage: _asInt(json['discount_percentage']),
    );
  }
}

class StockModel {
  static const int fallbackPurchasableQuantity = 99;

  final bool inStock;
  final int quantity;

  StockModel({this.inStock = false, this.quantity = 0});

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      inStock: _asBool(json['in_stock']),
      quantity: _asInt(json['quantity']),
    );
  }

  bool get isAvailable => inStock;

  int get maxPurchasableQuantity {
    if (!isAvailable) {
      return 0;
    }

    return quantity > 0 ? quantity : fallbackPurchasableQuantity;
  }
}

class RatingModel {
  final double average;
  final int count;

  RatingModel({this.average = 0.0, this.count = 0});

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      average: _asDouble(json['average']),
      count: _asInt(json['count']),
    );
  }
}

class BrandModel {
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;

  BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: _asInt(json['id']),
      name: _displayBrandName(json['name']),
      slug: _asString(json['slug']),
      logoUrl: _asNullableString(json['logo_url']),
    );
  }
}

class OptionsModel {
  final List<String> colors;
  final List<String> sizes;

  OptionsModel({this.colors = const [], this.sizes = const []});

  factory OptionsModel.fromJson(Map<String, dynamic> json) {
    return OptionsModel(
      colors: _asStringList(json['colors']),
      sizes: _asStringList(json['sizes']),
    );
  }
}

class ImageModel {
  final int id;
  final String url;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  ImageModel({
    required this.id,
    required this.url,
    this.altText,
    this.sortOrder = 1,
    this.isPrimary = false,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: _asInt(json['id']),
      url: _asString(json['url']),
      altText: _asNullableString(json['alt_text']),
      sortOrder: _asInt(json['sort_order'], fallback: 1),
      isPrimary: _asBool(json['is_primary']),
    );
  }
}

class VariantModel {
  final int id;
  final String type;
  final String value;
  final double priceModifier;
  final double finalPrice;
  final int stock;
  final String? sku;
  final String? imageUrl;

  VariantModel({
    required this.id,
    required this.type,
    required this.value,
    this.priceModifier = 0.0,
    required this.finalPrice,
    this.stock = 0,
    this.sku,
    this.imageUrl,
  });

  factory VariantModel.fromJson(Map<String, dynamic> json) {
    return VariantModel(
      id: _asInt(json['id']),
      type: _asString(json['type']),
      value: _asString(json['value']),
      priceModifier: _asDouble(json['price_modifier']),
      finalPrice: _asDouble(json['final_price']),
      stock: _asInt(json['stock']),
      sku: _asNullableString(json['sku']),
      imageUrl: _asNullableString(json['image_url']),
    );
  }

  bool get isAvailable => stock > 0;

  int get maxPurchasableQuantity => stock > 0 ? stock : 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  final map = _asMapOrNull(value);
  return map ?? const <String, dynamic>{};
}

Map<String, dynamic>? _asMapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

List<String> _asStringList(dynamic value) {
  return _asList(value)
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String _asString(dynamic value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

String _displayBrandName(dynamic value) {
  return _asString(value)
      .replaceAll(RegExp(r'\bAILA\b', caseSensitive: false), 'LUNORA')
      .replaceAll('آيلا', 'لونورا');
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final stringValue = value.toString();
  return stringValue.isEmpty ? null : stringValue;
}

String? _asNullableText(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    final lines = _asStringList(value);
    return lines.isEmpty ? null : lines.join('\n');
  }
  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? null : stringValue;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int? parentId;
  final int sortOrder;
  final int productsCount;
  final int childrenCount;
  final List<CategoryModel> children;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.parentId,
    required this.sortOrder,
    required this.productsCount,
    required this.childrenCount,
    this.children = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      slug: _asString(json['slug']),
      description: _asNullableString(json['description']),
      imageUrl: _asNullableString(json['image_url']),
      parentId: _asNullableInt(json['parent_id']),
      sortOrder: _asInt(json['sort_order'], fallback: 1),
      productsCount: _asInt(json['products_count']),
      childrenCount: _asInt(json['children_count']),
      children: _asList(json['children'])
          .whereType<Map>()
          .map(
            (child) => CategoryModel.fromJson(Map<String, dynamic>.from(child)),
          )
          .toList(),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _asString(dynamic value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final stringValue = value.toString();
  return stringValue.isEmpty ? null : stringValue;
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

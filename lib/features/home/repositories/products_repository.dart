import 'package:dio/dio.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';

class ProductsRepository {
  final Dio dio;

  ProductsRepository({required this.dio});

  /// جلب قائمة الفئات
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await dio.get('/api/flutter/categories');
      final data = response.data['data'] as List;
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('فشل في تحميل الفئات: $e');
    }
  }

  /// جلب قائمة المنتجات مع الفلترة والبحث
  Future<Map<String, dynamic>> fetchProducts({
    String? categorySlug,
    String? query,
    String availability = 'all',
    String sort = 'recommended',
    int perPage = 20,
    int page = 1,
  }) async {
    try {
      final response = await dio.get(
        '/api/flutter/products',
        queryParameters:
            {
                'availability': availability,
                'sort': sort,
                'per_page': perPage,
                'page': page,
              }
              ..addAll(
                categorySlug != null ? {'category_slug': categorySlug} : {},
              )
              ..addAll(query != null ? {'q': query} : {}),
      );

      final dataList = response.data['data'] as List;
      final products = dataList
          .map((json) => ProductModel.fromJson(json))
          .toList();
      final meta = response.data['meta'] as Map<String, dynamic>;

      return {
        'products': products,
        'meta': meta,
        'filters': response.data['filters'],
        'selected_category': response.data['selected_category'],
      };
    } catch (e) {
      throw Exception('فشل في تحميل المنتجات: $e');
    }
  }

  /// جلب تفاصيل منتج معين
  Future<ProductModel> fetchProductDetails(String slug) async {
    try {
      final response = await dio.get('/api/flutter/products/$slug');
      return ProductModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('فشل في تحميل تفاصيل المنتج: $e');
    }
  }
}

import 'dart:async';

import 'package:app_aila/core/models/product_model.dart';
import 'package:app_aila/features/home/repositories/products_repository.dart';
import 'package:app_aila/features/search/providers/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledProductsRepository extends ProductsRepository {
  _ControlledProductsRepository() : super(dio: Dio());

  final requests = <String, Completer<Map<String, dynamic>>>{};

  @override
  Future<Map<String, dynamic>> fetchProducts({
    String? categorySlug,
    String? query,
    String availability = 'all',
    String sort = 'recommended',
    int perPage = 20,
    int page = 1,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    requests[query ?? ''] = completer;
    return completer.future;
  }
}

ProductModel _product(int id, String name) {
  return ProductModel(
    id: id,
    name: name,
    slug: 'product-$id',
    pricing: PricingModel(price: 10, effectivePrice: 10),
    stock: StockModel(inStock: true, quantity: 5),
    rating: RatingModel(),
  );
}

Map<String, dynamic> _result(ProductModel product) => <String, dynamic>{
  'products': <ProductModel>[product],
  'meta': <String, dynamic>{},
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('latest search wins when responses arrive out of order', (
    tester,
  ) async {
    final repository = _ControlledProductsRepository();
    final provider = SearchProvider(repository: repository);

    provider.onSearchQueryChanged('first');
    await tester.pump(const Duration(milliseconds: 501));
    provider.onSearchQueryChanged('second');
    await tester.pump(const Duration(milliseconds: 501));

    repository.requests['second']!.complete(_result(_product(2, 'Second')));
    await tester.pump();
    repository.requests['first']!.complete(_result(_product(1, 'First')));
    await tester.pump();

    expect(provider.searchResults.single.name, 'Second');
    expect(provider.isLoadingSearch, isFalse);
    provider.dispose();
  });

  testWidgets('clearing search invalidates an in-flight response', (
    tester,
  ) async {
    final repository = _ControlledProductsRepository();
    final provider = SearchProvider(repository: repository);

    provider.onSearchQueryChanged('lipstick');
    await tester.pump(const Duration(milliseconds: 501));
    provider.clearSearch();
    repository.requests['lipstick']!.complete(_result(_product(1, 'Lipstick')));
    await tester.pump();

    expect(provider.searchQuery, isEmpty);
    expect(provider.searchResults, isEmpty);
    expect(provider.isLoadingSearch, isFalse);
    provider.dispose();
  });

  testWidgets('disposing cancels a pending debounced request', (tester) async {
    final repository = _ControlledProductsRepository();
    final provider = SearchProvider(repository: repository);

    provider.onSearchQueryChanged('mascara');
    provider.dispose();
    await tester.pump(const Duration(milliseconds: 501));

    expect(repository.requests, isEmpty);
  });
}

import 'package:app_aila/features/home/repositories/products_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/queue_http_adapter.dart';

Map<String, dynamic> _productJson() => <String, dynamic>{
  'id': 4,
  'name': 'Cleanser',
  'slug': 'cleanser',
  'pricing': <String, dynamic>{'price': 12, 'effective_price': 12},
  'stock': <String, dynamic>{'in_stock': true, 'quantity': 3},
  'rating': <String, dynamic>{'average': 4, 'count': 2},
};

void main() {
  test('fetchProducts maps filters, pagination, and valid models', () async {
    late RequestOptions captured;
    final adapter = QueueHttpAdapter(<AdapterResponse Function(RequestOptions)>[
      (request) {
        captured = request;
        return (
          statusCode: 200,
          body: <String, dynamic>{
            'data': <Map<String, dynamic>>[_productJson()],
            'meta': <String, dynamic>{'current_page': 2, 'last_page': 3},
            'filters': <String, dynamic>{},
            'selected_category': null,
          },
        );
      },
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    final repository = ProductsRepository(dio: dio);

    final result = await repository.fetchProducts(
      categorySlug: 'skin',
      query: 'clean',
      availability: 'in_stock',
      sort: 'price_asc',
      perPage: 10,
      page: 2,
    );

    expect(captured.path, '/api/flutter/products');
    expect(captured.queryParameters, <String, dynamic>{
      'availability': 'in_stock',
      'sort': 'price_asc',
      'per_page': 10,
      'page': 2,
      'category_slug': 'skin',
      'q': 'clean',
    });
    expect(result['products'], hasLength(1));
    expect(result['products'].first.name, 'Cleanser');
  });

  test('fetchProducts surfaces malformed API payloads as a failure', () async {
    final adapter = QueueHttpAdapter(<AdapterResponse Function(RequestOptions)>[
      (_) => (statusCode: 200, body: <String, dynamic>{'data': 'not-a-list'}),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    expect(
      ProductsRepository(dio: dio).fetchProducts(),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'fetchProductDetails encodes the product slug in the request path',
    () async {
      late RequestOptions captured;
      final adapter = QueueHttpAdapter(
        <AdapterResponse Function(RequestOptions)>[
          (request) {
            captured = request;
            return (
              statusCode: 200,
              body: <String, dynamic>{'data': _productJson()},
            );
          },
        ],
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;

      await ProductsRepository(dio: dio).fetchProductDetails('cleanser');

      expect(captured.path, '/api/flutter/products/cleanser');
    },
  );
}

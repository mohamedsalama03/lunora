import 'package:app_aila/features/orders/repositories/orders_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/queue_http_adapter.dart';

void main() {
  test(
    'createOrder sends only product identity, quantity, and server inputs',
    () async {
      late RequestOptions captured;
      final adapter = QueueHttpAdapter(
        <AdapterResponse Function(RequestOptions)>[
          (request) {
            captured = request;
            return (
              statusCode: 200,
              body: <String, dynamic>{
                'data': <String, dynamic>{
                  'order': <String, dynamic>{
                    'id': 1,
                    'order_number': 'ORD-1',
                    'status': 'pending',
                    'payment': <String, dynamic>{},
                    'items': <dynamic>[],
                  },
                },
              },
            );
          },
        ],
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      final repository = OrdersRepository(dio: dio);

      await repository.createOrder(
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 8,
            'product_variant_id': 3,
            'quantity': 2,
          },
        ],
        paymentMethod: 'cash',
        shippingAddressId: 9,
        shipping: <String, dynamic>{'full_name': 'Test User'},
      );

      expect(captured.method, 'POST');
      expect(captured.path, '/api/flutter/orders');
      final payload = captured.data as Map<String, dynamic>;
      expect(payload, isNot(contains('total')));
      expect(payload, isNot(contains('price')));
      expect(payload['payment_method'], 'cash');
      expect(payload['shipping'], <String, dynamic>{
        'address_id': 9,
        'full_name': 'Test User',
      });
    },
  );

  test('fetchOrders parses nested pagination payloads', () async {
    final adapter = QueueHttpAdapter(<AdapterResponse Function(RequestOptions)>[
      (_) => (
        statusCode: 200,
        body: <String, dynamic>{
          'data': <String, dynamic>{
            'data': <dynamic>[],
            'pagination': <String, dynamic>{
              'current_page': 1,
              'last_page': 2,
              'total': 16,
            },
          },
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    final result = await OrdersRepository(dio: dio).fetchOrders();

    expect(result.orders, isEmpty);
    expect(result.meta.currentPage, 1);
    expect(result.meta.lastPage, 2);
    expect(result.meta.total, 16);
  });

  test('fetchOrders hydrates a missing order item image', () async {
    final adapter = QueueHttpAdapter(<AdapterResponse Function(RequestOptions)>[
      (_) => (
        statusCode: 200,
        body: <String, dynamic>{
          'data': <String, dynamic>{
            'data': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'order_number': 'ORD-1',
                'status': 'pending',
                'payment': <String, dynamic>{},
                'items': <dynamic>[
                  <String, dynamic>{
                    'id': 10,
                    'product_id': 8,
                    'product_name': 'Primer',
                    'quantity': 1,
                  },
                ],
              },
            ],
          },
        },
      ),
      (_) => (
        statusCode: 200,
        body: <String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{
              'id': 8,
              'thumbnail': '/storage/products/primer.webp',
            },
          ],
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    final result = await OrdersRepository(dio: dio).fetchOrders();

    expect(
      result.orders.single.items.single.imageUrl,
      'https://aila.ly/storage/products/primer.webp',
    );
  });
}

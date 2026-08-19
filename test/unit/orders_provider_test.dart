import 'dart:async';

import 'package:app_aila/features/orders/models/order_model.dart';
import 'package:app_aila/features/orders/providers/orders_provider.dart';
import 'package:app_aila/features/orders/repositories/orders_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledOrdersRepository extends OrdersRepository {
  _ControlledOrdersRepository() : super(dio: Dio());

  int createCalls = 0;
  final createCompleter = Completer<CreateOrderResponse>();

  @override
  Future<CreateOrderResponse> createOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    int? shippingAddressId,
    Map<String, dynamic>? shipping,
  }) {
    createCalls++;
    return createCompleter.future;
  }
}

void main() {
  test(
    'ignores a duplicate create-order submission while one is running',
    () async {
      final repository = _ControlledOrdersRepository();
      final provider = OrdersProvider(repository: repository);

      final first = provider.createOrder(
        items: <Map<String, dynamic>>[
          <String, dynamic>{'product_id': 1, 'quantity': 1},
        ],
        paymentMethod: 'cash',
        shippingAddressId: 1,
      );
      final duplicate = await provider.createOrder(
        items: <Map<String, dynamic>>[
          <String, dynamic>{'product_id': 1, 'quantity': 1},
        ],
        paymentMethod: 'cash',
        shippingAddressId: 1,
      );

      expect(duplicate, isNull);
      expect(repository.createCalls, 1);

      repository.createCompleter.completeError(Exception('stop test request'));
      expect(await first, isNull);
    },
  );
}

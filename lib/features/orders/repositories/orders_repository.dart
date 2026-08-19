import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/order_model.dart';

class OrdersRepository {
  final Dio dio;

  OrdersRepository({required this.dio});

  /// GET /api/flutter/orders/lookups
  Future<OrdersLookups> fetchLookups() async {
    final response = await dio.get(ApiConstants.ordersLookups);
    final data = _readDataMap(response.data);
    return OrdersLookups.fromJson(data);
  }

  /// GET /api/flutter/orders
  Future<({List<OrderModel> orders, OrdersMeta meta})> fetchOrders({
    int page = 1,
    int perPage = 15,
    List<String>? statuses,
    List<String>? paymentStatuses,
    String? status,
    String? paymentStatus,
  }) async {
    Response<dynamic> response;

    try {
      response = await dio.get(
        ApiConstants.orders,
        queryParameters: _buildOrdersQueryParameters(
          page: page,
          perPage: perPage,
          statuses: statuses,
          paymentStatuses: paymentStatuses,
          status: status,
          paymentStatus: paymentStatus,
        ),
        options: Options(listFormat: ListFormat.multiCompatible),
      );
    } on DioException catch (e) {
      final canRetryWithCsv =
          ((statuses?.length ?? 0) > 1 || (paymentStatuses?.length ?? 0) > 1) &&
          (e.response?.statusCode == 400 || e.response?.statusCode == 422);

      if (!canRetryWithCsv) rethrow;

      response = await dio.get(
        ApiConstants.orders,
        queryParameters: _buildOrdersQueryParameters(
          page: page,
          perPage: perPage,
          status: statuses?.join(',') ?? status,
          paymentStatus: paymentStatuses?.join(',') ?? paymentStatus,
        ),
      );
    }

    final raw = _asMap(response.data);
    final parsedOrders = _readDataList(
      raw,
    ).map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
    final orders = await _hydrateMissingImagesForOrders(parsedOrders);
    final meta = OrdersMeta.fromJson(_readMetaMap(raw));
    return (orders: orders, meta: meta);
  }

  Future<int> fetchOrdersTotalCount() async {
    final result = await fetchOrders(page: 1, perPage: 1);
    if (result.meta.total > 0) return result.meta.total;
    return result.orders.length;
  }

  /// GET /api/flutter/orders/{orderNumber}
  Future<OrderModel> fetchOrder(String orderNumber) async {
    final response = await dio.get('${ApiConstants.orders}/$orderNumber');
    final data = _readDataMap(response.data);
    final order = OrderModel.fromJson(
      data['order'] as Map<String, dynamic>? ?? data,
    );
    return _hydrateMissingItemImages(order);
  }

  /// POST /api/flutter/orders
  Future<CreateOrderResponse> createOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    int? shippingAddressId,
    Map<String, dynamic>? shipping,
  }) async {
    final payload = <String, dynamic>{
      'items': items,
      'payment_method': paymentMethod,
    };

    if (shippingAddressId != null) {
      payload['shipping_address_id'] = shippingAddressId;
      payload['shipping'] = <String, dynamic>{
        'address_id': shippingAddressId,
        ...?shipping,
      };
    } else if (shipping != null) {
      payload['shipping'] = shipping;
    }

    final response = await dio.post(ApiConstants.orders, data: payload);
    return CreateOrderResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /api/flutter/orders/moamalat/confirm
  Future<OrderModel> confirmMoamalat(
    Map<String, dynamic> callbackPayload,
  ) async {
    final response = await dio.post(
      ApiConstants.ordersMoamalatConfirm,
      data: callbackPayload,
    );
    final data = _readDataMap(response.data);
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  /// POST /api/flutter/orders/moamalat/fail
  Future<({OrderModel order, bool awaitingGateway})> failMoamalat({
    required String merchantReference,
    String reason = 'user_cancelled',
    Map<String, dynamic>? callbackPayload,
  }) async {
    final response = await dio.post(
      ApiConstants.ordersMoamalatFail,
      data: <String, dynamic>{
        ...?callbackPayload,
        'merchant_reference': merchantReference,
        'reason': reason,
      },
    );
    final data = _readDataMap(response.data);
    return (
      order: OrderModel.fromJson(data['order'] as Map<String, dynamic>),
      awaitingGateway: (data['awaiting_gateway_notification'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> _buildOrdersQueryParameters({
    required int page,
    required int perPage,
    List<String>? statuses,
    List<String>? paymentStatuses,
    String? status,
    String? paymentStatus,
  }) {
    return <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (statuses != null && statuses.isNotEmpty) 'status': statuses,
      if (statuses == null && status != null && status.isNotEmpty)
        'status': status,
      if (paymentStatuses != null && paymentStatuses.isNotEmpty)
        'payment_status': paymentStatuses,
      if (paymentStatuses == null &&
          paymentStatus != null &&
          paymentStatus.isNotEmpty)
        'payment_status': paymentStatus,
    };
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const FormatException('Invalid API response format.');
  }

  Map<String, dynamic> _readDataMap(dynamic raw) {
    final map = _asMap(raw);
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Expected object in API data payload.');
  }

  List<dynamic> _readDataList(dynamic raw) {
    final map = _asMap(raw);
    final data = map['data'];

    if (data is List<dynamic>) return data;
    if (data is Map) {
      final nestedData = data['data'];
      if (nestedData is List<dynamic>) return nestedData;
    }

    throw const FormatException('Expected list in API data payload.');
  }

  Map<String, dynamic> _readMetaMap(dynamic raw) {
    final map = _asMap(raw);
    final meta = map['meta'];

    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) return Map<String, dynamic>.from(meta);

    final pagination = map['pagination'];
    if (pagination is Map<String, dynamic>) return pagination;
    if (pagination is Map) return Map<String, dynamic>.from(pagination);

    final data = map['data'];
    if (data is Map) {
      final nestedMeta = data['meta'];
      if (nestedMeta is Map<String, dynamic>) return nestedMeta;
      if (nestedMeta is Map) return Map<String, dynamic>.from(nestedMeta);

      final nestedPagination = data['pagination'];
      if (nestedPagination is Map<String, dynamic>) return nestedPagination;
      if (nestedPagination is Map) {
        return Map<String, dynamic>.from(nestedPagination);
      }
    }

    return const <String, dynamic>{};
  }

  Future<OrderModel> _hydrateMissingItemImages(OrderModel order) async {
    final missingImageItems = order.items
        .where((item) => item.imageUrl == null || item.imageUrl!.isEmpty)
        .toList();
    if (missingImageItems.isEmpty) return order;

    final imageByProductId = <int, String>{};

    for (final item in missingImageItems) {
      if (imageByProductId.containsKey(item.productId)) continue;

      final imageUrl = await _fetchProductThumbnailForOrderItem(item);
      if (imageUrl != null) {
        imageByProductId[item.productId] = imageUrl;
      }
    }

    if (imageByProductId.isEmpty) return order;

    return order.copyWith(
      items: order.items.map((item) {
        final imageUrl = imageByProductId[item.productId];
        if (imageUrl == null) return item;
        return item.copyWith(imageUrl: imageUrl);
      }).toList(),
    );
  }

  Future<List<OrderModel>> _hydrateMissingImagesForOrders(
    List<OrderModel> orders,
  ) async {
    final itemByProductId = <int, OrderItem>{};

    for (final order in orders) {
      for (final item in order.items) {
        final hasImage = item.imageUrl?.trim().isNotEmpty ?? false;
        if (!hasImage && item.productId > 0) {
          itemByProductId.putIfAbsent(item.productId, () => item);
        }
      }
    }

    if (itemByProductId.isEmpty) return orders;

    final resolvedImages = await Future.wait(
      itemByProductId.entries.map((entry) async {
        final imageUrl = await _fetchProductThumbnailForOrderItem(entry.value);
        return (productId: entry.key, imageUrl: imageUrl);
      }),
    );
    final imageByProductId = <int, String>{
      for (final result in resolvedImages)
        if (result.imageUrl != null) result.productId: result.imageUrl!,
    };

    if (imageByProductId.isEmpty) return orders;

    return orders.map((order) {
      return order.copyWith(
        items: order.items.map((item) {
          final imageUrl = imageByProductId[item.productId];
          return imageUrl == null ? item : item.copyWith(imageUrl: imageUrl);
        }).toList(),
      );
    }).toList();
  }

  Future<String?> _fetchProductThumbnailForOrderItem(OrderItem item) async {
    final queries = <Map<String, dynamic>>[
      if (item.productName.trim().isNotEmpty)
        <String, dynamic>{
          'q': item.productName.trim(),
          'per_page': 12,
          'page': 1,
        },
      <String, dynamic>{'per_page': 60, 'page': 1},
    ];

    for (final query in queries) {
      try {
        final response = await dio.get(
          '/api/flutter/products',
          queryParameters: query,
        );
        final products = _readDataList(
          response.data,
        ).whereType<Map>().map((product) => Map<String, dynamic>.from(product));

        for (final product in products) {
          final productId = (product['id'] as num?)?.toInt();
          if (productId != item.productId) continue;

          final thumbnail = product['thumbnail']?.toString().trim();
          if (thumbnail != null && thumbnail.isNotEmpty) {
            return _normalizeProductImageUrl(thumbnail);
          }
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  String _normalizeProductImageUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return '${ApiConstants.baseUrl}$value';
    return '${ApiConstants.baseUrl}/$value';
  }
}

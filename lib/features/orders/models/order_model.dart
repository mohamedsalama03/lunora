import '../../../core/constants/api_constants.dart';

/// بيانات الدفع الخاصة بالطلب
class OrderPayment {
  final String method;
  final String methodLabel;
  final String rawMethod;
  final String status;
  final String statusLabel;
  final double amount;
  final String merchantReference;
  final bool awaitingGatewayNotification;

  OrderPayment({
    required this.method,
    required this.methodLabel,
    required this.rawMethod,
    required this.status,
    required this.statusLabel,
    required this.amount,
    required this.merchantReference,
    required this.awaitingGatewayNotification,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      method: json['method'] ?? '',
      methodLabel: json['method_label'] ?? '',
      rawMethod: json['raw_method'] ?? '',
      status: json['status'] ?? '',
      statusLabel: json['status_label'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchantReference: json['merchant_reference'] ?? '',
      awaitingGatewayNotification:
          json['awaiting_gateway_notification'] ?? false,
    );
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isMoamalat => method == 'moamalat';
  bool get isCod => method == 'cod';
  bool get isWallet => method == 'wallet';
}

/// إجماليات الطلب
class OrderTotals {
  final double subtotal;
  final double discountAmount;
  final double shippingCost;
  final double taxAmount;
  final double total;

  OrderTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.shippingCost,
    required this.taxAmount,
    required this.total,
  });

  factory OrderTotals.fromJson(Map<String, dynamic> json) {
    return OrderTotals(
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// بيانات الشحن
class OrderShipping {
  final String fullName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String country;
  final String? postalCode;

  OrderShipping({
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    required this.country,
    this.postalCode,
  });

  factory OrderShipping.fromJson(Map<String, dynamic> json) {
    return OrderShipping(
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      addressLine1: json['address_line1'] ?? '',
      addressLine2: json['address_line2'] as String?,
      city: json['city'] ?? '',
      state: json['state'] as String?,
      country: json['country'] ?? '',
      postalCode: json['postal_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'address_line1': addressLine1,
      if (addressLine2 != null) 'address_line2': addressLine2,
      'city': city,
      if (state != null) 'state': state,
      'country': country,
      if (postalCode != null) 'postal_code': postalCode,
    };
  }
}

/// عنصر داخل الطلب
class OrderItem {
  final int id;
  final int productId;
  final int? productVariantId;
  final String productName;
  final String? variantInfo;
  final String? imageUrl;
  final String productSku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  OrderItem({
    required this.id,
    required this.productId,
    this.productVariantId,
    required this.productName,
    this.variantInfo,
    this.imageUrl,
    required this.productSku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productVariantId: json['product_variant_id'] as int?,
      productName: json['product_name'] ?? '',
      variantInfo: json['variant_info'] as String?,
      imageUrl: _extractOrderItemImageUrl(json),
      productSku: json['product_sku'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  OrderItem copyWith({String? imageUrl}) {
    return OrderItem(
      id: id,
      productId: productId,
      productVariantId: productVariantId,
      productName: productName,
      variantInfo: variantInfo,
      imageUrl: imageUrl ?? this.imageUrl,
      productSku: productSku,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );
  }
}

/// مساعدات قراءة صورة عنصر الطلب من أكثر من شكل محتمل في الـ API
String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _extractOrderItemImageUrl(Map<String, dynamic> json) {
  final candidates = <dynamic>[
    json['thumbnail'],
    json['thumbnail_url'],
    json['image_url'],
    json['image'],
    json['product_image'],
    json['product_thumbnail'],
    json['product_thumbnail_url'],
    json['variant_image'],
    json['variant_image_url'],
    json['product'],
    json['variant'],
  ];

  for (final candidate in candidates) {
    final imageUrl = _imageUrlFromValue(candidate);
    if (imageUrl != null) return imageUrl;
  }

  return null;
}

String? _imageUrlFromValue(dynamic value) {
  final direct = _normalizeImageUrl(value);
  if (direct != null) return direct;

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final candidates = <dynamic>[
      map['thumbnail'],
      map['thumbnail_url'],
      map['image_url'],
      map['image'],
      map['url'],
      map['src'],
      map['path'],
      map['original_url'],
      map['preview_url'],
      map['primary_image'],
      map['main_image'],
      map['cover'],
      map['images'],
      map['gallery'],
      map['media'],
    ];

    for (final candidate in candidates) {
      final imageUrl = _imageUrlFromValue(candidate);
      if (imageUrl != null) return imageUrl;
    }
  }

  if (value is List) {
    for (final item in value) {
      final imageUrl = _imageUrlFromValue(item);
      if (imageUrl != null) return imageUrl;
    }
  }

  return null;
}

String? _normalizeImageUrl(dynamic value) {
  if (value is Map || value is List) return null;

  final text = _asNullableString(value);
  if (text == null) return null;

  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) return text;
  if (text.startsWith('//')) return 'https:$text';
  if (text.startsWith('/')) return '${ApiConstants.baseUrl}$text';
  return '${ApiConstants.baseUrl}/$text';
}

/// طوابع وقت الطلب
class OrderTimestamps {
  final String createdAt;
  final String updatedAt;
  final String? shippedAt;
  final String? deliveredAt;

  OrderTimestamps({
    required this.createdAt,
    required this.updatedAt,
    this.shippedAt,
    this.deliveredAt,
  });

  factory OrderTimestamps.fromJson(Map<String, dynamic> json) {
    return OrderTimestamps(
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      shippedAt: json['shipped_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
    );
  }
}

/// النموذج الرئيسي للطلب
class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final OrderPayment payment;
  final OrderTotals? totals;
  final OrderShipping? shipping;
  final int itemsQty;
  final List<OrderItem> items;
  final OrderTimestamps? timestamps;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.payment,
    this.totals,
    this.shipping,
    required this.itemsQty,
    required this.items,
    this.timestamps,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      statusLabel: json['status_label'] ?? '',
      payment: OrderPayment.fromJson(
        json['payment'] as Map<String, dynamic>? ?? {},
      ),
      totals: json['totals'] != null
          ? OrderTotals.fromJson(json['totals'] as Map<String, dynamic>)
          : null,
      shipping: json['shipping'] != null
          ? OrderShipping.fromJson(json['shipping'] as Map<String, dynamic>)
          : null,
      itemsQty: json['items_qty'] ?? 0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      timestamps: json['timestamps'] != null
          ? OrderTimestamps.fromJson(json['timestamps'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive =>
      status == 'pending' || status == 'processing' || status == 'shipped';

  bool get isPast =>
      status == 'delivered' || status == 'cancelled' || status == 'refunded';

  OrderModel copyWith({List<OrderItem>? items}) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      status: status,
      statusLabel: statusLabel,
      payment: payment,
      totals: totals,
      shipping: shipping,
      itemsQty: itemsQty,
      items: items ?? this.items,
      timestamps: timestamps,
    );
  }
}

/// pagination meta للطلبات
class OrdersMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  OrdersMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory OrdersMeta.fromJson(Map<String, dynamic> json) {
    return OrdersMeta(
      currentPage: _readInt(json['current_page'], fallback: 1),
      lastPage: _readInt(json['last_page'], fallback: 1),
      perPage: _readInt(json['per_page'], fallback: 15),
      total: _readInt(json['total']),
    );
  }

  bool get hasMorePages => currentPage < lastPage;

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// طريقة دفع من الـ lookups
class PaymentMethodLookup {
  final String key;
  final String label;
  final bool enabled;
  final bool requiresOnlinePayment;

  PaymentMethodLookup({
    required this.key,
    required this.label,
    required this.enabled,
    required this.requiresOnlinePayment,
  });

  factory PaymentMethodLookup.fromJson(Map<String, dynamic> json) {
    return PaymentMethodLookup(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      enabled: json['enabled'] ?? true,
      requiresOnlinePayment: json['requires_online_payment'] ?? false,
    );
  }

  bool get isCod => key == 'cod';
  bool get isWallet => key == 'wallet';
  bool get isMoamalat => key == 'moamalat';
}

/// مدينة شحن من الـ lookups
class ShippingCityLookup {
  final String name;
  final double shippingCost;

  ShippingCityLookup({required this.name, required this.shippingCost});

  factory ShippingCityLookup.fromJson(Map<String, dynamic> json) {
    return ShippingCityLookup(
      name: json['name'] ?? '',
      shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// نتيجة جلب الـ lookups
class OrdersLookups {
  final String currency;
  final List<Map<String, String>> orderStatuses;
  final List<Map<String, String>> paymentStatuses;
  final List<PaymentMethodLookup> paymentMethods;
  final List<ShippingCityLookup> shippingCities;
  final double walletBalance;
  final bool walletEnabled;

  OrdersLookups({
    required this.currency,
    required this.orderStatuses,
    required this.paymentStatuses,
    required this.paymentMethods,
    required this.shippingCities,
    required this.walletBalance,
    required this.walletEnabled,
  });

  factory OrdersLookups.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>> parseStatuses(dynamic list) {
      return (list as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [];
    }

    final wallet = json['wallet'] as Map<String, dynamic>? ?? {};
    return OrdersLookups(
      currency: json['currency'] ?? 'LYD',
      orderStatuses: parseStatuses(json['order_statuses']),
      paymentStatuses: parseStatuses(json['payment_statuses']),
      paymentMethods:
          (json['payment_methods'] as List<dynamic>?)
              ?.map(
                (e) => PaymentMethodLookup.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      shippingCities:
          (json['shipping_cities'] as List<dynamic>?)
              ?.map(
                (e) => ShippingCityLookup.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      walletBalance: (wallet['balance'] as num?)?.toDouble() ?? 0.0,
      walletEnabled: wallet['enabled'] ?? false,
    );
  }

  List<PaymentMethodLookup> get enabledPaymentMethods =>
      paymentMethods.where((m) => m.enabled).toList();
}

/// بيانات checkout الخاص بـ مُعاملات للطلبات
class MoamalatOrderCheckout {
  final String scriptUrl;
  final String mid;
  final String tid;
  final String amountTrxn;
  final String merchantReference;
  final String trxDateTime;
  final String secureHash;

  MoamalatOrderCheckout({
    required this.scriptUrl,
    required this.mid,
    required this.tid,
    required this.amountTrxn,
    required this.merchantReference,
    required this.trxDateTime,
    required this.secureHash,
  });

  factory MoamalatOrderCheckout.fromJson(Map<String, dynamic> json) {
    return MoamalatOrderCheckout(
      scriptUrl: json['scriptUrl'] ?? '',
      mid: json['MID'] ?? '',
      tid: json['TID'] ?? '',
      amountTrxn: json['AmountTrxn'] ?? '',
      merchantReference: json['MerchantReference'] ?? '',
      trxDateTime: json['TrxDateTime'] ?? '',
      secureHash: json['SecureHash'] ?? '',
    );
  }
}

/// payment_action في response إنشاء الطلب موعاملات
class MoamalatOrderPaymentAction {
  final String type;
  final String merchantReference;
  final MoamalatOrderCheckout checkout;

  MoamalatOrderPaymentAction({
    required this.type,
    required this.merchantReference,
    required this.checkout,
  });

  factory MoamalatOrderPaymentAction.fromJson(Map<String, dynamic> json) {
    return MoamalatOrderPaymentAction(
      type: json['type'] ?? '',
      merchantReference: json['merchant_reference'] ?? '',
      checkout: MoamalatOrderCheckout.fromJson(
        json['checkout'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// الاستجابة الكاملة من create order
class CreateOrderResponse {
  final OrderModel order;
  final MoamalatOrderPaymentAction? paymentAction;

  CreateOrderResponse({required this.order, this.paymentAction});

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CreateOrderResponse(
      order: OrderModel.fromJson(data['order'] as Map<String, dynamic>),
      paymentAction: data['payment_action'] != null
          ? MoamalatOrderPaymentAction.fromJson(
              data['payment_action'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  bool get requiresMoamalat => paymentAction != null;
}

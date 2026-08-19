import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/order_model.dart';
import '../repositories/orders_repository.dart';

enum OrdersStatus { initial, loading, loaded, error }

class OrdersProvider with ChangeNotifier {
  final OrdersRepository repository;

  static const List<String> _activeStatuses = <String>[
    'pending',
    'processing',
    'shipped',
  ];

  static const List<String> _pastStatuses = <String>[
    'delivered',
    'cancelled',
    'refunded',
  ];

  OrdersProvider({required this.repository});

  // ─── Lookups ────────────────────────────────────────────────────────────────
  OrdersLookups? _lookups;
  bool _lookupsLoading = false;
  String? _lookupsError;
  int? _totalOrdersCount;
  bool _isLoadingTotalOrdersCount = false;
  int _scopeVersion = 0;

  OrdersLookups? get lookups => _lookups;
  bool get lookupsLoading => _lookupsLoading;
  String? get lookupsError => _lookupsError;
  bool get isLoadingTotalOrdersCount => _isLoadingTotalOrdersCount;
  int get totalOrdersCount =>
      _totalOrdersCount ?? (_activeOrders.length + _pastOrders.length);
  bool get isLoadingOrderCounts =>
      _isLoadingTotalOrdersCount && _totalOrdersCount == null;

  Future<void> loadTotalOrdersCount({bool forceRefresh = false}) async {
    if (_isLoadingTotalOrdersCount) return;
    if (!forceRefresh && _totalOrdersCount != null) return;

    final scopeVersion = _scopeVersion;
    _isLoadingTotalOrdersCount = true;
    notifyListeners();

    try {
      final total = await repository.fetchOrdersTotalCount();
      if (scopeVersion != _scopeVersion) return;
      _totalOrdersCount = total;
    } catch (_) {
      if (scopeVersion != _scopeVersion) return;
      _totalOrdersCount ??= _activeOrders.length + _pastOrders.length;
    } finally {
      if (scopeVersion == _scopeVersion) {
        _isLoadingTotalOrdersCount = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadLookups({bool forceRefresh = false}) async {
    if (_lookupsLoading) return;
    if (!forceRefresh && _lookups != null) return;

    _lookupsLoading = true;
    _lookupsError = null;
    notifyListeners();
    try {
      _lookups = await repository.fetchLookups();
    } on DioException catch (e) {
      _lookupsError = e.response?.data?['message'] ?? 'فشل تحميل إعدادات الطلب';
    } catch (_) {
      _lookupsError = 'حدث خطأ غير متوقع';
    }
    _lookupsLoading = false;
    notifyListeners();
  }

  // ─── Active Orders (pending/processing/shipped) ──────────────────────────────
  List<OrderModel> _activeOrders = [];
  OrdersMeta? _activeMeta;
  OrdersStatus _activeStatus = OrdersStatus.initial;
  bool _loadingMoreActive = false;

  List<OrderModel> get activeOrders => _activeOrders;
  OrdersStatus get activeStatus => _activeStatus;
  bool get loadingMoreActive => _loadingMoreActive;
  bool get hasMoreActivePages => _activeMeta?.hasMorePages ?? false;
  int get activeTotalCount => _activeMeta?.total ?? _activeOrders.length;

  Future<void> loadActiveOrders() async {
    final scopeVersion = _scopeVersion;
    _activeStatus = OrdersStatus.loading;
    _activeOrders = [];
    _activeMeta = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _fetchOrdersBucket(
        startPage: 1,
        statuses: _activeStatuses,
        matcher: _isActiveOrder,
      );
      if (scopeVersion != _scopeVersion) return;
      _activeOrders = result.orders;
      _activeMeta = result.meta;
      _activeStatus = OrdersStatus.loaded;
    } on DioException catch (e) {
      if (scopeVersion != _scopeVersion) return;
      _activeStatus = OrdersStatus.error;
      _errorMessage = e.response?.data?['message'] ?? 'فشل تحميل الطلبات';
    } catch (_) {
      if (scopeVersion != _scopeVersion) return;
      _activeStatus = OrdersStatus.error;
      _errorMessage = 'حدث خطأ غير متوقع';
    }
    if (scopeVersion != _scopeVersion) return;
    notifyListeners();
  }

  Future<void> loadMoreActiveOrders() async {
    if (_loadingMoreActive || !hasMoreActivePages) return;
    final scopeVersion = _scopeVersion;
    _loadingMoreActive = true;
    notifyListeners();
    try {
      final result = await _fetchOrdersBucket(
        startPage: (_activeMeta?.currentPage ?? 0) + 1,
        statuses: _activeStatuses,
        matcher: _isActiveOrder,
      );
      if (scopeVersion != _scopeVersion) return;
      _activeOrders.addAll(result.orders);
      _activeMeta = result.meta;
    } catch (_) {}
    if (scopeVersion != _scopeVersion) return;
    _loadingMoreActive = false;
    notifyListeners();
  }

  // ─── Past Orders (delivered/cancelled/refunded) ──────────────────────────────
  List<OrderModel> _pastOrders = [];
  OrdersMeta? _pastMeta;
  OrdersStatus _pastStatus = OrdersStatus.initial;
  bool _loadingMorePast = false;

  List<OrderModel> get pastOrders => _pastOrders;
  OrdersStatus get pastStatus => _pastStatus;
  bool get loadingMorePast => _loadingMorePast;
  bool get hasMorePastPages => _pastMeta?.hasMorePages ?? false;
  int get pastTotalCount => _pastMeta?.total ?? _pastOrders.length;

  Future<void> loadPastOrders() async {
    final scopeVersion = _scopeVersion;
    _pastStatus = OrdersStatus.loading;
    _pastOrders = [];
    _pastMeta = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _fetchOrdersBucket(
        startPage: 1,
        statuses: _pastStatuses,
        matcher: _isPastOrder,
      );
      if (scopeVersion != _scopeVersion) return;
      _pastOrders = result.orders;
      _pastMeta = result.meta;
      _pastStatus = OrdersStatus.loaded;
    } on DioException catch (e) {
      if (scopeVersion != _scopeVersion) return;
      _pastStatus = OrdersStatus.error;
      _errorMessage = e.response?.data?['message'] ?? 'فشل تحميل الطلبات';
    } catch (_) {
      if (scopeVersion != _scopeVersion) return;
      _pastStatus = OrdersStatus.error;
      _errorMessage = 'حدث خطأ غير متوقع';
    }
    if (scopeVersion != _scopeVersion) return;
    notifyListeners();
  }

  Future<void> loadMorePastOrders() async {
    if (_loadingMorePast || !hasMorePastPages) return;
    final scopeVersion = _scopeVersion;
    _loadingMorePast = true;
    notifyListeners();
    try {
      final result = await _fetchOrdersBucket(
        startPage: (_pastMeta?.currentPage ?? 0) + 1,
        statuses: _pastStatuses,
        matcher: _isPastOrder,
      );
      if (scopeVersion != _scopeVersion) return;
      _pastOrders.addAll(result.orders);
      _pastMeta = result.meta;
    } catch (_) {}
    if (scopeVersion != _scopeVersion) return;
    _loadingMorePast = false;
    notifyListeners();
  }

  // ─── Create Order ────────────────────────────────────────────────────────────
  bool _isCreatingOrder = false;
  CreateOrderResponse? _lastCreatedOrder;
  String? _errorMessage;

  bool get isCreatingOrder => _isCreatingOrder;
  CreateOrderResponse? get lastCreatedOrder => _lastCreatedOrder;
  String? get errorMessage => _errorMessage;
  OrderShipping? get preferredShippingPrefill {
    final latestShipping = _lastCreatedOrder?.order.shipping;
    if (_hasUsefulShipping(latestShipping)) {
      return latestShipping;
    }

    OrderModel? freshestOrder;
    var freshestTimestamp = -1;

    for (final order in <OrderModel>[..._activeOrders, ..._pastOrders]) {
      final shipping = order.shipping;
      if (!_hasUsefulShipping(shipping)) continue;

      final createdAt = _createdAtMillis(order.timestamps?.createdAt);
      if (freshestOrder == null || createdAt > freshestTimestamp) {
        freshestOrder = order;
        freshestTimestamp = createdAt;
      }
    }

    return freshestOrder?.shipping;
  }

  Future<CreateOrderResponse?> createOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    int? shippingAddressId,
    Map<String, dynamic>? shipping,
  }) async {
    if (_isCreatingOrder) return null;

    _isCreatingOrder = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await repository.createOrder(
        items: items,
        paymentMethod: paymentMethod,
        shippingAddressId: shippingAddressId,
        shipping: shipping,
      );
      _lastCreatedOrder = response;
      // أضف الطلب الجديد للقائمة النشطة محلياً
      final previousTotal =
          _totalOrdersCount ?? (_activeOrders.length + _pastOrders.length);
      _activeOrders.insert(0, response.order);
      _totalOrdersCount = previousTotal + 1;
      return response;
    } on DioException catch (e) {
      // قد يكون 422 مع order صالح (فشل تجهيز checkout بعد إنشاء الطلب)
      final body = e.response?.data as Map<String, dynamic>?;
      if (e.response?.statusCode == 422 && body?['data'] != null) {
        _errorMessage = body?['message'] as String?;
        // أنشئ response جزئي لحماية بيانات الطلب المُنشأ
        final partialData = body!['data'] as Map<String, dynamic>;
        if (partialData['order'] != null) {
          final partialOrder = OrderModel.fromJson(
            partialData['order'] as Map<String, dynamic>,
          );
          return CreateOrderResponse(order: partialOrder);
        }
      }
      _errorMessage = e.response?.data?['message'] ?? 'فشل إنشاء الطلب';
      return null;
    } catch (_) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء إنشاء الطلب';
      return null;
    } finally {
      _isCreatingOrder = false;
      notifyListeners();
    }
  }

  // ─── Moamalat Confirm ────────────────────────────────────────────────────────
  bool _isConfirming = false;
  bool get isConfirming => _isConfirming;

  Future<OrderModel?> confirmMoamalat(
    Map<String, dynamic> callbackPayload,
  ) async {
    _isConfirming = true;
    notifyListeners();
    try {
      final order = await repository.confirmMoamalat(callbackPayload);
      _updateOrderInLists(order);
      return order;
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['message'] ?? 'فشل تأكيد الدفع';
      return null;
    } catch (_) {
      _errorMessage = 'حدث خطأ غير متوقع';
      return null;
    } finally {
      _isConfirming = false;
      notifyListeners();
    }
  }

  // ─── Moamalat Fail ───────────────────────────────────────────────────────────
  Future<void> failMoamalat({
    required String merchantReference,
    String reason = 'user_cancelled',
    Map<String, dynamic>? callbackPayload,
  }) async {
    try {
      final result = await repository.failMoamalat(
        merchantReference: merchantReference,
        reason: reason,
        callbackPayload: callbackPayload,
      );
      _updateOrderInLists(result.order);
    } catch (_) {
      // silent — نسجل فقط، لا نبلغ المستخدم
    }
    notifyListeners();
  }

  // ─── Refresh single order ────────────────────────────────────────────────────
  Future<OrderModel?> refreshOrder(String orderNumber) async {
    try {
      final order = await repository.fetchOrder(orderNumber);
      _updateOrderInLists(order);
      return order;
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  Future<({List<OrderModel> orders, OrdersMeta meta})> _fetchOrdersBucket({
    required int startPage,
    required List<String> statuses,
    required bool Function(OrderModel order) matcher,
  }) async {
    var currentPage = startPage;
    final collected = <OrderModel>[];
    OrdersMeta? lastMeta;

    while (true) {
      final result = await repository.fetchOrders(
        page: currentPage,
        perPage: 15,
      );
      lastMeta = result.meta;
      collected.addAll(result.orders.where(matcher));

      if (collected.isNotEmpty || !result.meta.hasMorePages) {
        return (orders: collected, meta: lastMeta);
      }

      currentPage = result.meta.currentPage + 1;
    }
  }

  bool _isActiveOrder(OrderModel order) =>
      _activeStatuses.contains(order.status);

  bool _isPastOrder(OrderModel order) => _pastStatuses.contains(order.status);

  void _updateOrderInLists(OrderModel updated) {
    final activeIdx = _activeOrders.indexWhere(
      (o) => o.orderNumber == updated.orderNumber,
    );
    if (activeIdx != -1) {
      _activeOrders[activeIdx] = updated;
    }

    final pastIdx = _pastOrders.indexWhere(
      (o) => o.orderNumber == updated.orderNumber,
    );
    if (pastIdx != -1) {
      _pastOrders[pastIdx] = updated;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearUserScopedData() {
    _scopeVersion++;
    _lookups = null;
    _lookupsLoading = false;
    _lookupsError = null;
    _totalOrdersCount = null;
    _isLoadingTotalOrdersCount = false;
    _activeOrders = [];
    _activeMeta = null;
    _activeStatus = OrdersStatus.initial;
    _loadingMoreActive = false;
    _pastOrders = [];
    _pastMeta = null;
    _pastStatus = OrdersStatus.initial;
    _loadingMorePast = false;
    _isCreatingOrder = false;
    _lastCreatedOrder = null;
    _errorMessage = null;
    _isConfirming = false;
    notifyListeners();
  }

  void updateLookupsWalletBalance(double balance) {
    final current = _lookups;
    if (current == null) return;

    _lookups = OrdersLookups(
      currency: current.currency,
      orderStatuses: current.orderStatuses,
      paymentStatuses: current.paymentStatuses,
      paymentMethods: current.paymentMethods,
      shippingCities: current.shippingCities,
      walletBalance: balance,
      walletEnabled: current.walletEnabled,
    );
    notifyListeners();
  }

  bool _hasUsefulShipping(OrderShipping? shipping) {
    if (shipping == null) return false;

    return shipping.fullName.trim().isNotEmpty ||
        shipping.phone.trim().isNotEmpty ||
        shipping.addressLine1.trim().isNotEmpty ||
        (shipping.addressLine2?.trim().isNotEmpty ?? false) ||
        shipping.city.trim().isNotEmpty;
  }

  int _createdAtMillis(String? rawValue) {
    return DateTime.tryParse(rawValue ?? '')?.millisecondsSinceEpoch ?? -1;
  }
}

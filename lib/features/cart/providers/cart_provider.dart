import 'package:flutter/material.dart';

class CartItem {
  static const int fallbackMaxQuantity = 99;

  final String id;
  final int productId;
  final int? productVariantId;
  final String name;
  final String? variantInfo;
  final double price;
  final String imageUrl;
  int maxQuantity;
  bool? _isAvailable;
  int quantity;

  static String buildId({
    required int productId,
    int? productVariantId,
    String? variantKey,
  }) {
    final normalizedVariantKey = variantKey?.trim().toLowerCase();
    final suffix = productVariantId?.toString() ?? normalizedVariantKey;
    if (suffix == null || suffix.isEmpty) {
      return productId.toString();
    }
    return '$productId:$suffix';
  }

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.productVariantId,
    this.variantInfo,
    int? maxQuantity,
    bool? isAvailable,
    this.quantity = 1,
  }) : _isAvailable = isAvailable,
       maxQuantity = maxQuantity == null || maxQuantity <= 0
           ? fallbackMaxQuantity
           : maxQuantity;

  bool get isAvailable => _isAvailable ?? true;

  set isAvailable(bool? value) {
    _isAvailable = value ?? true;
  }

  int get maxPurchasableQuantity => isAvailable ? maxQuantity : 0;

  bool get canIncrease => quantity < maxPurchasableQuantity;

  bool get canCheckout =>
      isAvailable && quantity > 0 && quantity <= maxPurchasableQuantity;
}

enum CartMutationStatus {
  added,
  updated,
  unavailable,
  limitReached,
  invalidQuantity,
}

class CartMutationResult {
  final CartMutationStatus status;
  final int? maxQuantity;

  const CartMutationResult._(this.status, {this.maxQuantity});

  bool get didChange =>
      status == CartMutationStatus.added ||
      status == CartMutationStatus.updated;

  bool get isUnavailable => status == CartMutationStatus.unavailable;

  bool get isLimitReached => status == CartMutationStatus.limitReached;

  bool get isInvalidQuantity => status == CartMutationStatus.invalidQuantity;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  bool get canCheckout =>
      _items.isNotEmpty && _items.every((item) => item.canCheckout);

  CartMutationResult addItem(CartItem item) {
    if (item.quantity <= 0) {
      return const CartMutationResult._(CartMutationStatus.invalidQuantity);
    }

    if (!item.isAvailable || item.maxPurchasableQuantity <= 0) {
      return const CartMutationResult._(CartMutationStatus.unavailable);
    }

    final index = _items.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      final existing = _items[index];
      existing.isAvailable = item.isAvailable;
      existing.maxQuantity = item.maxPurchasableQuantity;

      final nextQuantity = existing.quantity + item.quantity;
      if (nextQuantity > existing.maxPurchasableQuantity) {
        if (existing.quantity >= existing.maxPurchasableQuantity) {
          return CartMutationResult._(
            CartMutationStatus.limitReached,
            maxQuantity: existing.maxPurchasableQuantity,
          );
        }

        existing.quantity = existing.maxPurchasableQuantity;
        notifyListeners();
        return CartMutationResult._(
          CartMutationStatus.updated,
          maxQuantity: existing.maxPurchasableQuantity,
        );
      }

      existing.quantity = nextQuantity;
      notifyListeners();
      return CartMutationResult._(
        CartMutationStatus.updated,
        maxQuantity: existing.maxPurchasableQuantity,
      );
    }

    final quantity = item.quantity
        .clamp(1, item.maxPurchasableQuantity)
        .toInt();
    item.quantity = quantity;
    _items.add(item);
    notifyListeners();
    return CartMutationResult._(
      CartMutationStatus.added,
      maxQuantity: item.maxPurchasableQuantity,
    );
  }

  CartMutationResult increaseQuantity(String id) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) {
      return const CartMutationResult._(CartMutationStatus.unavailable);
    }

    final item = _items[index];
    if (!item.isAvailable || item.maxPurchasableQuantity <= 0) {
      return const CartMutationResult._(CartMutationStatus.unavailable);
    }

    if (item.quantity >= item.maxPurchasableQuantity) {
      return CartMutationResult._(
        CartMutationStatus.limitReached,
        maxQuantity: item.maxPurchasableQuantity,
      );
    }

    item.quantity++;
    notifyListeners();
    return CartMutationResult._(
      CartMutationStatus.updated,
      maxQuantity: item.maxPurchasableQuantity,
    );
  }

  void removeItem(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void decreaseQuantity(String id) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

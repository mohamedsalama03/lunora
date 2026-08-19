import 'package:app_aila/features/cart/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CartItem item({
    String id = '1',
    int quantity = 1,
    int maxQuantity = 5,
    bool isAvailable = true,
    double price = 12.5,
  }) {
    return CartItem(
      id: id,
      productId: int.parse(id.split(':').first),
      name: 'Product $id',
      price: price,
      imageUrl: '',
      quantity: quantity,
      maxQuantity: maxQuantity,
      isAvailable: isAvailable,
    );
  }

  group('CartProvider', () {
    test('adds an available product and calculates totals', () {
      final cart = CartProvider();

      final result = cart.addItem(item(quantity: 2));

      expect(result.status, CartMutationStatus.added);
      expect(cart.itemCount, 2);
      expect(cart.totalPrice, 25);
      expect(cart.canCheckout, isTrue);
    });

    test('merges duplicate cart IDs', () {
      final cart = CartProvider()..addItem(item());

      final result = cart.addItem(item(quantity: 2));

      expect(result.status, CartMutationStatus.updated);
      expect(cart.items, hasLength(1));
      expect(cart.items.single.quantity, 3);
    });

    test('caps a duplicate at available stock', () {
      final cart = CartProvider()..addItem(item(quantity: 4));

      final result = cart.addItem(item(quantity: 3));

      expect(result.status, CartMutationStatus.updated);
      expect(cart.items.single.quantity, 5);
      expect(result.maxQuantity, 5);
    });

    test('reports the stock limit without mutating a full item', () {
      final cart = CartProvider()..addItem(item(quantity: 5));

      final result = cart.increaseQuantity('1');

      expect(result.status, CartMutationStatus.limitReached);
      expect(cart.items.single.quantity, 5);
    });

    test('rejects unavailable products', () {
      final cart = CartProvider();

      final result = cart.addItem(item(isAvailable: false));

      expect(result.status, CartMutationStatus.unavailable);
      expect(cart.items, isEmpty);
    });

    test('rejects zero and negative quantities for new products', () {
      final cart = CartProvider();

      final zero = cart.addItem(item(quantity: 0));
      final negative = cart.addItem(item(quantity: -2));

      expect(zero.status, CartMutationStatus.invalidQuantity);
      expect(negative.status, CartMutationStatus.invalidQuantity);
      expect(cart.items, isEmpty);
    });

    test('negative duplicate quantity cannot reduce an existing item', () {
      final cart = CartProvider()..addItem(item(quantity: 3));

      final result = cart.addItem(item(quantity: -2));

      expect(result.status, CartMutationStatus.invalidQuantity);
      expect(cart.items.single.quantity, 3);
      expect(cart.canCheckout, isTrue);
    });

    test('decreasing one item removes it', () {
      final cart = CartProvider()..addItem(item());

      cart.decreaseQuantity('1');

      expect(cart.items, isEmpty);
      expect(cart.canCheckout, isFalse);
    });

    test('remove and clear update the cart', () {
      final cart = CartProvider()
        ..addItem(item())
        ..addItem(item(id: '2'));

      cart.removeItem('1');
      expect(cart.items.map((entry) => entry.id), ['2']);

      cart.clearCart();
      expect(cart.items, isEmpty);
      expect(cart.totalPrice, 0);
    });

    test('buildId distinguishes variants and normalizes variant keys', () {
      expect(CartItem.buildId(productId: 7), '7');
      expect(CartItem.buildId(productId: 7, productVariantId: 3), '7:3');
      expect(
        CartItem.buildId(productId: 7, variantKey: '  RED / XL '),
        '7:red / xl',
      );
    });
  });
}

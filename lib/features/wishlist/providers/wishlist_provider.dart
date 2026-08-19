import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class WishlistProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String _storageKey = 'wishlist_items';

  List<ProductModel> _items = [];

  List<ProductModel> get items => _items;
  int get itemCount => _items.length;

  WishlistProvider() {
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      final String? data = await _storage.read(key: _storageKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _items = jsonList.map((item) {
          // Add missing options if they don't exist since they are now required in some screens
          if (item['options'] == null) {
            item['options'] = {'colors': [], 'sizes': []};
          }
          return ProductModel.fromJson(item);
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> _saveWishlist() async {
    try {
      // Create a map representation that can be encoded back to JSON
      final List<Map<String, dynamic>> jsonList = _items.map((item) {
        return {
          'id': item.id,
          'name': item.name,
          'slug': item.slug,
          'short_description': item.shortDescription,
          'thumbnail': item.thumbnail,
          'pricing': {
            'price': item.pricing.price,
            'sale_price': item.pricing.salePrice,
            'effective_price': item.pricing.effectivePrice,
            'is_on_sale': item.pricing.isOnSale,
            'discount_percentage': item.pricing.discountPercentage,
          },
          'stock': {
            'in_stock': item.stock.inStock,
            'quantity': item.stock.quantity,
          },
          'rating': {
            'average': item.rating.average,
            'count': item.rating.count,
          },
          'is_featured': item.isFeatured,
          'options': {
            'colors': item.options?.colors ?? [],
            'sizes': item.options?.sizes ?? [],
          },
        };
      }).toList();

      await _storage.write(key: _storageKey, value: jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving wishlist: $e');
    }
  }

  bool isFavorite(int productId) {
    return _items.any((item) => item.id == productId);
  }

  void toggleFavorite(ProductModel product) {
    final bool exists = isFavorite(product.id);
    if (exists) {
      _items.removeWhere((item) => item.id == product.id);
    } else {
      _items.add(product);
    }
    _saveWishlist();
    notifyListeners();
  }

  void removeFavorite(int productId) {
    _items.removeWhere((item) => item.id == productId);
    _saveWishlist();
    notifyListeners();
  }

  void clearWishlist() {
    _items.clear();
    _saveWishlist();
    notifyListeners();
  }
}

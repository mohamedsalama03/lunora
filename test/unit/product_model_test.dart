import 'package:app_aila/core/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseJson() => <String, dynamic>{
  'id': '12',
  'name': 'Serum',
  'slug': 'serum',
  'pricing': <String, dynamic>{
    'price': '25.50',
    'sale_price': 20,
    'effective_price': '20.0',
    'is_on_sale': 1,
    'discount_percentage': '22',
  },
  'stock': <String, dynamic>{'in_stock': true, 'quantity': '4'},
  'rating': <String, dynamic>{'average': '4.5', 'count': '8'},
};

void main() {
  group('ProductModel.fromJson', () {
    test('accepts numeric values represented as numbers or strings', () {
      final product = ProductModel.fromJson(_baseJson());

      expect(product.id, 12);
      expect(product.pricing.price, 25.5);
      expect(product.pricing.salePrice, 20);
      expect(product.pricing.isOnSale, isTrue);
      expect(product.rating.average, 4.5);
      expect(product.maxPurchasableQuantity, 4);
    });

    test('uses safe defaults for missing nested API objects', () {
      final product = ProductModel.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Minimal',
        'slug': 'minimal',
      });

      expect(product.pricing.effectivePrice, 0);
      expect(product.stock.isAvailable, isFalse);
      expect(product.rating.count, 0);
      expect(product.isPurchasable, isFalse);
    });

    test('drops malformed and empty image entries', () {
      final json = _baseJson()
        ..['images'] = <dynamic>[
          null,
          'not-a-map',
          <String, dynamic>{'id': 1, 'url': ''},
          <String, dynamic>{'id': 2, 'url': '/valid.jpg'},
        ];

      final product = ProductModel.fromJson(json);

      expect(product.images, hasLength(1));
      expect(product.images!.single.url, '/valid.jpg');
    });

    test('requires an available variant when loaded variants exist', () {
      final json = _baseJson()
        ..['options'] = <String, dynamic>{
          'colors': <String>['red'],
          'sizes': <String>[],
        }
        ..['variants'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'type': 'color',
            'value': 'red',
            'final_price': 20,
            'stock': 0,
          },
        ];

      final product = ProductModel.fromJson(json);

      expect(product.hasLoadedVariants, isTrue);
      expect(product.hasPurchasableVariant, isFalse);
      expect(product.isPurchasable, isFalse);
      expect(product.maxPurchasableQuantity, 4);
    });

    test('uses the largest available variant stock as purchase limit', () {
      final json = _baseJson()
        ..['variants'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'type': 'color',
            'value': 'red',
            'final_price': 20,
            'stock': 2,
          },
          <String, dynamic>{
            'id': 3,
            'type': 'color',
            'value': 'blue',
            'final_price': 22,
            'stock': 7,
          },
        ];

      final product = ProductModel.fromJson(json);

      expect(product.isPurchasable, isTrue);
      expect(product.maxPurchasableQuantity, 7);
    });

    test('normalizes tags and permissive boolean values', () {
      final json = _baseJson()
        ..['is_featured'] = 'yes'
        ..['tags'] = <dynamic>[' skin ', '', null, 3];

      final product = ProductModel.fromJson(json);

      expect(product.isFeatured, isTrue);
      expect(product.tags, <String>['skin', '3']);
    });

    test('maps detail content fields from product details payload', () {
      final json = _baseJson()
        ..['ingredients'] = <dynamic>[' water ', '', null, 'vitamin c']
        ..['usage_instructions'] = 'Apply after cleansing.';

      final product = ProductModel.fromJson(json);

      expect(product.ingredients, 'water\nvitamin c');
      expect(product.usageInstructions, 'Apply after cleansing.');
    });

    test('accepts fallback usage field names', () {
      final product = ProductModel.fromJson(
        _baseJson()..['how_to_use'] = 'Use once daily.',
      );

      expect(product.usageInstructions, 'Use once daily.');
    });
  });
}

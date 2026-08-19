# Flutter Products/Categories API

هذا الملف يوثق واجهات عرض الفئات والمنتجات الخاصة بتطبيق Flutter.

الواجهات عامة ولا تحتاج `Authorization`، وهي مخصصة لشاشات:

- الصفحة الرئيسية
- قائمة الفئات
- قائمة المنتجات
- صفحة تفاصيل المنتج

## Base URL

`BASE_URL = https://hindam.ly`

كل المسارات التالية تكون بالنسبة إلى `BASE_URL`.

## Public Endpoints

- `GET /api/flutter/categories`
- `GET /api/flutter/products`
- `GET /api/flutter/products/{slug}`

## Headers المقترحة

```http
Accept: application/json
Content-Type: application/json
```

## 1) Categories

### Endpoint

`GET /api/flutter/categories`

### الاستخدام

إرجاع الفئات الرئيسية النشطة مع الفئات الفرعية النشطة الخاصة بها.

### ملاحظات مهمة

- هذا endpoint يعيد فقط الفئات المناسبة للعرض داخل التطبيق.
- الفئات غير النشطة لا تظهر.
- الفئات الفارغة التي لا تحتوي على منتجات نشطة لا تظهر.
- كل فئة رئيسية يمكن أن تحتوي على `children` لعرض الفئات الفرعية.

### Success Response

`200 OK`

```json
{
  "data": [
    {
      "id": 1,
      "name": "ماكينات الحلاقة",
      "slug": "clippers",
      "description": null,
      "image_url": "https://hindam.ly/images/placeholder-category.jpg",
      "parent_id": null,
      "sort_order": 1,
      "products_count": 0,
      "children_count": 2,
      "children": [
        {
          "id": 2,
          "name": "ماكينات احترافية",
          "slug": "professional-clippers",
          "description": null,
          "image_url": "https://hindam.ly/images/placeholder-category.jpg",
          "parent_id": 1,
          "sort_order": 1,
          "products_count": 6,
          "children_count": 0,
          "children": []
        }
      ]
    }
  ]
}
```

### شرح الحقول

- `id`: رقم الفئة.
- `name`: اسم الفئة.
- `slug`: يستخدم في الربط والفلترة.
- `description`: وصف الفئة أو `null`.
- `image_url`: رابط صورة الفئة.
- `parent_id`: `null` إذا كانت الفئة رئيسية.
- `sort_order`: ترتيب العرض.
- `products_count`: عدد المنتجات النشطة المباشرة داخل هذه الفئة.
- `children_count`: عدد الفئات الفرعية المعادة.
- `children`: مصفوفة الفئات الفرعية.

## 2) Products List

### Endpoint

`GET /api/flutter/products`

### الاستخدام

إرجاع قائمة المنتجات مع دعم الفلترة والبحث والترتيب وPagination.

### Query Parameters

- `q`: اختياري. البحث داخل `name` و`short_description`.
- `category_slug`: اختياري. فلترة المنتجات حسب `slug` الفئة.
- `availability`: اختياري. القيم المسموحة:
  - `all`
  - `in_stock`
  - `on_sale`
  - `featured`
- `sort`: اختياري. القيم المسموحة:
  - `recommended`
  - `latest`
  - `price_low`
  - `price_high`
  - `name`
- `per_page`: اختياري. الافتراضي `20` والحد الأقصى `60`.
- `page`: اختياري. رقم الصفحة الحالية.

### ملاحظات السلوك

- إذا أرسلت `category_slug` لفئة رئيسية ولديها فئات فرعية تحتوي على منتجات، فسيتم إرجاع منتجات الفئات الفرعية.
- إذا كانت الفئة الفرعية المختارة لا تحتوي على منتجات مباشرة، فقد يتم الرجوع إلى منتجات الفئة الرئيسية بحسب منطق المتجر الحالي.
- يعاد فقط المنتج النشط `is_active = true`.

### Example Request

```http
GET /api/flutter/products?category_slug=clippers&availability=featured&sort=price_low&per_page=10&page=1
```

### Success Response

`200 OK`

```json
{
  "data": [
    {
      "id": 15,
      "name": "Andis Pro",
      "slug": "andis-pro",
      "short_description": "ماكينة احترافية للحلاقين",
      "thumbnail": "https://hindam.ly/storage/products/andis-pro.jpg",
      "pricing": {
        "price": 120,
        "sale_price": 90,
        "effective_price": 90,
        "is_on_sale": true,
        "discount_percentage": 25
      },
      "stock": {
        "in_stock": true,
        "quantity": 7
      },
      "rating": {
        "average": 4.5,
        "count": 12
      },
      "is_featured": true,
      "category": {
        "id": 2,
        "name": "ماكينات احترافية",
        "slug": "professional-clippers"
      },
      "brand": {
        "id": 3,
        "name": "Andis",
        "slug": "andis",
        "logo_url": "https://hindam.ly/images/placeholder-brand.jpg"
      },
      "options": {
        "colors": [
          "Black"
        ],
        "sizes": []
      }
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 10,
    "total": 1,
    "from": 1,
    "to": 1
  },
  "filters": {
    "q": null,
    "category_slug": "clippers",
    "availability": "featured",
    "sort": "price_low"
  },
  "selected_category": {
    "id": 1,
    "name": "ماكينات الحلاقة",
    "slug": "clippers"
  }
}
```

### شرح أهم الحقول

- `thumbnail`: صورة المنتج الأساسية أو أول صورة متاحة أو صورة افتراضية.
- `pricing.price`: السعر الأصلي.
- `pricing.sale_price`: سعر العرض أو `null`.
- `pricing.effective_price`: السعر الفعلي الذي يجب عرضه داخل التطبيق.
- `pricing.is_on_sale`: هل المنتج عليه تخفيض.
- `pricing.discount_percentage`: نسبة الخصم.
- `stock.in_stock`: هل المنتج متوفر.
- `stock.quantity`: الكمية الحالية.
- `rating.average`: متوسط التقييم.
- `rating.count`: عدد التقييمات.
- `options.colors`: الألوان المتاحة من الـ variants النشطة.
- `options.sizes`: الأحجام المتاحة من الـ variants النشطة.
- `meta`: بيانات Pagination.
- `filters`: الفلاتر المستخدمة فعليًا بعد تطبيق القيم الافتراضية.
- `selected_category`: الفئة التي تم الفلترة بها إذا تم إرسال `category_slug`.

### الأخطاء المحتملة

#### الفئة غير موجودة

`404 Not Found`

```json
{
  "message": "Category not found."
}
```

#### خطأ في قيم الفلاتر

`422 Unprocessable Entity`

مثال إذا أرسلت قيمة غير صحيحة في `availability` أو `sort` أو `per_page`.

## 3) Product Details

### Endpoint

`GET /api/flutter/products/{slug}`

### الاستخدام

إرجاع تفاصيل منتج واحد باستخدام `slug`.

### Example Request

```http
GET /api/flutter/products/wahl-detailer
```

### Success Response

`200 OK`

```json
{
  "data": {
    "id": 21,
    "name": "Wahl Detailer",
    "slug": "wahl-detailer",
    "short_description": "Precision trimmer",
    "thumbnail": "https://hindam.ly/storage/products/wahl-detailer-primary.jpg",
    "pricing": {
      "price": 120,
      "sale_price": 99,
      "effective_price": 99,
      "is_on_sale": true,
      "discount_percentage": 18
    },
    "stock": {
      "in_stock": true,
      "quantity": 8
    },
    "rating": {
      "average": 4.5,
      "count": 12
    },
    "is_featured": false,
    "category": {
      "id": 5,
      "name": "Trimmers",
      "slug": "trimmers"
    },
    "brand": {
      "id": 4,
      "name": "Wahl",
      "slug": "wahl",
      "logo_url": "https://hindam.ly/images/placeholder-brand.jpg"
    },
    "options": {
      "colors": [
        "Silver"
      ],
      "sizes": []
    },
    "description": "Professional trimmer for barbers.",
    "sku": "WAHL-DETAILER",
    "weight": "350g",
    "dimensions": "15x4x4 cm",
    "tags": [
      "trimmer",
      "wahl"
    ],
    "images": [
      {
        "id": 1,
        "url": "https://hindam.ly/storage/products/wahl-detailer-primary.jpg",
        "alt_text": "Wahl Detailer",
        "sort_order": 1,
        "is_primary": true
      },
      {
        "id": 2,
        "url": "https://hindam.ly/storage/products/wahl-detailer-gallery.jpg",
        "alt_text": "Wahl Detailer Side",
        "sort_order": 2,
        "is_primary": false
      }
    ],
    "variants": [
      {
        "id": 8,
        "type": "color",
        "value": "Silver",
        "price_modifier": 5,
        "final_price": 104,
        "stock": 4,
        "sku": "WAHL-DETAILER-SILVER",
        "image_url": null
      }
    ]
  }
}
```

### ملاحظات مهمة

- هذا endpoint يعيد فقط المنتج النشط.
- `variants` تحتوي فقط على الـ variants النشطة.
- `final_price` داخل كل variant = `effective_price + price_modifier`.
- `images` جاهزة للعرض مباشرة داخل Flutter لأنها روابط كاملة.

### الخطأ المحتمل

`404 Not Found`

```json
{
  "message": "Product not found."
}
```

## مثال سريع باستخدام Dio

```dart
final dio = Dio(
  BaseOptions(
    baseUrl: 'https://hindam.ly',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ),
);

Future<Map<String, dynamic>> fetchCategories() async {
  final response = await dio.get('/api/flutter/categories');
  return Map<String, dynamic>.from(response.data as Map);
}

Future<Map<String, dynamic>> fetchProducts({
  String? categorySlug,
  String? query,
  String availability = 'all',
  String sort = 'recommended',
  int perPage = 20,
  int page = 1,
}) async {
  final response = await dio.get(
    '/api/flutter/products',
    queryParameters: {
      'category_slug': categorySlug,
      'q': query,
      'availability': availability,
      'sort': sort,
      'per_page': perPage,
      'page': page,
    },
  );

  return Map<String, dynamic>.from(response.data as Map);
}

Future<Map<String, dynamic>> fetchProductDetails(String slug) async {
  final response = await dio.get('/api/flutter/products/$slug');
  return Map<String, dynamic>.from(response.data as Map);
}
```

## روابط كاملة كمثال

- `GET https://hindam.ly/api/flutter/categories`
- `GET https://hindam.ly/api/flutter/products`
- `GET https://hindam.ly/api/flutter/products/{slug}`

# Flutter Offers API

هذا الملف يشرح واجهة `API` الخاصة بالعروض التي يتم إدارتها من لوحة التحكم في صفحة:

`resources/views/admin/offers/index.blade.php`

الهدف من هذا الـ API هو تمكين تطبيق Flutter من جلب العروض الفعالة وعرضها بنفس المنطق الموجود حالياً في الموقع، مع دعم:

- العروض العادية `normal` التي تظهر داخل قسم العروض الرئيسي.
- العروض المنبثقة `popup`.
- العروض الخاصة المرتبطة بعميل محدد.
- العروض الموجهة لشريحة `top_customers`.
- العمل بشكل عام للزوار، وبشكل مخصص أكثر عند إرسال `Bearer Token` لعميل مسجل.

## ما الذي تمت إضافته

تمت إضافة endpoint جديد:

`GET /api/flutter/offers`

وهو endpoint مخصص للقراءة فقط من تطبيق Flutter.

هذا المسار لا يقوم بإنشاء أو تعديل أو حذف العروض. الإدارة تبقى من لوحة التحكم، بينما التطبيق يستهلك فقط العروض المناسبة للمستخدم الحالي.

## Base URL

استبدل الدومين التالي بعنوان السيرفر الحقيقي:

`BASE_URL = https://your-domain.com`

## Endpoint

```http
GET /api/flutter/offers
```

## Authentication

هذا الـ endpoint يعمل بطريقتين:

### 1) بدون تسجيل دخول

إذا استدعى Flutter هذا المسار بدون `Authorization` header فسيحصل على:

- العروض العامة `normal` فقط.
- بدون أي عروض `popup`.
- بدون عروض العملاء الخاصة.
- بدون عروض `top_customers`.

### 2) مع تسجيل دخول عميل

إذا أرسل Flutter توكن عميل فعال:

```http
Authorization: Bearer YOUR_TOKEN
Accept: application/json
Content-Type: application/json
```

فإن الـ API سيحاول تخصيص النتيجة بحسب العميل الحالي، ويعيد:

- العروض الخاصة المرتبطة بهذا العميل إن وجدت.
- العروض المناسبة له إذا كان ضمن `top_customers`.
- العروض المنبثقة `popup` الخاصة به أو العامة المناسبة له.

مهم:

- التوكن اختياري.
- إذا لم يكن التوكن صالحاً أو كان المستخدم غير عميل أو الحساب غير فعال، فسيتم التعامل مع الطلب كزائر عام.

## فكرة الاستجابة

الاستجابة تحتوي على 4 أجزاء رئيسية:

- `viewer`: معلومات عن حالة المستخدم الحالي بالنسبة لهذا الـ API.
- `normal_offers`: العروض العادية لقسم العروض الرئيسي.
- `popup_offers`: العروض المنبثقة.
- `counts`: عدد العناصر في كل قسم.

## Success Response

`200 OK`

### مثال response لزائر غير مسجل

```json
{
  "data": {
    "viewer": {
      "is_authenticated": false,
      "customer_id": null,
      "is_top_customer": false,
      "has_personalized_offers": false
    },
    "normal_offers": [
      {
        "id": 3,
        "title": "خصم 20% على الماكينات",
        "subtitle": "لفترة محدودة",
        "description": "استفد من خصم خاص على المنتجات المحددة.",
        "badge_text": "HOT",
        "highlight_text": "ينتهي قريباً",
        "coupon_code": "SAVE20",
        "cta_text": "تسوق الآن",
        "cta_url": "/products",
        "cta_web_url": "https://your-domain.com/products",
        "cta_type": "internal",
        "display_mode": "normal",
        "target_audience": "all_customers",
        "is_active": true,
        "sort_order": 1,
        "mobile_bg_image": "https://your-domain.com/storage/offers/mobile_sample.jpg",
        "desktop_bg_image": "https://your-domain.com/storage/offers/desktop_sample.jpg",
        "source": "general"
      }
    ],
    "popup_offers": [],
    "counts": {
      "normal_offers": 1,
      "popup_offers": 0
    },
    "fetched_at": "2026-03-11T10:15:22.000000Z"
  }
}
```

### مثال response لعميل مسجل لديه عروض خاصة

```json
{
  "data": {
    "viewer": {
      "is_authenticated": true,
      "customer_id": 15,
      "is_top_customer": false,
      "has_personalized_offers": true
    },
    "normal_offers": [
      {
        "id": 12,
        "title": "عرض خاص لك",
        "subtitle": "للعملاء المميزين",
        "description": "خصم مخصص على مجموعة مختارة.",
        "badge_text": "VIP",
        "highlight_text": "متاح الآن",
        "coupon_code": "VIP30",
        "cta_text": "افتح العرض",
        "cta_url": "/products",
        "cta_web_url": "https://your-domain.com/products",
        "cta_type": "internal",
        "display_mode": "normal",
        "target_audience": "all_customers",
        "is_active": true,
        "sort_order": 99,
        "mobile_bg_image": "https://your-domain.com/storage/offers/vip_mobile.jpg",
        "desktop_bg_image": "https://your-domain.com/storage/offers/vip_desktop.jpg",
        "source": "special"
      },
      {
        "id": 4,
        "title": "عرض عام إضافي",
        "subtitle": null,
        "description": null,
        "badge_text": null,
        "highlight_text": null,
        "coupon_code": null,
        "cta_text": null,
        "cta_url": "/products",
        "cta_web_url": "https://your-domain.com/products",
        "cta_type": "internal",
        "display_mode": "normal",
        "target_audience": "all_customers",
        "is_active": true,
        "sort_order": 1,
        "mobile_bg_image": null,
        "desktop_bg_image": null,
        "source": "general"
      }
    ],
    "popup_offers": [
      {
        "id": 18,
        "title": "Popup خاص لك",
        "subtitle": null,
        "description": "هذا العرض يظهر لك لأنك مرتبط به مباشرة.",
        "badge_text": null,
        "highlight_text": "لفترة محدودة",
        "coupon_code": "POP15",
        "cta_text": "استعراض",
        "cta_url": "/products",
        "cta_web_url": "https://your-domain.com/products",
        "cta_type": "internal",
        "display_mode": "popup",
        "target_audience": "all_customers",
        "is_active": true,
        "sort_order": 0,
        "mobile_bg_image": "https://your-domain.com/storage/offers/popup.jpg",
        "desktop_bg_image": null,
        "source": "special"
      }
    ],
    "counts": {
      "normal_offers": 2,
      "popup_offers": 1
    },
    "fetched_at": "2026-03-11T10:15:22.000000Z"
  }
}
```

## شرح الحقول

### `viewer`

- `is_authenticated`: هل تم التعرف على عميل صالح من خلال توكن Sanctum.
- `customer_id`: رقم العميل الحالي إذا كان الطلب مخصصاً، وإلا `null`.
- `is_top_customer`: هل العميل الحالي يقع ضمن شريحة العملاء الأعلى طلباً.
- `has_personalized_offers`: تصبح `true` إذا كان هناك أي عرض مصدره `special`.

### `normal_offers`

مصفوفة تمثل العروض العادية الخاصة بقسم العروض الرئيسي داخل التطبيق.

عددها الأقصى حالياً:

- `3` عناصر

### `popup_offers`

مصفوفة تمثل العروض المنبثقة.

عددها الأقصى حالياً:

- `8` عناصر عند استخدام العروض العامة `popup`
- أو جميع العروض الخاصة المرتبطة بالعميل إذا وجدت

مهم:

- الزائر غير المسجل سيستلم `popup_offers = []`
- العروض المنبثقة حالياً موجهة فقط لحالة وجود عميل مسجل

### الحقول داخل كل عنصر عرض

- `id`: رقم العرض.
- `title`: عنوان العرض.
- `subtitle`: عنوان فرعي اختياري.
- `description`: وصف اختياري.
- `badge_text`: شارة صغيرة مثل `HOT` أو `VIP`.
- `highlight_text`: نص إبراز مثل "ينتهي خلال 48 ساعة".
- `coupon_code`: كود الكوبون إن وجد.
- `cta_text`: نص زر الإجراء إن كان محفوظاً في لوحة التحكم، وقد يكون `null`.
- `cta_url`: الرابط الفعال الذي يجب أن يستخدمه Flutter. قد يكون:
  - رابطاً داخلياً يبدأ بـ `/`
  - أو رابطاً خارجياً كاملاً مثل `https://...`
  - وإذا لم يكن هناك رابط محفوظ فستكون القيمة الافتراضية `/products`
- `cta_web_url`: نفس الرابط لكن بصيغة كاملة قابلة للفتح مباشرة في المتصفح.
- `cta_type`: نوع الرابط:
  - `internal`
  - `external`
- `display_mode`: نوع العرض:
  - `normal`
  - `popup`
- `target_audience`: فئة الاستهداف:
  - `all_customers`
  - `top_customers`
- `is_active`: حالة العرض.
- `sort_order`: ترتيب العرض داخل النتائج العامة.
- `mobile_bg_image`: رابط صورة العرض المخصصة للهاتف (قد يكون `null`).
- `desktop_bg_image`: رابط صورة العرض المخصصة للشاشات الكبيرة (قد يكون `null`).
- `source`: مصدر العرض:
  - `general` إذا جاء من العروض العامة
  - `special` إذا كان العرض مرتبطاً مباشرة بالعميل

### `counts`

- `normal_offers`: عدد العروض في القائمة الأولى.
- `popup_offers`: عدد العروض المنبثقة.

### `fetched_at`

تاريخ ووقت إنشاء الاستجابة الحالية من السيرفر بصيغة ISO 8601.

## منطق اختيار العروض

هذا الجزء مهم جداً لأن تطبيق Flutter يجب أن يفهم كيف يختار السيرفر النتائج.

### أولاً: العروض العادية `normal_offers`

#### للزائر

يعيد السيرفر:

- العروض `active`
- من نوع `display_mode = normal`
- الموجهة إلى `all_customers`
- مرتبة حسب `sort_order` ثم `id`
- بحد أقصى `3`

#### للعميل المسجل

يعيد السيرفر بالترتيب التالي:

1. العروض الخاصة المرتبطة بالعميل مباشرة، إن وجدت.
2. إذا كان عدد العروض الخاصة أقل من `3`، يتم إكمال الباقي من العروض العامة المناسبة له.
3. إذا لم توجد عروض خاصة أصلاً، يتم الاكتفاء بالعروض العامة المناسبة له.

إذا كان العميل من `top_customers` فالعروض العامة المناسبة له تشمل:

- `all_customers`
- `top_customers`

أما إذا لم يكن ضمن هذه الشريحة فسيستلم فقط:

- `all_customers`

### ثانياً: العروض المنبثقة `popup_offers`

#### للزائر

حالياً:

- لا يتم إرجاع أي popup offers

#### للعميل المسجل

المنطق هو:

1. إذا كان لدى العميل عروض خاصة من نوع `popup`، يتم إرجاعها مباشرة.
2. إذا لم توجد عروض `popup` خاصة، يتم إرجاع العروض العامة `popup` المناسبة له.

إذا كان العميل `top_customer` فالعروض العامة `popup` قد تشمل:

- `all_customers`
- `top_customers`

## كيف يتعامل Flutter مع `cta_url`

أفضل ممارسة:

- إذا كانت `cta_type = internal`:
  - حاول توجيه المستخدم داخلياً داخل التطبيق حسب المسار.
  - مثال: `/products`
- إذا كانت `cta_type = external`:
  - افتح الرابط عبر `url_launcher` أو `WebView`
- إذا لم يكن لدى التطبيق route داخلي مطابق:
  - استخدم `cta_web_url` كخيار آمن لفتح صفحة الويب

## مثال Request

### بدون توكن

```http
GET /api/flutter/offers
Accept: application/json
```

### مع توكن

```http
GET /api/flutter/offers
Accept: application/json
Authorization: Bearer YOUR_TOKEN
```

## مثال Dio

```dart
class OffersApi {
  OffersApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> fetchOffers({String? token}) async {
    final response = await dio.get(
      '/api/flutter/offers',
      options: Options(
        headers: token == null
            ? null
            : <String, String>{
                'Authorization': 'Bearer $token',
              },
      ),
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}
```

## مثال Models في Flutter

```dart
class OfferViewer {
  OfferViewer({
    required this.isAuthenticated,
    required this.customerId,
    required this.isTopCustomer,
    required this.hasPersonalizedOffers,
  });

  final bool isAuthenticated;
  final int? customerId;
  final bool isTopCustomer;
  final bool hasPersonalizedOffers;

  factory OfferViewer.fromJson(Map<String, dynamic> json) {
    return OfferViewer(
      isAuthenticated: json['is_authenticated'] as bool? ?? false,
      customerId: json['customer_id'] as int?,
      isTopCustomer: json['is_top_customer'] as bool? ?? false,
      hasPersonalizedOffers: json['has_personalized_offers'] as bool? ?? false,
    );
  }
}

class OfferItem {
  OfferItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badgeText,
    required this.highlightText,
    required this.couponCode,
    required this.ctaText,
    required this.ctaUrl,
    required this.ctaWebUrl,
    required this.ctaType,
    required this.displayMode,
    required this.targetAudience,
    required this.isActive,
    required this.sortOrder,
    this.mobileBgImage,
    this.desktopBgImage,
    required this.source,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? badgeText;
  final String? highlightText;
  final String? couponCode;
  final String? ctaText;
  final String ctaUrl;
  final String ctaWebUrl;
  final String ctaType;
  final String displayMode;
  final String targetAudience;
  final bool isActive;
  final int sortOrder;
  final String? mobileBgImage;
  final String? desktopBgImage;
  final String source;

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    return OfferItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      badgeText: json['badge_text'] as String?,
      highlightText: json['highlight_text'] as String?,
      couponCode: json['coupon_code'] as String?,
      ctaText: json['cta_text'] as String?,
      ctaUrl: json['cta_url'] as String? ?? '/products',
      ctaWebUrl: json['cta_web_url'] as String? ?? '',
      ctaType: json['cta_type'] as String? ?? 'internal',
      displayMode: json['display_mode'] as String? ?? 'normal',
      targetAudience: json['target_audience'] as String? ?? 'all_customers',
      isActive: json['is_active'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      mobileBgImage: json['mobile_bg_image'] as String?,
      desktopBgImage: json['desktop_bg_image'] as String?,
      source: json['source'] as String? ?? 'general',
    );
  }
}

class OffersResponse {
  OffersResponse({
    required this.viewer,
    required this.normalOffers,
    required this.popupOffers,
    required this.normalOffersCount,
    required this.popupOffersCount,
    required this.fetchedAt,
  });

  final OfferViewer viewer;
  final List<OfferItem> normalOffers;
  final List<OfferItem> popupOffers;
  final int normalOffersCount;
  final int popupOffersCount;
  final DateTime? fetchedAt;

  factory OffersResponse.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map);

    return OffersResponse(
      viewer: OfferViewer.fromJson(
        Map<String, dynamic>.from(data['viewer'] as Map),
      ),
      normalOffers: (data['normal_offers'] as List<dynamic>? ?? const [])
          .map((item) => OfferItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      popupOffers: (data['popup_offers'] as List<dynamic>? ?? const [])
          .map((item) => OfferItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      normalOffersCount:
          (data['counts'] as Map<String, dynamic>?)?['normal_offers'] as int? ?? 0,
      popupOffersCount:
          (data['counts'] as Map<String, dynamic>?)?['popup_offers'] as int? ?? 0,
      fetchedAt: data['fetched_at'] != null
          ? DateTime.tryParse(data['fetched_at'] as String)
          : null,
    );
  }
}
```

## مثال استخدام داخل Flutter

```dart
final payload = await offersApi.fetchOffers(token: accessToken);
final offers = OffersResponse.fromJson(payload);

final heroOffers = offers.normalOffers;
final popupOffers = offers.popupOffers;
final shouldShowPopup = popupOffers.isNotEmpty;
final isTopCustomer = offers.viewer.isTopCustomer;
```

## توصية عملية في التطبيق

يمكنك تقسيم الاستخدام داخل Flutter بهذا الشكل:

- الشاشة الرئيسية:
  - استخدم `normal_offers`
- عند فتح التطبيق بعد تسجيل الدخول:
  - افحص `popup_offers`
  - إذا كانت غير فارغة اعرض popup داخلياً
- إذا كان `source = special`:
  - يمكنك إعطاء العرض تمييزاً بصرياً إضافياً داخل التطبيق

## أكواد الحالة

- `200`: نجاح الطلب
- `500`: خطأ داخلي في السيرفر

## ملاحظات مهمة

- هذا الـ API يعيد فقط العروض الفعالة `is_active = true`.
- التطبيق لا يحتاج للوصول إلى صفحة الإدارة أو نماذج الحذف/التعديل.
- إذا أردت محاكاة سلوك الموقع بدقة، استدعِ هذا endpoint مع التوكن بعد تسجيل الدخول، وبدونه قبل تسجيل الدخول.
- إذا كان `cta_text = null` يمكنك وضع fallback داخل التطبيق مثل:
  - `تسوق العرض`
- إذا كان `popup_offers` فارغاً فهذا سلوك صحيح وليس خطأ.

## الخلاصة

الربط المقترح داخل Flutter يكون كالتالي:

- استخدم `GET /api/flutter/offers`
- بدون توكن للحصول على العروض العامة
- ومع توكن للحصول على العروض المخصصة
- اعتمد على:
  - `normal_offers` لعرض بطاقات العروض الرئيسية
  - `popup_offers` لعرض العروض المنبثقة
  - `viewer` لفهم حالة المستخدم الحالية

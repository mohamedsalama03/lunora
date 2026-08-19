# Flutter App Banners API

هذا الملف يشرح endpoint اللوحات الإعلانية الخاصة بتطبيق Flutter، وهي اللوحات التي تتم إدارتها من لوحة التحكم ثم تظهر داخل التطبيق، غالباً في الصفحة الرئيسية أو أي Slider / Carousel مشابه.

تم التحقق من المسار من خلال:

- تعريفه في `routes/api.php`.
- الكنترولر `App\Http\Controllers\Api\FlutterAppBannerController`.
- الموديل `App\Models\AppBanner`.
- اختبار Feature جديد: `tests/Feature/FlutterAppBannersApiTest.php`.

## الهدف

الهدف من هذا الـ API هو أن يجلب تطبيق Flutter اللوحات الفعالة فقط من لوحة التحكم، مرتبة حسب ترتيب العرض، مع معلومات تساعد التطبيق على تحديد ماذا يحدث عند ضغط المستخدم على اللوحة.

المسار للقراءة فقط. تطبيق Flutter لا ينشئ ولا يعدل ولا يحذف اللوحات من هذا endpoint.

## Base URL

استبدل الدومين التالي بدومين السيرفر الحقيقي:

```text
BASE_URL=https://hindam.ly
```

## Endpoint

```http
GET /api/flutter/app-banners
```

مثال كامل:

```http
GET https://hindam.ly/api/flutter/app-banners
Accept: application/json
```

## Authentication

هذا endpoint عام ولا يحتاج إلى `Bearer Token`.

لا ترسل توكن لهذا المسار إلا إذا كان إعداد Dio العام يضيفه تلقائياً؛ وجود التوكن لا يغير نتيجة اللوحات حالياً، لأن المسار خارج مجموعة `auth:sanctum`.

## Success Response

كود النجاح:

```http
200 OK
```

شكل الاستجابة:

```json
{
  "data": [
    {
      "id": 1,
      "title": "عرض خاص على الماكينات",
      "image_url": "https://your-domain.com/storage/app-banners/banner.jpg",
      "type": "category",
      "linked_id": 4,
      "external_link": null,
      "sort_order": 1
    }
  ]
}
```

إذا لم توجد لوحات فعالة، ستكون الاستجابة ناجحة لكن القائمة فارغة:

```json
{
  "data": []
}
```

## منطق الإرجاع

السيرفر يرجع اللوحات بهذه القواعد:

- يرجع فقط اللوحات التي قيمة `is_active` لديها تساوي `true`.
- لا يرجع اللوحات غير الفعالة حتى لو كانت موجودة في قاعدة البيانات.
- يرتب النتائج حسب `sort_order` تصاعدياً.
- إذا تساوت أكثر من لوحة في `sort_order`، يتم ترتيبها بعدها حسب `id` تصاعدياً.

الاستعلام الفعلي داخل الكنترولر يعتمد على:

```php
AppBanner::where('is_active', true)
    ->orderBy('sort_order')
    ->orderBy('id')
```

## شرح الحقول

### `id`

رقم اللوحة في قاعدة البيانات.

استخدمه داخل Flutter كمفتاح ثابت للعنصر، أو لتتبع الضغطات والتحليلات إن احتجت ذلك.

### `title`

عنوان اللوحة.

قد تكون القيمة `null` إذا لم تتم إضافة عنوان من لوحة التحكم. لذلك يجب أن يتعامل Flutter معها كقيمة اختيارية.

### `image_url`

رابط الصورة الكامل الجاهز للعرض داخل التطبيق.

القيمة يتم توليدها من مسار الصورة المخزن في قاعدة البيانات باستخدام Storage public URL. في Flutter استخدم هذا الرابط مباشرة مع `Image.network` أو `CachedNetworkImage`.

قد تكون القيمة `null` فقط إذا كان سجل اللوحة لا يحتوي على صورة، لكن حسب جدول قاعدة البيانات حقل `image` مطلوب عند الإنشاء.

### `type`

نوع الإجراء عند الضغط على اللوحة.

القيم المدعومة حالياً:

- `category`: اللوحة تشير إلى قسم/تصنيف.
- `offer`: اللوحة تشير إلى عرض.
- `external_link`: اللوحة تفتح رابطاً خارجياً.
- `none`: اللوحة للعرض فقط ولا تحتاج إجراء عند الضغط.

### `linked_id`

رقم العنصر المرتبط باللوحة.

يستخدم مع:

- `type = category`: يمثل رقم التصنيف.
- `type = offer`: يمثل رقم العرض.

إذا كان النوع `external_link` أو `none` فغالباً تكون القيمة `null`.

### `external_link`

رابط خارجي كامل.

يستخدم فقط عندما تكون:

```text
type=external_link
```

في Flutter يمكن فتحه عبر `url_launcher` أو WebView حسب تجربة التطبيق.

### `sort_order`

رقم ترتيب ظهور اللوحة.

القيمة الأصغر تظهر أولاً. هذا الحقل مفيد للتطبيق فقط للعرض أو التشخيص؛ الترتيب نفسه جاهز من السيرفر ولا يحتاج التطبيق لإعادة ترتيبه.

## التعامل مع الضغط داخل Flutter

اقترح التعامل مع اللوحة حسب `type` بهذا الشكل:

```dart
Future<void> handleBannerTap(AppBannerItem banner) async {
  switch (banner.type) {
    case 'category':
      if (banner.linkedId != null) {
        // افتح شاشة منتجات التصنيف حسب id أو حوّلها إلى slug إن كان التطبيق يعتمد على slug.
      }
      break;

    case 'offer':
      if (banner.linkedId != null) {
        // افتح شاشة العرض أو شاشة العروض مع تحديد العرض.
      }
      break;

    case 'external_link':
      if (banner.externalLink != null && banner.externalLink!.isNotEmpty) {
        // افتح الرابط عبر url_launcher أو WebView.
      }
      break;

    case 'none':
    default:
      // لا يوجد إجراء.
      break;
  }
}
```

ملاحظة مهمة: هذا endpoint يرجع `linked_id` فقط، وليس بيانات القسم أو العرض كاملة. إذا احتاج التطبيق تفاصيل القسم أو العرض، يجب استخدام endpoints أخرى مثل:

- `GET /api/flutter/categories`
- `GET /api/flutter/offers`
- `GET /api/flutter/products`

## مثال Dio

```dart
class AppBannersApi {
  AppBannersApi(this.dio);

  final Dio dio;

  Future<AppBannersResponse> fetchBanners() async {
    final response = await dio.get(
      '/api/flutter/app-banners',
      options: Options(
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      ),
    );

    return AppBannersResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
```

## مثال Model في Flutter

```dart
class AppBannerItem {
  const AppBannerItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.type,
    required this.linkedId,
    required this.externalLink,
    required this.sortOrder,
  });

  final int id;
  final String? title;
  final String? imageUrl;
  final String type;
  final int? linkedId;
  final String? externalLink;
  final int sortOrder;

  factory AppBannerItem.fromJson(Map<String, dynamic> json) {
    return AppBannerItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String?,
      imageUrl: json['image_url'] as String?,
      type: json['type'] as String? ?? 'none',
      linkedId: json['linked_id'] as int?,
      externalLink: json['external_link'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class AppBannersResponse {
  const AppBannersResponse({
    required this.data,
  });

  final List<AppBannerItem> data;

  factory AppBannersResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? const [];

    return AppBannersResponse(
      data: items
          .map(
            (item) => AppBannerItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
```

## مثال استخدام داخل الصفحة الرئيسية

```dart
final bannersResponse = await appBannersApi.fetchBanners();
final banners = bannersResponse.data;

if (banners.isEmpty) {
  // أخفِ قسم اللوحات أو اعرض Placeholder بسيط حسب تصميم التطبيق.
} else {
  // اعرض Carousel / PageView باستخدام imageUrl.
}
```

## حالات يجب التعامل معها في التطبيق

- `data` قد تكون فارغة، وهذا ليس خطأ.
- `title` قد تكون `null`.
- `external_link` قد تكون `null` إلا عندما يكون النوع `external_link`.
- `linked_id` قد تكون `null`، لذلك لا تنتقل لشاشة داخلية إلا بعد فحصها.
- `image_url` رابط كامل، لذلك لا تضف له `BASE_URL` مرة أخرى.
- رتب اللوحات كما وصلت من السيرفر، ولا تحتاج إلى sort إضافي داخل Flutter.

## أكواد الحالة المتوقعة

- `200`: تم جلب اللوحات بنجاح.
- `500`: خطأ داخلي في السيرفر.

لا يوجد حالياً `401` لهذا المسار لأنه لا يحتاج مصادقة.

## نتيجة التحقق

تم التأكد أن endpoint موجود ويعمل بهذه الصيغة:

```http
GET /api/flutter/app-banners
```

وتمت إضافة اختبار يغطي السلوك الأساسي:

- يعمل بدون تسجيل دخول.
- يرجع فقط اللوحات المفعلة.
- يستبعد اللوحات غير المفعلة.
- يحافظ على ترتيب العرض.
- يرجع الحقول التي يحتاجها تطبيق Flutter: `id`, `title`, `image_url`, `type`, `linked_id`, `external_link`, `sort_order`.

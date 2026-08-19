# Flutter Privacy Policy API

هذا الملف يشرح واجهة `API` الخاصة بسياسة الخصوصية والشروط والأحكام لتطبيق Flutter، بحيث يستطيع التطبيق:

- جلب النص الحالي من السيرفر بدل كتابة المحتوى داخل التطبيق بشكل ثابت.
- عرض السياسة داخل شاشة مخصصة في التطبيق.
- فتح صفحة الويب الرسمية عند الحاجة داخل `WebView` أو المتصفح.
- البقاء متوافقًا مع أي تعديل يتم من لوحة الإدارة بدون إصدار نسخة جديدة من التطبيق.

## لماذا تحتاج هذا الـ API

عند نشر التطبيق في المتجر، يوجد عادة احتياجان مختلفان:

- رابط عام ثابت لسياسة الخصوصية يمكن وضعه في إعدادات المتجر.
- `API` داخل التطبيق نفسه لجلب نص السياسة والشروط وعرضهما للمستخدم.

في هذا المشروع يوجد بالفعل رابط ويب عام:

`GET /privacy-policy`

وتمت إضافة API مخصص للتطبيق:

`GET /api/flutter/policies`

استخدم رابط الويب عند إدخال رابط سياسة الخصوصية في المتجر، واستخدم الـ API داخل التطبيق لعرض المحتوى بشكل ديناميكي.

## Base URL

استبدل هذا الدومين بعنوان السيرفر الحقيقي:

`BASE_URL = https://hindam.ly`

## Authentication

هذا الـ endpoint عام ولا يحتاج تسجيل دخول.

الهيدر المفضل:

```http
Accept: application/json
Content-Type: application/json
```

## Endpoint

`GET /api/flutter/policies`

## وظيفة الـ endpoint

هذا المسار يعيد:

- رابط صفحة الويب الرسمية للسياسات.
- عنوان ونص سياسة الخصوصية.
- عنوان ونص الشروط والأحكام.
- `paragraphs` جاهزة للعرض داخل Flutter بدون الحاجة لتقسيم النص يدويًا.
- `updated_at` لمعرفة آخر وقت تم فيه تعديل المحتوى.
- `version` لمساعدة التطبيق في التخزين المؤقت `cache`.

## Success Response

`200 OK`

```json
{
  "data": {
    "page_url": "https://hindam.ly/privacy-policy",
    "privacy_policy": {
      "title": "سياسة الخصوصية",
      "content": "نحن نحترم خصوصية عملائنا...\n\nقد تشمل البيانات التي نجمعها...",
      "paragraphs": [
        "نحن نحترم خصوصية عملائنا...",
        "قد تشمل البيانات التي نجمعها..."
      ]
    },
    "terms_conditions": {
      "title": "الشروط والأحكام",
      "content": "استخدامك للموقع يعني موافقتك...\n\nيجب تقديم بيانات صحيحة...",
      "paragraphs": [
        "استخدامك للموقع يعني موافقتك...",
        "يجب تقديم بيانات صحيحة..."
      ]
    },
    "updated_at": "2026-03-10T09:30:00.000000Z",
    "version": "9d352c1af5b3bdbf1d792b1c7e16c4c90d5c7eb1"
  }
}
```

## شرح الحقول

- `page_url`: رابط صفحة الويب الرسمية. هذا هو الرابط المناسب أيضًا لوضعه في إعدادات متجر التطبيق.
- `privacy_policy.title`: عنوان قسم سياسة الخصوصية.
- `privacy_policy.content`: النص الكامل كما هو محفوظ في لوحة الإدارة.
- `privacy_policy.paragraphs`: النص نفسه لكن مقسم إلى فقرات؛ مناسب مباشرة للعرض داخل `ListView`.
- `terms_conditions.title`: عنوان قسم الشروط والأحكام.
- `terms_conditions.content`: النص الكامل للشروط والأحكام.
- `terms_conditions.paragraphs`: الشروط مقسمة إلى فقرات.
- `updated_at`: آخر تاريخ تعديل تم حفظه في السيرفر. قد يكون `null` إذا لم تحفظ الإدارة أي محتوى مخصص بعد.
- `version`: بصمة تتغير عند تغيير النص أو العنوان. استخدمها لمعرفة هل المحتوى تغير أم لا.

## من أين يأتي المحتوى

المحتوى لا يأتي من ملف ثابت داخل Flutter، بل من إعدادات النظام داخل Laravel:

- `privacy_policy_title`
- `privacy_policy_content`
- `terms_conditions_title`
- `terms_conditions_content`

هذه القيم يتم تعديلها من لوحة الإدارة، ثم يعيدها `GET /api/flutter/policies` مباشرة.

هذا يعني:

- أي تعديل من لوحة الإدارة يظهر في التطبيق بعد إعادة الجلب.
- لا تحتاج إلى رفع نسخة جديدة من التطبيق عند تعديل النص.

## متى يستدعي Flutter هذا الـ API

السيناريو المقترح:

1. عند فتح شاشة "سياسة الخصوصية" أو "الشروط والأحكام".
2. أو مرة واحدة عند بدء تشغيل التطبيق ثم تخزين النتيجة محليًا.
3. ثم إعادة الجلب عند تغير `version` أو بعد مدة زمنية مناسبة.

## أفضل طريقة استخدام داخل التطبيق

يوجد طريقتان:

### 1) عرض نص محلي داخل التطبيق

اعتمد على:

- `privacy_policy.title`
- `privacy_policy.paragraphs`
- `terms_conditions.title`
- `terms_conditions.paragraphs`

هذه الطريقة أفضل إذا كنت تريد تصميمًا داخليًا نظيفًا داخل التطبيق.

### 2) فتح صفحة الويب الرسمية

اعتمد على:

- `page_url`

هذه الطريقة مفيدة عندما تريد:

- زر "عرض سياسة الخصوصية في المتصفح"
- `WebView`
- وضع الرابط في صفحة المتجر أثناء النشر

## مثال Request

```http
GET /api/flutter/policies
Accept: application/json
```

## مثال Dio

```dart
class PrivacyApi {
  PrivacyApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> fetchPolicies() async {
    final response = await dio.get('/api/flutter/policies');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
```

## مثال Model مبسط في Flutter

```dart
class PolicySection {
  PolicySection({
    required this.title,
    required this.content,
    required this.paragraphs,
  });

  final String title;
  final String content;
  final List<String> paragraphs;

  factory PolicySection.fromJson(Map<String, dynamic> json) {
    return PolicySection(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      paragraphs: (json['paragraphs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class PoliciesResponse {
  PoliciesResponse({
    required this.pageUrl,
    required this.privacyPolicy,
    required this.termsConditions,
    required this.updatedAt,
    required this.version,
  });

  final String pageUrl;
  final PolicySection privacyPolicy;
  final PolicySection termsConditions;
  final DateTime? updatedAt;
  final String version;

  factory PoliciesResponse.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map);

    return PoliciesResponse(
      pageUrl: data['page_url'] as String? ?? '',
      privacyPolicy: PolicySection.fromJson(
        Map<String, dynamic>.from(data['privacy_policy'] as Map),
      ),
      termsConditions: PolicySection.fromJson(
        Map<String, dynamic>.from(data['terms_conditions'] as Map),
      ),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
      version: data['version'] as String? ?? '',
    );
  }
}
```

## مثال استخدام داخل شاشة Flutter

```dart
final payload = await privacyApi.fetchPolicies();
final policies = PoliciesResponse.fromJson(payload);

final privacyTitle = policies.privacyPolicy.title;
final privacyParagraphs = policies.privacyPolicy.paragraphs;
final termsTitle = policies.termsConditions.title;
final termsParagraphs = policies.termsConditions.paragraphs;
final webUrl = policies.pageUrl;
```

## ملاحظات مهمة للنشر

- عند إرسال التطبيق إلى المتجر، ضع رابط صفحة الويب `page_url` أو الرابط المباشر `https://your-domain.com/privacy-policy`، وليس رابط الـ JSON API.
- لا تعمل `hardcode` لنصوص السياسة داخل Flutter.
- إذا أردت دعم العمل بدون إنترنت، خزّن آخر response محليًا واعرضه عند فشل الطلب.
- إذا رجع `updated_at = null` فهذا يعني أن النظام يستخدم النص الافتراضي الحالي.
- إذا تغير `version`، حدّث النسخة المخزنة محليًا.

## أكواد الحالة

- `200`: نجاح الطلب
- `500`: خطأ داخلي في السيرفر

## الخلاصة

الربط الصحيح للنشر يكون كالتالي:

- رابط المتجر الرسمي للخصوصية: `/privacy-policy`
- API داخل التطبيق: `GET /api/flutter/policies`

بهذا الشكل يصبح لديك:

- رابط عام مناسب للمراجعة والنشر
- ومحتوى ديناميكي داخل التطبيق قابل للتحديث من لوحة الإدارة

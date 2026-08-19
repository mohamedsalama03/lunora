# Logo API — توثيق Flutter

يوضح هذا الملف كيفية استخدام نقطة النهاية (API) الخاصة بشعار المتجر في تطبيق Flutter.

---

## نظرة عامة

يتيح المدير رفع شعار المتجر من **لوحة الإدارة → الإعدادات → المظهر والهوية البصرية**.  
أي شعار يرفعه المدير يُحفظ تلقائيًا في قاعدة البيانات ويكون متاحًا فورًا عبر هذا الـ API.

---

## نقطة النهاية

| العنصر | التفاصيل |
|--------|----------|
| **Method** | `GET` |
| **URL** | `/api/flutter/logo` |
| **المصادقة** | لا تحتاج (عامة - Public) |
| **Content-Type** | `application/json` |

---

## الاستجابة (Response)

### ✅ عند وجود شعار

```json
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": {
    "has_logo": true,
    "logo_url": "https://hindam.ly/storage/logos/abc123.png",
    "updated_at": "2026-03-17T00:01:44.000000Z"
  }
}
```

### ⬜ عند عدم وجود شعار

```json
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": {
    "has_logo": false,
    "logo_url": null,
    "updated_at": null
  }
}
```

---

## وصف الحقول

| الحقل | النوع | الوصف |
|-------|-------|-------|
| `has_logo` | `bool` | هل يوجد شعار مضاف من الإدارة؟ |
| `logo_url` | `string \| null` | الرابط الكامل للشعار. `null` إذا لم يوجد شعار |
| `updated_at` | `string \| null` | آخر تاريخ تحديث للإعدادات (ISO 8601). `null` إذا لم تُحفظ إعدادات بعد |

---

## دمج مع Flutter

### 1. نموذج البيانات `logo_model.dart`

```dart
class LogoModel {
  final bool hasLogo;
  final String? logoUrl;
  final String? updatedAt;

  const LogoModel({
    required this.hasLogo,
    this.logoUrl,
    this.updatedAt,
  });

  factory LogoModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return LogoModel(
      hasLogo: data['has_logo'] as bool,
      logoUrl: data['logo_url'] as String?,
      updatedAt: data['updated_at'] as String?,
    );
  }
}
```

---

### 2. خدمة الجلب `logo_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logo_model.dart';

class LogoService {
  static const String _baseUrl = 'https://hindam.ly/api/flutter';

  Future<LogoModel> fetchLogo() async {
    final uri = Uri.parse('$_baseUrl/logo');

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return LogoModel.fromJson(body);
    }

    throw Exception('Failed to load logo: ${response.statusCode}');
  }
}
```

---

### 3. عرض الشعار في الواجهة

```dart
import 'package:flutter/material.dart';
import 'logo_service.dart';
import 'logo_model.dart';

class StoreLogo extends StatefulWidget {
  final double size;
  const StoreLogo({super.key, this.size = 48});

  @override
  State<StoreLogo> createState() => _StoreLogoState();
}

class _StoreLogoState extends State<StoreLogo> {
  late final Future<LogoModel> _logoFuture;

  @override
  void initState() {
    super.initState();
    _logoFuture = LogoService().fetchLogo();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LogoModel>(
      future: _logoFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // يمكن استخدام Shimmer أو مؤشر تحميل هنا
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final logo = snap.data;

        // إذا لم يكن هناك شعار أو حدث خطأ: اعرض النص الاحتياطي
        if (logo == null || !logo.hasLogo || logo.logoUrl == null) {
          return Text(
            'تصاميم',
            style: TextStyle(
              fontSize: widget.size * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }

        return Image.network(
          logo.logoUrl!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            'تصاميم',
            style: TextStyle(
              fontSize: widget.size * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
```

**الاستخدام في `home_screen.dart`:**

```dart
// في الـ AppBar أو الـ Header
StoreLogo(size: 48)
```

---

### 4. التخزين المؤقت (Caching)

يُوصى باستخدام حزمة [`cached_network_image`](https://pub.dev/packages/cached_network_image) لتخزين صورة الشعار محليًا وتجنب تحميلها في كل مرة:

```yaml
# pubspec.yaml
dependencies:
  cached_network_image: ^3.3.1
```

```dart
import 'package:cached_network_image/cached_network_image.dart';

// بدلاً من Image.network
CachedNetworkImage(
  imageUrl: logo.logoUrl!,
  width: widget.size,
  height: widget.size,
  fit: BoxFit.contain,
  placeholder: (context, url) =>
      const CircularProgressIndicator(strokeWidth: 2),
  errorWidget: (context, url, error) =>
      const Icon(Icons.store, color: Colors.white),
)
```

---

## التحديث التلقائي

إذا أردت أن يتحقق التطبيق من وجود تحديث للشعار دون إعادة تشغيل، يمكنك مقارنة قيمة `updated_at` المحفوظة محليًا مع القيمة التي يُرجعها الـ API:

```dart
Future<void> refreshLogoIfChanged() async {
  final logo = await LogoService().fetchLogo();
  final cachedTimestamp = prefs.getString('logo_updated_at');

  if (logo.updatedAt != cachedTimestamp) {
    // الشعار تغيّر — احذف الكاش وأعد التحميل
    await CachedNetworkImage.evictFromCache(cachedLogoUrl ?? '');
    await prefs.setString('logo_updated_at', logo.updatedAt ?? '');
    // قم بتحديث الـ State
  }
}
```

---

## معالجة الأخطاء

| الحالة | الوصف | الاستجابة الموصى بها |
|--------|-------|----------------------|
| `has_logo = false` | لا يوجد شعار مضاف | اعرض النص الاحتياطي (مثل: "تصاميم") |
| `logo_url` لا يُحمّل | خطأ في الشبكة أو الملف محذوف | اعرض `errorBuilder` بنص أو أيقونة |
| `timeout` | انتهت مهلة الطلب | اعرض النص الاحتياطي ولا توقف التطبيق |
| `500 Server Error` | خطأ في الخادم | اعرض النص الاحتياطي وسجّل الخطأ |

---

## ملاحظات تقنية

- **مسار التخزين:** الشعار يُرفع وُيخزَّن في `storage/app/public/logos/` ويُصدر عبر `Storage::url()`.
- **الصيغ المدعومة:** JPG، PNG، WEBP، SVG (حجم أقصى 4MB).
- **لا يوجد إصدار (version):** الـ API يُرجع `updated_at` لتتمكن من كشف التغييرات.
- **لا يحتاج مصادقة:** الشعار معلومة عامة ويمكن الوصول إليه بدون توكن.

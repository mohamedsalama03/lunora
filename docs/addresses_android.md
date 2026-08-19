# Android Address Map API

هذا الملف يشرح واجهات الـ API الخاصة بشاشة إضافة العنوان على Android عند استخدام الخريطة لتحديد موقع العميل ثم حفظ العنوان في النظام.

الواجهة الأساسية الجديدة هي:

- `GET /api/flutter/addresses/map-config`

هذه الواجهة تعطي تطبيق Android كل ما يحتاجه لفتح شاشة الخريطة بشكل صحيح قبل تنفيذ حفظ العنوان.

## ما الذي يحتاجه تطبيق Android من السيرفر

عند فتح شاشة إضافة العنوان، التطبيق يحتاج إلى:

- نقطة بداية للخريطة.
- موقع المتجر.
- قائمة المدن المدعومة للشحن.
- قواعد التحقق من البيانات.
- مسارات الحفظ والتعديل والتقدير.

الـ endpoint الجديد يجمع هذه المعلومات في استجابة واحدة.

## Authentication

كل المسارات التالية تتطلب `Bearer Token` صادر من:

- `POST /api/flutter/auth/login`
- `POST /api/flutter/auth/register`

الهيدر المطلوب:

```http
Accept: application/json
Authorization: Bearer {access_token}
Content-Type: application/json
```

## Endpoints المستخدمة في شاشة العنوان

- `GET /api/flutter/addresses/map-config`
- `GET /api/flutter/addresses`
- `POST /api/flutter/addresses`
- `PUT /api/flutter/addresses/{id}`
- `DELETE /api/flutter/addresses/{id}`
- `POST /api/flutter/addresses/{id}/set-default`
- `POST /api/flutter/routes/estimate`

## 1) Map Config

### Endpoint

`GET /api/flutter/addresses/map-config`

### لماذا مهم لتطبيق Android

بدل hardcode داخل التطبيق، هذه الاستجابة تسمح بأن يأتي التالي من السيرفر:

- مركز الخريطة الافتراضي.
- موقع المتجر الحالي.
- العنوان الافتراضي للمستخدم إن وجد.
- المدن المدعومة للشحن.
- قواعد التحقق من الحقول.

### Success Response

```json
{
  "data": {
    "map_provider": "google_maps",
    "default_center": {
      "lat": 32.8872,
      "lng": 13.1913
    },
    "store_location": {
      "lat": 32.3778004,
      "lng": 15.099659
    },
    "default_address": {
      "id": 12,
      "label": "البيت",
      "full_name": "Mohamed Ali",
      "phone": "0912345678",
      "address_line1": "شارع النصر",
      "address_line2": null,
      "city": "طرابلس",
      "state": null,
      "country": "Libya",
      "postal_code": null,
      "formatted_address": "شارع النصر، طرابلس",
      "place_id": "place_123",
      "location": {
        "lat": 32.8872,
        "lng": 13.1913
      },
      "notes": null,
      "is_default": true,
      "is_active": true,
      "created_at": "2026-04-16T10:00:00.000000Z",
      "updated_at": "2026-04-16T10:00:00.000000Z"
    },
    "supported_cities": [
      {
        "name": "طرابلس",
        "shipping_cost": 10,
        "location": {
          "lat": 32.8872,
          "lng": 13.1913
        }
      },
      {
        "name": "مصراتة",
        "shipping_cost": 12,
        "location": {
          "lat": 32.3754,
          "lng": 15.0925
        }
      }
    ],
    "validation": {
      "required_fields": ["latitude", "longitude", "city"],
      "phone_regex": "^09\\d{8}$",
      "supports_formatted_address": true,
      "supports_place_id": true
    },
    "checkout": {
      "requires_supported_city": true,
      "misrata_boundary_km": 35
    },
    "defaults": {
      "country": "Libya"
    },
    "endpoints": {
      "list": "/api/flutter/addresses",
      "create": "/api/flutter/addresses",
      "update": "/api/flutter/addresses/{id}",
      "delete": "/api/flutter/addresses/{id}",
      "set_default": "/api/flutter/addresses/{id}/set-default",
      "route_estimate": "/api/flutter/routes/estimate"
    }
  }
}
```

### شرح الحقول

- `map_provider`: تعريف لمزود الخرائط الحالي.
- `default_center`: النقطة التي تفتح عليها `GoogleMap`.
- `store_location`: موقع المتجر ويمكن وضع Marker له.
- `default_address`: إن كان للمستخدم عنوان افتراضي محفوظ، يمكن تحريك الكاميرا عليه مباشرة.
- `supported_cities`: المدن التي يفضل اعتمادها في اختيار المدينة بدل إدخال حر.
- `validation.required_fields`: أهم الحقول التي يجب إرسالها عند حفظ العنوان.
- `validation.phone_regex`: تحقق رقم الهاتف.
- `checkout.requires_supported_city`: عند إنشاء الطلب لاحقًا يجب أن تكون المدينة مدعومة.
- `endpoints`: مرجع للمسارات التي ستستخدمها الشاشة لاحقًا.

## 2) حفظ العنوان

### Endpoint

`POST /api/flutter/addresses`

### Body

```json
{
  "label": "البيت",
  "full_name": "Mohamed Ali",
  "phone": "0912345678",
  "latitude": 32.8872,
  "longitude": 13.1913,
  "formatted_address": "شارع النصر، طرابلس، ليبيا",
  "place_id": "ChIJ-example",
  "address_line1": "شارع النصر",
  "address_line2": "بجانب الصيدلية",
  "city": "طرابلس",
  "state": "طرابلس",
  "country": "Libya",
  "postal_code": null,
  "notes": "الاتصال قبل الوصول",
  "is_default": true
}
```

### قواعد مهمة

- `latitude` و `longitude` مطلوبان.
- `city` مطلوب.
- `formatted_address` اختياري لكنه مستحسن.
- `place_id` اختياري.
- `phone` يجب أن يطابق `^09\\d{8}$`.
- يفضل تعبئة `city` من `supported_cities` وليس من نص حر.

### Success Response

```json
{
  "message": "Address created successfully.",
  "data": {
    "id": 12,
    "label": "البيت",
    "full_name": "Mohamed Ali",
    "phone": "0912345678",
    "address_line1": "شارع النصر",
    "address_line2": "بجانب الصيدلية",
    "city": "طرابلس",
    "state": "طرابلس",
    "country": "Libya",
    "postal_code": null,
    "formatted_address": "شارع النصر، طرابلس، ليبيا",
    "place_id": "ChIJ-example",
    "location": {
      "lat": 32.8872,
      "lng": 13.1913
    },
    "notes": "الاتصال قبل الوصول",
    "is_default": true,
    "is_active": true,
    "created_at": "2026-04-16T10:00:00.000000Z",
    "updated_at": "2026-04-16T10:00:00.000000Z"
  }
}
```

## 3) تعديل عنوان موجود

### Endpoint

`PUT /api/flutter/addresses/{id}`

مثال:

```json
{
  "label": "العمل",
  "latitude": 32.8891,
  "longitude": 13.1978,
  "formatted_address": "موقع جديد - طرابلس",
  "address_line1": "موقع جديد",
  "city": "طرابلس"
}
```

## 4) جعل العنوان افتراضيًا

### Endpoint

`POST /api/flutter/addresses/{id}/set-default`

## 5) حساب المسافة والزمن

### Endpoint

`POST /api/flutter/routes/estimate`

### Body

```json
{
  "origin": {
    "lat": 32.3778004,
    "lng": 15.099659
  },
  "destination": {
    "lat": 32.8872,
    "lng": 13.1913
  },
  "vehicle_type": "car"
}
```

### لماذا يفيد على Android

- عرض مسافة تقريبية مباشرة بعد إسقاط Marker.
- عرض زمن الوصول.
- رسم المسار إذا كانت `polyline` موجودة.
- **حساب تكلفة التوصيل داخل مصراتة:** التوصيل داخل مصراتة ليس مجانياً، بل يتم حساب التكلفة ديناميكياً من الباك إند بناءً على المسافة بالكيلومتر وقيمة البداية عبر هذا الـ API.

## 6) المدن المعتمدة خارج مصراتة

هذا هو نفس السلوك المطبق على الويب، ويجب أن يطبقه Android بنفس الفكرة:

- إذا كانت الإحداثيات داخل حدود مصراتة: لا تعرض قائمة المدن، واجعل المدينة `مصراتة` تلقائيًا.
- إذا كانت الإحداثيات خارج حدود مصراتة: اعرض قائمة المدن المعتمدة فقط مع سعر التوصيل لكل مدينة.
- لا تسمح بحفظ العنوان خارج مصراتة إلا بعد اختيار مدينة من القائمة.

### الـ endpoint الأساسي لهذه الحالة

`GET /api/flutter/addresses/map-config`

هذا الـ endpoint يعيد الحقول التي يحتاجها Android لبناء هذا السلوك:

- `data.supported_cities`: قائمة المدن المعتمدة من لوحة الإدارة.
- `data.supported_cities[].name`: اسم المدينة.
- `data.supported_cities[].shipping_cost`: سعر التوصيل الخاص بهذه المدينة.
- `data.checkout.misrata_boundary_km`: نصف القطر المعتمد لاعتبار الموقع داخل حدود مصراتة.
- `data.checkout.requires_supported_city`: يؤكد أن الـ checkout يعتمد مدينة مدعومة.

### مثال الجزء المهم من الاستجابة

```json
{
  "data": {
    "supported_cities": [
      {
        "name": "طرابلس",
        "shipping_cost": 10,
        "location": {
          "lat": 32.8872,
          "lng": 13.1913
        }
      },
      {
        "name": "بنغازي",
        "shipping_cost": 12,
        "location": {
          "lat": 32.1167,
          "lng": 20.0667
        }
      },
      {
        "name": "مصراتة",
        "shipping_cost": 12,
        "location": {
          "lat": 32.3754,
          "lng": 15.0925
        }
      }
    ],
    "checkout": {
      "requires_supported_city": true,
      "misrata_boundary_km": 35
    }
  }
}
```

### كيف يطبقه Android

1. عند فتح شاشة إضافة أو تعديل العنوان استدعِ `GET /api/flutter/addresses/map-config`.
2. خزّن `supported_cities` و `misrata_boundary_km` محليًا داخل الشاشة.
3. بعد أن يحدد المستخدم النقطة على الخريطة أو يتم جلب موقعه الحالي:
   احسب هل النقطة داخل حدود مصراتة أم خارجها.
4. إذا كانت داخل حدود مصراتة:
   اجعل `city = "مصراتة"` تلقائيًا وأخفِ `city picker`.
5. إذا كانت خارج حدود مصراتة:
   أظهر `city picker` مبنيًا من `supported_cities`.
6. اعرض كل خيار بهذه الصيغة مثلًا:
   `طرابلس - 10 LYD`
7. عند اختيار مدينة من القائمة:
   خزّن فقط `name` في حقل `city` داخل طلب الحفظ.
8. سعر التوصيل المعروض للمستخدم يأتي من `supported_cities[].shipping_cost` فقط للعرض.
9. عند إنشاء الطلب لاحقًا، الباك اند هو الذي يحسب السعر النهائي من المدينة المحفوظة، وليس التطبيق.

### طلب حفظ العنوان خارج مصراتة

يبقى نفس endpoint الحفظ:

`POST /api/flutter/addresses`

ومثال body عند كون الموقع خارج مصراتة:

```json
{
  "label": "البيت",
  "full_name": "Mohamed Ali",
  "phone": "0912345678",
  "latitude": 32.8872,
  "longitude": 13.1913,
  "formatted_address": "Airport Road, Tripoli",
  "address_line1": "Airport Road",
  "address_line2": "Near XYZ",
  "city": "Tripoli",
  "state": "Tripoli",
  "country": "Libya",
  "notes": "الاتصال عند الوصول",
  "is_default": true
}
```

### Endpoint إضافي مفيد في شاشة checkout

إذا احتاج Android عرض قائمة المدن وأسعارها داخل شاشة checkout أو مراجعة الطلب، يمكنه أيضًا استخدام:

`GET /api/flutter/orders/lookups`

ومن هذه الاستجابة يقرأ:

- `data.shipping_cities`
- `data.shipping_cities[].name`
- `data.shipping_cities[].shipping_cost`

لكن بالنسبة لشاشة إضافة/تعديل العنوان، المرجع الأساسي يظل:

`GET /api/flutter/addresses/map-config`

## الترتيب المقترح داخل Android

1. افتح شاشة إضافة العنوان.
2. اطلب `GET /api/flutter/addresses/map-config`.
3. حرّك الكاميرا إلى `default_address.location` إن وجدت، وإلا إلى `default_center`.
4. اطلب صلاحية الموقع باستخدام Android permissions.
5. اجلب موقع المستخدم عبر `FusedLocationProviderClient` عند الحاجة.
6. عند تحريك Marker أو اختيار نقطة، نفذ reverse geocoding داخل التطبيق.
7. عبئ الحقول الأساسية:
   `latitude`, `longitude`, `formatted_address`, `address_line1`, `city`.
8. إذا كان الموقع خارج حدود مصراتة، اعرض قائمة `supported_cities` مع `shipping_cost` لكل مدينة ولا تسمح بالحفظ قبل الاختيار.
9. إذا أردت عرض تقدير المسافة، استدع `POST /api/flutter/routes/estimate`.
10. عند الضغط على حفظ، أرسل `POST /api/flutter/addresses`.

## ملاحظات خاصة بـ Android

- الـ API لا يرسل Google Maps API key.
- المفتاح يجب أن يكون مضبوطًا داخل `AndroidManifest.xml` أو داخل إعدادات التطبيق.
- إذا كنت تستخدم Google Places على Android فأرسل `place_id` إن توفر.
- إذا لم يكن لديك `place_id` فلا توجد مشكلة، فهو اختياري.
- لا تعتمد على اسم المدينة الناتج من geocoder فقط بدون مقارنة مع `supported_cities`.
- لا ترسل `shipping_cost` في طلب حفظ العنوان؛ اعرضه فقط في الواجهة وخزّن `city` المختارة، والسيرفر سيحسب الشحن لاحقًا.

## مثال Kotlin باستخدام OkHttp

```kotlin
import okhttp3.OkHttpClient
import okhttp3.Request

fun buildMapConfigRequest(token: String): Request {
    return Request.Builder()
        .url("https://your-domain.com/api/flutter/addresses/map-config")
        .get()
        .addHeader("Accept", "application/json")
        .addHeader("Authorization", "Bearer $token")
        .build()
}

val client = OkHttpClient()
val request = buildMapConfigRequest(accessToken)

client.newCall(request).execute().use { response ->
    if (!response.isSuccessful) error("Request failed: ${response.code}")
    val json = response.body?.string().orEmpty()
    println(json)
}
```

## ملاحظات نهائية

- إذا لم يحصل المستخدم على مدينة واضحة من الخريطة، اطلب منه اختيار نقطة أدق.
- إذا كانت المدينة غير مدعومة للشحن، الأفضل تنبيهه أثناء إضافة العنوان وليس عند checkout فقط.
- إذا كان هناك `default_address` محفوظ، فاستفد منه لتقليل عدد خطوات المستخدم عند التعديل.

# iOS Address Map API

هذا الملف يشرح واجهات الـ API المطلوبة لشاشة إضافة العنوان على iOS عند استخدام خريطة لاختيار موقع العميل ثم حفظ العنوان داخل النظام.

الاعتماد الأساسي هنا صار على endpoint جديد:

- `GET /api/flutter/addresses/map-config`

وهذا endpoint مخصص لتجهيز شاشة الخريطة قبل أن يبدأ المستخدم باختيار الموقع.

## الهدف من الـ flow

داخل تطبيق iOS شاشة إضافة العنوان تحتاج عادة إلى 4 أشياء:

- مركز افتراضي لفتح الخريطة.
- موقع المتجر.
- المدن المدعومة للشحن.
- endpoint حفظ العنوان بعد اختيار النقطة.

الـ API الجديد يعيد هذه البيانات في استجابة واحدة، ثم بعد ذلك يستخدم التطبيق `POST /api/flutter/addresses` لحفظ العنوان.

## Authentication

كل هذه المسارات تحتاج `Bearer Token` من:

- `POST /api/flutter/auth/login`
- `POST /api/flutter/auth/register`

الهيدر المطلوب:

```http
Accept: application/json
Authorization: Bearer {access_token}
Content-Type: application/json
```

## Endpoints المستخدمة في شاشة إضافة العنوان

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

### لماذا يستدعى أولاً

هذا الطلب يجب أن يرسل عند فتح شاشة إضافة العنوان أو شاشة تعديل العنوان، لأنه يعيد:

- `default_center`: النقطة التي تفتح عليها الخريطة.
- `store_location`: موقع المتجر.
- `default_address`: العنوان الافتراضي الحالي للمستخدم إن وجد.
- `supported_cities`: المدن المعتمدة للشحن.
- `validation`: قواعد الإدخال التي يجب احترامها عند الحفظ.
- `checkout`: معلومات مهمة مرتبطة بالمدن المدعومة وحدود مصراتة.

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

- `map_provider`: قيمة تعريفية فقط لتوضيح مزود الخريطة المتوقع حاليًا.
- `default_center`: النقطة التي يجب أن تفتح عليها `GMSMapView` أو `MKMapView`.
- `store_location`: موقع المتجر ويمكن إظهاره Marker منفصل إذا كان ذلك مطلوبًا.
- `default_address`: إذا كان للمستخدم عنوان افتراضي محفوظ، يستحسن بدء الشاشة عليه بدل مركز المتجر.
- `supported_cities`: القائمة التي يفضل أن يختار المستخدم منها المدينة بدل كتابتها يدويًا.
- `validation.required_fields`: الحقول التي لا يصح إرسال الطلب بدونها.
- `validation.phone_regex`: النمط المطلوب لرقم الهاتف.
- `checkout.requires_supported_city`: عند إنشاء الطلب لاحقًا يجب أن تكون المدينة مدعومة.
- `checkout.misrata_boundary_km`: معلومة يمكن استخدامها لشرح السلوك داخل واجهة المستخدم إن لزم.
- `endpoints.route_estimate`: endpoint اختياري لحساب المسافة ووقت التوصيل بعد اختيار النقطة.

## 2) حفظ العنوان بعد اختيار النقطة

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
  "address_line2": "بالقرب من الإشارة",
  "city": "طرابلس",
  "state": "طرابلس",
  "country": "Libya",
  "postal_code": null,
  "notes": "الاتصال قبل الوصول",
  "is_default": true
}
```

### ملاحظات مهمة

- `latitude` و `longitude` مطلوبان دائمًا.
- `city` مطلوب.
- `formatted_address` اختياري لكنه مهم جدًا لعرض العنوان النهائي للمستخدم.
- `place_id` اختياري.
- `address_line1` يجب أن يحمل وصفًا واضحًا حتى لو كانت `formatted_address` موجودة.
- `phone` يجب أن يطابق `^09\\d{8}$`.
- يفضل أن تكون `city` من نفس القيم الموجودة في `supported_cities` لتجنب مشاكل checkout لاحقًا.

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
    "address_line2": "بالقرب من الإشارة",
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

## 3) تحديث عنوان موجود

### Endpoint

`PUT /api/flutter/addresses/{id}`

أرسل فقط الحقول التي تغيرت. مثال:

```json
{
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

هذه الواجهة مفيدة إذا كان المستخدم أضاف عدة عناوين ويريد اعتماد واحد منها افتراضيًا.

## 5) حساب المسافة بعد اختيار النقطة

### Endpoint

`POST /api/flutter/routes/estimate`

### الاستخدام

بعد أن يختار المستخدم النقطة على الخريطة، يمكن للتطبيق أن يحسب تقدير المسافة والزمن بين المتجر والموقع المحدد.

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

### الفائدة داخل شاشة iOS

- عرض تقدير أولي للمسافة.
- عرض زمن التوصيل المتوقع.
- استخدام `polyline` إن أردت رسم المسار على الخريطة.
- **حساب تكلفة التوصيل داخل مصراتة:** التوصيل داخل مصراتة ليس مجانياً، بل يتم حساب التكلفة ديناميكياً من الباك إند بناءً على المسافة بالكيلومتر وقيمة البداية عبر هذا الـ API.

## الترتيب المقترح داخل iOS

1. افتح الشاشة.
2. اطلب `GET /api/flutter/addresses/map-config`.
3. ركز الخريطة على `default_address.location` إن وجدت، وإلا على `default_center`.
4. اطلب إذن الموقع من `CLLocationManager`.
5. عندما يختار المستخدم نقطة جديدة، نفذ reverse geocoding داخل التطبيق.
6. املأ الحقول:
   `latitude`, `longitude`, `formatted_address`, `address_line1`, `city`.
7. إذا أردت، استدع `POST /api/flutter/routes/estimate`.
8. عند الضغط على حفظ أرسل `POST /api/flutter/addresses`.

## 6) المدن المعتمدة خارج مصراتة

نفس منطق الويب يجب أن يطبق داخل iOS:

- إذا كانت الإحداثيات داخل حدود مصراتة: لا تظهر قائمة المدن، واجعل المدينة `مصراتة` تلقائيًا.
- إذا كانت الإحداثيات خارج حدود مصراتة: أظهر قائمة المدن المعتمدة فقط مع سعر التوصيل لكل مدينة.
- لا تسمح بحفظ العنوان خارج مصراتة إلا بعد اختيار مدينة من القائمة.

### الـ endpoint الأساسي لهذه الحالة

`GET /api/flutter/addresses/map-config`

الحقول المهمة من هذه الاستجابة:

- `data.supported_cities`
- `data.supported_cities[].name`
- `data.supported_cities[].shipping_cost`
- `data.checkout.misrata_boundary_km`
- `data.checkout.requires_supported_city`

### مثال الاستجابة المطلوبة لبناء القائمة

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

### كيف يطبقه iOS

1. عند فتح شاشة إضافة أو تعديل العنوان استدعِ `GET /api/flutter/addresses/map-config`.
2. احتفظ بقائمة `supported_cities` وقيمة `misrata_boundary_km`.
3. بعد أن يختار المستخدم النقطة على الخريطة، افحص هل الموقع داخل حدود مصراتة أو خارجها.
4. إذا كان داخل حدود مصراتة:
   اجعل `city = "مصراتة"` تلقائيًا وأخفِ حقل اختيار المدينة.
5. إذا كان خارج حدود مصراتة:
   اعرض `Picker` أو `Bottom Sheet` مبنيًا من `supported_cities`.
6. اعرض كل مدينة مع سعرها مثل:
   `طرابلس - 10 LYD`
7. عند اختيار مدينة، خزّن اسم المدينة فقط داخل `city`.
8. لا ترسل `shipping_cost` ضمن طلب الحفظ؛ هذا السعر للعرض فقط.
9. الباك اند سيحسب سعر الشحن النهائي لاحقًا عند إنشاء الطلب اعتمادًا على المدينة المحفوظة.

### طلب حفظ العنوان خارج مصراتة

يبقى نفس endpoint:

`POST /api/flutter/addresses`

ومثال body:

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

إذا احتاج iOS عرض قائمة المدن وأسعار الشحن في شاشة checkout أو مراجعة الطلب، يمكنه أيضًا استدعاء:

`GET /api/flutter/orders/lookups`

ومن هذه الاستجابة يقرأ:

- `data.shipping_cities`
- `data.shipping_cities[].name`
- `data.shipping_cities[].shipping_cost`

لكن في شاشة العنوان نفسها، المرجع الأساسي يظل:

`GET /api/flutter/addresses/map-config`

## ملاحظات خاصة بـ iOS

- الـ API لا يعيد مفاتيح Google Maps أو Apple Maps.
- مفاتيح الخرائط يجب أن تضبط داخل تطبيق iOS نفسه.
- إذا كنت تستخدم `Google Maps SDK for iOS` فيمكن إرسال `place_id` إذا حصلت عليه من Places SDK.
- إذا كنت تستخدم `MapKit` فقط، يمكن ترك `place_id = null`.
- المهم بالنسبة للسيرفر هو:
  `latitude`, `longitude`, `city`, ويفضل `formatted_address`.
- لا تعتمد على اسم المدينة المستنتج من reverse geocoding وحده إذا كانت النقطة خارج مصراتة؛ يجب أن يختار المستخدم مدينة من `supported_cities`.
- لا ترسل `shipping_cost` في طلب حفظ العنوان؛ استخدمه فقط للعرض داخل الواجهة.

## مثال Swift باستخدام URLSession

```swift
import Foundation

struct AddressMapConfigResponse: Decodable {
    let data: AddressMapConfig
}

struct AddressMapConfig: Decodable {
    let mapProvider: String
    let defaultCenter: Coordinates
    let storeLocation: Coordinates
    let supportedCities: [SupportedCity]

    enum CodingKeys: String, CodingKey {
        case mapProvider = "map_provider"
        case defaultCenter = "default_center"
        case storeLocation = "store_location"
        case supportedCities = "supported_cities"
    }
}

struct Coordinates: Decodable {
    let lat: Double
    let lng: Double
}

struct SupportedCity: Decodable {
    let name: String
    let shippingCost: Double

    enum CodingKeys: String, CodingKey {
        case name
        case shippingCost = "shipping_cost"
    }
}

func fetchAddressMapConfig(token: String) async throws -> AddressMapConfig {
    let url = URL(string: "https://your-domain.com/api/flutter/addresses/map-config")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    return try JSONDecoder().decode(AddressMapConfigResponse.self, from: data).data
}
```

## ملاحظات أخيرة

- يفضل عدم فتح شاشة الدفع أو checkout بعنوان لا يحتوي على `city` واضحة.
- إذا التقط المستخدم موقعًا بعيدًا أو غير واضح، اعرض له رسالة تطلب اختيار نقطة أدق.
- إذا كان لديك عنوان افتراضي محفوظ، اجعل تجربة التعديل تبدأ منه مباشرة بدل نقطة المتجر.

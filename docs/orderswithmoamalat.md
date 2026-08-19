# Flutter Orders API

هذا الملف يوثق واجهات الطلبات الخاصة بتطبيق Flutter، بما في ذلك:

- جلب إعدادات الشحن ووسائل الدفع المتاحة.
- إنشاء الطلبات من التطبيق.
- الدفع بالمحفظة.
- الربط مع `معاملات` عبر flow واضح: `create order -> open lightbox -> confirm/fail`.
- استعراض قائمة طلبات العميل وتفاصيل كل طلب.

هذه الواجهات مبنية على `Laravel Sanctum` وتعمل باستخدام `Bearer Token` فقط.

## Base URL

استبدل هذا الدومين بعنوان السيرفر الحقيقي:

`BASE_URL = https://hindam.ly`

كل المسارات التالية تكون بالنسبة إلى `BASE_URL`.

## Authentication

كل واجهات الطلبات في هذا الملف تتطلب أن يكون العميل مسجل الدخول ويرسل التوكن في الهيدر:

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer {access_token}
```

يمكنك الحصول على `access_token` من:

- `POST /api/flutter/auth/login`
- `POST /api/flutter/auth/register`

## Orders Endpoints

- `GET /api/flutter/orders/lookups`
- `GET /api/flutter/orders`
- `GET /api/flutter/orders/{orderNumber}`
- `POST /api/flutter/orders`
- `POST /api/flutter/orders/moamalat/confirm`
- `POST /api/flutter/orders/moamalat/fail`

## الفكرة العامة للـ Flow

### إذا كانت طريقة الدفع `cod`

1. التطبيق يرسل `POST /api/flutter/orders`
2. السيرفر ينشئ الطلب مباشرة
3. يرجع الطلب بحالة:
   - `payment.method = cod`
   - `payment.status = pending`

### إذا كانت طريقة الدفع `wallet`

1. التطبيق يرسل `POST /api/flutter/orders`
2. السيرفر يتحقق من الرصيد
3. إذا الرصيد يكفي:
   - يخصم القيمة من المحفظة
   - ينشئ الطلب
   - ينشئ حركة `wallet withdrawal`
   - يرجع الطلب بحالة `payment.status = paid`

### إذا كانت طريقة الدفع `moamalat`

1. التطبيق يرسل `POST /api/flutter/orders`
2. السيرفر ينشئ الطلب أولاً
3. ثم يجهز `checkout` الخاص بـ `معاملات`
4. التطبيق يفتح LightBox باستخدام البيانات الراجعة
5. بعد نجاح الدفع:
   - يرسل التطبيق payload الرجوع إلى `POST /api/flutter/orders/moamalat/confirm`
6. إذا أغلقت النافذة أو رجع callback فشل:
   - يرسل التطبيق `POST /api/flutter/orders/moamalat/fail`
7. بعد ذلك يمكن للتطبيق إعادة جلب الطلب من:
   - `GET /api/flutter/orders/{orderNumber}`

## 1) Order Lookups

### Endpoint

`GET /api/flutter/orders/lookups`

### الاستخدام

هذا هو الـ endpoint الذي يفضل استدعاؤه قبل فتح شاشة الدفع في التطبيق، لأنه يعيد:

- العملة.
- حالات الطلبات.
- حالات الدفع.
- وسائل الدفع المتاحة حالياً من إعدادات السيرفر.
- المدن المتاحة للشحن مع تكلفة كل مدينة.
- رصيد المحفظة الحالي.

### Success Response

```json
{
  "data": {
    "currency": "LYD",
    "order_statuses": [
      {
        "key": "pending",
        "label": "قيد الانتظار"
      },
      {
        "key": "delivered",
        "label": "تم التسليم"
      }
    ],
    "payment_statuses": [
      {
        "key": "pending",
        "label": "قيد الانتظار"
      },
      {
        "key": "paid",
        "label": "مدفوع"
      }
    ],
    "payment_methods": [
      {
        "key": "cod",
        "label": "الدفع عند الاستلام",
        "enabled": true,
        "requires_online_payment": false
      },
      {
        "key": "wallet",
        "label": "المحفظة",
        "enabled": true,
        "requires_online_payment": false
      },
      {
        "key": "moamalat",
        "label": "معاملات",
        "enabled": true,
        "requires_online_payment": true
      }
    ],
    "shipping_cities": [
      {
        "name": "Tripoli",
        "shipping_cost": 10
      },
      {
        "name": "Benghazi",
        "shipping_cost": 20
      }
    ],
    "wallet": {
      "balance": 85.5,
      "enabled": true
    }
  }
}
```

### ملاحظات مهمة

- لا تعمل hardcode لطرق الدفع داخل التطبيق. اعتمد على `payment_methods`.
- إذا كانت `enabled = false` فلا تعرض الطريقة كخيار دفع.
- `wallet.balance` مفيد جداً لتحديد هل تعرض خيار المحفظة كمفعل أو كخيار مع رسالة "الرصيد غير كافٍ".

## 2) Orders List

### Endpoint

`GET /api/flutter/orders`

### Query Parameters

- `status`: اختياري. مثل `pending`, `processing`, `shipped`, `delivered`, `cancelled`, `refunded`
- `payment_status`: اختياري. مثل `pending`, `paid`, `failed`, `refunded`
- `per_page`: اختياري. من `1` إلى `50`
- `page`: اختياري

### Example Request

```http
GET /api/flutter/orders?payment_status=pending&per_page=10&page=1
```

### Success Response

```json
{
  "data": [
    {
      "id": 15,
      "order_number": "ORD-AB12CD34",
      "status": "pending",
      "status_label": "قيد الانتظار",
      "payment": {
        "method": "moamalat",
        "method_label": "معاملات",
        "raw_method": "card",
        "status": "pending",
        "status_label": "قيد الانتظار",
        "amount": 130,
        "merchant_reference": "ORD-AB12CD34",
        "awaiting_gateway_notification": true
      },
      "totals": {
        "subtotal": 120,
        "discount_amount": 0,
        "shipping_cost": 10,
        "tax_amount": 0,
        "total": 130
      },
      "shipping": {
        "full_name": "Mohamed Ali",
        "phone": "0912345678",
        "address_line1": "Airport Road",
        "address_line2": null,
        "city": "Tripoli",
        "state": null,
        "country": "Libya",
        "postal_code": null
      },
      "items_qty": 1,
      "items": [
        {
          "id": 21,
          "product_id": 9,
          "product_variant_id": null,
          "product_name": "Premium Dryer",
          "variant_info": null,
          "product_sku": "DRY-120",
          "quantity": 1,
          "unit_price": 120,
          "total_price": 120
        }
      ],
      "timestamps": {
        "created_at": "2026-03-09T18:05:00.000000Z",
        "updated_at": "2026-03-09T18:05:00.000000Z",
        "shipped_at": null,
        "delivered_at": null
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
  }
}
```

## 3) Order Details

### Endpoint

`GET /api/flutter/orders/{orderNumber}`

### مثال

```http
GET /api/flutter/orders/ORD-AB12CD34
```

### الاستخدام

استعمل هذا الـ endpoint في:

- شاشة تفاصيل الطلب.
- تحديث حالة الطلب بعد الدفع عبر `معاملات`.
- polling بسيط بعد `fail` إذا كنت تنتظر الإشعار النهائي من البوابة.

### ملاحظة مهمة جداً

في بعض الحالات بعد نجاح الدفع عبر `معاملات` سيظهر:

- `payment.method = moamalat`
- لكن `payment.raw_method = wallet`

هذا مقصود داخل النظام، لأن الدفع عبر `معاملات` يتم تحويله محاسبياً إلى حركات محفظة داخلية، بينما الواجهة المخصصة للتطبيق ما زالت تعرضه لك كـ `moamalat` حتى لا يلتبس الأمر على المستخدم.

## 4) Create Order

### Endpoint

`POST /api/flutter/orders`

### Body

```json
{
  "items": [
    {
      "product_id": 9,
      "product_variant_id": 14,
      "quantity": 2
    },
    {
      "product_id": 12,
      "quantity": 1
    }
  ],
  "payment_method": "moamalat",
  "shipping": {
    "full_name": "Mohamed Ali",
    "phone": "0912345678",
    "address_line1": "Airport Road",
    "address_line2": "Near XYZ",
    "city": "Tripoli",
    "state": "Tripoli",
    "country": "Libya",
    "postal_code": "21801"
  }
}
```

### شرح الحقول

- `items`: مطلوبة. مصفوفة فيها عنصر واحد على الأقل.
- `items[].product_id`: مطلوب.
- `items[].product_variant_id`: اختياري.
- `items[].quantity`: مطلوب.
- `payment_method`: مطلوب. القيم المسموحة:
  - `cod`
  - `wallet`
  - `moamalat`
- `shipping.full_name`: مطلوب.
- `shipping.phone`: مطلوب ويجب أن يطابق النمط المحلي الحالي مثل `0912345678`.
- `shipping.address_line1`: مطلوب.
- `shipping.city`: مطلوب ويجب أن تكون المدينة مدعومة في إعدادات الشحن.
- باقي حقول `shipping`: اختيارية.

### ملاحظات سلوكية

- السعر لا يؤخذ من التطبيق، بل يحسبه السيرفر من بيانات المنتج الحالية.
- تكلفة الشحن لا ترسل من التطبيق، بل تحسب من المدينة على السيرفر.
- المخزون يراجع ويخصم على السيرفر أثناء إنشاء الطلب.
- إذا أرسلت `product_variant_id` غير صالح أو غير نشط، سيرجع السيرفر `422`.

### Response عند الدفع `cod`

```json
{
  "message": "Order created successfully.",
  "data": {
    "order": {
      "id": 15,
      "order_number": "ORD-COD12345",
      "status": "pending",
      "status_label": "قيد الانتظار",
      "payment": {
        "method": "cod",
        "method_label": "الدفع عند الاستلام",
        "raw_method": "cash_on_delivery",
        "status": "pending",
        "status_label": "قيد الانتظار",
        "amount": 170,
        "merchant_reference": "ORD-COD12345",
        "awaiting_gateway_notification": false
      },
      "totals": {
        "subtotal": 160,
        "discount_amount": 0,
        "shipping_cost": 10,
        "tax_amount": 0,
        "total": 170
      },
      "shipping": {
        "full_name": "Mohamed Ali",
        "phone": "0912345678",
        "address_line1": "Hay Andalus",
        "address_line2": null,
        "city": "Tripoli",
        "state": null,
        "country": "Libya",
        "postal_code": null
      },
      "items_qty": 2,
      "items": [
        {
          "id": 45,
          "product_id": 3,
          "product_variant_id": null,
          "product_name": "Cordless Clipper",
          "variant_info": null,
          "product_sku": "CLIP-001",
          "quantity": 2,
          "unit_price": 80,
          "total_price": 160
        }
      ],
      "timestamps": {
        "created_at": "2026-03-09T18:20:00.000000Z",
        "updated_at": "2026-03-09T18:20:00.000000Z",
        "shipped_at": null,
        "delivered_at": null
      }
    },
    "payment_action": null
  }
}
```

### Response عند الدفع `wallet`

```json
{
  "message": "Order created successfully.",
  "data": {
    "order": {
      "order_number": "ORD-WALLET123",
      "payment": {
        "method": "wallet",
        "raw_method": "wallet",
        "status": "paid",
        "amount": 190,
        "awaiting_gateway_notification": false
      }
    },
    "payment_action": null
  }
}
```

### Response عند الدفع `moamalat`

```json
{
  "message": "Order created and Moamalat checkout initialized successfully.",
  "data": {
    "order": {
      "order_number": "ORD-MOAM1234",
      "payment": {
        "method": "moamalat",
        "raw_method": "card",
        "status": "pending",
        "amount": 130,
        "merchant_reference": "ORD-MOAM1234",
        "awaiting_gateway_notification": true
      }
    },
    "payment_action": {
      "type": "moamalat_lightbox",
      "merchant_reference": "ORD-MOAM1234",
      "checkout": {
        "scriptUrl": "https://tnpg.moamalat.net:6006/js/lightbox.js",
        "MID": "MID123",
        "TID": "TID456",
        "AmountTrxn": "130000",
        "MerchantReference": "ORD-MOAM1234",
        "TrxDateTime": "202603091825",
        "SecureHash": "ABCDEF1234567890"
      }
    }
  }
}
```

### إذا فشل تجهيز checkout بعد إنشاء الطلب

قد يرجع السيرفر:

`422 Unprocessable Entity`

```json
{
  "message": "Order was created, but Moamalat checkout could not be initialized.",
  "data": {
    "order": {
      "order_number": "ORD-MOAM1234",
      "payment": {
        "method": "moamalat",
        "status": "failed"
      }
    }
  }
}
```

هذا مهم جداً داخل التطبيق، لأن معنى هذا الرد:

- الطلب تم إنشاؤه فعلاً.
- لكن نافذة الدفع لم تجهز.
- لذلك يجب أن تتعامل مع `data.order` ولا تفترض أن الطلب لم يُنشأ.

## 5) Moamalat Confirm

### Endpoint

`POST /api/flutter/orders/moamalat/confirm`

### الاستخدام

بعد نجاح LightBox في التطبيق، أرسل payload الرجوع إلى هذا الـ endpoint.

يفضل إرسال كل الحقول القادمة من `معاملات` كما هي، وأهم شيء:

- `MerchantReference`
- `ActionCode`
- `Message`
- `SecureHash` إذا كان متوفراً

### Example Request

```json
{
  "MerchantReference": "ORD-MOAM1234",
  "ActionCode": "000",
  "Message": "Approved",
  "SecureHash": "ABCDEF1234567890"
}
```

### Success Response

```json
{
  "success": true,
  "message": "Order payment confirmed successfully.",
  "data": {
    "order": {
      "order_number": "ORD-MOAM1234",
      "payment": {
        "method": "moamalat",
        "method_label": "معاملات",
        "raw_method": "wallet",
        "status": "paid",
        "status_label": "مدفوع",
        "amount": 130,
        "merchant_reference": "ORD-MOAM1234",
        "awaiting_gateway_notification": false
      }
    }
  }
}
```

### ملاحظة مهمة جداً بخصوص `SecureHash`

في تدفق الطلبات عبر `معاملات`، السيرفر يحاول التحقق من `SecureHash`، لكن إذا كان callback callback نجاح من LightBox وبعض الحقول الناقصة منعت التحقق، فالسيرفر ما زال يقبل التأكيد ويعلم الطلب كمدفوع، ويسجل ملاحظة audit داخلية.

السبب هو أن بعض نسخ LightBox قد ترجع callback نجاح بدون كل الحقول اللازمة للتحقق الكامل، بينما تكون عملية الدفع ناجحة فعلاً.

بمعنى أوضح:

- success callback من LightBox ما زال معتمداً للتأكيد.
- أما الإشعار النهائي من البوابة فيبقى طبقة إضافية لتعزيز التزامن.

### الأخطاء المحتملة

#### مرجع مفقود

`422 Unprocessable Entity`

```json
{
  "success": false,
  "message": "Missing merchant reference."
}
```

#### الطلب غير موجود

`404 Not Found`

```json
{
  "success": false,
  "message": "Order not found."
}
```

#### البوابة رجعت فشل

`422 Unprocessable Entity`

```json
{
  "success": false,
  "message": "Moamalat reported the payment as failed."
}
```

## 6) Moamalat Fail

### Endpoint

`POST /api/flutter/orders/moamalat/fail`

### الاستخدام

استدع هذا الـ endpoint إذا:

- أغلق المستخدم نافذة الدفع.
- رجع error callback من `معاملات`.
- حصل fail callback من الـ SDK أو WebView.

### Example Request

```json
{
  "merchant_reference": "ORD-MOAM1234",
  "reason": "user_cancelled"
}
```

### Success Response

```json
{
  "success": true,
  "message": "Payment callback recorded. Final payment status is pending until the gateway notification resolves it.",
  "data": {
    "order": {
      "order_number": "ORD-MOAM1234",
      "payment": {
        "method": "moamalat",
        "status": "pending",
        "awaiting_gateway_notification": true
      }
    },
    "awaiting_gateway_notification": true
  }
}
```

### لماذا لا يتم دائماً تحويل الحالة إلى `failed` مباشرة؟

لأن fail callback القادم من الواجهة ليس دائماً هو النتيجة النهائية المعتمدة من البوابة. لذلك:

- السيرفر يسجل الحدث.
- يبقي حالة الدفع `pending` إذا لم يصل تأكيد نهائي بعد.
- ويترك الإشعار النهائي القادم من بوابة `معاملات` ليحسم الحالة.

لذلك بعد `fail` يفضل أن يفعل التطبيق واحداً من الآتي:

1. يعرض رسالة "بانتظار الحالة النهائية من البوابة".
2. يعيد جلب `GET /api/flutter/orders/{orderNumber}` بعد عدة ثوانٍ.
3. يحدث شاشة الطلبات عند العودة إلى الواجهة.

## شكل كائن الطلب

نفس الشكل تقريباً يرجع في:

- `orders list`
- `order details`
- `create order`
- `moamalat confirm`
- `moamalat fail`

```json
{
  "id": 15,
  "order_number": "ORD-AB12CD34",
  "status": "pending",
  "status_label": "قيد الانتظار",
  "payment": {
    "method": "moamalat",
    "method_label": "معاملات",
    "raw_method": "wallet",
    "status": "paid",
    "status_label": "مدفوع",
    "amount": 130,
    "merchant_reference": "ORD-AB12CD34",
    "awaiting_gateway_notification": false
  },
  "totals": {
    "subtotal": 120,
    "discount_amount": 0,
    "shipping_cost": 10,
    "tax_amount": 0,
    "total": 130
  },
  "shipping": {
    "full_name": "Mohamed Ali",
    "phone": "0912345678",
    "address_line1": "Airport Road",
    "address_line2": null,
    "city": "Tripoli",
    "state": null,
    "country": "Libya",
    "postal_code": null
  },
  "items_qty": 1,
  "items": [
    {
      "id": 21,
      "product_id": 9,
      "product_variant_id": null,
      "product_name": "Premium Dryer",
      "variant_info": null,
      "product_sku": "DRY-120",
      "quantity": 1,
      "unit_price": 120,
      "total_price": 120
    }
  ],
  "timestamps": {
    "created_at": "2026-03-09T18:05:00.000000Z",
    "updated_at": "2026-03-09T18:08:00.000000Z",
    "shipped_at": null,
    "delivered_at": null
  }
}
```

## التسلسل المقترح داخل Flutter

### عند فتح شاشة Checkout

1. استدع `GET /api/flutter/orders/lookups`
2. اعرض المدن المتاحة وتكلفة الشحن
3. اعرض طرق الدفع من `payment_methods`
4. اعرض رصيد المحفظة من `wallet.balance`

### عند إنشاء طلب `cod`

1. أرسل `POST /api/flutter/orders`
2. إذا رجع `201`:
   - افتح شاشة نجاح الطلب
   - خزّن `order_number`
   - أضف الطلب إلى قائمة الطلبات المحلية أو أعد تحميلها

### عند إنشاء طلب `wallet`

1. أرسل `POST /api/flutter/orders`
2. إذا رجع `201` و`payment.status = paid`:
   - حدث رصيد المحفظة محلياً إذا كنت تعرضه
   - اعرض نجاح الطلب مباشرة

### عند إنشاء طلب `moamalat`

1. أرسل `POST /api/flutter/orders`
2. خزّن:
   - `data.order.order_number`
   - `data.payment_action.merchant_reference`
   - `data.payment_action.checkout`
3. افتح LightBox باستخدام `checkout`
4. عند success callback:
   - أرسل payload إلى `POST /api/flutter/orders/moamalat/confirm`
5. عند fail أو cancel:
   - أرسل `merchant_reference` إلى `POST /api/flutter/orders/moamalat/fail`
6. بعد `confirm` الناجح:
   - اعرض نجاح الدفع والطلب
7. بعد `fail`:
   - اعرض حالة انتظار أو أعد التحقق من تفاصيل الطلب

## Example Dio Service

```dart
class OrdersApi {
  OrdersApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> fetchLookups() async {
    final response = await dio.get('/api/flutter/orders/lookups');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchOrders({
    int page = 1,
    int perPage = 15,
    String? status,
    String? paymentStatus,
  }) async {
    final response = await dio.get(
      '/api/flutter/orders',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null) 'status': status,
        if (paymentStatus != null) 'payment_status': paymentStatus,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchOrder(String orderNumber) async {
    final response = await dio.get('/api/flutter/orders/$orderNumber');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required Map<String, dynamic> shipping,
  }) async {
    final response = await dio.post(
      '/api/flutter/orders',
      data: {
        'items': items,
        'payment_method': paymentMethod,
        'shipping': shipping,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> confirmMoamalat(Map<String, dynamic> callbackPayload) async {
    final response = await dio.post(
      '/api/flutter/orders/moamalat/confirm',
      data: callbackPayload,
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> failMoamalat({
    required String merchantReference,
    String reason = 'user_cancelled',
  }) async {
    final response = await dio.post(
      '/api/flutter/orders/moamalat/fail',
      data: {
        'merchant_reference': merchantReference,
        'reason': reason,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}
```

## أكواد الحالة المستخدمة

- `200`: نجاح جلب البيانات أو نجاح confirm/fail
- `201`: تم إنشاء الطلب بنجاح
- `401`: لا يوجد توكن أو التوكن غير صالح
- `403`: المستخدم غير عميل أو الحساب غير مفعل
- `404`: الطلب غير موجود
- `422`: خطأ تحقق أو طريقة دفع غير متاحة أو فشل من `معاملات`
- `500`: خطأ داخلي أثناء تأكيد الدفع أو إنشاء الطلب

## أشهر رسائل الخطأ التي قد يراها التطبيق

```json
{
  "message": "Selected payment method is not available right now."
}
```

```json
{
  "message": "Moamalat credentials are not configured."
}
```

```json
{
  "message": "Wallet balance is insufficient for this order."
}
```

```json
{
  "message": "One or more requested items are unavailable or out of stock."
}
```

```json
{
  "success": false,
  "message": "Missing merchant reference."
}
```

## روابط كاملة كمثال

- `GET https://hindam.ly/api/flutter/orders/lookups`
- `GET https://hindam.ly/api/flutter/orders`
- `GET https://hindam.ly/api/flutter/orders/ORD-AB12CD34`
- `POST https://hindam.ly/api/flutter/orders`
- `POST https://hindam.ly/api/flutter/orders/moamalat/confirm`
- `POST https://hindam.ly/api/flutter/orders/moamalat/fail`

# Flutter Wallet API

هذا الملف يوثق واجهات محفظة العميل الخاصة بتطبيق Flutter، بحيث يكون رصيد العميل وحركاته داخل التطبيق مطابقًا تمامًا للمحفظة الموجودة في الموقع.

الواجهات مبنية على `Laravel Sanctum` وتعمل بنظام `Bearer Token`، لذلك تطبيق Flutter لا يحتاج إلى `Cookies` أو `CSRF`.

## الهدف من هذه الواجهات

من خلال هذه المجموعة تستطيع شاشة المحفظة في Flutter أن:

- تعرض رصيد العميل الحالي.
- تعرض آخر الحركات وسجل الحركات كاملًا مع التصفية.
- تعرف وسائل الشحن المتاحة بدون hardcode داخل التطبيق.
- تنفذ الشحن المباشر للوسائل العادية مثل `bank_transfer`.
- تنفذ شحن `moamalat` عبر Flow منفصل: `prepare -> lightbox -> confirm/fail`.

## Base URL

استبدل هذا الدومين بعنوان السيرفر الحقيقي:

`BASE_URL = https://hindam.ly`

كل المسارات التالية تكون بالنسبة إلى `BASE_URL`.

## Authentication

جميع واجهات المحفظة تتطلب أن يكون العميل مسجل الدخول وأن يرسل `access_token` الذي يحصل عليه من:

- `POST /api/flutter/auth/login`
- `POST /api/flutter/auth/register`

الهيدر المطلوب:

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer {access_token}
```

## Wallet Endpoints

- `GET /api/flutter/wallet`
- `GET /api/flutter/wallet/transactions`
- `POST /api/flutter/wallet/top-up`
- `POST /api/flutter/wallet/top-up/moamalat/prepare`
- `POST /api/flutter/wallet/top-up/moamalat/confirm`
- `POST /api/flutter/wallet/top-up/moamalat/fail`

## 1) Wallet Summary

### Endpoint

`GET /api/flutter/wallet`

### الاستخدام

هذا هو الـ endpoint الأساسي الذي يجب أن تناديه عند فتح شاشة المحفظة داخل التطبيق.

يعيد:

- الرصيد الحالي.
- العملة.
- هل الدفع بالمحفظة مفعل داخل النظام أم لا.
- وسائل الشحن المتاحة حاليًا.
- آخر 10 حركات.

### Success Response

`200 OK`

```json
{
  "data": {
    "balance": 125.5,
    "currency": "LYD",
    "wallet_payment_enabled": true,
    "top_up_providers": [
      {
        "key": "moamalat",
        "label": "معاملات",
        "mode": "moamalat_lightbox"
      },
      {
        "key": "bank_transfer",
        "label": "تحويل بنكي",
        "mode": "direct"
      }
    ],
    "recent_transactions": [
      {
        "id": 8,
        "transaction_number": "WTX-20260309010101-ABC123",
        "type": "deposit",
        "type_label": "إيداع",
        "amount": 50,
        "balance_before": 75.5,
        "balance_after": 125.5,
        "status": "completed",
        "status_label": "مكتملة",
        "provider": "bank_transfer",
        "provider_label": "تحويل بنكي",
        "reference": "BANK-REF-100",
        "notes": "Manual transfer",
        "created_at": "2026-03-09T10:22:00.000000Z",
        "updated_at": "2026-03-09T10:22:00.000000Z"
      }
    ]
  }
}
```

### شرح الحقول

- `balance`: الرصيد الحالي الفعلي في محفظة العميل.
- `currency`: العملة الافتراضية للنظام.
- `wallet_payment_enabled`: هل النظام يسمح حاليًا بالدفع من المحفظة أثناء الشراء.
- `top_up_providers`: قائمة مزودي الشحن المتاحين حاليًا من السيرفر.
- `top_up_providers[].key`: القيمة التي يجب إرسالها لاحقًا في `provider`.
- `top_up_providers[].mode`: تحدد طريقة التنفيذ:
  - `direct`: شحن مباشر عبر `POST /wallet/top-up`
  - `moamalat_lightbox`: يجب استخدام `prepare` ثم `confirm` أو `fail`
- `recent_transactions`: آخر 10 حركات فقط لعرض سريع داخل الشاشة.

## 2) Wallet Transactions

### Endpoint

`GET /api/flutter/wallet/transactions`

### الاستخدام

هذا الـ endpoint مخصص لشاشة "كل الحركات" مع دعم pagination وfiltering.

### Query Parameters

- `type`: اختياري. القيم المسموحة: `deposit`, `withdrawal`, `adjustment`
- `status`: اختياري. القيم المسموحة: `pending`, `completed`, `failed`
- `provider`: اختياري. فلتر نصي حسب قيمة الموفر المخزنة في قاعدة البيانات
- `per_page`: اختياري. من `1` إلى `100`
- `page`: اختياري. رقم الصفحة

### أمثلة على provider

قد ترى قيما مثل:

- `moamalat`
- `bank_transfer`
- `sadad`
- `wallet_checkout`
- `admin_credit`

### Example Request

```http
GET /api/flutter/wallet/transactions?type=deposit&status=completed&provider=bank_transfer&per_page=15&page=1
```

### Success Response

```json
{
  "data": [
    {
      "id": 8,
      "transaction_number": "WTX-20260309010101-ABC123",
      "type": "deposit",
      "type_label": "إيداع",
      "amount": 50,
      "balance_before": 75.5,
      "balance_after": 125.5,
      "status": "completed",
      "status_label": "مكتملة",
      "provider": "bank_transfer",
      "provider_label": "تحويل بنكي",
      "reference": "BANK-REF-100",
      "notes": "Manual transfer",
      "created_at": "2026-03-09T10:22:00.000000Z",
      "updated_at": "2026-03-09T10:22:00.000000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 15,
    "total": 1,
    "has_more_pages": false
  }
}
```

### ملاحظات مهمة

- استخدم `provider_label` و`type_label` و`status_label` مباشرة في الواجهة إذا أردت عرضًا سريعًا.
- إذا كنت تريد منطقًا خاصًا في UI، اعتمد على القيم الخام: `type`, `status`, `provider`.
- عند الدفع من رصيد المحفظة في الطلبات، قد تظهر حركات من النوع `withdrawal` وبالموفر `wallet_checkout`.

## 3) Direct Top-Up

### Endpoint

`POST /api/flutter/wallet/top-up`

### الاستخدام

هذا الـ endpoint مخصص لوسائل الشحن المباشرة فقط مثل:

- `bank_transfer`
- `sadad` إذا كان مفعلًا في الإعدادات

ولا يجب استخدامه مع `moamalat`.

### Body

```json
{
  "amount": 25.5,
  "provider": "bank_transfer",
  "reference": "BANK-REF-100",
  "notes": "Manual transfer"
}
```

### الحقول

- `amount`: مطلوب. رقم بين `1` و`50000`
- `provider`: مطلوب. يجب أن يكون من القيم الموجودة في `top_up_providers`
- `reference`: اختياري. رقم مرجعي للحوالة أو العملية
- `notes`: اختياري. ملاحظات إضافية

### Success Response

`201 Created`

```json
{
  "message": "Wallet topped up successfully.",
  "data": {
    "balance": 75.5,
    "transaction": {
      "id": 15,
      "transaction_number": "WTX-20260309010202-XYZ789",
      "type": "deposit",
      "type_label": "إيداع",
      "amount": 25.5,
      "balance_before": 50,
      "balance_after": 75.5,
      "status": "completed",
      "status_label": "مكتملة",
      "provider": "bank_transfer",
      "provider_label": "تحويل بنكي",
      "reference": "BANK-REF-100",
      "notes": "Manual transfer",
      "created_at": "2026-03-09T10:25:00.000000Z",
      "updated_at": "2026-03-09T10:25:00.000000Z"
    }
  }
}
```

### تنبيه مهم جدًا

في المنطق الحالي للنظام، الشحن عبر `bank_transfer` و`sadad` يتم اعتماده مباشرة عند استدعاء هذا الـ endpoint، أي أن الرصيد يزداد فورًا ولا توجد دورة مراجعة منفصلة.

إذا كنت تريد مستقبلًا أن يتحول الشحن البنكي أو `sadad` إلى "طلب شحن ينتظر مراجعة الإدارة"، فذلك يحتاج تعديل منطق الخادم وليس Flutter فقط.

### إذا أرسلت moamalat هنا

ستحصل على:

`422 Unprocessable Entity`

```json
{
  "message": "Use the Moamalat prepare endpoint for this provider."
}
```

## 4) Moamalat Prepare

### Endpoint

`POST /api/flutter/wallet/top-up/moamalat/prepare`

### الاستخدام

هذا هو أول step في شحن المحفظة عبر `moamalat`.

السيرفر يقوم هنا بـ:

1. إنشاء حركة محفظة بحالة `pending`
2. إنشاء `merchant_reference`
3. تجهيز بيانات `lightbox`
4. إرجاع كل ما يحتاجه Flutter لبدء عملية الدفع

### Body

```json
{
  "amount": 30,
  "provider": "moamalat",
  "notes": "Top up via lightbox"
}
```

### Success Response

`200 OK`

```json
{
  "success": true,
  "message": "Moamalat checkout initialized successfully.",
  "data": {
    "merchant_reference": "WTOP-WTX-20260309010303-AAA111",
    "checkout": {
      "scriptUrl": "https://tnpg.moamalat.net:6006/js/lightbox.js",
      "MID": "MID123",
      "TID": "TID456",
      "AmountTrxn": "30000",
      "MerchantReference": "WTOP-WTX-20260309010303-AAA111",
      "TrxDateTime": "202603091030",
      "SecureHash": "ABCDEF1234567890"
    },
    "transaction": {
      "id": 21,
      "transaction_number": "WTX-20260309010303-AAA111",
      "type": "deposit",
      "type_label": "إيداع",
      "amount": 30,
      "balance_before": 20,
      "balance_after": 20,
      "status": "pending",
      "status_label": "قيد الانتظار",
      "provider": "moamalat",
      "provider_label": "معاملات",
      "reference": "WTOP-WTX-20260309010303-AAA111",
      "notes": "Top up via lightbox",
      "created_at": "2026-03-09T10:30:00.000000Z",
      "updated_at": "2026-03-09T10:30:00.000000Z"
    }
  }
}
```

### شرح checkout

- `scriptUrl`: رابط سكربت `moamalat` lightbox
- `MID`: Merchant ID
- `TID`: Terminal ID
- `AmountTrxn`: قيمة العملية بصيغة `moamalat`
- `MerchantReference`: المرجع الذي يجب الاحتفاظ به داخل التطبيق
- `TrxDateTime`: وقت العملية
- `SecureHash`: التوقيع الذي تتحقق به `moamalat`

## 5) Moamalat Confirm

### Endpoint

`POST /api/flutter/wallet/top-up/moamalat/confirm`

### الاستخدام

بعد نجاح عملية الدفع في `moamalat`، يجب على Flutter إرسال payload الرجوع إلى هذا الـ endpoint.

السيرفر يقوم هنا بـ:

1. التحقق من `SecureHash`
2. التأكد من أن العملية ليست فاشلة
3. تحديث الحركة من `pending` إلى `completed`
4. إضافة المبلغ فعليًا إلى رصيد المحفظة

### Body

يفضل إرسال payload العودة كاملًا كما جاء من `moamalat`. مثال:

```json
{
  "AmountTrxn": "30000",
  "MID": "MID123",
  "TID": "TID456",
  "TrxDateTime": "202603091030",
  "MerchantReference": "WTOP-WTX-20260309010303-AAA111",
  "ActionCode": "000",
  "Message": "Approved",
  "SecureHash": "ABCDEF1234567890"
}
```

### Success Response

```json
{
  "success": true,
  "message": "Wallet has been topped up successfully.",
  "data": {
    "balance": 50,
    "transaction": {
      "id": 21,
      "transaction_number": "WTX-20260309010303-AAA111",
      "type": "deposit",
      "type_label": "إيداع",
      "amount": 30,
      "balance_before": 20,
      "balance_after": 50,
      "status": "completed",
      "status_label": "مكتملة",
      "provider": "moamalat",
      "provider_label": "معاملات",
      "reference": "WTOP-WTX-20260309010303-AAA111",
      "notes": "Top up via lightbox",
      "created_at": "2026-03-09T10:30:00.000000Z",
      "updated_at": "2026-03-09T10:31:00.000000Z"
    }
  }
}
```

### الأخطاء المحتملة

#### مرجع ناقص

`422 Unprocessable Entity`

```json
{
  "success": false,
  "message": "Missing merchant reference."
}
```

#### توقيع غير صحيح

`422 Unprocessable Entity`

```json
{
  "success": false,
  "message": "Invalid Moamalat callback signature."
}
```

#### العملية فشلت في معاملات

`422 Unprocessable Entity`

```json
{
  "success": false,
  "message": "Moamalat reported the payment as failed."
}
```

#### الحركة غير موجودة

`404 Not Found`

```json
{
  "success": false,
  "message": "Related wallet transaction was not found."
}
```

## 6) Moamalat Fail

### Endpoint

`POST /api/flutter/wallet/top-up/moamalat/fail`

### الاستخدام

يجب استدعاء هذا الـ endpoint إذا:

- ألغى العميل الدفع
- أرجعت `moamalat` حالة فشل
- أغلقت نافذة الدفع قبل الإتمام

### Body

```json
{
  "merchant_reference": "WTOP-WTX-20260309010303-AAA111",
  "reason": "user_cancelled"
}
```

أو يمكن إرسال `MerchantReference` القادم من `moamalat` مباشرة.

### Success Response

```json
{
  "success": true,
  "message": "Wallet top-up marked as failed."
}
```

## شكل كائن الحركة

نفس الشكل تقريبًا يظهر في:

- `wallet.recent_transactions`
- `wallet/transactions`
- `top-up` response
- `moamalat confirm` response

```json
{
  "id": 21,
  "transaction_number": "WTX-20260309010303-AAA111",
  "type": "deposit",
  "type_label": "إيداع",
  "amount": 30,
  "balance_before": 20,
  "balance_after": 50,
  "status": "completed",
  "status_label": "مكتملة",
  "provider": "moamalat",
  "provider_label": "معاملات",
  "reference": "WTOP-WTX-20260309010303-AAA111",
  "notes": "Top up via lightbox",
  "created_at": "2026-03-09T10:30:00.000000Z",
  "updated_at": "2026-03-09T10:31:00.000000Z"
}
```

## التسلسل المقترح داخل Flutter

### عند فتح شاشة المحفظة

1. استدعِ `GET /api/flutter/wallet`
2. اعرض `balance`
3. اعرض `recent_transactions`
4. اعرض قائمة الشحن من `top_up_providers`

### عند فتح شاشة كل الحركات

1. استدعِ `GET /api/flutter/wallet/transactions?page=1`
2. استخدم `meta.has_more_pages` لمعرفة هل توجد صفحات إضافية
3. أرسل `page + 1` عند الـ infinite scroll أو زر "تحميل المزيد"

### عند الشحن المباشر

1. اختر provider من `top_up_providers` بشرط أن يكون `mode = direct`
2. أرسل الطلب إلى `POST /api/flutter/wallet/top-up`
3. حدّث الرصيد المحلي من `data.balance`
4. أعد تحميل شاشة المحفظة أو أضف الحركة مباشرة إلى القائمة

### عند الشحن عبر moamalat

1. أرسل `POST /api/flutter/wallet/top-up/moamalat/prepare`
2. خزّن `merchant_reference`
3. افتح واجهة الدفع باستخدام `checkout`
4. عند النجاح أرسل payload الرجوع كاملًا إلى `POST /confirm`
5. عند الفشل أو الإلغاء أرسل `merchant_reference` إلى `POST /fail`
6. بعد `confirm` الناجح حدّث الرصيد والحركات

## ملاحظات تنفيذ مهمة

- لا تعمل hardcode لقائمة مزودي الشحن داخل التطبيق. اعتمد على `top_up_providers` القادمة من السيرفر.
- ما زال `wallet_balance` يظهر أيضًا داخل `login/register/me`، لكن شاشة المحفظة يجب أن تعتمد على `GET /api/flutter/wallet` لأنه يعيد أيضًا الحركات والموفرين.
- إذا رجع السيرفر `401`، احذف التوكن محليًا ووجّه المستخدم لتسجيل الدخول.
- إذا رجع `403`، فهذا يعني غالبًا أن الحساب غير عميل أو غير مفعل.
- استخدم `provider_label`, `type_label`, `status_label` لعرض نصوص جاهزة في الواجهة عند الحاجة.

## مثال Dio

```dart
class WalletApi {
  WalletApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> fetchSummary() async {
    final response = await dio.get('/api/flutter/wallet');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchTransactions({
    int page = 1,
    int perPage = 15,
    String? type,
    String? status,
    String? provider,
  }) async {
    final response = await dio.get(
      '/api/flutter/wallet/transactions',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        if (provider != null) 'provider': provider,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> topUpDirect({
    required double amount,
    required String provider,
    String? reference,
    String? notes,
  }) async {
    final response = await dio.post(
      '/api/flutter/wallet/top-up',
      data: {
        'amount': amount,
        'provider': provider,
        'reference': reference,
        'notes': notes,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> prepareMoamalat({
    required double amount,
  }) async {
    final response = await dio.post(
      '/api/flutter/wallet/top-up/moamalat/prepare',
      data: {
        'amount': amount,
        'provider': 'moamalat',
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> confirmMoamalat(Map<String, dynamic> callbackPayload) async {
    final response = await dio.post(
      '/api/flutter/wallet/top-up/moamalat/confirm',
      data: callbackPayload,
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> failMoamalat({
    required String merchantReference,
    String reason = 'user_cancelled',
  }) async {
    await dio.post(
      '/api/flutter/wallet/top-up/moamalat/fail',
      data: {
        'merchant_reference': merchantReference,
        'reason': reason,
      },
    );
  }
}
```

## أكواد الحالة المستخدمة

- `200`: نجاح الطلب
- `201`: تم إنشاء حركة شحن ناجحة مباشرة
- `401`: لا يوجد توكن أو التوكن غير صالح
- `403`: الحساب غير مصرح له أو غير مفعل
- `404`: الحركة المطلوبة غير موجودة
- `422`: خطأ تحقق أو موفر غير مناسب أو فشل من `moamalat`
- `500`: خطأ داخلي أثناء تأكيد عملية الشحن

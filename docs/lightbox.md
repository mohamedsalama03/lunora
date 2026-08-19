# Flutter Moamalat LightBox Integration

هذا الملف يشرح بالتفصيل كيف تجعل المستخدم عندما يختار `معاملات` من تطبيق الهاتف يظهر له `Moamalat LightBox` عن طريق الربط مع الـ API الموجود في هذا المشروع.

الملف المكمل لهذا الشرح:

- `docs/flutter/orders.md`

## الفكرة الأساسية

التطبيق لا ينشئ بيانات `LightBox` بنفسه، ولا يحسب `SecureHash` داخل الهاتف.

الذي يحدث فعلياً هو:

1. التطبيق يرسل طلب إنشاء الطلب إلى السيرفر.
2. إذا كانت وسيلة الدفع `moamalat` فإن السيرفر ينشئ الطلب أولاً.
3. بعد ذلك يعيد للتطبيق بيانات `checkout` الجاهزة لفتح `LightBox`.
4. التطبيق يفتح `LightBox` داخل `WebView`.
5. عند نجاح الدفع يرسل التطبيق callback payload إلى:
   `POST /api/flutter/orders/moamalat/confirm`
6. عند الإلغاء أو الفشل يرسل التطبيق:
   `POST /api/flutter/orders/moamalat/fail`

بمعنى أوضح:

- السيرفر مسؤول عن تجهيز بيانات `Moamalat`.
- التطبيق مسؤول عن عرض `LightBox`.
- التطبيق لا يحتفظ بأي `secret key`.

## لماذا هذا مهم

لو حاولت فتح `LightBox` من الهاتف بدون الرجوع إلى الـ API فستدخل في مشاكل مثل:

- عدم وجود `SecureHash` الصحيح.
- كشف بيانات حساسة داخل التطبيق.
- عدم تطابق `MerchantReference` مع الطلب الفعلي.
- صعوبة تأكيد الدفع وربطه بالطلب الصحيح.

لذلك الربط الصحيح هو دائماً:

`Flutter -> API create order -> API returns checkout -> Flutter opens LightBox -> Flutter calls confirm/fail`

## الـ Endpoints المستخدمة

هذه هي المسارات الأساسية في تدفق الدفع عبر `معاملات`:

- `GET /api/flutter/orders/lookups`
- `POST /api/flutter/orders`
- `POST /api/flutter/orders/moamalat/confirm`
- `POST /api/flutter/orders/moamalat/fail`
- `GET /api/flutter/orders/{orderNumber}`

## التسلسل الكامل عند ضغط المستخدم على `معاملات`

### 1) عند فتح شاشة الدفع

التطبيق يستدعي:

`GET /api/flutter/orders/lookups`

ثم يقرأ:

- `payment_methods`
- `shipping_cities`
- `wallet.balance`

ومن `payment_methods` يعرف هل `moamalat` متاحة أم لا.

إذا كانت:

```json
{
  "key": "moamalat",
  "enabled": true,
  "requires_online_payment": true
}
```

فيمكن عرض زر أو اختيار `معاملات` للمستخدم.

### 2) المستخدم يختار `معاملات`

هذا لا يفتح `LightBox` مباشرة.

الذي يجب أن يحدث هو إرسال طلب إنشاء الطلب:

`POST /api/flutter/orders`

مع:

```json
{
  "items": [
    {
      "product_id": 9,
      "quantity": 1
    }
  ],
  "payment_method": "moamalat",
  "shipping": {
    "full_name": "Mohamed Ali",
    "phone": "0912345678",
    "address_line1": "Airport Road",
    "city": "Tripoli"
  }
}
```

### 3) السيرفر ينشئ الطلب ويرجع payload الـ LightBox

إذا نجح إنشاء الطلب وتجهيز `Moamalat checkout`، فالسيرفر يرجع `201 Created` مع هذا الشكل:

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

من هذه اللحظة:

- الطلب تم إنشاؤه فعلاً.
- يجب تخزين `order_number`.
- يجب تخزين `merchant_reference`.
- يجب تخزين كامل `checkout`.
- بعد ذلك فقط يفتح التطبيق `LightBox`.

## شرح الحقول الموجودة داخل `checkout`

السيرفر يعيد الحقول التالية داخل `data.payment_action.checkout`:

- `scriptUrl`
  رابط ملف JavaScript الخاص بـ `Moamalat LightBox`.

- `MID`
  رقم التاجر.

- `TID`
  رقم الطرفية.

- `AmountTrxn`
  قيمة العملية بالصيغة التي تطلبها `معاملات`.
  لا تحسبها داخل Flutter.

- `MerchantReference`
  المرجع الذي يربط عملية الدفع بالطلب.
  في هذا المشروع يساوي `order_number`.

- `TrxDateTime`
  وقت إنشاء العملية بصيغة تعتمدها البوابة.

- `SecureHash`
  قيمة حماية تم إنشاؤها من السيرفر.
  لا يجب إنشاؤها على الهاتف.

## نقطة مهمة جداً

عندما يضغط المستخدم على `معاملات`:

- لا تفتح `LightBox` قبل استدعاء `POST /api/flutter/orders`
- لا تنشئ `SecureHash` داخل التطبيق
- لا تعمل hardcode لـ `MID` أو `TID`
- لا تنشئ طلباً جديداً كلما أُعيد فتح شاشة `WebView`

لأن الطلب يكون قد أُنشئ مسبقاً.

إذا فشل فتح `LightBox` بعد إنشاء الطلب، فهذا لا يعني أن الطلب لم يُنشأ.

## كيف يفتح Flutter الـ LightBox

`Moamalat LightBox` يعتمد على JavaScript، لذلك في Flutter أفضل طريقة عملية هي:

1. تستلم `checkout` من الـ API
2. تفتح صفحة `WebView`
3. تحمل داخلها HTML صغير
4. هذا الـ HTML يقوم بتحميل `scriptUrl`
5. ثم يضبط:
   `window.Lightbox.Checkout.configure`
6. ثم يستدعي:
   `window.Lightbox.Checkout.showLightbox()`

## لماذا نستخدم `WebView`

لأن `LightBox` ليس endpoint عادي تفتحه كرابط فقط، بل هو تدفق JavaScript فيه:

- `completeCallback`
- `errorCallback`
- `cancelCallback`

والتطبيق يحتاج التقاط هذه callbacks ثم إرسالها إلى الـ API.

## التدفق المقترح داخل Flutter

### حالة الشاشة

يفضل أن تحفظ هذه القيم أثناء التدفق:

- `selectedPaymentMethod`
- `pendingOrderNumber`
- `pendingMerchantReference`
- `pendingCheckout`
- `isSubmittingOrder`
- `isOpeningLightbox`
- `isConfirmingPayment`

### التسلسل العملي

1. المستخدم يختار `معاملات`.
2. التطبيق يرسل `POST /api/flutter/orders`.
3. إذا عاد `payment_action.type = moamalat_lightbox`:
   افتح صفحة `WebView`.
4. صفحة `WebView` تفتح `LightBox`.
5. إذا وصل `completeCallback`:
   أرسل payload إلى `POST /api/flutter/orders/moamalat/confirm`.
6. إذا وصل `errorCallback`:
   أرسل payload إلى `POST /api/flutter/orders/moamalat/fail`.
7. إذا أغلق المستخدم النافذة:
   أرسل `merchant_reference` إلى `POST /api/flutter/orders/moamalat/fail`.
8. بعد `confirm` أو `fail`:
   حدّث شاشة الطلب باستدعاء `GET /api/flutter/orders/{orderNumber}` عند الحاجة.

## مثال خدمة Flutter

هذا مثال عملي بسيط مبني على `Dio`:

```dart
class OrdersApi {
  OrdersApi(this.dio);

  final Dio dio;

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

  Future<Map<String, dynamic>> confirmMoamalat(
    Map<String, dynamic> callbackPayload,
  ) async {
    final response = await dio.post(
      '/api/flutter/orders/moamalat/confirm',
      data: callbackPayload,
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> failMoamalat({
    required String merchantReference,
    String reason = 'user_cancelled',
    Map<String, dynamic>? callbackPayload,
  }) async {
    final response = await dio.post(
      '/api/flutter/orders/moamalat/fail',
      data: {
        ...?callbackPayload,
        'merchant_reference': merchantReference,
        'reason': reason,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}
```

## مثال تنفيذ عند اختيار `معاملات`

هذا المثال يوضح ماذا يحدث بعد ضغط المستخدم على زر إتمام الطلب:

```dart
Future<void> submitOrderWithMoamalat() async {
  final response = await ordersApi.createOrder(
    items: [
      {
        'product_id': 9,
        'quantity': 1,
      },
    ],
    paymentMethod: 'moamalat',
    shipping: {
      'full_name': 'Mohamed Ali',
      'phone': '0912345678',
      'address_line1': 'Airport Road',
      'city': 'Tripoli',
    },
  );

  final data = Map<String, dynamic>.from(response['data'] as Map);
  final order = Map<String, dynamic>.from(data['order'] as Map);
  final paymentAction = Map<String, dynamic>.from(
    (data['payment_action'] ?? {}) as Map,
  );

  if (paymentAction['type'] != 'moamalat_lightbox') {
    throw Exception('Moamalat LightBox payload was not returned.');
  }

  final merchantReference =
      (paymentAction['merchant_reference'] ?? order['order_number']) as String;

  final checkout = Map<String, dynamic>.from(paymentAction['checkout'] as Map);

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MoamalatLightboxPage(
        ordersApi: ordersApi,
        orderNumber: order['order_number'] as String,
        merchantReference: merchantReference,
        checkout: checkout,
      ),
    ),
  );
}
```

## مثال صفحة `WebView` لفتح الـ LightBox

المثال التالي يوضح الفكرة العملية. الهدف هنا ليس فرض تصميم معين، بل توضيح كيف يتم:

- تحميل `scriptUrl`
- تشغيل `showLightbox()`
- استقبال `completeCallback`
- استقبال `errorCallback`
- استقبال `cancelCallback`
- تمرير النتيجة من JavaScript إلى Flutter

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MoamalatLightboxPage extends StatefulWidget {
  const MoamalatLightboxPage({
    super.key,
    required this.ordersApi,
    required this.orderNumber,
    required this.merchantReference,
    required this.checkout,
  });

  final OrdersApi ordersApi;
  final String orderNumber;
  final String merchantReference;
  final Map<String, dynamic> checkout;

  @override
  State<MoamalatLightboxPage> createState() => _MoamalatLightboxPageState();
}

class _MoamalatLightboxPageState extends State<MoamalatLightboxPage> {
  late final WebViewController _controller;
  bool _handledResult = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MoamalatChannel',
        onMessageReceived: (message) async {
          await _handleJsMessage(message.message);
        },
      )
      ..loadHtmlString(_buildHtml(widget.checkout));
  }

  Future<void> _handleJsMessage(String rawMessage) async {
    if (_handledResult) {
      return;
    }

    final event = Map<String, dynamic>.from(jsonDecode(rawMessage) as Map);
    final type = (event['type'] ?? '') as String;
    final payload = Map<String, dynamic>.from(
      (event['payload'] ?? <String, dynamic>{}) as Map,
    );

    if ((payload['MerchantReference'] as String?) == null ||
        (payload['MerchantReference'] as String).isEmpty) {
      payload['MerchantReference'] = widget.merchantReference;
    }

    try {
      switch (type) {
        case 'complete':
          _handledResult = true;
          await widget.ordersApi.confirmMoamalat(payload);
          await _controller.runJavaScript(
            'window.Lightbox?.Checkout?.closeLightbox?.();',
          );
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;

        case 'error':
          _handledResult = true;
          await widget.ordersApi.failMoamalat(
            merchantReference: widget.merchantReference,
            reason: 'lightbox_error',
            callbackPayload: payload,
          );
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;

        case 'cancel':
          _handledResult = true;
          await widget.ordersApi.failMoamalat(
            merchantReference: widget.merchantReference,
            reason: 'user_cancelled',
          );
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;

        case 'init_error':
          _handledResult = true;
          await widget.ordersApi.failMoamalat(
            merchantReference: widget.merchantReference,
            reason: 'lightbox_init_failed',
            callbackPayload: payload,
          );
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  String _buildHtml(Map<String, dynamic> checkout) {
    final checkoutJson = jsonEncode(checkout);

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Moamalat Checkout</title>
    <style>
      body {
        font-family: sans-serif;
        padding: 24px;
      }
    </style>
  </head>
  <body>
    <p>Opening payment window...</p>
    <script>
      const checkout = $checkoutJson;

      function send(type, payload) {
        MoamalatChannel.postMessage(JSON.stringify({
          type: type,
          payload: payload || {},
        }));
      }

      function loadScript(src) {
        return new Promise((resolve, reject) => {
          const script = document.createElement('script');
          script.src = src;
          script.onload = resolve;
          script.onerror = () => reject(new Error('Unable to load LightBox script.'));
          document.head.appendChild(script);
        });
      }

      async function startLightbox() {
        try {
          await loadScript(checkout.scriptUrl);

          if (!window.Lightbox || !window.Lightbox.Checkout) {
            throw new Error('LightBox object is not available.');
          }

          window.Lightbox.Checkout.configure = {
            MID: checkout.MID,
            TID: checkout.TID,
            AmountTrxn: checkout.AmountTrxn,
            MerchantReference: checkout.MerchantReference,
            TrxDateTime: checkout.TrxDateTime,
            SecureHash: checkout.SecureHash,
            completeCallback: function(callbackPayload) {
              send('complete', callbackPayload || {});
            },
            errorCallback: function(errorPayload) {
              send('error', errorPayload || {});
            },
            cancelCallback: function() {
              send('cancel', {
                MerchantReference: checkout.MerchantReference
              });
            }
          };

          window.Lightbox.Checkout.showLightbox();
        } catch (error) {
          send('init_error', {
            MerchantReference: checkout.MerchantReference,
            message: String(error)
          });
        }
      }

      window.addEventListener('load', startLightbox);
    </script>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moamalat')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

## ماذا ترسل الـ JavaScript callbacks

الهدف من الـ callbacks داخل `LightBox` هو إعادة نتيجة الدفع إلى Flutter:

- `completeCallback`
  يعني أن واجهة `Moamalat` أعادت نتيجة نجاح من جهة المستخدم.
  عندها أرسل كامل الـ payload إلى:
  `POST /api/flutter/orders/moamalat/confirm`

- `errorCallback`
  يعني أن `LightBox` أعادت فشل أو خطأ.
  عندها أرسل:
  `merchant_reference`
  ويفضل أيضاً إرسال payload الخطأ إن وجد إلى:
  `POST /api/flutter/orders/moamalat/fail`

- `cancelCallback`
  يعني أن المستخدم أغلق نافذة الدفع.
  عندها أرسل:
  `merchant_reference`
  وسبب مثل:
  `user_cancelled`

## لماذا نرسل كامل payload في `confirm`

لأن السيرفر يستفيد من الحقول القادمة من `Moamalat` مثل:

- `MerchantReference`
- `ActionCode`
- `Message`
- `SecureHash`
- `SystemReference`
- `NetworkReference`
- `PaidThrough`

كلما أرسلت payload كاملاً كانت عملية التتبع والتحقق أفضل.

## ماذا يحدث في السيرفر عند `confirm`

عندما يرسل التطبيق:

`POST /api/flutter/orders/moamalat/confirm`

فالسيرفر يقوم تقريباً بالآتي:

1. يقرأ `MerchantReference`
2. يبحث عن الطلب الخاص بالمستخدم
3. يتحقق هل الـ payload يمثل نجاحاً أم لا
4. يحاول التحقق من `SecureHash`
5. إذا اعتبر الدفع ناجحاً:
   - يعلّم الطلب `paid`
   - يسجل ملاحظة audit داخلية
   - يحول المعالجة المحاسبية الداخلية إلى `wallet`

لذلك قد ترى بعد نجاح الدفع:

- `payment.method = moamalat`
- لكن `payment.raw_method = wallet`

وهذا متعمد داخل النظام.

## ملاحظة مهمة بخصوص `SecureHash`

السيرفر يحاول التحقق من `SecureHash`، لكن بعض نسخ `LightBox` قد تعيد success callback مع حقول ناقصة.

لهذا السبب:

- إذا كان callback واضحاً أنه نجاح
- لكن التحقق الكامل من `SecureHash` لم يكتمل

فالسيرفر ما زال يقبل تأكيد العملية ويسجل ملاحظة audit.

هذا السلوك موجود عمداً حتى لا يتعطل العميل بسبب نقص بعض الحقول الراجعة من `LightBox`.

## ماذا يحدث في السيرفر عند `fail`

عندما يرسل التطبيق:

`POST /api/flutter/orders/moamalat/fail`

فالسيرفر لا يحول الحالة دائماً إلى `failed` مباشرة.

في كثير من الحالات سيبقيها:

`payment.status = pending`

والسبب أن `errorCallback` أو `cancelCallback` القادم من الواجهة ليس دائماً هو الحكم النهائي، وقد تصل لاحقاً إشعارات بوابة الدفع بالحالة النهائية.

لذلك بعد `fail` يفضل أن يفعل التطبيق واحداً من التالي:

1. يعرض رسالة انتظار للحالة النهائية.
2. يجلب تفاصيل الطلب بعد ثوانٍ قليلة.
3. يحدث شاشة الطلبات عندما يعود المستخدم.

## مثال طلب `confirm`

```json
{
  "MerchantReference": "ORD-MOAM1234",
  "ActionCode": "000",
  "Message": "Approved",
  "SecureHash": "ABCDEF1234567890"
}
```

## مثال طلب `fail`

```json
{
  "merchant_reference": "ORD-MOAM1234",
  "reason": "user_cancelled"
}
```

## ماذا تفعل إذا أغلق المستخدم الصفحة بالكامل

إذا أغلق المستخدم شاشة `WebView` أو خرج من التطبيق قبل وصول callback:

1. إذا كنت تعرف `merchant_reference` فأرسل `fail` بشكل best effort.
2. بعد ذلك عند رجوع المستخدم افتح:
   `GET /api/flutter/orders/{orderNumber}`
3. اعرض الحالة الحالية للطلب.

## ماذا تفعل إذا فشل تجهيز الـ LightBox بعد إنشاء الطلب

قد يرجع `POST /api/flutter/orders` هذه الاستجابة:

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

هذا يعني:

- الطلب تم إنشاؤه
- لكن `LightBox` لم يجهز
- لذلك لا ترسل `POST /api/flutter/orders` مرة ثانية تلقائياً

بدلاً من ذلك:

1. اعرض رسالة واضحة للمستخدم.
2. احتفظ بـ `order_number`.
3. اسمح له بمراجعة الطلب أو إعادة المحاولة من تدفق جديد إذا كان ذلك مناسباً في التطبيق.

## أفضل ممارسات مهمة

- اعتمد على `payment_methods` القادمة من `lookups` ولا تعمل hardcode.
- خزّن `merchant_reference` فور رجوع `create order`.
- إذا كان callback لا يحتوي `MerchantReference` فاملأه من القيمة المخزنة.
- أرسل كل payload النجاح كما هو إلى `confirm`.
- أرسل `fail` حتى في حالات الإلغاء أو فشل تحميل السكربت.
- بعد `confirm` أو `fail` حدّث شاشة الطلب.
- لا تضع `secret key` داخل التطبيق.
- لا تحسب `SecureHash` داخل الهاتف.

## Checklist سريعة للتنفيذ

قبل التنفيذ تأكد أن التطبيق يقوم فعلاً بهذه الخطوات:

1. يجلب `lookups`
2. يعرض `معاملات` فقط إذا كانت `enabled = true`
3. يرسل `payment_method = moamalat`
4. يتحقق من وجود `payment_action.type = moamalat_lightbox`
5. يفتح `WebView`
6. يلتقط `completeCallback`
7. يرسل `confirm`
8. يلتقط `errorCallback` و `cancelCallback`
9. يرسل `fail`
10. يحدث حالة الطلب بعد نهاية التدفق

## الخلاصة

إذا أردت أن يظهر `LightBox` عندما يضغط المستخدم على `معاملات` من الهاتف، فالتنفيذ الصحيح ليس:

`فتح رابط معاملات مباشرة`

بل هو:

`إنشاء الطلب عبر API -> استلام checkout payload -> فتح LightBox داخل WebView -> إرسال confirm أو fail إلى API`

وهذا هو التدفق الذي يدعمه المشروع حالياً بالفعل.

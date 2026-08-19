# ربط ميزة التحويل البنكي داخل تطبيق Flutter

هذا الملف يشرح **كيف يعمل الـ API الحالي** لميزة شحن المحفظة عن طريق **التحويل البنكي** داخل تطبيق Flutter، وما الذي يحتاجه التطبيق فعليًا حتى يربط الميزة بشكل صحيح.

> مهم:
> الـ API الحالي يدعم:
> 1. جلب وسائل شحن المحفظة.
> 2. إرسال طلب تحويل بنكي مع إيصال.
> 3. متابعة حالة الطلب من خلال سجل المحفظة.
>
> لكنه **لا يرسل بيانات الحساب البنكي** مثل:
> `bank_name`, `bank_account_holder`, `bank_account_number`, `bank_iban`
>
> لذلك إذا كان التطبيق يحتاج عرض هذه البيانات للمستخدم، فهناك حاليًا خياران:
> 1. حفظها داخل التطبيق من إعدادات ثابتة.
> 2. إضافة endpoint أو حقول جديدة في API لاحقًا.

---

## 1. الفكرة العامة

تدفق التحويل البنكي داخل التطبيق ليس شحنًا مباشرًا.

المنطق الحالي يعمل كالتالي:

1. المستخدم يسجل الدخول ويحصل على `Bearer token`.
2. التطبيق يطلب بيانات المحفظة من `/api/flutter/wallet`.
3. إذا ظهر المزود `bank_transfer` وبـ `mode = bank_transfer_receipt` فهذا يعني أن التطبيق يجب أن:
   - يجمع `amount`
   - يجمع `reference` إن وجد
   - يجمع `notes` إن وجدت
   - يطلب من المستخدم رفع إيصال التحويل
4. التطبيق يرسل الطلب إلى `/api/flutter/wallet/top-up` بصيغة `multipart/form-data`.
5. السيرفر ينشئ عملية محفظة بحالة `pending` ولا يضيف الرصيد مباشرة.
6. المدير يراجع الطلب من لوحة التحكم:
   - إذا وافق: تصبح العملية `completed` ويتم إضافة الرصيد.
   - إذا رفض: تصبح العملية `failed` ويتم حفظ سبب الرفض.
7. التطبيق يتابع الحالة من خلال:
   - `/api/flutter/wallet`
   - أو `/api/flutter/wallet/transactions`

---

## 2. المصادقة المطلوبة

كل endpoints الخاصة بالمحفظة داخل Flutter تتطلب:

- تسجيل دخول عميل فقط
- توكن Sanctum من نوع `Bearer`

### Endpoint تسجيل الدخول

`POST /api/flutter/auth/login`

### Request

```json
{
  "email": "customer@example.com",
  "password": "secret123",
  "device_name": "flutter-app"
}
```

### Response

```json
{
  "message": "Authenticated successfully.",
  "token_type": "Bearer",
  "access_token": "1|long-token-here",
  "abilities": [
    "customer:access"
  ],
  "user": {
    "id": 5,
    "name": "Ahmed",
    "email": "customer@example.com",
    "phone": "0910000000",
    "role": "customer",
    "is_active": true,
    "wallet_balance": 50,
    "avatar_url": "https://...",
    "created_at": "2026-04-12T10:00:00.000000Z"
  }
}
```

بعدها يجب إرسال الهيدر التالي في كل طلب:

```http
Authorization: Bearer YOUR_ACCESS_TOKEN
Accept: application/json
```

---

## 3. اكتشاف توفر التحويل البنكي

### Endpoint

`GET /api/flutter/wallet`

### الهدف

هذا endpoint يعيد:

- رصيد المحفظة
- العملة
- هل الدفع بالمحفظة مفعّل
- وسائل شحن المحفظة المتاحة
- آخر العمليات

### مثال Response

```json
{
  "data": {
    "balance": 50,
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
        "mode": "bank_transfer_receipt"
      }
    ],
    "recent_transactions": []
  }
}
```

### كيف يقرأ التطبيق هذه النتيجة

عندما يجد التطبيق:

```json
{
  "key": "bank_transfer",
  "mode": "bank_transfer_receipt"
}
```

فهذا يعني:

- يجب إظهار خيار "تحويل بنكي"
- يجب طلب رفع إيصال
- يجب الإرسال إلى endpoint الشحن العادي `/wallet/top-up`
- لكن بصيغة `multipart/form-data`

---

## 4. إرسال طلب التحويل البنكي

### Endpoint

`POST /api/flutter/wallet/top-up`

### شرط مهم

عندما يكون:

```text
provider = bank_transfer
```

يصبح الحقل `receipt` **إجباريًا**.

### Content-Type

```http
multipart/form-data
```

### الحقول المطلوبة

| الحقل | النوع | مطلوب | الوصف |
|---|---|---:|---|
| `amount` | number | نعم | مبلغ الشحن |
| `provider` | string | نعم | يجب أن يكون `bank_transfer` |
| `reference` | string | لا | رقم مرجعي يكتبه المستخدم إذا أراد |
| `notes` | string | لا | ملاحظات المستخدم |
| `receipt` | file | نعم | صورة أو PDF لإثبات التحويل |

### أنواع الملفات المقبولة

- `jpg`
- `jpeg`
- `png`
- `webp`
- `pdf`

### الحد الأقصى للحجم

- `5 MB` تقريبًا

### مثال `curl`

```bash
curl --request POST "https://your-domain.com/api/flutter/wallet/top-up" \
  --header "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  --header "Accept: application/json" \
  --form "amount=120" \
  --form "provider=bank_transfer" \
  --form "reference=TRX-7788" \
  --form "notes=تم التحويل من تطبيق المصرف" \
  --form "receipt=@/path/to/receipt.pdf"
```

### مثال Response عند النجاح

```json
{
  "message": "Bank transfer request submitted successfully.",
  "data": {
    "balance": 50,
    "transaction": {
      "id": 18,
      "transaction_number": "WTX-20260412110000-AB12CD",
      "type": "deposit",
      "type_label": "إيداع",
      "amount": 120,
      "balance_before": 50,
      "balance_after": 50,
      "status": "pending",
      "status_label": "قيد الانتظار",
      "provider": "bank_transfer",
      "provider_label": "تحويل بنكي",
      "reference": "TRX-7788",
      "receipt_uploaded": true,
      "receipt_url": "https://your-domain.com/storage/wallet-receipts/abc.pdf",
      "notes": "تم التحويل من تطبيق المصرف",
      "created_at": "2026-04-12T11:00:00.000000Z",
      "updated_at": "2026-04-12T11:00:00.000000Z"
    }
  }
}
```

### ملاحظات مهمة جدًا

- `balance_after` يساوي الرصيد الحالي نفسه وقت الطلب.
- هذا طبيعي لأن الشحن **لم يُعتمد بعد**.
- الحالة تكون `pending`.
- لا يجب على التطبيق اعتبار العملية ناجحة ماليًا فورًا.

---

## 5. ماذا يفعل التطبيق بعد الإرسال؟

بعد نجاح الإرسال:

1. اعرض رسالة نجاح مثل:
   `تم إرسال طلب التحويل البنكي بنجاح وهو الآن بانتظار المراجعة`
2. أضف العملية مباشرة إلى قائمة العمليات من الاستجابة الحالية.
3. اعرض حالة العملية `pending`.
4. لا تقم بزيادة الرصيد محليًا.
5. نفذ تحديثًا دوريًا أو تحديثًا عند فتح صفحة المحفظة من:
   - `GET /api/flutter/wallet`
   - أو `GET /api/flutter/wallet/transactions`

---

## 6. متابعة حالة الطلب

### Endpoint

`GET /api/flutter/wallet/transactions`

### فلاتر اختيارية

| الحقل | النوع | مثال |
|---|---|---|
| `type` | string | `deposit` |
| `status` | string | `pending` / `completed` / `failed` |
| `provider` | string | `bank_transfer` |
| `per_page` | integer | `20` |

### مثال

```http
GET /api/flutter/wallet/transactions?provider=bank_transfer&status=pending&per_page=20
```

### مثال Response

```json
{
  "data": [
    {
      "id": 18,
      "transaction_number": "WTX-20260412110000-AB12CD",
      "type": "deposit",
      "type_label": "إيداع",
      "amount": 120,
      "balance_before": 50,
      "balance_after": 50,
      "status": "pending",
      "status_label": "قيد الانتظار",
      "provider": "bank_transfer",
      "provider_label": "تحويل بنكي",
      "reference": "TRX-7788",
      "receipt_uploaded": true,
      "receipt_url": "https://your-domain.com/storage/wallet-receipts/abc.pdf",
      "notes": "تم التحويل من تطبيق المصرف",
      "created_at": "2026-04-12T11:00:00.000000Z",
      "updated_at": "2026-04-12T11:00:00.000000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 20,
    "total": 1,
    "has_more_pages": false
  }
}
```

---

## 7. كيف يعرف التطبيق أن المدير وافق أو رفض؟

بعد مراجعة المدير، ستتغير العملية إلى واحدة من الحالتين:

### 1. `completed`

هذا يعني:

- تم اعتماد الحوالة
- تم شحن الرصيد
- يجب على التطبيق تحديث الرصيد من API

### 2. `failed`

هذا يعني:

- تم رفض الحوالة
- لا يتم شحن الرصيد
- يجب على التطبيق إظهار سبب الرفض للمستخدم

---

## 8. سبب الرفض في الـ API

حاليًا، عند رفض الحوالة من لوحة المدير، يتم حفظ سبب الرفض داخل `notes` بصيغة منظمة تحتوي على marker داخلي:

```text
[BANK_TRANSFER_REJECTION_REASON]: السبب هنا
```

### مهم جدًا

الـ API الحالي **لا يعيد حقلًا منفصلًا** باسم مثل:

- `rejection_reason`

بل يعيد السبب ضمن `notes` فقط.

### هذا يعني أن تطبيق Flutter أمامه الآن خياران

#### الخيار الحالي بدون تعديل backend

يقوم التطبيق بقراءة `notes` واستخراج السبب من السطر الذي يبدأ بـ:

```text
[BANK_TRANSFER_REJECTION_REASON]:
```

#### الخيار الأفضل مستقبلًا

إضافة حقل صريح في الـ API مثل:

```json
{
  "rejection_reason": "الإيصال غير واضح"
}
```

لكن هذا **غير موجود حاليًا**.

### مثال `notes` بعد الرفض

```text
تم التحويل من تطبيق المصرف
[تعقيب إداري]: تم رفض طلب الحوالة البنكية.
[BANK_TRANSFER_REJECTION_REASON]: الإيصال غير واضح
```

### دالة Parsing مقترحة داخل Flutter

```dart
String? extractBankTransferRejectionReason(String? notes) {
  if (notes == null || notes.trim().isEmpty) return null;

  const marker = '[BANK_TRANSFER_REJECTION_REASON]:';
  final lines = notes.split(RegExp(r'\r\n|\r|\n'));

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.startsWith(marker)) {
      final reason = line.substring(marker.length).trim();
      return reason.isEmpty ? null : reason;
    }
  }

  return null;
}
```

---

## 9. التوصية العملية داخل التطبيق

### شاشة شحن المحفظة

يفضل أن يعمل التطبيق بهذا الترتيب:

1. اطلب `/api/flutter/wallet`
2. افحص `top_up_providers`
3. إذا وجدت `bank_transfer`:
   - اعرض بطاقة "تحويل بنكي"
   - اعرض بيانات الحساب البنكي من مصدر آخر
   - اعرض زر رفع الإيصال
4. عند الإرسال:
   - استخدم `multipart/form-data`
   - لا ترسل JSON عادي

### شاشة سجل العمليات

يفضل أن يعرض التطبيق:

- رقم العملية
- مبلغ العملية
- تاريخ العملية
- الحالة
- الإيصال إن لزم
- سبب الرفض إذا كانت:
  - `provider = bank_transfer`
  - `status = failed`

### نصوص مقترحة للحالات

| الحالة | النص المقترح |
|---|---|
| `pending` | طلب التحويل قيد المراجعة |
| `completed` | تم اعتماد الحوالة وإضافة الرصيد |
| `failed` | تم رفض طلب التحويل |

---

## 10. الأخطاء المتوقعة

### 422 عند نقص الإيصال

إذا أرسل التطبيق:

- `provider = bank_transfer`
- بدون `receipt`

فسيعود خطأ تحقق `422`.

### 422 عند إرسال `moamalat` إلى endpoint الخطأ

إذا استخدم التطبيق:

```text
provider = moamalat
```

داخل:

```text
POST /api/flutter/wallet/top-up
```

فسيعود:

```json
{
  "message": "Use the Moamalat prepare endpoint for this provider."
}
```

لأن `moamalat` له تدفق مختلف.

---

## 11. مثال خدمة Flutter مقترحة

```dart
class BankTransferTopUpRequest {
  final double amount;
  final String? reference;
  final String? notes;
  final String receiptPath;

  BankTransferTopUpRequest({
    required this.amount,
    this.reference,
    this.notes,
    required this.receiptPath,
  });
}
```

```dart
Future<Map<String, dynamic>> submitBankTransferTopUp(
  Dio dio,
  BankTransferTopUpRequest request,
) async {
  final formData = FormData.fromMap({
    'amount': request.amount,
    'provider': 'bank_transfer',
    if (request.reference != null && request.reference!.trim().isNotEmpty)
      'reference': request.reference,
    if (request.notes != null && request.notes!.trim().isNotEmpty)
      'notes': request.notes,
    'receipt': await MultipartFile.fromFile(request.receiptPath),
  });

  final response = await dio.post(
    '/api/flutter/wallet/top-up',
    data: formData,
    options: Options(
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  return response.data as Map<String, dynamic>;
}
```

---

## 12. ملخص التنفيذ داخل Flutter

إذا أردنا ربط الميزة اليوم بالـ API الحالي، فالتطبيق يجب أن يعمل هكذا:

1. تسجيل دخول العميل.
2. جلب `/api/flutter/wallet`.
3. التأكد من وجود:
   - `key = bank_transfer`
   - `mode = bank_transfer_receipt`
4. عرض واجهة تحويل بنكي للمستخدم.
5. جمع المبلغ + الإيصال.
6. إرسال `POST /api/flutter/wallet/top-up` بصيغة `multipart/form-data`.
7. اعتبار العملية `pending`.
8. تحديث السجل من `/api/flutter/wallet/transactions`.
9. إذا أصبحت `completed`:
   - حدث الرصيد
10. إذا أصبحت `failed`:
   - اقرأ `notes`
   - استخرج `[BANK_TRANSFER_REJECTION_REASON]:`
   - اعرض السبب للمستخدم

---

## 13. ملاحظة معمارية مهمة

حاليًا يوجد **نقصان وظيفيان** يجب الانتباه لهما عند الربط:

### 1. بيانات الحساب البنكي غير مرسلة للـ app

الـ API لا يعيد:

- اسم المصرف
- اسم صاحب الحساب
- رقم الحساب
- IBAN

### 2. سبب الرفض غير مرسل كحقل مستقل

الـ API يعيده داخل `notes` فقط.

### التوصية الأفضل لاحقًا

يفضل إضافة endpoint أو توسعة `GET /api/flutter/wallet` ليعيد:

```json
{
  "bank_transfer_details": {
    "bank_name": "شمال أفريقيا",
    "bank_account_holder": "شركة تصاميم",
    "bank_account_number": "00901118418017",
    "bank_iban": "LY47007009009011184181017"
  }
}
```

وأيضًا داخل transaction:

```json
{
  "rejection_reason": "الإيصال غير واضح"
}
```

لكن إلى أن يتم ذلك، فإن الشرح أعلاه هو **التدفق الصحيح والدقيق للـ API الحالي**.

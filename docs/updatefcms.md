# نظام FCM العالمي والشخصي لتطبيق Flutter

هذا الملف هو المرجع المعتمد لتدفق الإشعارات في التطبيق بعد تعديل النظام ليعمل بقناتين واضحتين:

1. **إشعارات عامة Global** تصل لكل جهاز عليه التطبيق، سواء كان المستخدم مسجل دخول أو ضيف.
2. **إشعارات شخصية User-specific** تصل فقط لأجهزة المستخدم المسجل دخوله.

الفكرة المهمة: عند تسجيل الخروج نحذف ربط الـ FCM token بالمستخدم من الـ backend، لكن لا نحذف token من Firebase ولا نلغي الاشتراك في قناة الإشعارات العامة.

---

## القنوات المعتمدة

### 1. قناة عامة عبر FCM Topic

كل تثبيت للتطبيق يشترك في topic اسمه:

```text
global
```

هذه القناة مخصصة للإعلانات العامة مثل:

- عروض عامة
- تنبيهات صيانة
- رسائل إدارية لكل مستخدمي التطبيق
- تحديثات لا تحتوي بيانات خاصة بمستخدم معين

يجب أن يرسل الـ backend الإشعار العام إلى:

```json
{
  "message": {
    "topic": "global",
    "notification": {
      "title": "عنوان الإشعار",
      "body": "نص الإشعار"
    },
    "data": {
      "audience": "global",
      "type": "announcement",
      "screen": "notifications",
      "notification_id": "announcement-2026-04-26-001"
    }
  }
}
```

### 2. قناة شخصية عبر device token

عند تسجيل الدخول، التطبيق يرسل FCM token إلى الـ backend ويربطه بالمستخدم الحالي.

هذه القناة مخصصة للإشعارات الخاصة مثل:

- تحديث حالة طلب
- حركة محفظة
- رد خاص بحساب المستخدم

عند تسجيل الخروج، التطبيق يحذف هذا الربط فقط حتى لا تصل إشعارات المستخدم السابق لنفس الجهاز.

---

## ما الذي ينفذه Flutter الآن؟

الملفات الأساسية:

- `lib/core/notifications/push_notification_service.dart`
- `lib/features/notifications/repositories/notifications_api_repository.dart`
- `lib/features/notifications/repositories/notifications_storage.dart`
- `lib/core/constants/api_constants.dart`

التدفق الحالي:

1. عند تهيئة خدمة الإشعارات، التطبيق يضبط صندوق إشعارات الضيف `guest_global`.
2. إذا كانت صلاحية الإشعارات مفعلة، يشترك التطبيق في topic العام `global`.
3. عند تسجيل الدخول، يتحول صندوق الإشعارات المحلي إلى scope المستخدم، ثم يرسل token إلى backend.
4. عند تسجيل الخروج، يحذف التطبيق token من جدول أجهزة المستخدم فقط، ثم يرجع إلى صندوق `guest_global`.
5. عند تغيير FCM token، يعيد التطبيق الاشتراك في `global`، ولو المستخدم مسجل دخول يعيد تسجيل token الجديد في backend.

---

## Endpoints المطلوبة من Laravel

التطبيق الحالي يستخدم هذه المسارات:

```text
POST   /api/flutter/devices/token
DELETE /api/flutter/devices/token
POST   /api/flutter/auth/logout
```

المسارات معرفة في:

```text
lib/core/constants/api_constants.dart
```

### `POST /api/flutter/devices/token`

يربط FCM token بالمستخدم المسجل دخوله.

Request:

```json
{
  "token": "FCM_DEVICE_TOKEN",
  "platform": "android",
  "device_name": "Samsung S24",
  "app_version": "1.0.0"
}
```

قواعد backend المطلوبة:

- `token` مطلوب.
- `platform` واحد من `android`, `ios`, `web`.
- استخدم `updateOrCreate(['token' => $token], [...])`.
- إذا كان token مربوطًا بمستخدم سابق، انقله للمستخدم الحالي.
- اجعل العملية idempotent حتى لا يسبب تكرار الطلب مشكلة.

### `DELETE /api/flutter/devices/token`

يحذف ربط FCM token بالمستخدم الحالي فقط.

Request:

```json
{
  "token": "FCM_DEVICE_TOKEN"
}
```

قواعد backend المطلوبة:

- احذف السجل الذي يطابق `user_id` الحالي و`token`.
- لا تحاول إلغاء topic العام من الـ backend.
- لا تعتبر فشل الحذف سببًا لمنع logout محليًا.

### `POST /api/flutter/auth/logout`

ينهي جلسة المستخدم.

التطبيق الحالي يحذف device token قبل هذا الطلب، لذلك لا يعتمد logout على وجود `fcm_token` داخل body.

---

## قواعد الإرسال من Backend

### إرسال إشعار عام

أرسل إلى topic:

```text
global
```

ويجب ألا يحتوي الإشعار العام أي بيانات خاصة بمستخدم محدد.

يفضل دائمًا إضافة:

```json
{
  "audience": "global",
  "type": "announcement",
  "screen": "notifications",
  "notification_id": "unique-global-id"
}
```

### إرسال إشعار شخصي

1. اجلب tokens الخاصة بالمستخدم من جدول `device_tokens`.
2. أرسل لكل token نشط.
3. إذا رجع FCM بخطأ `UNREGISTERED` أو token غير صالح، احذف token من قاعدة البيانات.

مثال data:

```json
{
  "audience": "user",
  "type": "order_update",
  "screen": "order_details",
  "order_number": "ORD-1001",
  "notification_id": "order-ORD-1001-status-paid"
}
```

مهم: في FCM HTTP v1 كل قيم `data` يجب أن تكون strings.

---

## سلوك تسجيل الدخول والخروج

### عند تسجيل الدخول

```text
1. يحصل التطبيق على access_token.
2. يضبط صندوق الإشعارات المحلي على user id.
3. يطلب/يفحص صلاحية الإشعارات.
4. يشترك في topic العام global.
5. يرسل FCM token إلى POST /api/flutter/devices/token.
```

### عند تسجيل الخروج

```text
1. يحصل التطبيق على FCM token الحالي.
2. يرسل DELETE /api/flutter/devices/token لحذف الربط الشخصي.
3. ينفذ POST /api/flutter/auth/logout.
4. يمسح بيانات الجلسة محليًا.
5. يرجع صندوق الإشعارات المحلي إلى guest_global.
6. يبقى الجهاز مشتركًا في topic العام global.
```

لا تستخدم:

```dart
FirebaseMessaging.instance.deleteToken();
FirebaseMessaging.instance.unsubscribeFromTopic('global');
```

إلا في حالة reset كامل للتطبيق أو خيار صريح لإيقاف كل الإشعارات.

---

## التخزين المحلي داخل التطبيق

التطبيق يستخدم scope منفصل لكل حالة:

```text
guest_global        إشعارات عامة للضيف
{user_id}           إشعارات المستخدم بعد تسجيل الدخول
```

هذا يمنع اختلاط إشعارات مستخدم سابق مع مستخدم جديد على نفس الجهاز.

إذا وصل إشعار أثناء الخلفية ولم يكن هناك مستخدم نشط، يتم حفظه في `guest_global`.

---

## Payload موصى به

لكل إشعار، أرسل `notification_id` ثابتًا وفريدًا. هذا يساعد التطبيق على منع تكرار نفس الإشعار في inbox.

```json
{
  "notification": {
    "title": "تم تحديث طلبك",
    "body": "طلبك أصبح قيد التجهيز"
  },
  "data": {
    "audience": "user",
    "type": "order_update",
    "screen": "order_details",
    "order_number": "ORD-1001",
    "notification_id": "order-ORD-1001-preparing"
  }
}
```

القيم المدعومة في `screen` حاليًا:

```text
notifications
order_details
orders
wallet
```

---

## قائمة اختبار سريعة

1. افتح التطبيق كضيف وفعّل الإشعارات، ثم أرسل إشعارًا إلى topic `global`.
2. سجل الدخول، وتأكد أن `POST /api/flutter/devices/token` تم بنجاح.
3. أرسل إشعارًا شخصيًا للمستخدم، وتأكد أنه يظهر ويفتح الشاشة الصحيحة.
4. سجل الخروج، وتأكد أن `DELETE /api/flutter/devices/token` تم قبل logout.
5. بعد الخروج، أرسل إشعارًا شخصيًا للمستخدم السابق، ويجب ألا يصل للجهاز.
6. بعد الخروج، أرسل إشعارًا عامًا إلى `global`، ويجب أن يصل للجهاز.
7. سجل الدخول بحساب آخر على نفس الجهاز، وتأكد أن token انتقل للحساب الجديد.

---

## ملاحظات أمان مهمة

- لا ترسل بيانات حساسة عبر topic `global`.
- أي إشعار يحتوي بيانات مستخدم يجب أن يرسل عبر tokens الخاصة بهذا المستخدم فقط.
- حذف token عند logout يعني حذف الربط الشخصي، وليس تعطيل الإشعارات العامة.
- لا تعتمد على `fcm_token` داخل login/logout إذا كان التطبيق يسجل token عبر `/devices/token` بعد المصادقة.
- اجعل backend يتحمل تكرار تسجيل نفس token وتغيير مالكه بين المستخدمين.

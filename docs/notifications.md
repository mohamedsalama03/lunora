# Firebase Notifications

هذا المشروع مربوط مع Laravel backend على أساس `FCM + local notifications + local inbox`.

## البنية الحالية

- `lib/core/notifications/push_notification_service.dart`
  يدير التهيئة، الصلاحيات، تسجيل `FCM token`، استقبال الإشعارات، وعمل التنقل داخل التطبيق.
- `lib/features/notifications/providers/notifications_provider.dart`
  يحتفظ بحالة الإشعارات غير المقروءة وحالة الربط مع Firebase.
- `lib/features/notifications/repositories/notifications_api_repository.dart`
  يربط التطبيق مع Laravel endpoints الخاصة بتسجيل الجهاز والإشعار الاختباري.
- `lib/features/notifications/repositories/notifications_storage.dart`
  يخزن صندوق الإشعارات محليًا لكل مستخدم على حدة باستخدام `SharedPreferences`.
- `lib/features/notifications/screens/notifications_screen.dart`
  شاشة العرض الفعلية للإشعارات مع حالة التفعيل وأزرار المزامنة.

## ما الذي تم ربطه

1. تهيئة `firebase_messaging` و `flutter_local_notifications`.
2. استقبال الإشعارات في الحالات:
   - `foreground`
   - `background`
   - `terminated`
3. تخزين كل إشعار محليًا في inbox داخل التطبيق.
4. إظهار Local Notification عند وصول إشعار أثناء فتح التطبيق.
5. تسجيل `FCM token` في Laravel بعد تسجيل الدخول.
6. حذف `FCM token` من Laravel عند تسجيل الخروج.
7. تحديث التوكن تلقائيًا عبر `onTokenRefresh`.
8. دعم التنقل من الإشعار إلى:
   - شاشة الإشعارات
   - تفاصيل الطلب
   - الطلبات
   - المحفظة

## endpoints المطلوبة من Laravel

التطبيق يفترض وجود هذه المسارات:

- `POST /api/flutter/devices/token`
- `DELETE /api/flutter/devices/token`
- `POST /api/flutter/notifications/test`

المسارات معرفة في:

- `lib/core/constants/api_constants.dart`

## تدفق العمل

1. يبدأ التطبيق ويهيئ خدمة الإشعارات داخل `main.dart`.
2. بعد نجاح تسجيل الدخول أو استعادة الجلسة:
   - يطلب الإذن
   - يحصل على `FCM token`
   - يرسل التوكن إلى Laravel
3. عند وصول إشعار:
   - يُخزن في inbox المحلي
   - إذا كان التطبيق مفتوحًا يُعرض Local Notification
4. عند الضغط على الإشعار:
   - يتم تعليم الإشعار كمقروء
   - يتم تنفيذ navigation حسب `data.screen`

## شكل payload المتوقع

الربط الحالي يعتمد أساسًا على `data payload`.

مثال:

```json
{
  "title": "تم تحديث حالة طلبك",
  "body": "طلبك ORD-123 أصبح قيد الشحن",
  "type": "order_status_changed",
  "order_number": "ORD-123",
  "screen": "order_details"
}
```

القيم المدعومة حاليًا في `screen`:

- `notifications`
- `order_details`
- `orders`
- `wallet`

## إعداد Firebase داخل Flutter

يوجد مساران مدعومان:

1. الإعداد الافتراضي عبر ملفات Firebase الرسمية:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

2. الإعداد عبر `--dart-define` runtime options
   الملف المسؤول:
   - `lib/core/notifications/firebase_runtime_options.dart`

### متغيرات Android

- `FIREBASE_ANDROID_API_KEY`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_ANDROID_MESSAGING_SENDER_ID`
- `FIREBASE_ANDROID_PROJECT_ID`
- `FIREBASE_ANDROID_STORAGE_BUCKET`

### متغيرات iOS

- `FIREBASE_IOS_API_KEY`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_IOS_MESSAGING_SENDER_ID`
- `FIREBASE_IOS_PROJECT_ID`
- `FIREBASE_IOS_STORAGE_BUCKET`
- `FIREBASE_IOS_BUNDLE_ID`

## مثال تشغيل محلي

```bash
flutter run \
  --dart-define=FIREBASE_ANDROID_API_KEY=xxx \
  --dart-define=FIREBASE_ANDROID_APP_ID=xxx \
  --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=xxx \
  --dart-define=FIREBASE_ANDROID_PROJECT_ID=xxx
```

إذا لم تكن إعدادات Firebase موجودة فلن ينهار التطبيق. سيتم تعطيل الإشعارات فقط مع رسالة توضح السبب داخل شاشة الإشعارات.

## Android

تم تنفيذ الآتي:

- `POST_NOTIFICATIONS`
- `VIBRATE`
- قناة إشعارات عالية الأهمية
- أيقونة Notification مستقلة:
  - `android/app/src/main/res/drawable/ic_notification.xml`
- إبقاء أيقونة الإشعارات من الحذف أثناء build:
  - `android/app/src/main/res/raw/keep.xml`

## iOS

تم تنفيذ داخل المشروع:

- `UNUserNotificationCenter.current().delegate = self`
- `registerForRemoteNotifications()`
- `UIBackgroundModes -> remote-notification`

ويبقى مطلوبًا على جهاز Mac / Xcode:

1. تفعيل `Push Notifications` capability
2. تفعيل `Background Modes > Remote notifications`
3. ربط APNs مع Firebase project
4. استخدام provisioning profile يحتوي صلاحية push

## متى يُفتح إعداد النظام

إذا رفض المستخدم الإشعارات من النظام، ستظهر داخل شاشة الإشعارات زر:

- `فتح الإعدادات`

وعند العودة للتطبيق ستُعاد مزامنة الحالة تلقائيًا.

## اختبار التكامل

1. سجّل الدخول داخل التطبيق.
2. افتح شاشة الإشعارات وتأكد أن الحالة أصبحت `تمت مزامنة الجهاز مع الإشعارات`.
3. في debug mode استخدم زر الإشعار الاختباري.
4. تحقق من:
   - ظهور Local Notification في foreground
   - وصول الإشعار في inbox داخل التطبيق
   - فتح الشاشة الصحيحة عند الضغط

## ملاحظات تشغيل

- inbox محفوظ لكل مستخدم بشكل منفصل لتجنب تسرّب إشعارات مستخدم إلى آخر.
- تسجيل التوكن لا يتم إلا بعد وجود جلسة authenticated.
- حذف التوكن يتم قبل `logout`.
- الإشعار في foreground لا يعتمد على notification tray فقط، بل يُعرض عبر local notification لضمان تجربة ثابتة.

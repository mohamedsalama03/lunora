# تقرير مراجعة الكود والاختبارات

تاريخ المراجعة: 2026-07-05

## 1. ملخص المشروع

- **النوع والتقنية:** تطبيق متجر إلكتروني Flutter متعدد المنصات، باستخدام Flutter 3.41.2 وDart 3.11.0.
- **المعمارية:** تنظيم Feature-first مع فصل نسبي إلى Models وRepositories وProviders وScreens. لا توجد طبقة Domain مستقلة.
- **إدارة الحالة وحقن الاعتماديات:** `provider` و`ChangeNotifier`، والاعتماديات تُنشأ وتُحقن في `main.dart`.
- **التنقل:** `Navigator` و`MaterialPageRoute` مع `navigatorKey` مركزي، من دون Router declarative.
- **الشبكة:** Dio مع HTTPS، مهلات اتصال/استقبال/إرسال قدرها 15 ثانية، وInterceptor لإضافة Bearer token وتحديث الجلسة عند 401 عبر single-flight.
- **التخزين المحلي:** `flutter_secure_storage` لسجل ذري واحد يحتوي زوج Access/Refresh وتواريخ الانتهاء، و`shared_preferences` لبيانات المستخدم غير السرية وonboarding والبحث والمفضلة والإشعارات.
- **الخدمات الخارجية:** Firebase Messaging وLocal Notifications وGoogle Maps وMoamalat عبر WebView/Backend callbacks.
- **حالة الاختبارات قبل العمل:** ملف اختبار واحد، اختبار واحد ناجح، ولا توجد Integration Tests.
- **نطاق المستودع:** تطبيق العميل فقط؛ لا يوجد Backend يمكن من خلاله تدقيق التحقق النهائي من الأسعار والخصومات والدفع وWebhook والصلاحيات.

## 2. الأوامر التي تم تشغيلها

| الأمر | النتيجة |
|---|---|
| `flutter --version` و`dart --version` | Flutter 3.41.2، Dart 3.11.0 |
| `flutter doctor -v` | Android وChrome والأجهزة سليمة؛ Visual Studio غير مثبت، لذلك بناء Windows غير متاح |
| `flutter pub get` | نجح |
| `dart format --output=none --set-exit-if-changed .` | كشف 19 ملفًا غير منسق؛ نسخة الأداة أعادت تنسيقها |
| `flutter analyze` قبل التعديل | نجح بلا مشكلات |
| `flutter test --reporter expanded` قبل التعديل | 1/1 ناجح |
| `flutter pub outdated` | 17 اعتمادًا مباشرًا/مقيدًا أقدم من نسخة قابلة للحل، و45 اعتمادًا مقفلة على نسخ أقدم |
| `dart format lib test` | نجح؛ أصلح تنسيق 18 ملف مصدر إضافة إلى الملفات المعدلة/المضافة |
| `flutter analyze` بعد التعديل | نجح بلا أخطاء أو تحذيرات |
| `flutter test --reporter expanded` بعد التعديل | 34/34 ناجحة |
| `flutter test --coverage` | 34/34 ناجحة؛ تغطية الأسطر 5.48% (687 من 12540) |
| `flutter build apk --debug` | نجح، وتم إنشاء `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter run -d emulator-5554 --debug --no-resident` | نجح البناء والتثبيت والتشغيل على Android Emulator |
| `git diff --check` | لا توجد أخطاء whitespace؛ ظهرت تنبيهات تحويل LF/CRLF فقط |

## 3. المشكلات المكتشفة

### AILA-001 — قبول كمية سالبة لمنتج مكرر

- **المسار:** `lib/features/cart/providers/cart_provider.dart`
- **الوصف والسبب:** `addItem` كان يدمج `item.quantity` من دون رفض الصفر أو السالب؛ لذلك قد تنقص إضافة مكررة كمية موجودة، وكان `canCheckout` يقبل كمية سالبة.
- **التأثير:** حساب سلة غير صحيح وإمكانية إرسال كمية غير صالحة إلى الطلب.
- **الخطورة:** High.
- **الإصلاح:** إضافة `invalidQuantity`، رفض الكميات `<= 0`، واشتراط كمية موجبة للدفع.
- **الاختبار:** `test/unit/cart_provider_test.dart`، خصوصًا حالتا الصفر/السالب والمنتج المكرر السالب.

### AILA-002 — Race condition في البحث

- **المسار:** `lib/features/search/providers/search_provider.dart`
- **الوصف والسبب:** لم يكن هناك إلغاء منطقي للطلب السابق؛ وصول نتيجة بحث قديمة متأخرًا كان يستبدل نتيجة البحث الأحدث. كما أن `clearSearch` لم يبطل الطلب الجاري.
- **التأثير:** نتائج لا تطابق النص الحالي وحالة تحميل غير صحيحة.
- **الخطورة:** High.
- **الإصلاح:** رقم جيل لكل بحث، تجاهل الاستجابات القديمة، إلغاء debounce عند المسح والتخلص، وإرجاع قوائم غير قابلة للتعديل.
- **الاختبار:** `test/unit/search_provider_test.dart` يغطي عكس ترتيب الاستجابات والمسح أثناء الطلب.

### AILA-003 — إرسال إنشاء الطلب مرتين

- **المسار:** `lib/features/orders/providers/orders_provider.dart`
- **الوصف والسبب:** `createOrder` لم يمنع الاستدعاء الثاني أثناء بقاء الأول قيد التنفيذ.
- **التأثير:** احتمال إنشاء طلبين عند الضغط المتكرر، خصوصًا مع شبكة بطيئة.
- **الخطورة:** High.
- **الإصلاح:** تجاهل أي إرسال جديد أثناء `_isCreatingOrder`.
- **الاختبار:** `test/unit/orders_provider_test.dart` يثبت أن Repository يُستدعى مرة واحدة.

### AILA-004 — إشعار SearchProvider بعد التخلص منه

- **المسار:** `lib/features/search/providers/search_provider.dart`
- **الوصف والسبب:** التحميل غير المتزامن لسجل البحث قد يكمل بعد `dispose` ثم ينادي `notifyListeners`.
- **التأثير:** استثناء وقت التشغيل وتسريب دورة حياة في التنقل السريع.
- **الخطورة:** Medium.
- **الإصلاح:** تتبع حالة التخلص وإيقاف Timer وعدم الإشعار بعد التخلص.
- **الاختبار:** حالة التخلص قبل انتهاء debounce في `test/unit/search_provider_test.dart`.

### AILA-005 — طباعة Push tokens كاملة

- **المسارات:** `lib/core/notifications/push_notification_service.dart` و`ios/Runner/AppDelegate.swift`.
- **الوصف والسبب:** سجلات Debug كانت تحتوي FCM وAPNs tokens كاملة.
- **التأثير:** كشف credential خاص بالجهاز في السجلات أو تقارير الأعطال.
- **الخطورة:** High.
- **الإصلاح:** تسجيل وجود الرمز فقط، من دون قيمته.
- **الاختبار/التحقق:** فحص ثابت للكود، إضافة إلى نجاح تحليل وبناء Android.

### AILA-006 — عدم الالتزام بالتنسيق

- **المسار:** 18 ملف مصدر كان يحتاج تنسيقًا آليًا.
- **التأثير:** ضوضاء في diffs وصعوبة المراجعة، من دون أثر وظيفي مباشر.
- **الخطورة:** Low.
- **الإصلاح:** تشغيل `dart format lib test`.
- **التحقق:** التحليل والاختبارات بعد التنسيق ناجحة.

### AILA-007 — جلسة غير متناسقة وغياب Refresh Token

- **المسارات:** `lib/core/auth/session_store.dart` و`lib/core/api/api_client.dart` و`lib/features/auth/providers/auth_provider.dart`.
- **الوصف والسبب:** كان التطبيق يحفظ Access Token منفردًا ويمسحه عند 401 داخل Dio، بينما قد يبقى `AuthProvider` في حالة مصادق عليها. لم يكن تدوير Refresh Token أو إعادة الطلبات مدعومًا.
- **التأثير:** خروج غير متوقع كل 15 دقيقة، طلبات فاشلة، واحتمال اختلاف حالة الواجهة عن التخزين.
- **الخطورة:** High.
- **الإصلاح:** SessionStore مركزي، تخزين زوج الرموز كسجل واحد، تدوير آمن، Refresh Future واحدة للطلبات المتزامنة، إعادة كل طلب مرة واحدة، وإنهاء الجلسة idempotent عند فشل التحديث.
- **الاختبار:** `test/core/auth/session_store_test.dart` و`test/core/api/api_client_refresh_test.dart`.

## 4. الاختبارات المضافة

| الملف | ما يغطيه |
|---|---|
| `test/unit/cart_provider_test.dart` | الإضافة، الدمج، زيادة/خفض الكمية، حد المخزون، عدم التوفر، الصفر والسالب، الحذف، التفريغ، الإجماليات، وتمييز الخيارات |
| `test/unit/search_provider_test.dart` | Debounce، ترتيب استجابات معكوس، المسح أثناء الطلب، وdispose |
| `test/unit/orders_provider_test.dart` | منع إنشاء طلب مكرر أثناء الطلب الجاري |
| `test/unit/product_model_test.dart` | تحويل الأرقام والنصوص والـ booleans، القيم الناقصة، الصور التالفة، الخيارات والمخزون |
| `test/repositories/products_repository_test.dart` | query/filter/pagination، تحويل الاستجابة، الاستجابة غير الصحيحة، ومسار التفاصيل |
| `test/repositories/orders_repository_test.dart` | Payload الطلب من دون سعر/إجمالي من العميل، وقراءة pagination المتداخلة |
| `test/helpers/queue_http_adapter.dart` | HTTP fake حتمي وقابل لإعادة الاستخدام، من دون خادم حقيقي |
| `test/core/auth/session_store_test.dart` | التخزين الذري، الاستعادة، انتهاء الصلاحية، ترحيل الرمز القديم، وإنهاء الجلسة مرة واحدة |
| `test/core/api/api_client_refresh_test.dart` | 401 متزامنة، single-flight، تدوير الرمزين، إعادة الطلبات، فشل/reuse، ومنع refresh loop |

تمت إضافة **33 حالة اختبار**؛ الإجمالي الحالي **34**.

## 5. اختبارات لم يمكن تشغيلها

- **Integration/E2E:** لا يوجد مجلد `integration_test` ولا fixtures كاملة أو Backend تجريبي معزول. يلزم staging API وحسابات اختبار وبيانات منتجات/عناوين ثابتة.
- **الدفع وWebhook/Callback/Refund:** لم تُستخدم بوابة حقيقية التزامًا بالأمان. يلزم Moamalat sandbox وBackend staging للتحقق من التوقيع، idempotency، المبلغ، العملة، والتحديث مرة واحدة.
- **الخصومات وأكواد الخصم والضرائب:** لا توجد طبقة أو endpoints لهذه الوظائف في تطبيق العميل الحالي.
- **iOS:** بيئة Windows لا توفر Xcode/Simulator؛ يلزم macOS وملف Secrets محلي غير متتبع.
- **Windows:** `flutter doctor` أكد غياب Visual Studio مع Desktop C++ workload.
- **Release signing:** تم التحقق من Debug APK فقط؛ يلزم مفاتيح CI/Release المعتمدة من مسؤول النشر.

## 6. نتائج الاختبارات

- الإجمالي: **34**
- الناجحة: **34**
- الفاشلة: **0**
- المتخطاة: **0**
- نسبة النجاح: **100%**
- تغطية الأسطر: **5.48%**؛ منخفضة ولا تكفي كدليل جاهزية شامل رغم نجاح المجموعة الحالية.

## 7. المخاطر المتبقية

### High

1. **Backend خارج نطاق المستودع:** لا يمكن إثبات أن السعر والخصم والمخزون والمبلغ والعملة ونتيجة الدفع تُحسب وتُتحقق على الخادم، أو أن Webhook idempotent. اختبار الـ payload أثبت فقط أن إنشاء الطلب لا يرسل السعر/الإجمالي من العميل.
2. **Validation errors غير القياسية قد تسبب TypeError:** ما زال `auth_repository.dart` يفترض أن أول validation error قائمة نصوص.

### Medium

1. السلة غير محفوظة محليًا ولا تُستعاد بعد إعادة التشغيل.
2. `StockModel` يستخدم حدًا احتياطيًا 99 عندما `in_stock=true` و`quantity=0`؛ يجب توثيق معنى الصفر من الـ API أو عدم افتراض مخزون.
3. عدة Providers تعرض قوائمها الداخلية القابلة للتعديل مباشرة، منها Orders وWallet وWishlist.
4. طبقة المنتجات تلف كل الأخطاء داخل `Exception` عام، فتفقد نوع Dio/status code ولا تقدم سياسة موحدة لـ 400/401/403/404/422/429/500 أو retry/cancel.
5. لا توجد Integration Tests، وتغطية الأسطر 5.48% فقط.
6. لا توجد اختبارات Widget للحالات الرئيسية المطلوبة: loading/error/empty، checkout، الطلبات، العناوين، wallet وRTL على شاشة صغيرة.

### Low

1. ملفات Firebase client config متتبعة؛ هذا شائع وليس سرًا بحد ذاته، لكن يجب تقييد مفاتيح المشروع في Google Cloud/Firebase بحسب package/bundle IDs.
2. `home_screen.dart` يتجاوز 130KB ويجمع مسؤوليات UI كثيرة، ما يرفع كلفة الصيانة وإعادة البناء.
3. توجد تحديثات كثيرة للاعتماديات؛ يجب ترقيتها تدريجيًا مع CI وليس دفعة واحدة قبل النشر.

## 8. قرار الجاهزية

**يحتاج إصلاحات مهمة قبل النشر.**

تم إصلاح العيوب المؤكدة ذات الأثر المباشر، ومنها تجديد الجلسة، والتحليل والبناء والتشغيل و34 اختبارًا ناجحة. لكن لا يمكن اعتبار متجر يتضمن طلبات ومحفظة ودفع جاهزًا للنشر بتغطية منخفضة ومن دون E2E على staging أو تدقيق Backend للدفع والأسعار والـ idempotency.

## توصيات عملية بالترتيب

1. توفير Backend staging وMoamalat sandbox، ثم إضافة Integration Tests للطلب والدفع الفاشل/الناجح وWebhook المكرر.
2. إضافة persistence آمن للسلة واختبارات الاستعادة وتغير السعر/المخزون.
3. رفع تغطية Providers/Repositories/Widgets الحرجة قبل توسيع refactoring.
4. تقسيم الشاشات الضخمة تدريجيًا بعد تثبيت اختبارات السلوك.

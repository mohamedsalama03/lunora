# 🔐 Change Password — Flutter API Documentation

## نظرة عامة

يتيح هذا الـ endpoint للعميل تغيير كلمة مروره أثناء وجوده مُسجَّلاً دخولاً.  
يتطلب التحقق من كلمة المرور الحالية أولاً، ثم تُلغى جميع جلسات الأجهزة الأخرى تلقائياً لحماية الحساب.

---

## بيانات الـ Endpoint

| الخاصية      | القيمة                           |
|--------------|----------------------------------|
| **Method**   | `POST`                           |
| **URL**      | `/api/flutter/auth/change-password` |
| **Auth**     | Bearer Token ✅ (مطلوب)          |
| **Middleware** | `auth:sanctum`, `api.customer` |

---

## Request Headers

```http
POST /api/flutter/auth/change-password HTTP/1.1
Content-Type: application/json
Accept: application/json
Authorization: Bearer {access_token}
```

---

## Request Body

```json
{
  "current_password": "OldPass@123",
  "password": "NewPass@456",
  "password_confirmation": "NewPass@456"
}
```

### وصف الحقول

| الحقل                  | النوع    | مطلوب | الوصف                                                             |
|------------------------|----------|--------|-------------------------------------------------------------------|
| `current_password`     | `string` | ✅ نعم | كلمة المرور الحالية للمستخدم                                      |
| `password`             | `string` | ✅ نعم | كلمة المرور الجديدة — الحد الأدنى **8 أحرف**                     |
| `password_confirmation`| `string` | ✅ نعم | تأكيد كلمة المرور الجديدة — يجب أن تطابق `password` تماماً     |

> **ملاحظة:** قاعدة `Password::min(8)` من Laravel تقبل أي 8 أحرف أو أكثر.  
> يمكنك تشديدها لاحقاً بـ `.letters().numbers().symbols()` إن أردت.

---

## Responses

### ✅ 200 — نجاح التغيير

```json
{
  "message": "Password changed successfully."
}
```

**ماذا يحدث في الخلفية؟**
1. يتحقق السيرفر من صحة `current_password`.
2. يُحدِّث كلمة المرور في قاعدة البيانات.
3. يُلغي جميع tokens الجلسات الأخرى (الأجهزة الأخرى) ويُبقي الجلسة الحالية فعّالة.

---

### ❌ 422 — كلمة المرور الحالية خاطئة

```json
{
  "message": "The current password is incorrect.",
  "errors": {
    "current_password": ["The current password is incorrect."]
  }
}
```

---

### ❌ 422 — فشل التحقق من الصحة (Validation)

يُعيد Laravel هذا الشكل تلقائياً عند فشل أي حقل:

```json
{
  "message": "The password field must be at least 8 characters.",
  "errors": {
    "password": ["The password field must be at least 8 characters."],
    "password_confirmation": ["The password confirmation does not match."]
  }
}
```

---

### ❌ 401 — غير مُصادَق

```json
{
  "message": "Unauthenticated."
}
```

---

## 📂 كود Dart / Flutter — الربط الكامل

### 1. Repository Layer — `auth_repository.dart`

```dart
import 'package:dio/dio.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  /// تغيير كلمة المرور للعميل المُسجَّل دخولاً.
  ///
  /// يرمي [DioException] في حالة فشل الطلب.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/flutter/auth/change-password',
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      },
    );
  }
}
```

---

### 2. ViewModel / Controller — `change_password_controller.dart`

```dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../repositories/auth_repository.dart';

class ChangePasswordController extends ChangeNotifier {
  final AuthRepository _authRepository;

  ChangePasswordController(this._authRepository);

  bool isLoading = false;
  String? successMessage;
  String? errorMessage;
  Map<String, List<String>> fieldErrors = {};

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isLoading = true;
    successMessage = null;
    errorMessage = null;
    fieldErrors = {};
    notifyListeners();

    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      successMessage = 'تم تغيير كلمة المرور بنجاح.';
    } on DioException catch (e) {
      final data = e.response?.data;

      if (e.response?.statusCode == 422 && data is Map) {
        errorMessage = data['message'] as String? ?? 'حدث خطأ في التحقق.';

        // استخرج أخطاء الحقول
        final rawErrors = data['errors'] as Map<String, dynamic>?;
        if (rawErrors != null) {
          fieldErrors = rawErrors.map(
            (key, value) => MapEntry(
              key,
              (value as List).map((e) => e.toString()).toList(),
            ),
          );
        }
      } else {
        errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      }
    } catch (e) {
      errorMessage = 'خطأ في الاتصال بالسيرفر.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

---

### 3. UI Screen — `change_password_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/change_password_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<ChangePasswordController>();

    await controller.changePassword(
      currentPassword: _currentPasswordCtrl.text.trim(),
      newPassword: _newPasswordCtrl.text.trim(),
    );

    if (!mounted) return;

    if (controller.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.successMessage!),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(); // العودة للشاشة السابقة
    } else if (controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: Consumer<ChangePasswordController>(
        builder: (context, controller, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // كلمة المرور الحالية
                  TextFormField(
                    controller: _currentPasswordCtrl,
                    obscureText: _obscureCurrent,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      errorText: controller.fieldErrors['current_password']?.firstOrNull,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // كلمة المرور الجديدة
                  TextFormField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNew,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      errorText: controller.fieldErrors['password']?.firstOrNull,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                      if (v.trim().length < 8) return 'يجب أن تكون 8 أحرف على الأقل';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // تأكيد كلمة المرور
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                      if (v.trim() != _newPasswordCtrl.text.trim()) {
                        return 'كلمة المرور غير متطابقة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: controller.isLoading ? null : _submit,
                      child: controller.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('حفظ كلمة المرور الجديدة'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

---

## 🔄 تسجيل الـ Provider

أضف `ChangePasswordController` في ملف providers أو `main.dart`:

```dart
ChangeNotifierProvider(
  create: (_) => ChangePasswordController(
    AuthRepository(dio), // نفس Dio instance المُعدَّة مع Bearer token
  ),
),
```

---

## 🛡️ ملاحظات أمنية مهمة

| النقطة | التفاصيل |
|--------|----------|
| **المصادقة** | يجب إرسال `Bearer token` في كل طلب — لا يعمل بدونه |
| **إلغاء الجلسات** | عند النجاح، تُلغى جميع tokens الأجهزة الأخرى تلقائياً |
| **الجلسة الحالية** | تظل الجلسة الحالية فعّالة — لا يحتاج المستخدم لإعادة تسجيل الدخول |
| **الحد الأدنى** | 8 أحرف كحد أدنى لكلمة المرور (يمكن تشديدها من الـ controller) |
| **HTTPS** | تأكد دائماً من أن الطلبات ترسل عبر HTTPS في الإنتاج |

---

## 🧪 اختبار بـ cURL

```bash
curl -X POST https://your-domain.com/api/flutter/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "current_password": "OldPass@123",
    "password": "NewPass@456",
    "password_confirmation": "NewPass@456"
  }'
```

**ردّ النجاح المتوقع:**
```json
{
  "message": "Password changed successfully."
}
```

---

## 🗺️ الملفات المُعدَّلة في الـ Backend

| الملف | التعديل |
|-------|---------|
| `app/Http/Controllers/Api/FlutterAuthController.php` | إضافة دالة `changePassword()` |
| `routes/api.php` | إضافة `POST /api/flutter/auth/change-password` |

# 🔐 Forgot Password — Flutter API Documentation

> **Base URL:** `https://hindam.ly/api/flutter/auth/`  
> **Auth Required:** ❌ لا يحتاج token (جميع هذه الـ endpoints عامة)  
> **Content-Type:** `application/json`

---

## نظرة عامة على التدفق

```
┌────────────────────────────────────────────────────────┐
│  Step 1 — المستخدم يُدخل بريده الإلكتروني             │
│  POST /auth/forgot-password                             │
│  ← يُرسَل رمز OTP (6 أرقام) إلى البريد (10 دقائق)    │
└───────────────────────┬────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────┐
│  Step 2 — المستخدم يُدخل رمز OTP                      │
│  POST /auth/verify-reset-code                           │
│  ← يُعيد reset_token مؤقت (5 دقائق)                   │
└───────────────────────┬────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────┐
│  Step 3 — المستخدم يُدخل كلمة المرور الجديدة          │
│  POST /auth/reset-password                              │
│  ← تُحدَّث كلمة المرور وتُلغى جميع الجلسات السابقة   │
└────────────────────────────────────────────────────────┘
```

---

## Step 1 — طلب إرسال رمز OTP

### `POST /api/flutter/auth/forgot-password`

يقبل البريد الإلكتروني ويُرسل رمز OTP مكوّناً من 6 أرقام.

#### Request

```http
POST /api/flutter/auth/forgot-password
Content-Type: application/json

{
  "email": "customer@example.com"
}
```

| Field   | Type     | Required | Validation          |
|---------|----------|----------|---------------------|
| `email` | `string` | ✅        | بريد إلكتروني صحيح |

#### Responses

**`200 OK` — دائماً (حتى لو البريد غير مسجّل)**
```json
{
  "message": "If this email is registered, a reset code has been sent."
}
```

> ⚠️ الاستجابة موحّدة دائماً لحماية خصوصية المستخدمين ومنع هجمات تخمين البريد.

**`422 Unprocessable Content` — بيانات غير صحيحة**
```json
{
  "message": "The email field must be a valid email address.",
  "errors": {
    "email": ["The email field must be a valid email address."]
  }
}
```

**`429 Too Many Requests` — تجاوز الحد المسموح**
```json
{
  "message": "Too many attempts. Please try again in 9 minute(s)."
}
```

> الحد الأقصى: **3 محاولات** كل 10 دقائق لكل IP.

#### Dart Example

```dart
Future<void> sendResetCode(String email) async {
  final response = await http.post(
    Uri.parse('https://hindam.ly/api/flutter/auth/forgot-password'),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'email': email}),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 429) {
    throw Exception(data['message']); // Too many attempts
  }

  if (response.statusCode == 422) {
    throw Exception(data['errors']['email'][0]);
  }

  // 200 — دائماً نجاح، انتقل لشاشة إدخال OTP
  // message: "If this email is registered, a reset code has been sent."
}
```

---

## Step 2 — التحقق من رمز OTP

### `POST /api/flutter/auth/verify-reset-code`

يتحقق من صحة الرمز ويُعيد `reset_token` مؤقتاً لإتمام الخطوة الثالثة.

#### Request

```http
POST /api/flutter/auth/verify-reset-code
Content-Type: application/json

{
  "email": "customer@example.com",
  "otp": "847291"
}
```

| Field   | Type     | Required | Validation                    |
|---------|----------|----------|-------------------------------|
| `email` | `string` | ✅        | نفس البريد المُستخدم في Step 1 |
| `otp`   | `string` | ✅        | 6 أرقام بالضبط               |

#### Responses

**`200 OK` — الرمز صحيح ✅**
```json
{
  "message": "Code verified successfully.",
  "reset_token": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
}
```

> ⚡ احفظ `reset_token` فوراً — صلاحيته **5 دقائق فقط** ولا يمكن إعادة استخدامه.

**`422` — الرمز منتهي الصلاحية أو مستخدم من قبل**
```json
{
  "message": "The reset code is invalid or has expired.",
  "errors": {
    "otp": ["The reset code is invalid or has expired."]
  }
}
```

**`422` — الرمز خاطئ**
```json
{
  "message": "The reset code is incorrect.",
  "errors": {
    "otp": ["The reset code is incorrect."]
  }
}
```

#### Dart Example

```dart
Future<String> verifyResetCode(String email, String otp) async {
  final response = await http.post(
    Uri.parse('https://hindam.ly/api/flutter/auth/verify-reset-code'),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'email': email, 'otp': otp}),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 422) {
    final errors = data['errors'] as Map<String, dynamic>?;
    final otpErrors = errors?['otp'] as List?;
    throw Exception(otpErrors?.first ?? data['message']);
  }

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Unknown error');
  }

  return data['reset_token'] as String; // احفظه للخطوة التالية
}
```

---

## Step 3 — تعيين كلمة المرور الجديدة

### `POST /api/flutter/auth/reset-password`

يُحدِّث كلمة المرور ويُلغي جميع الجلسات السابقة.

#### Request

```http
POST /api/flutter/auth/reset-password
Content-Type: application/json

{
  "reset_token": "a1b2c3d4e5f6...",
  "password": "NewSecurePass123",
  "password_confirmation": "NewSecurePass123"
}
```

| Field                   | Type     | Required | Validation                         |
|-------------------------|----------|----------|------------------------------------|
| `reset_token`           | `string` | ✅        | الـ token المُعاد من Step 2         |
| `password`              | `string` | ✅        | 8 أحرف على الأقل                   |
| `password_confirmation` | `string` | ✅        | يجب أن يطابق `password` تماماً     |

#### Responses

**`200 OK` — تم تغيير كلمة المرور ✅**
```json
{
  "message": "Password reset successfully. Please log in again."
}
```

> بعد هذه الاستجابة:
> - ✅ كلمة المرور تم تحديثها
> - ✅ جميع Sanctum tokens السابقة تم حذفها
> - ✅ يجب على المستخدم تسجيل الدخول مجدداً

**`422` — الـ token منتهي أو غير صالح**
```json
{
  "message": "The reset token is invalid or has expired.",
  "errors": {
    "reset_token": ["The reset token is invalid or has expired."]
  }
}
```

**`422` — كلمة المرور لا تطابق التأكيد**
```json
{
  "message": "The password field confirmation does not match.",
  "errors": {
    "password": ["The password field confirmation does not match."]
  }
}
```

#### Dart Example

```dart
Future<void> resetPassword(String resetToken, String password) async {
  final response = await http.post(
    Uri.parse('https://hindam.ly/api/flutter/auth/reset-password'),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({
      'reset_token': resetToken,
      'password': password,
      'password_confirmation': password,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 422) {
    final errors = data['errors'] as Map<String, dynamic>?;
    final firstError = errors?.values.first as List?;
    throw Exception(firstError?.first ?? data['message']);
  }

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Unknown error');
  }

  // نجاح — وجّه المستخدم لشاشة تسجيل الدخول
}
```

---

## جدول HTTP Status Codes

| Code  | المعنى                                           |
|-------|--------------------------------------------------|
| `200` | ✅ العملية ناجحة                                 |
| `422` | ❌ بيانات خاطئة أو رمز/token منتهي الصلاحية     |
| `429` | ⛔ تجاوز حد الطلبات (انتظر 10 دقائق)            |
| `404` | ⚠️ المستخدم غير موجود (نادر جداً في Step 3)    |
| `500` | 🔥 خطأ داخلي في السيرفر                          |

---

## مثال كامل — Flutter Service Class

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ForgotPasswordService {
  static const String _baseUrl = 'https://hindam.ly/api/flutter/auth';

  /// Step 1: إرسال OTP إلى البريد الإلكتروني
  static Future<void> sendResetCode(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 429) {
      throw ForgotPasswordException(data['message'] as String);
    }
    if (response.statusCode == 422) {
      throw ForgotPasswordException(_extractError(data, 'email'));
    }
    // 200 دائماً — انتقل لشاشة OTP
  }

  /// Step 2: التحقق من رمز OTP والحصول على reset_token
  static Future<String> verifyCode(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verify-reset-code'),
      headers: _headers,
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 422) {
      throw ForgotPasswordException(_extractError(data, 'otp'));
    }
    if (response.statusCode != 200) {
      throw ForgotPasswordException(data['message'] as String? ?? 'Error');
    }

    return data['reset_token'] as String;
  }

  /// Step 3: تعيين كلمة المرور الجديدة
  static Future<void> resetPassword(String resetToken, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reset-password'),
      headers: _headers,
      body: jsonEncode({
        'reset_token': resetToken,
        'password': password,
        'password_confirmation': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 422) {
      throw ForgotPasswordException(_extractError(data, 'password'));
    }
    if (response.statusCode != 200) {
      throw ForgotPasswordException(data['message'] as String? ?? 'Error');
    }
    // نجاح — وجّه لشاشة Login
  }

  // ── Helpers ──────────────────────────────────────
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String _extractError(Map<String, dynamic> data, String field) {
    final errors = data['errors'] as Map<String, dynamic>?;
    final fieldErrors = errors?[field] as List?;
    return fieldErrors?.first as String? ??
        data['message'] as String? ??
        'An error occurred';
  }
}

class ForgotPasswordException implements Exception {
  final String message;
  const ForgotPasswordException(this.message);

  @override
  String toString() => message;
}
```

---

## تدفق الشاشات المقترح في Flutter

```
LoginScreen
    │
    └── "نسيت كلمة المرور؟"
            │
            ▼
    ForgotPasswordScreen          ← يحمل: email
    [POST /forgot-password]
            │
            ▼
    VerifyOtpScreen               ← يحمل: email
    [POST /verify-reset-code]
            │ ← reset_token
            ▼
    ResetPasswordScreen           ← يحمل: reset_token
    [POST /reset-password]
            │
            ▼
    LoginScreen ✅ (مع رسالة نجاح)
```

---

## ميزات الأمان المُضمَّنة

| الميزة                    | التفاصيل                                                   |
|---------------------------|------------------------------------------------------------|
| 🔒 **OTP مشفّر**          | يُخزَّن مشفَّراً بـ `bcrypt`، لا يُخزَّن نصاً صريحاً       |
| ⏱ **انتهاء الصلاحية**    | OTP ينتهي بعد **10 دقائق**، reset_token بعد **5 دقائق**   |
| 🚫 **منع إعادة الاستخدام**| بعد التحقق، يُعلَّم OTP كـ "مستخدم" ويُرفض مجدداً         |
| 🛡 **Rate Limiting**       | 3 محاولات كل 10 دقائق لكل IP                              |
| 🕵️ **Anti-Enumeration**   | نفس استجابة الـ 200 سواء كان البريد موجوداً أم لا          |
| 🔑 **إلغاء الجلسات**      | عند تغيير كلمة المرور، تُحذف جميع Sanctum tokens السابقة  |

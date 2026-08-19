import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';
import '../models/user_model.dart';
import 'dart:io' show Platform;

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
          'device_name': _getDeviceName(),
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.register,
        data: {
          'name': name,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'device_name': _getDeviceName(),
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel> getCurrentUser() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.me);
      // بناءً على وثيقة الـ API الـ Me تُرجع {'data': { ...user data... }}
      return UserModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.updateProfile,
        data: {
          'name': name,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return UserModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.changePassword,
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPasswordConfirmation,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> sendPasswordResetCode({required String email}) async {
    try {
      await apiClient.dio.post(
        ApiConstants.forgotPassword,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.verifyResetCode,
        data: {'email': email, 'otp': otp},
      );
      final resetToken = response.data['reset_token']?.toString();
      if (resetToken == null || resetToken.isEmpty) {
        throw 'تعذر التحقق من رمز الاستعادة. حاول مرة أخرى.';
      }
      return resetToken;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resetPassword({
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.resetPassword,
        data: {
          'reset_token': resetToken,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post(ApiConstants.logout);
    } on DioException catch (_) {
      // نتجاهل الخطأ في تسجيل الخروج أحياناً بحيث تُمسح التوكن محلياً على الأقل
    }
  }

  Future<void> deleteAccount({required String password}) async {
    try {
      await apiClient.dio.delete(
        ApiConstants.deleteAccount,
        data: <String, dynamic>{'password': password},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _getDeviceName() {
    try {
      if (Platform.isAndroid) return 'flutter-android';
      if (Platform.isIOS) return 'flutter-ios';
      if (Platform.isWindows) return 'flutter-windows';
      return 'flutter-app';
    } catch (_) {
      return 'flutter-web';
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;

      // Validation Errors
      if (error.response?.statusCode == 422) {
        if (data is Map && data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first as List;
          return _translateApiMessage(firstError.first.toString());
        }
        if (data is Map && data['message'] != null) {
          return _translateApiMessage(data['message'].toString());
        }
        return 'تأكد من صحة البيانات المدخلة.';
      }
      // Authentication / Authorization Errors
      else if (error.response?.statusCode == 401) {
        return _translateAuthMessage(
          data is Map ? data['message']?.toString() : null,
        );
      } else if (error.response?.statusCode == 403) {
        return data is Map && data['message'] != null
            ? _translateApiMessage(data['message'].toString())
            : 'غير مسموح لك بالوصول.';
      } else if (error.response?.statusCode == 404) {
        return 'هذه الخدمة غير متاحة حالياً على الخادم. يرجى التواصل مع إدارة المتجر لتفعيلها.';
      } else if (error.response?.statusCode == 429) {
        return _translateResetMessage(
          data is Map ? data['message']?.toString() : null,
        );
      }

      return 'حدث خطأ في الخادم (${error.response?.statusCode}). يرجى المحاولة لاحقاً.';
    } else {
      return 'لا يمكن الاتصال بالخادم. تأكد من اتصالك بالإنترنت.';
    }
  }

  String _translateAuthMessage(String? message) {
    final normalized = message?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }

    if (normalized.contains('invalid credentials') ||
        normalized.contains('unauthenticated')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }

    return message!;
  }

  String _translateApiMessage(String message) {
    final normalized = message.trim().toLowerCase();

    if (normalized.contains('password field is required')) {
      return 'يرجى إدخال كلمة المرور.';
    }

    if (normalized.contains('password') &&
        (normalized.contains('incorrect') ||
            normalized.contains('invalid') ||
            normalized.contains('does not match'))) {
      return 'كلمة المرور غير صحيحة.';
    }

    if (normalized.contains('invalid credentials') ||
        normalized.contains('invalid credential') ||
        normalized.contains('these credentials') ||
        normalized.contains('unauthenticated')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }

    if (normalized.contains('too many attempts')) {
      return 'تم تجاوز عدد المحاولات. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
    }

    if (normalized.contains('valid email')) {
      return 'يرجى إدخال بريد إلكتروني صحيح.';
    }

    if (normalized.contains('reset code is incorrect')) {
      return 'رمز التحقق غير صحيح.';
    }

    if (normalized.contains('reset code is invalid') ||
        normalized.contains('reset code') && normalized.contains('expired')) {
      return 'رمز التحقق غير صالح أو انتهت صلاحيته.';
    }

    if (normalized.contains('reset token') && normalized.contains('expired')) {
      return 'انتهت صلاحية جلسة الاستعادة. يرجى طلب رمز جديد.';
    }

    if (normalized.contains('confirmation does not match') ||
        normalized.contains('does not match')) {
      return 'كلمتا المرور غير متطابقتين.';
    }

    if (normalized.contains('password') &&
        normalized.contains('at least') &&
        normalized.contains('8')) {
      return 'كلمة المرور يجب ألا تقل عن 8 أحرف.';
    }

    return message;
  }

  String _translateResetMessage(String? message) {
    final normalized = message?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 'تم تجاوز عدد المحاولات. يرجى المحاولة لاحقاً.';
    }

    if (normalized.contains('too many attempts')) {
      return 'تم تجاوز عدد المحاولات. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
    }

    return message!;
  }
}

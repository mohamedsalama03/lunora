class ApiConstants {
  // الدومين الفعلي للسيرفر
  static const String baseUrl = 'https://lunora.ly';

  static const String apiBaseUrl = '$baseUrl/api/flutter';

  // مسارات المصادقة
  static const String register = '/api/flutter/auth/register';
  static const String login = '/api/flutter/auth/login';
  static const String refresh = '/api/flutter/auth/refresh';
  static const String me = '/api/flutter/auth/me';
  static const String logout = '/api/flutter/auth/logout';
  static const String deleteAccount = '/api/flutter/auth/account';
  static const String updateProfile = '/api/flutter/auth/profile';
  static const String changePassword = '/api/flutter/auth/change-password';
  static const String forgotPassword = '/api/flutter/auth/forgot-password';
  static const String verifyResetCode = '/api/flutter/auth/verify-reset-code';
  static const String resetPassword = '/api/flutter/auth/reset-password';
  static const String deviceToken = '/api/flutter/devices/token';
  static const String notificationsTest = '/api/flutter/notifications/test';

  // مسارات المحفظة
  static const String walletSummary = '/api/flutter/wallet';
  static const String walletTransactions = '/api/flutter/wallet/transactions';
  static const String walletTopUp = '/api/flutter/wallet/top-up';
  static const String walletMoamalatPrepare =
      '/api/flutter/wallet/top-up/moamalat/prepare';
  static const String walletMoamalatConfirm =
      '/api/flutter/wallet/top-up/moamalat/confirm';
  static const String walletMoamalatFail =
      '/api/flutter/wallet/top-up/moamalat/fail';

  // مسارات الطلبات
  static const String ordersLookups = '/api/flutter/orders/lookups';
  static const String orders = '/api/flutter/orders';
  static const String ordersMoamalatConfirm =
      '/api/flutter/orders/moamalat/confirm';
  static const String ordersMoamalatFail = '/api/flutter/orders/moamalat/fail';

  // مسارات العناوين
  static const String addressMapConfig = '/api/flutter/addresses/map-config';
  static const String addresses = '/api/flutter/addresses';
  static const String routeEstimate = '/api/flutter/routes/estimate';
}

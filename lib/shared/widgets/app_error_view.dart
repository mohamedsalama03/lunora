import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// نوع المشكلة المستنتَج من رسالة الخطأ.
enum AppErrorKind { connection, server, generic }

/// حالة خطأ أنيقة بأسلوب LUNORA تُعرض عند ضعف الإنترنت أو وجود مشكلة في الخادم.
///
/// تصنّف الخطأ تلقائياً (اتصال / خادم / عام) وتعرض أيقونة ورسالة مناسبة
/// مع زر "إعادة المحاولة". استخدمي [compact] للأقسام الداخلية الصغيرة.
class AppErrorView extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  final bool isRetrying;
  final bool compact;

  const AppErrorView({
    super.key,
    required this.onRetry,
    this.error,
    this.isRetrying = false,
    this.compact = false,
  });

  AppErrorKind get _kind {
    final value = (error ?? '').toLowerCase();
    if (value.contains('socket') ||
        value.contains('connection') ||
        value.contains('timeout') ||
        value.contains('network') ||
        value.contains('host lookup') ||
        value.contains('انترنت') ||
        value.contains('الاتصال')) {
      return AppErrorKind.connection;
    }
    if (value.contains('500') ||
        value.contains('501') ||
        value.contains('502') ||
        value.contains('503') ||
        value.contains('504') ||
        value.contains('bad response') ||
        value.contains('server') ||
        value.contains('خادم')) {
      return AppErrorKind.server;
    }
    return AppErrorKind.generic;
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String message) = switch (_kind) {
      AppErrorKind.connection => (
        AppIcons.wifi_off_rounded,
        'انقطع الاتصال',
        'يبدو أن اتصالك بالإنترنت ضعيف أو منقطع.\n'
            'تحقّقي من الشبكة ثم أعيدي المحاولة.',
      ),
      AppErrorKind.server => (
        AppIcons.warning_amber_rounded,
        'تعذّر الوصول للخادم',
        'نواجه مشكلة مؤقتة من جانبنا.\n'
            'نعتذر عن ذلك، حاولي مرة أخرى بعد قليل.',
      ),
      AppErrorKind.generic => (
        AppIcons.error_outline_rounded,
        'حدث خطأ ما',
        'تعذّر تحميل المحتوى.\nحاولي مرة أخرى من فضلك.',
      ),
    };

    final badgeSize = compact ? 84.0 : 112.0;
    final iconSize = compact ? 36.0 : 50.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.8),
                    AppColors.surface,
                  ],
                ),
                border: Border.all(
                  color: AppColors.neutral.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  const BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: iconSize, color: AppColors.accent),
            ),
            SizedBox(height: compact ? 18 : 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: compact ? 16 : 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: compact ? 12.5 : 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.65,
              ),
            ),
            SizedBox(height: compact ? 18 : 28),
            _RetryButton(
              onRetry: onRetry,
              isRetrying: isRetrying,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isRetrying;
  final bool compact;

  const _RetryButton({
    required this.onRetry,
    required this.isRetrying,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRetrying ? null : onRetry,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 22 : 28,
              vertical: compact ? 12 : 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRetrying)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surface,
                    ),
                  )
                else
                  Icon(
                    AppIcons.refresh_rounded,
                    color: AppColors.surface,
                    size: compact ? 17 : 19,
                  ),
                const SizedBox(width: 9),
                Text(
                  'إعادة المحاولة',
                  style: GoogleFonts.cairo(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// يعرض شعار المتجر المحلي لضمان ثبات هوية LUNORA في جميع الحالات.
class StoreLogo extends StatelessWidget {
  /// حجم الشعار بالـ dp.
  final double size;

  /// النص الاحتياطي الذي يظهر إذا تعذر تحميل الأصل المحلي.
  final String fallbackText;

  const StoreLogo({super.key, this.size = 48, this.fallbackText = 'LUNORA'});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          _FallbackLogo(text: fallbackText, size: size),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final String text;
  final double size;

  const _FallbackLogo({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text.isNotEmpty ? text[0] : 'L',
        style: GoogleFonts.cairo(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w600,
          color: AppColors.surface,
        ),
      ),
    );
  }
}

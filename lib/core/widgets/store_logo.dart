import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/logo_service.dart';
import '../models/logo_model.dart';
import '../theme/app_colors.dart';

/// Widget يعرض شعار المتجر من الـ API.
/// في حالة عدم وجود شعار أو حدوث خطأ يعرض النص الاحتياطي.
class StoreLogo extends StatefulWidget {
  /// حجم الشعار بالـ dp
  final double size;

  /// نص احتياطي يُعرض عند غياب الشعار
  final String fallbackText;

  const StoreLogo({super.key, this.size = 48, this.fallbackText = 'AILA'});

  @override
  State<StoreLogo> createState() => _StoreLogoState();
}

class _StoreLogoState extends State<StoreLogo> {
  late final Future<LogoModel> _logoFuture;

  @override
  void initState() {
    super.initState();
    _logoFuture = LogoService().fetchLogo();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (widget.size * devicePixelRatio).round().clamp(64, 512);

    return FutureBuilder<LogoModel>(
      future: _logoFuture,
      builder: (context, snap) {
        // حالة التحميل
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final logo = snap.data;

        // لا توجد بيانات أو لا يوجد شعار → النص الاحتياطي
        if (logo == null || !logo.hasLogo || logo.logoUrl == null) {
          return _FallbackLogo(text: widget.fallbackText, size: widget.size);
        }

        // عرض الشعار بدون كاش خارجي
        return Image.network(
          logo.logoUrl!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.low,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, url, error) =>
              _FallbackLogo(text: widget.fallbackText, size: widget.size),
        );
      },
    );
  }
}

/// الشعار الاحتياطي: مربع وردي-ذهبي مع حرف أول من النص
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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text.isNotEmpty ? text[0] : 'A',
          style: GoogleFonts.cairo(
            fontSize: size * 0.46,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

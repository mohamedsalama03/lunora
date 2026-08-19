import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Shared AILA Beauty Boutique design primitives.
///
/// These mirror the recurring building blocks of the AILA web design
/// (eyebrow labels, section headers, gradient CTAs, soft top bar) so the
/// whole Flutter app speaks the same soft-luxury visual language.

/// Tiny uppercase eyebrow label (Poppins, wide tracking) — e.g. "SOFT LUXURY
/// BEAUTY" or category kickers.
class AilaEyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;
  final double letterSpacing;

  const AilaEyebrow(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 10.5,
    this.letterSpacing = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
        color: color ?? AppColors.taupe,
        height: 1.2,
      ),
    );
  }
}

/// The "AILA ·" wordmark in Playfair Display (Latin serif).
class AilaWordmark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const AilaWordmark({
    super.key,
    this.fontSize = 26,
    this.color = AppColors.mauve,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'AILA',
          style: GoogleFonts.cairo(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: fontSize * 0.22,
            color: color,
            height: 1,
          ),
        ),
        SizedBox(width: fontSize * 0.14),
        Container(
          width: fontSize * 0.14,
          height: fontSize * 0.14,
          decoration: const BoxDecoration(
            gradient: AppColors.roseGradient,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Standard section header: bold mauve title (with optional subtitle) and an
/// optional rose-gold "عرض الكل" trailing action.
class AilaSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AilaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mauve,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.taupe,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.roseGold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-width rose-gradient pill CTA — the AILA primary action button.
class AilaGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  const AilaGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(height),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: AppColors.roseGradient,
              borderRadius: BorderRadius.circular(height),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowSoft,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.cairo(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft AILA top bar: circular back button + centered title, on a transparent
/// pearl background. Mirrors the web design's `TopBar`.
class AilaTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const AilaTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Row(
          children: [
            _CircleButton(
              icon: Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_right
                  : Icons.chevron_left,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mauve,
                ),
              ),
            ),
            if (actions.isEmpty)
              const SizedBox(width: 42)
            else
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: AppColors.shadowCard,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: AppColors.mauve),
        ),
      ),
    );
  }
}

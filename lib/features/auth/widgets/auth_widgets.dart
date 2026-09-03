import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';

/// LUNORA / Lovable auth input field — a soft rounded card with a leading
/// rose-gold icon and an inline placeholder (no separate label).
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPassword;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(widget.icon, size: 19, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              style: GoogleFonts.cairo(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: widget.hint,
                hintStyle: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textHint,
                ),
                // Override the global inputDecorationTheme (blush fill + borders)
                // so the field is clean white inside the rounded card.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (widget.isPassword)
            IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              splashRadius: 20,
              icon: Icon(
                _obscure
                    ? AppIcons.visibility_off_rounded
                    : AppIcons.visibility_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Segmented pill toggle between Sign in / Sign up (mirrors the Lovable auth
/// toggle). Tapping the inactive side runs [onTapOther] to switch screens.
class AuthModeToggle extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onTapOther;

  const AuthModeToggle({
    super.key,
    required this.isLogin,
    required this.onTapOther,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'تسجيل الدخول',
            active: isLogin,
            onTap: isLogin ? null : onTapOther,
          ),
          _Segment(
            label: 'إنشاء حساب',
            active: !isLogin,
            onTap: !isLogin ? null : onTapOther,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _Segment({required this.label, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular back button used at the top of the auth screens.
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
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
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            AppIcons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Footer terms line shown on the auth screens.
class AuthTermsFooter extends StatelessWidget {
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const AuthTermsFooter({
    super.key,
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.cairo(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      height: 1.6,
    );
    final link = GoogleFonts.cairo(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.accent,
      height: 1.6,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'بالمتابعة فأنتِ توافقين على ', style: base),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onTerms,
              child: Text('الشروط', style: link),
            ),
          ),
          TextSpan(text: ' و ', style: base),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onPrivacy,
              child: Text('الخصوصية', style: link),
            ),
          ),
          TextSpan(text: ' الخاصة بـ لونورا.', style: base),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// "or continue with" divider + Google / Apple buttons (mirrors Lovable auth).
class AuthSocialSection extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const AuthSocialSection({
    super.key,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.divider, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'أو تابعي عبر',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.divider, height: 1)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                onTap: onGoogle,
                label: 'Google',
                leading: Text(
                  'G',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                onTap: onApple,
                label: 'Apple',
                leading: const Icon(
                  // Apple is a brand mark; Lucide's apple icon is the fruit.
                  Icons.apple,
                  size: 21,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Widget leading;

  const _SocialButton({
    required this.onTap,
    required this.label,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

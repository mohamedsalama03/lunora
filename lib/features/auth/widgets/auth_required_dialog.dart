import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';

enum AuthPromptAction { login, later }

Future<AuthPromptAction?> showAuthRequiredDialog(
  BuildContext context, {
  required String title,
  required String message,
  String badge = 'الدخول اختياري الآن',
  String primaryLabel = 'تسجيل الدخول',
  String secondaryLabel = 'لاحقاً',
  bool barrierDismissible = true,
  IconData icon = AppIcons.lock_outline_rounded,
}) {
  return showGeneralDialog<AuthPromptAction>(
    context: context,
    barrierLabel: 'auth_required_dialog',
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.34),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return Directionality(
        textDirection: TextDirection.rtl,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 9 * curvedAnimation.value,
            sigmaY: 9 * curvedAnimation.value,
          ),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.94,
                end: 1,
              ).animate(curvedAnimation),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.neutral.withValues(alpha: 0.18),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.16,
                              ),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // شارة أيقونة دائرية ناعمة
                            Container(
                              width: 80,
                              height: 80,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: <Color>[
                                    AppColors.secondary.withValues(alpha: 0.85),
                                    AppColors.surface,
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.neutral.withValues(
                                    alpha: 0.30,
                                  ),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: 36,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              badge,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                                letterSpacing: 0.2,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                height: 1.75,
                              ),
                            ),
                            const SizedBox(height: 26),
                            _DialogPrimaryButton(
                              label: primaryLabel,
                              onTap: () => Navigator.of(
                                context,
                              ).pop(AuthPromptAction.login),
                            ),
                            const SizedBox(height: 6),
                            _DialogGhostButton(
                              label: secondaryLabel,
                              onTap: () => Navigator.of(
                                context,
                              ).pop(AuthPromptAction.later),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DialogPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DialogPrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DialogGhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

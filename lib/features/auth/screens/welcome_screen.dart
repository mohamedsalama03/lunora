import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// AILA Beauty Boutique — onboarding / auth gateway.
/// Soft luxury aesthetic: blush gradient, Playfair "AILA" wordmark, rose-gold ritual.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.blushGradient),
          child: Stack(
            children: [
              // Soft decorative blooms
              Positioned(
                right: -70,
                top: -40,
                child: _Bloom(
                  size: 220,
                  color: AppColors.rosePink.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                left: -50,
                bottom: 120,
                child: _Bloom(
                  size: 160,
                  color: AppColors.roseGold.withValues(alpha: 0.10),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      // Eyebrow
                      Text(
                        'SOFT LUXURY BEAUTY',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.roseGold,
                          letterSpacing: 5,
                        ),
                      ),

                      const Spacer(flex: 3),

                      // AILA wordmark
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AILA',
                            style: AppTheme.brandFont(
                              fontSize: 56,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mauve,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.roseGradient,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'la beauté en délicatesse',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: AppColors.taupe,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'مرحباً بكِ في عالم آيلا للجمال',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.7,
                        ),
                      ),

                      const Spacer(flex: 4),

                      // Primary ritual button → Login
                      _PrimaryButton(
                        label: 'ابدئي رحلتكِ',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Secondary → Register
                      _OutlinedButton(
                        label: 'إنشاء حساب جديد',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  final double size;
  final Color color;
  const _Bloom({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppColors.roseGradient,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseGold.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.pearl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: AppColors.roseGold.withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.roseGold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

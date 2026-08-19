import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../main.dart'; // للوصول لـ MainShell
import '../../../../core/utils/app_notifications.dart';
import '../../policies/screens/legal_policies_screen.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnAfterAuth;

  const LoginScreen({super.key, this.returnAfterAuth = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppNotifications.showError(
        context,
        'الرجاء إدخال البريد الإلكتروني وكلمة المرور',
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.login(email, password);
      if (!mounted) return;

      if (widget.returnAfterAuth) {
        Navigator.pop(context, true);
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    }
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _openLegal(LegalPolicyTab tab) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalPoliciesScreen(initialTab: tab)),
    );
  }

  void _socialComingSoon(String provider) {
    AppNotifications.showSuccess(
      context,
      'تسجيل الدخول عبر $provider سيتوفّر قريباً ✨',
    );
  }

  Future<void> _goToRegister() async {
    if (widget.returnAfterAuth) {
      final didAuthenticate = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const RegisterScreen(returnAfterAuth: true),
        ),
      );
      if (!mounted) return;
      if (didAuthenticate == true) Navigator.of(context).pop(true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AuthBackButton(onTap: () => Navigator.pop(context)),
                ),
                const SizedBox(height: 22),
                const AilaWordmark(fontSize: 28),
                const SizedBox(height: 24),
                Text(
                  'أهلاً بعودتكِ',
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.mauve,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سجّلي الدخول لمتابعة طقوسكِ الجمالية.',
                  style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.taupe,
                  ),
                ),
                const SizedBox(height: 22),
                AuthModeToggle(isLogin: true, onTapOther: _goToRegister),
                const SizedBox(height: 22),
                AuthField(
                  controller: _emailController,
                  hint: 'البريد الإلكتروني',
                  icon: AppIcons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _passwordController,
                  hint: 'كلمة المرور',
                  icon: AppIcons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _openForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'نسيتِ كلمة المرور؟',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.roseGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return AilaGradientButton(
                      label: 'تسجيل الدخول',
                      loading: auth.isLoading,
                      onPressed: _handleLogin,
                    );
                  },
                ),
                const SizedBox(height: 26),
                AuthSocialSection(
                  onGoogle: () => _socialComingSoon('Google'),
                  onApple: () => _socialComingSoon('Apple'),
                ),
                const SizedBox(height: 22),
                AuthTermsFooter(
                  onTerms: () => _openLegal(LegalPolicyTab.terms),
                  onPrivacy: () => _openLegal(LegalPolicyTab.privacy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

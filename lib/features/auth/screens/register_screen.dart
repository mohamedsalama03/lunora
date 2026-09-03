import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/app_notifications.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../../addresses/models/address_model.dart';
import '../../addresses/screens/address_map_screen.dart';
import '../../policies/screens/legal_policies_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool returnAfterAuth;

  const RegisterScreen({super.key, this.returnAfterAuth = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      AppNotifications.showError(context, 'الرجاء إدخال جميع الحقول المطلوبة');
      return;
    }

    if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
      AppNotifications.showError(
        context,
        'رقم الهاتف يجب أن يكون مثل 0912345678',
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.register(name, email, phone, password, password);
      if (!mounted) return;

      final shouldOpenLocation = await _askForLocationAfterRegistration();
      if (!mounted) return;

      if (shouldOpenLocation) {
        await _openLocationMapAfterRegistration();
        if (!mounted) return;
      }

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

  Future<bool> _askForLocationAfterRegistration() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.location_on_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            title: Text(
              'تحديد موقعك',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            content: Text(
              'هل تريد تحديد موقعك الآن لتسهيل عملية التوصيل، أم تفضل إضافته لاحقًا؟',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'لاحقًا',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(AppIcons.my_location_rounded, size: 18),
                label: Text(
                  'تحديد الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _openLocationMapAfterRegistration() async {
    final result = await Navigator.of(context).push<AddressModel>(
      MaterialPageRoute(builder: (_) => const AddressMapScreen()),
    );

    if (!mounted || result == null) {
      return;
    }

    AppNotifications.showSuccess(context, 'تم حفظ موقعك بنجاح');
  }

  void _openLegalScreen(LegalPolicyTab initialTab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalPoliciesScreen(initialTab: initialTab),
      ),
    );
  }

  void _socialComingSoon(String provider) {
    AppNotifications.showSuccess(
      context,
      'تسجيل الدخول عبر $provider سيتوفّر قريباً ✨',
    );
  }

  Future<void> _goToLogin() async {
    if (widget.returnAfterAuth) {
      final didAuthenticate = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnAfterAuth: true),
        ),
      );
      if (!mounted) return;
      if (didAuthenticate == true) Navigator.of(context).pop(true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
                  'أنشئي حسابكِ',
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'انضمي إلى تجربة لونورا للجمال الفاخر.',
                  style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                AuthModeToggle(isLogin: false, onTapOther: _goToLogin),
                const SizedBox(height: 22),
                AuthField(
                  controller: _nameController,
                  hint: 'الاسم الكامل',
                  icon: AppIcons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _emailController,
                  hint: 'البريد الإلكتروني',
                  icon: AppIcons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _phoneController,
                  hint: 'رقم الهاتف (0912345678)',
                  icon: AppIcons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _passwordController,
                  hint: 'كلمة المرور',
                  icon: AppIcons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegister(),
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return AilaGradientButton(
                      label: 'إنشاء حساب',
                      loading: auth.isLoading,
                      onPressed: _handleRegister,
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
                  onTerms: () => _openLegalScreen(LegalPolicyTab.terms),
                  onPrivacy: () => _openLegalScreen(LegalPolicyTab.privacy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

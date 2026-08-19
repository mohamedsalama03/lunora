import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../providers/auth_provider.dart';

enum _ResetPasswordStep { email, otp, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetPasswordStep _step = _ResetPasswordStep.email;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    switch (_step) {
      case _ResetPasswordStep.email:
        await _sendCode();
      case _ResetPasswordStep.otp:
        await _verifyCode();
      case _ResetPasswordStep.password:
        await _resetPassword();
    }
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppNotifications.showError(context, 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().repository.sendPasswordResetCode(
        email: email,
      );
      if (!mounted) return;
      setState(() => _step = _ResetPasswordStep.otp);
      AppNotifications.showSuccess(
        context,
        'إذا كان البريد مسجلاً، فسيصلك رمز الاستعادة.',
      );
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      AppNotifications.showError(context, 'يرجى إدخال رمز مكون من 6 أرقام');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await context
          .read<AuthProvider>()
          .repository
          .verifyPasswordResetCode(email: email, otp: otp);
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = _ResetPasswordStep.password;
      });
      AppNotifications.showSuccess(context, 'تم التحقق من الرمز بنجاح');
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;
    final resetToken = _resetToken;

    if (resetToken == null || resetToken.isEmpty) {
      AppNotifications.showError(
        context,
        'انتهت جلسة الاستعادة. ابدأ من جديد.',
      );
      setState(() => _step = _ResetPasswordStep.email);
      return;
    }

    if (password.length < 8) {
      AppNotifications.showError(
        context,
        'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف',
      );
      return;
    }

    if (password != confirmation) {
      AppNotifications.showError(context, 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().repository.resetPassword(
        resetToken: resetToken,
        password: password,
        passwordConfirmation: confirmation,
      );
      if (!mounted) return;
      AppNotifications.showSuccess(
        context,
        'تم تغيير كلمة المرور. يمكنك تسجيل الدخول الآن.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBackStep() {
    if (_isLoading) return;

    if (_step == _ResetPasswordStep.email) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      if (_step == _ResetPasswordStep.password) {
        _step = _ResetPasswordStep.otp;
      } else {
        _step = _ResetPasswordStep.email;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: _goBackStep,
          icon: const Icon(AppIcons.arrow_back_ios_new_rounded),
          color: AppColors.textPrimary,
        ),
        title: Text(
          'استعادة كلمة المرور',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResetProgress(step: _step),
              const SizedBox(height: 28),
              Text(
                _title,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildStepFields(),
              ),
              const SizedBox(height: 30),
              _ResetPrimaryButton(
                text: _buttonText,
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              if (_step == _ResetPasswordStep.otp) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: Text(
                      'إعادة إرسال الرمز',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepFields() {
    switch (_step) {
      case _ResetPasswordStep.email:
        return _ResetTextField(
          key: const ValueKey('email'),
          controller: _emailController,
          label: 'البريد الإلكتروني',
          hint: 'example@email.com',
          icon: AppIcons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        );
      case _ResetPasswordStep.otp:
        return _ResetTextField(
          key: const ValueKey('otp'),
          controller: _otpController,
          label: 'رمز التحقق',
          hint: '000000',
          icon: AppIcons.check_circle_outline_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        );
      case _ResetPasswordStep.password:
        return Column(
          key: const ValueKey('password'),
          children: [
            _ResetTextField(
              controller: _passwordController,
              label: 'كلمة المرور الجديدة',
              hint: '********',
              icon: AppIcons.lock_reset_rounded,
              obscureText: _obscurePassword,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(height: 18),
            _ResetTextField(
              controller: _confirmPasswordController,
              label: 'تأكيد كلمة المرور',
              hint: '********',
              icon: AppIcons.check_circle_outline_rounded,
              obscureText: _obscureConfirmPassword,
              onTogglePassword: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
          ],
        );
    }
  }

  String get _title {
    switch (_step) {
      case _ResetPasswordStep.email:
        return 'أدخل بريدك الإلكتروني';
      case _ResetPasswordStep.otp:
        return 'أدخل رمز التحقق';
      case _ResetPasswordStep.password:
        return 'عيّن كلمة مرور جديدة';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _ResetPasswordStep.email:
        return 'سنرسل رمز تحقق من 6 أرقام إلى بريدك إذا كان مسجلاً لدينا.';
      case _ResetPasswordStep.otp:
        return 'تحقق من بريدك الإلكتروني وأدخل الرمز قبل انتهاء صلاحيته.';
      case _ResetPasswordStep.password:
        return 'اختر كلمة مرور جديدة لا تقل عن 8 أحرف ثم سجّل الدخول بها.';
    }
  }

  String get _buttonText {
    switch (_step) {
      case _ResetPasswordStep.email:
        return 'إرسال الرمز';
      case _ResetPasswordStep.otp:
        return 'تحقق من الرمز';
      case _ResetPasswordStep.password:
        return 'تغيير كلمة المرور';
    }
  }
}

class _ResetProgress extends StatelessWidget {
  final _ResetPasswordStep step;

  const _ResetProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    final currentIndex = step.index;

    return Row(
      children: List.generate(3, (index) {
        final active = index <= currentIndex;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 6,
            margin: EdgeInsetsDirectional.only(end: index == 2 ? 0 : 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _ResetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final List<TextInputFormatter>? inputFormatters;

  const _ResetTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.onTogglePassword,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final isPassword = onTogglePassword != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            inputFormatters: inputFormatters,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.next,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint.withValues(alpha: 0.65),
              ),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscureText
                            ? AppIcons.visibility_off_rounded
                            : AppIcons.visibility_rounded,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetPrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ResetPrimaryButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

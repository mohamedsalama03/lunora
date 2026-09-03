import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/app_notifications.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isObscureCurrent = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;
  bool get _hasPasswordInput =>
      _currentPasswordController.text.trim().isNotEmpty ||
      _newPasswordController.text.trim().isNotEmpty ||
      _confirmPasswordController.text.trim().isNotEmpty;

  bool _hasProfileChanges(AuthProvider auth) {
    final user = auth.user;
    if (user == null) return true;

    return _nameController.text.trim() != user.name.trim() ||
        _emailController.text.trim() != user.email.trim() ||
        _phoneController.text.trim() != (user.phone ?? '').trim();
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        _nameController.text = auth.user!.name;
        _emailController.text = auth.user!.email;
        _phoneController.text = auth.user!.phone ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final repo = auth.repository;
    final shouldUpdateProfile = _hasProfileChanges(auth);
    final shouldChangePassword = _hasPasswordInput;

    if (!shouldUpdateProfile && !shouldChangePassword) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotifications.showError(context, 'لا توجد تغييرات لحفظها');
      return;
    }

    bool success = true;
    String? errorMsg;

    // 1) تحديث المعلومات الشخصية
    if (shouldUpdateProfile) {
      try {
        final updatedUser = await repo.updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        auth.updateUser(updatedUser);
      } catch (e) {
        success = false;
        errorMsg = e.toString();
      }
    }

    // 2) تغيير كلمة المرور (فقط إذا أدخل المستخدم شيئاً)
    if (success && shouldChangePassword) {
      try {
        await repo.changePassword(
          currentPassword: _currentPasswordController.text.trim(),
          newPassword: _newPasswordController.text.trim(),
          newPasswordConfirmation: _confirmPasswordController.text.trim(),
        );
      } catch (e) {
        success = false;
        errorMsg = e.toString();
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      AppNotifications.showSuccess(context, 'تم حفظ التعديلات بنجاح');
      Navigator.pop(context);
    } else {
      AppNotifications.showError(context, errorMsg ?? 'حدث خطأ غير متوقع');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _EditHeader(onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  24,
                  22,
                  24,
                  MediaQuery.viewInsetsOf(context).bottom + 28,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormSection(
                        icon: AppIcons.person_outline_rounded,
                        title: 'المعلومات الشخصية',
                        children: [
                          _BuildTextField(
                            controller: _nameController,
                            label: 'الاسم الكامل',
                            icon: AppIcons.person_outline_rounded,
                            validator: (value) =>
                                value!.isEmpty ? 'يرجى إدخال الاسم' : null,
                          ),
                          _BuildTextField(
                            controller: _emailController,
                            label: 'البريد الإلكتروني',
                            icon: AppIcons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value!.isEmpty
                                ? 'يرجى إدخال البريد الإلكتروني'
                                : null,
                          ),
                          _BuildTextField(
                            controller: _phoneController,
                            label: 'رقم الهاتف',
                            icon: AppIcons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) {
                                return 'يرجى إدخال رقم الهاتف';
                              }
                              if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
                                return 'رقم الهاتف يجب أن يكون مثل 0912345678';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _FormSection(
                        icon: AppIcons.lock_outline_rounded,
                        title: 'تغيير كلمة المرور',
                        hint: 'اتركيها فارغة إن لم ترغبي بتغييرها',
                        children: [
                          _BuildTextField(
                            controller: _currentPasswordController,
                            label: 'كلمة المرور الحالية',
                            icon: AppIcons.lock_outline_rounded,
                            isPassword: true,
                            isObscure: _isObscureCurrent,
                            onToggleVisibility: () {
                              setState(
                                () => _isObscureCurrent = !_isObscureCurrent,
                              );
                            },
                            validator: (value) {
                              if (_hasPasswordInput &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'يرجى إدخال كلمة المرور الحالية';
                              }
                              return null;
                            },
                          ),
                          _BuildTextField(
                            controller: _newPasswordController,
                            label: 'كلمة المرور الجديدة',
                            icon: AppIcons.lock_reset_rounded,
                            isPassword: true,
                            isObscure: _isObscureNew,
                            onToggleVisibility: () {
                              setState(() => _isObscureNew = !_isObscureNew);
                            },
                            validator: (value) {
                              final password = value?.trim() ?? '';
                              if (_hasPasswordInput && password.isEmpty) {
                                return 'يرجى إدخال كلمة المرور الجديدة';
                              }
                              if (password.isNotEmpty && password.length < 8) {
                                return 'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف';
                              }
                              return null;
                            },
                          ),
                          _BuildTextField(
                            controller: _confirmPasswordController,
                            label: 'تأكيد كلمة المرور الجديدة',
                            icon: AppIcons.check_circle_outline_rounded,
                            isPassword: true,
                            isObscure: _isObscureConfirm,
                            onToggleVisibility: () {
                              setState(
                                () => _isObscureConfirm = !_isObscureConfirm,
                              );
                            },
                            validator: (value) {
                              if (_hasPasswordInput &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'يرجى تأكيد كلمة المرور الجديدة';
                              }
                              if (_newPasswordController.text.isNotEmpty &&
                                  value != _newPasswordController.text) {
                                return 'كلمتا المرور غير متطابقتين';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      AilaGradientButton(
                        label: 'حفظ التعديلات',
                        icon: AppIcons.check_rounded,
                        loading: _isLoading,
                        onPressed: _handleSave,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _EditHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _EditHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 12),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final name = auth.user?.name.trim();
          final initial = (name != null && name.isNotEmpty)
              ? name.characters.first.toUpperCase()
              : 'A';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CircleButton(
                icon: AppIcons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'تعديل الحساب',
                      style: GoogleFonts.cairo(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    if (name != null && name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary,
                ),
                child: Text(
                  initial,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          );
        },
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
      color: AppColors.surface,
      shape: CircleBorder(side: BorderSide(color: AppColors.divider)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ─── Section card ──────────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final List<Widget> children;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint!,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// ─── Text field ────────────────────────────────────────────────────────────────

class _BuildTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool isObscure;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _BuildTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.isObscure = false,
    this.onToggleVisibility,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFDC2626);

    OutlineInputBorder borderWith(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
    }

    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.cairo(
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: GoogleFonts.cairo(
          color: AppColors.accent,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: GoogleFonts.cairo(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: AppColors.accent, size: 21),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? AppIcons.visibility_off_outlined
                      : AppIcons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        border: borderWith(Colors.transparent, 0),
        enabledBorder: borderWith(Colors.transparent, 0),
        focusedBorder: borderWith(AppColors.primary, 1.6),
        errorBorder: borderWith(errorColor, 1.4),
        focusedErrorBorder: borderWith(errorColor, 1.4),
        errorStyle: GoogleFonts.cairo(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: errorColor,
        ),
        errorMaxLines: 2,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/utils/app_notifications.dart';
import '../../addresses/screens/address_list_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../policies/screens/legal_policies_screen.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/wallet_screen.dart';
import 'about_app_screen.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'return_exchange_policy_screen.dart';
import 'shipping_delivery_policy_screen.dart';
import 'support_screen.dart';
import '../../orders/providers/orders_provider.dart';

/// AILA profile — rose-gradient curved header with avatar + stats, followed by
/// grouped list cards (mirrors the Lovable web design).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProfileHeader(),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MenuGroup(
                      title: 'الحساب',
                      items: [
                        _MenuRow(
                          icon: AppIcons.person_outline_rounded,
                          label: 'المعلومات الشخصية',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.shopping_bag_outlined,
                          label: 'طلباتي',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrdersScreen(),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.account_balance_wallet_outlined,
                          label: 'محفظتي',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WalletScreen(),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.location_on_outlined,
                          label: 'عناويني',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddressListScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _MenuGroup(
                      title: 'حول المتجر',
                      items: [
                        _MenuRow(
                          icon: AppIcons.headset_mic_rounded,
                          label: 'الدعم',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SupportScreen(),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.info_outline_rounded,
                          label: 'عن التطبيق',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutAppScreen(),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.privacy_tip_outlined,
                          label: 'سياسة الخصوصية',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalPoliciesScreen(
                                initialTab: LegalPolicyTab.privacy,
                              ),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.gavel_rounded,
                          label: 'الشروط والأحكام',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalPoliciesScreen(
                                initialTab: LegalPolicyTab.terms,
                              ),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.refresh_rounded,
                          label: 'سياسة الاسترجاع والاستبدال',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ReturnExchangePolicyScreen(),
                            ),
                          ),
                        ),
                        _MenuRow(
                          icon: AppIcons.local_shipping_rounded,
                          label: 'سياسة الشحن والتوصيل',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ShippingDeliveryPolicyScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _MenuGroup(
                      title: 'إدارة الحساب',
                      items: [
                        _MenuRow(
                          icon: AppIcons.logout_rounded,
                          label: 'تسجيل الخروج',
                          isDestructive: true,
                          onTap: () async {
                            await authProvider.logout();
                            if (!context.mounted) return;
                            context.read<AppShellController>().goHome();
                          },
                        ),
                        if (authProvider.isAuthenticated)
                          _MenuRow(
                            icon: AppIcons.delete_outline_rounded,
                            label: 'حذف الحساب نهائيًا',
                            isDestructive: true,
                            onTap: () async {
                              final deleted = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const _DeleteAccountDialog(),
                              );
                              if (deleted != true || !context.mounted) return;

                              context.read<AppShellController>().goHome();
                              AppNotifications.showSuccess(
                                context,
                                'تم حذف حسابك نهائيًا',
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();

  bool _isDeleting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كلمة المرور.');
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().deleteAccount(password: password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'حذف الحساب نهائيًا؟',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم حذف حسابك وبياناته نهائيًا، ولن تتمكني من استعادته بعد ذلك.',
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              enabled: !_isDeleting,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: (_) => _isDeleting ? null : _deleteAccount(),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                hintText: 'أدخلي كلمة مرور حسابك',
                prefixIcon: const Icon(AppIcons.lock_outline_rounded, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                suffixIcon: IconButton(
                  onPressed: _isDeleting
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? AppIcons.visibility_outlined
                        : AppIcons.visibility_off_outlined,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  padding: EdgeInsets.zero,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC75D6A),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: _isDeleting ? null : _deleteAccount,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC75D6A),
              foregroundColor: Colors.white,
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'حذف نهائي',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader();

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  String? _lastOrdersCountScope;

  void _loadOrdersCountFor(AuthProvider auth) {
    if (!auth.isAuthenticated) {
      _lastOrdersCountScope = null;
      return;
    }

    final user = auth.user;
    final scope = '${user?.id ?? user?.email ?? 'current'}';
    if (_lastOrdersCountScope == scope) return;
    _lastOrdersCountScope = scope;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrdersProvider>().loadTotalOrdersCount(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.viewPaddingOf(context).top;

    return Consumer3<AuthProvider, WalletProvider, OrdersProvider>(
      builder: (context, auth, wallet, orders, _) {
        _loadOrdersCountFor(auth);

        final user = auth.user;
        final userName = user?.name.trim();
        final avatarLabel = (userName != null && userName.isNotEmpty)
            ? userName.characters.first.toUpperCase()
            : 'A';

        final balance =
            wallet.summary?.balance.toStringAsFixed(2) ??
            user?.walletBalance.toStringAsFixed(2) ??
            '0.00';
        final totalOrders = orders.totalOrdersCount;
        final isLoadingOrders = orders.isLoadingOrderCounts;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 28),
          decoration: const BoxDecoration(
            gradient: AppColors.roseGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowFloat,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarLabel,
                  style: GoogleFonts.cairo(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: AppColors.roseGold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.name ?? 'مرحباً بكِ في آيلا',
                style: GoogleFonts.cairo(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user?.email ?? 'سجّلي الدخول للوصول إلى حسابك',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _HeaderStat(
                      label: 'الطلبات',
                      value: isLoadingOrders ? '...' : '$totalOrders',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeaderStat(label: 'الرصيد', value: '$balance د.ل'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final String title;
  final List<_MenuRow> items;

  const _MenuGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 10),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.taupe,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 64, left: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.blush,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFC75D6A) : AppColors.mauve;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFC75D6A).withValues(alpha: 0.10)
                      : AppColors.blush,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 19,
                  color: isDestructive
                      ? const Color(0xFFC75D6A)
                      : AppColors.roseGold,
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(
                AppIcons.arrow_forward_ios_rounded,
                color: AppColors.taupe.withValues(alpha: 0.5),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

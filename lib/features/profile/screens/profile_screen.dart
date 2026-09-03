import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../addresses/screens/address_list_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../policies/screens/legal_policies_screen.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import 'about_app_screen.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'return_exchange_policy_screen.dart';
import 'shipping_delivery_policy_screen.dart';
import 'support_screen.dart';
import '../../orders/providers/orders_provider.dart';

/// LUNORA profile with Aura's warm editorial card and grouped account actions.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProfileHeader(),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 32),
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
            fontWeight: FontWeight.w600,
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
                  color: AppColors.error,
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
              backgroundColor: AppColors.error,
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
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
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
    final savedCount = context.select<WishlistProvider, int>(
      (wishlist) => wishlist.itemCount,
    );

    return Consumer3<AuthProvider, WalletProvider, OrdersProvider>(
      builder: (context, auth, wallet, orders, _) {
        _loadOrdersCountFor(auth);

        final user = auth.user;
        final userName = user?.name.trim();
        final avatarLabel = (userName != null && userName.isNotEmpty)
            ? userName.characters.first.toUpperCase()
            : 'A';

        final balance = auth.isAuthenticated
            ? wallet.summary?.balance.toStringAsFixed(2) ??
                  user?.walletBalance.toStringAsFixed(2) ??
                  '0.00'
            : '0.00';
        final totalOrders = auth.isAuthenticated ? orders.totalOrdersCount : 0;
        final isLoadingOrders =
            auth.isAuthenticated && orders.isLoadingOrderCounts;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(24, topPad + 24, 24, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'MEMBER · LUNORA',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'مرحباً بكِ في لونورا',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? 'سجّلي الدخول للوصول إلى حسابك',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.surface.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderStat(
                        label: 'الطلبات',
                        value: isLoadingOrders ? '...' : '$totalOrders',
                      ),
                    ),
                    const _HeaderStatDivider(),
                    Expanded(
                      child: _HeaderStat(
                        label: 'الرصيد',
                        value: '$balance د.ل',
                      ),
                    ),
                    const _HeaderStatDivider(),
                    Expanded(
                      child: _HeaderStat(
                        label: 'المحفوظات',
                        value: '$savedCount',
                      ),
                    ),
                  ],
                ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
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

class _HeaderStatDivider extends StatelessWidget {
  const _HeaderStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppColors.surface.withValues(alpha: 0.18),
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.taupe,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.72),
            ),
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
                      color: AppColors.divider.withValues(alpha: 0.8),
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
    final color = isDestructive ? AppColors.error : AppColors.mauve;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.10)
                      : AppColors.blush,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 19,
                  color: isDestructive ? AppColors.error : AppColors.primary,
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
